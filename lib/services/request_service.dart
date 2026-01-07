/// Request service for creating and managing data requests

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:decision_agent/data/db/app_db.dart';
import 'package:decision_agent/data/db/dao.dart';
import 'package:decision_agent/data/google/sheets_service.dart';
import 'package:decision_agent/data/google/google_auth_service.dart';
import 'package:decision_agent/data/google/gmail_service.dart';
import 'package:decision_agent/services/logging_service.dart';
import 'package:decision_agent/domain/models.dart' as models;
import 'package:decision_agent/domain/request_schema.dart';
import 'package:decision_agent/domain/email_protocol.dart';
import 'package:decision_agent/utils/ids.dart';
import 'dart:async';
import 'dart:convert';

class RequestService {
  final AppDatabase _db;
  final SheetsService _sheetsService;
  final GoogleAuthService _authService;
  final GmailService _gmailService;
  final LoggingService _loggingService;

  RequestService(
    this._db,
    this._sheetsService,
    this._authService,
    this._gmailService,
    this._loggingService,
  );

  /// Create a new conversation
  /// Returns the conversationId
  /// If title is "New Conversation", generates a unique name like "New Conversation 2"
  Future<String> createConversation({required String title}) async {
    // If title is "New Conversation", generate a unique name
    if (title == 'New Conversation') {
      final allConversations = await _db.getConversations(
        includeArchived: true,
      );

      // Find all conversations that start with "New Conversation"
      final newConversations =
          allConversations.where((c) {
            return c.title == 'New Conversation' ||
                c.title.startsWith('New Conversation ');
          }).toList();

      // Generate unique name
      // Collect all numbers used (including base "New Conversation" as 1)
      final usedNumbers = <int>{};
      for (final conv in newConversations) {
        if (conv.title == 'New Conversation') {
          usedNumbers.add(1); // Base "New Conversation" counts as #1
        } else {
          // Extract number from "New Conversation 2", "New Conversation 3", etc.
          final match = RegExp(
            r'New Conversation (\d+)$',
          ).firstMatch(conv.title);
          if (match != null) {
            final num = int.tryParse(match.group(1) ?? '0') ?? 0;
            if (num > 0) {
              usedNumbers.add(num);
            }
          }
        }
      }

      // Find the next available number starting from 2
      // (since "New Conversation" without number is treated as #1)
      if (usedNumbers.isEmpty) {
        // No existing "New Conversation" titles, use base name
        title = 'New Conversation';
      } else {
        // Find the next available number
        int nextNumber = 2;
        while (usedNumbers.contains(nextNumber)) {
          nextNumber++;
        }
        title = 'New Conversation $nextNumber';
      }
    }

    // Generate conversation ID
    final conversationId = generateId();

    // Create conversation (sheetId and sheetUrl will be empty until sheet is created)
    await _db.insertConversation(
      ConversationsCompanion.insert(
        id: conversationId,
        kind: models.ConversationKind.sentRequest.index,
        title: title,
        sheetId: '', // Will be set when sheet is created
        sheetUrl: '', // Will be set when sheet is created
        archived: const Value(false),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return conversationId;
  }

  /// Update conversation title
  Future<void> updateConversationTitle({
    required String conversationId,
    required String title,
  }) async {
    // Get conversation
    final conversations = await _db.getConversations(includeArchived: true);
    final conversation = conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw Exception('Conversation not found: $conversationId'),
    );

    // Update conversation title
    await _db.insertConversation(
      ConversationsCompanion.insert(
        id: conversationId,
        kind: conversation.kind.index,
        title: title.trim(),
        sheetId: conversation.sheetId,
        sheetUrl: conversation.sheetUrl,
        archived: Value(conversation.archived),
        createdAt: conversation.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Create a draft request in a conversation
  /// Returns the requestId
  Future<String> createDraftRequest({
    required String conversationId,
    required String title,
    required RequestSchema schema,
    required List<String> recipients,
    required DateTime dueDate,
    String? instructions,
  }) async {
    // Generate request ID
    final requestId = generateId();

    // Get user email for ownerEmail
    final ownerEmail = await _authService.getUserEmail();

    // Create data request
    final request = models.DataRequest(
      requestId: requestId,
      conversationId: conversationId,
      title: title,
      description: instructions,
      ownerEmail: ownerEmail,
      dueAt: dueDate,
      schema: schema,
      recipients: recipients,
      isTemplate: false, // Can be marked as template later
    );

    await _db.insertRequest(request);

    return requestId;
  }

  /// Create Google Sheet for a conversation
  /// [conversationId] - Conversation ID
  /// [schema] - Request schema for headers
  /// Returns the sheet URL
  Future<String> createSheetForConversation(
    String conversationId,
    RequestSchema schema,
  ) async {
    // Get conversation from database
    final conversations = await _db.getConversations(includeArchived: true);
    final conversation = conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw Exception('Conversation not found: $conversationId'),
    );

    // If conversation already has a sheet, return it
    if (conversation.sheetId.isNotEmpty && conversation.sheetUrl.isNotEmpty) {
      return conversation.sheetUrl;
    }

    // Create sheet with conversation title
    final sheetInfo = await _sheetsService.createSheet(conversation.title);
    final sheetId = sheetInfo['sheetId'];
    final sheetUrl = sheetInfo['sheetUrl'];

    if (sheetId == null || sheetId.isEmpty) {
      throw Exception('Failed to create sheet: no sheet ID returned');
    }

    if (sheetUrl == null || sheetUrl.isEmpty) {
      throw Exception('Failed to create sheet: no sheet URL returned');
    }

    // Set up Responses tab with headers
    await _sheetsService.ensureResponsesTabAndHeaders(sheetId, schema);

    // Update conversation with sheet info
    await _db.insertConversation(
      ConversationsCompanion.insert(
        id: conversationId,
        kind: conversation.kind.index,
        title: conversation.title,
        sheetId: sheetId,
        sheetUrl: sheetUrl,
        archived: Value(conversation.archived),
        createdAt: conversation.createdAt,
        updatedAt: DateTime.now(),
      ),
    );

    return sheetUrl;
  }

  /// Validate request data
  /// Returns list of validation errors (empty if valid)
  List<String> validateRequest({
    required String title,
    required RequestSchema schema,
    required List<String> recipients,
    required DateTime dueDate,
  }) {
    final errors = <String>[];

    if (title.trim().isEmpty) {
      errors.add('Title is required');
    }

    if (schema.columns.isEmpty) {
      errors.add('At least one column is required in the schema');
    }

    for (final column in schema.columns) {
      if (column.name.trim().isEmpty) {
        errors.add('Column name cannot be empty');
      }
    }

    if (recipients.isEmpty) {
      errors.add('At least one recipient is required');
    }

    for (final recipient in recipients) {
      if (!_isValidEmail(recipient)) {
        errors.add('Invalid email address: $recipient');
      }
    }

    if (dueDate.isBefore(DateTime.now())) {
      errors.add('Due date must be in the future');
    }

    return errors;
  }

  /// Check if email is valid
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  /// Send request emails to all recipients
  /// [requestId] - Request ID to send
  /// Returns map with send results: {sent: int, failed: int, errors: List<String>}
  Future<Map<String, dynamic>> sendRequest(String requestId) async {
    // Load request from database
    final request = await _db.getRequest(requestId);
    if (request == null) {
      throw Exception('Request not found: $requestId');
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
      throw Exception('Sheet must be created before sending request');
    }

    final results = <String, dynamic>{
      'sent': 0,
      'failed': 0,
      'errors': <String>[],
    };

    // Validate schema before generating email
    if (request.schema.columns.isEmpty) {
      throw Exception(
        'Request schema is empty. Cannot send email without schema columns.',
      );
    }

    // Debug: Log schema columns to verify correctness
    debugPrint(
      'Sending request ${request.requestId} with schema columns: ${request.schema.columns.map((c) => c.name).join(", ")}',
    );

    // Generate email subject and body
    final subject = buildRequestSubjectFromId(request.requestId, request.title);
    final emailBody = buildRequestEmailBody(request);

    // Send to each recipient
    for (final recipient in request.recipients) {
      try {
        // Send email
        final messageId = await _gmailService.sendEmail(
          to: recipient,
          subject: subject,
          body: emailBody,
        );

        // Mark recipient as pending
        await _db.upsertRecipientStatus(
          models.RecipientStatus(
            requestId: requestId,
            email: recipient,
            status: models.RecipientState.pending,
            lastMessageId: messageId,
            lastResponseAt: null,
            reminderSentAt: null,
            note: null,
          ),
        );

        // Log activity
        await _loggingService.logActivity(requestId, models.ActivityType.sent, {
          'recipient': recipient,
          'messageId': messageId,
        });

        results['sent'] = (results['sent'] as int) + 1;

        // Rate limiting: 100ms delay between sends
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        // Mark recipient as bounced
        await _db.upsertRecipientStatus(
          models.RecipientStatus(
            requestId: requestId,
            email: recipient,
            status: models.RecipientState.bounced,
            lastMessageId: null,
            lastResponseAt: null,
            reminderSentAt: null,
            note: 'Send failed: $e',
          ),
        );

        // Log error
        await _loggingService.logActivity(
          requestId,
          models.ActivityType.sendError,
          {'recipient': recipient, 'error': e.toString()},
        );

        results['failed'] = (results['failed'] as int) + 1;
        (results['errors'] as List<String>).add('$recipient: $e');
      }
    }

    // Update conversation's updatedAt timestamp
    final allConversations = await _db.getConversations(includeArchived: true);
    final conversationToUpdate = allConversations.firstWhere(
      (c) => c.id == request.conversationId,
      orElse:
          () =>
              throw Exception('Conversation not found for request: $requestId'),
    );

    await _db.insertConversation(
      ConversationsCompanion.insert(
        id: conversationToUpdate.id,
        kind: conversationToUpdate.kind.index,
        title: conversationToUpdate.title,
        sheetId: conversationToUpdate.sheetId,
        sheetUrl: conversationToUpdate.sheetUrl,
        archived: Value(conversationToUpdate.archived),
        createdAt: conversationToUpdate.createdAt,
        updatedAt: DateTime.now(),
      ),
    );

    return results;
  }

  /// Create a new iteration from a template request
  ///
  /// [templateRequestId] - The template request ID to create iteration from
  /// [newDueDate] - Due date for the new iteration
  /// [reuseSheet] - If true, reuse template's sheet; if false, create new sheet
  ///
  /// Returns the new requestId
  Future<String> createIterationFromTemplate({
    required String templateRequestId,
    required DateTime newDueDate,
    bool reuseSheet = false,
  }) async {
    // Load template request
    final template = await _db.getRequest(templateRequestId);
    if (template == null) {
      throw Exception('Template request not found: $templateRequestId');
    }

    // Count existing iterations to determine iteration number
    final iterationCount = await _db.countTemplateIterations(templateRequestId);
    final iterationNumber = iterationCount + 1;

    // Generate new request ID
    final newRequestId = generateId();

    // Reuse the same conversation (iterations belong to the same conversation)
    final conversationId = template.conversationId;

    // Get conversation to check if it has a sheet
    final conversations = await _db.getConversations(includeArchived: true);
    final conversation = conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw Exception('Conversation not found: $conversationId'),
    );

    // Ensure conversation has a sheet
    if (conversation.sheetId.isEmpty) {
      await createSheetForConversation(conversationId, template.schema);
      // Get updated conversation with sheet info
      final updatedConversations = await _db.getConversations(
        includeArchived: true,
      );
      final updatedConversation = updatedConversations.firstWhere(
        (c) => c.id == conversationId,
      );
      // Verify sheet was created
      if (updatedConversation.sheetId.isEmpty) {
        throw Exception('Failed to create sheet for iteration');
      }
    }

    // Create new iteration request in the same conversation
    final iteration = models.DataRequest(
      requestId: newRequestId,
      conversationId: conversationId,
      title: template.title,
      description: template.description,
      ownerEmail: template.ownerEmail,
      dueAt: newDueDate,
      schema: template.schema,
      recipients: template.recipients,
      replyFormat: template.replyFormat,
      templateRequestId: templateRequestId,
      iterationNumber: iterationNumber,
      isTemplate: false,
    );

    await _db.insertRequest(iteration);

    return newRequestId;
  }

  /// Get all iterations for a template request
  Future<List<models.DataRequest>> getTemplateIterations(
    String templateRequestId,
  ) async {
    return await _db.getTemplateIterations(templateRequestId);
  }

  /// Mark a request as a template (for recurring requests)
  Future<void> markAsTemplate(String requestId) async {
    await _db.updateRequest(
      requestId,
      RequestsCompanion(isTemplate: const Value(true)),
    );
  }

  /// Add participants to a conversation
  /// Adds the participants to all existing requests in the conversation
  /// [conversationId] - The conversation ID
  /// [participantEmails] - List of email addresses to add
  Future<void> addParticipantsToConversation(
    String conversationId,
    List<String> participantEmails,
  ) async {
    // Get all requests for this conversation
    final requests = await _db.getRequestsByConversation(conversationId);

    if (requests.isEmpty) {
      throw Exception('No requests found in conversation');
    }

    // Add participants to each request
    for (final request in requests) {
      // Create recipient status entries for new participants
      for (final email in participantEmails) {
        // Check if participant already exists for this request
        final existingStatuses = await _db.getRecipientStatuses(
          request.requestId,
        );
        final exists = existingStatuses.any(
          (s) => s.email.toLowerCase() == email.toLowerCase(),
        );

        if (!exists) {
          // Add as pending participant
          await _db.upsertRecipientStatus(
            models.RecipientStatus(
              requestId: request.requestId,
              email: email,
              status: models.RecipientState.pending,
              lastMessageId: null,
              lastResponseAt: null,
              reminderSentAt: null,
              note: null,
            ),
          );

          // Log activity
          await _loggingService.logActivity(
            request.requestId,
            models.ActivityType.ingestionCheck,
            {'action': 'participant_added', 'email': email},
          );
        }
      }

      // Update request recipients list if needed
      final currentRecipients = request.recipients;
      final updatedRecipients = <String>[...currentRecipients];
      for (final email in participantEmails) {
        if (!updatedRecipients.any(
          (r) => r.toLowerCase() == email.toLowerCase(),
        )) {
          updatedRecipients.add(email);
        }
      }

      // Update request if recipients changed
      if (updatedRecipients.length != currentRecipients.length) {
        await _db.updateRequest(
          request.requestId,
          RequestsCompanion(
            recipientsJson: Value(jsonEncode(updatedRecipients)),
          ),
        );
      }
    }

    // Update conversation's updatedAt timestamp
    final allConversations = await _db.getConversations(includeArchived: true);
    final conversationToUpdate = allConversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw Exception('Conversation not found'),
    );

    await _db.insertConversation(
      ConversationsCompanion.insert(
        id: conversationToUpdate.id,
        kind: conversationToUpdate.kind.index,
        title: conversationToUpdate.title,
        sheetId: conversationToUpdate.sheetId,
        sheetUrl: conversationToUpdate.sheetUrl,
        archived: Value(conversationToUpdate.archived),
        createdAt: conversationToUpdate.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Remove participants from a conversation
  /// Removes the participants from all requests in the conversation
  /// [conversationId] - The conversation ID
  /// [participantEmails] - List of email addresses to remove
  Future<void> removeParticipantsFromConversation(
    String conversationId,
    List<String> participantEmails,
  ) async {
    // Get all requests for this conversation
    final requests = await _db.getRequestsByConversation(conversationId);

    // Remove participants from each request
    for (final request in requests) {
      for (final email in participantEmails) {
        // Delete recipient status entries
        await _db.deleteRecipientStatus(request.requestId, email);

        // Log activity
        await _loggingService.logActivity(
          request.requestId,
          models.ActivityType.ingestionCheck,
          {'action': 'participant_removed', 'email': email},
        );
      }

      // Update request recipients list
      final currentRecipients = request.recipients;
      final updatedRecipients =
          currentRecipients
              .where(
                (r) =>
                    !participantEmails.any(
                      (e) => e.toLowerCase() == r.toLowerCase(),
                    ),
              )
              .toList();

      // Update request if recipients changed
      if (updatedRecipients.length != currentRecipients.length) {
        await _db.updateRequest(
          request.requestId,
          RequestsCompanion(
            recipientsJson: Value(jsonEncode(updatedRecipients)),
          ),
        );
      }
    }

    // Update conversation's updatedAt timestamp
    final allConversations = await _db.getConversations(includeArchived: true);
    final conversationToUpdate = allConversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw Exception('Conversation not found'),
    );

    await _db.insertConversation(
      ConversationsCompanion.insert(
        id: conversationToUpdate.id,
        kind: conversationToUpdate.kind.index,
        title: conversationToUpdate.title,
        sheetId: conversationToUpdate.sheetId,
        sheetUrl: conversationToUpdate.sheetUrl,
        archived: Value(conversationToUpdate.archived),
        createdAt: conversationToUpdate.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }
}
