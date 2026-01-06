/// Ingestion service for processing email replies and appending to Google Sheets

import 'package:decision_agent/data/db/app_db.dart';
import 'package:decision_agent/data/db/dao.dart';
import 'package:decision_agent/data/google/gmail_service.dart';
import 'package:decision_agent/data/google/sheets_service.dart';
import 'package:decision_agent/services/parsing_service.dart';
import 'package:decision_agent/services/logging_service.dart';
import 'package:decision_agent/domain/models.dart' as models;
import 'package:decision_agent/domain/request_schema.dart';

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

      // Process each message
      for (final message in messages) {
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

          // Parse the table reply
          final parseResult = _parsingService.parseTableReply(body, schema);

          // Mark message as processed BEFORE appending to sheet to prevent duplicate processing
          // This ensures that even if sheet append fails, we don't reprocess the same message
          await _db.markMessageProcessed(requestId, messageId);

          if (parseResult.success && parseResult.rows.isNotEmpty) {
            // Success: append rows to sheet
            for (final row in parseResult.rows) {
              // Convert row to sheet format
              final sheetRow = _convertRowToSheetFormat(
                row,
                schema,
                fromEmail,
                messageId,
                timestamp,
              );

              // Append to sheet (use conversation's sheetId)
              await _sheetsService.appendRows(conversation.sheetId, [sheetRow]);
            }

            // Update recipient status - parsing succeeded
            await _updateRecipientStatus(
              requestId,
              fromEmail,
              messageId ?? '',
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
              messageId ?? '',
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
  /// Sheet format: [__receivedAt, __fromEmail, __messageId, __parseStatus, ...schema columns]
  List<Object?> _convertRowToSheetFormat(
    Map<String, dynamic> row,
    RequestSchema schema,
    String fromEmail,
    String messageId,
    DateTime? timestamp,
  ) {
    final sheetRow = <Object?>[
      timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
      fromEmail,
      messageId,
      'OK',
    ];

    // Add schema columns in order
    for (final column in schema.columns) {
      final value = row[column.name];
      sheetRow.add(value);
    }

    return sheetRow;
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
