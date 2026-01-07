/// Ingestion service for processing email replies and appending to Google Sheets

import 'package:decision_agent/data/db/app_db.dart';
import 'package:decision_agent/data/db/dao.dart';
import 'package:decision_agent/data/google/gmail_service.dart';
import 'package:decision_agent/data/google/sheets_service.dart';
import 'package:decision_agent/services/parsing_service.dart';
import 'package:decision_agent/services/logging_service.dart';
import 'package:decision_agent/domain/models.dart' as models;
import 'package:decision_agent/domain/request_schema.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

/// Result of ingestion operation
class IngestionResult {
  final int ingestedCount;
  final int errorCount;
  final List<String> errors;

  IngestionResult({
    required this.ingestedCount,
    required this.errorCount,
    required this.errors,
  });
}

/// Ingestion service for processing email replies
class IngestionService {
  final AppDatabase _db;
  final GmailService _gmailService;
  final SheetsService _sheetsService;
  final ParsingService _parsingService;
  final LoggingService _loggingService;

  IngestionService(
    this._db,
    this._gmailService,
    this._sheetsService,
    this._parsingService,
    this._loggingService,
  );

  /// Ingest responses for a request
  ///
  /// Searches Gmail for replies, parses table data, and appends to Google Sheet.
  ///
  /// [requestId] - The request ID to ingest responses for
  ///
  /// Returns IngestionResult with counts and errors
  Future<IngestionResult> ingestResponses(String requestId) async {
    final errors = <String>[];
    int ingestedCount = 0;
    int errorCount = 0;

    try {
      // Load request from database
      final request = await _db.getRequest(requestId);
      if (request == null) {
        return IngestionResult(
          ingestedCount: 0,
          errorCount: 0,
          errors: ['Request not found: $requestId'],
        );
      }

      // Get conversation to check for sheet
      final conversations = await _db.getConversations(includeArchived: true);
      final conversation = conversations.firstWhere(
        (c) => c.id == request.conversationId,
        orElse:
            () =>
                throw Exception(
                  'Conversation not found: ${request.conversationId}',
                ),
      );

      if (conversation.sheetId.isEmpty) {
        return IngestionResult(
          ingestedCount: 0,
          errorCount: 0,
          errors: ['No sheet associated with conversation'],
        );
      }

      // Load schema
      final schema = request.schema;

      // Search Gmail for replies
      final messages = await _gmailService.searchMessagesByRequestId(requestId);

      if (messages.isEmpty) {
        await _loggingService.logActivity(
          requestId,
          models.ActivityType.ingestionCheck,
          {'message': 'No replies found'},
        );
        return IngestionResult(ingestedCount: 0, errorCount: 0, errors: []);
      }

      // Filter out original request emails (from owner) and sort by timestamp (oldest first)
      // This ensures newer replies override older ones when processed sequentially
      final filteredMessages = <gmail.Message>[];
      for (final message in messages) {
        final fromEmail = _gmailService.getFromEmail(message) ?? '';
        // Skip messages from the request owner (these are the original request emails, not replies)
        if (fromEmail.toLowerCase() == request.ownerEmail.toLowerCase()) {
          continue;
        }
        filteredMessages.add(message);
      }

      // Sort by timestamp (oldest first) to ensure chronological processing
      // When processing sequentially, newer messages will override older ones
      filteredMessages.sort((a, b) {
        final timestampA = _gmailService.getInternalDate(a) ?? DateTime(1970);
        final timestampB = _gmailService.getInternalDate(b) ?? DateTime(1970);
        return timestampA.compareTo(timestampB);
      });

      if (filteredMessages.isEmpty) {
        await _loggingService.logActivity(
          requestId,
          models.ActivityType.ingestionCheck,
          {'message': 'No reply messages found (only original request emails)'},
        );
        return IngestionResult(ingestedCount: 0, errorCount: 0, errors: []);
      }

      // Process each message in chronological order
      for (final message in filteredMessages) {
        try {
          final messageId = message.id ?? '';

          // Check if already processed
          final isProcessed = await _db.isMessageProcessed(
            requestId,
            messageId,
          );
          if (isProcessed) {
            continue; // Skip already processed messages
          }

          // Extract message data
          final fromEmail = _gmailService.getFromEmail(message) ?? '';
          final timestamp = _gmailService.getInternalDate(message);
          final body = _gmailService.extractPlainTextBody(message) ?? '';

          if (body.isEmpty) {
            // Mark as processed even if body is empty to avoid reprocessing
            await _db.markMessageProcessed(requestId, messageId);
            continue; // Skip messages with no body
          }

          // Check if we should skip this message because a newer one was already processed
          final recipientStatuses = await _db.getRecipientStatuses(requestId);
          final recipientStatus =
              recipientStatuses
                  .where(
                    (s) => s.email.toLowerCase() == fromEmail.toLowerCase(),
                  )
                  .firstOrNull;
          if (recipientStatus != null &&
              recipientStatus.lastResponseAt != null &&
              timestamp != null &&
              timestamp.isBefore(recipientStatus.lastResponseAt!)) {
            // This message is older than one we've already processed for this recipient
            // Skip it to avoid overwriting newer data
            await _db.markMessageProcessed(requestId, messageId);
            continue;
          }

          // Parse the table reply
          final parseResult = _parsingService.parseTableReply(body, schema);

          // Mark message as processed BEFORE appending to sheet to prevent duplicate processing
          // This ensures that even if sheet append fails, we don't reprocess the same message
          await _db.markMessageProcessed(requestId, messageId);

          if (parseResult.success && parseResult.rows.isNotEmpty) {
            // Success: update or insert rows in sheet
            final sheetRows = <List<Object?>>[];
            for (final row in parseResult.rows) {
              // Convert row to sheet format
              final sheetRow = _convertRowToSheetFormat(
                row,
                schema,
                fromEmail,
                messageId,
                requestId,
                timestamp,
              );
              sheetRows.add(sheetRow);
            }

            // Update or insert rows (will update existing rows by fromEmail+requestId)
            await _sheetsService.updateOrInsertRows(
              conversation.sheetId,
              sheetRows,
              requestId,
            );

            // Update recipient status - parsing succeeded
            await _updateRecipientStatus(
              requestId,
              fromEmail,
              messageId,
              timestamp,
              models.RecipientState.responded,
              null, // No error - parsing succeeded
            );

            // Log success (only log parse errors if parsing actually failed)
            await _loggingService.logActivity(
              requestId,
              models.ActivityType.ingested,
              {
                'fromEmail': fromEmail,
                'messageId': messageId,
                'rowsCount': parseResult.rows.length,
                // Include warnings if any (but don't treat as errors)
                if (parseResult.errors.isNotEmpty)
                  'warnings': parseResult.errors,
              },
            );

            ingestedCount += parseResult.rows.length;
          } else {
            // Complete failure: no rows parsed
            final errorNote =
                parseResult.rawTable != null
                    ? _truncateString(parseResult.rawTable!, 500)
                    : 'Parse failed: ${parseResult.errors.join("; ")}';

            await _updateRecipientStatus(
              requestId,
              fromEmail,
              messageId,
              timestamp,
              models.RecipientState.error,
              errorNote,
            );

            // Log parse error
            await _loggingService
                .logActivity(requestId, models.ActivityType.parseError, {
                  'fromEmail': fromEmail,
                  'messageId': messageId,
                  'errors': parseResult.errors,
                });

            errorCount++;
            errors.add('$fromEmail: ${parseResult.errors.join("; ")}');
          }

          // Message already marked as processed above (before sheet append)
        } catch (e) {
          // Handle individual message processing errors
          errorCount++;
          errors.add('Error processing message: $e');
          await _loggingService.logActivity(
            requestId,
            models.ActivityType.ingestionError,
            {'error': e.toString()},
          );
        }
      }

      return IngestionResult(
        ingestedCount: ingestedCount,
        errorCount: errorCount,
        errors: errors,
      );
    } catch (e) {
      return IngestionResult(
        ingestedCount: ingestedCount,
        errorCount: errorCount,
        errors: [...errors, 'Ingestion failed: $e'],
      );
    }
  }

  /// Convert parsed row to sheet row format
  ///
  /// New format: [schema columns..., __fromEmail, __version, __receivedAt, __messageId, __requestId]
  List<Object?> _convertRowToSheetFormat(
    Map<String, dynamic> row,
    RequestSchema schema,
    String fromEmail,
    String messageId,
    String requestId,
    DateTime? timestamp,
  ) {
    final sheetRow = <Object?>[];

    // Add schema columns first
    for (final column in schema.columns) {
      final value = row[column.name];
      sheetRow.add(value);
    }

    // Add metadata columns at the end (rightmost)
    final receivedAt = timestamp ?? DateTime.now();
    sheetRow.addAll([
      fromEmail, // __fromEmail
      1, // __version (will be incremented if row exists)
      _formatRelativeTime(receivedAt), // __receivedAt (human-readable)
      messageId, // __messageId
      requestId, // __requestId
    ]);

    return sheetRow;
  }

  /// Format timestamp as human-readable relative time
  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Update recipient status
  Future<void> _updateRecipientStatus(
    String requestId,
    String email,
    String? messageId,
    DateTime? timestamp,
    models.RecipientState status,
    String? note,
  ) async {
    final recipientStatus = models.RecipientStatus(
      requestId: requestId,
      email: email,
      status: status,
      lastMessageId: messageId,
      lastResponseAt: timestamp,
      reminderSentAt: null, // Keep existing reminder time
      note: note,
    );

    await _db.upsertRecipientStatus(recipientStatus);
  }

  /// Truncate string to max length
  String _truncateString(String str, int maxLength) {
    if (str.length <= maxLength) {
      return str;
    }
    return '${str.substring(0, maxLength)}...';
  }
}
