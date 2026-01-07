/// DAO (Data Access Object) methods for database operations

import 'package:drift/drift.dart';
import 'package:decision_agent/data/db/app_db.dart';
import 'dart:convert';
import 'package:decision_agent/domain/models.dart' as models;
import 'package:decision_agent/domain/request_schema.dart';

// This file will be implemented after database generation works
// For now, these are placeholder method signatures

extension AppDatabaseDao on AppDatabase {
  // Conversations
  Future<void> insertConversation(ConversationsCompanion conversation) async {
    await into(conversations).insert(conversation, mode: InsertMode.replace);
  }

  Future<List<models.Conversation>> getConversations({
    bool includeArchived = false,
  }) async {
    var query = select(conversations);
    if (!includeArchived) {
      query = query..where((c) => c.archived.equals(false));
    }
    final rows = await query.get();
    return rows
        .map(
          (row) => models.Conversation(
            id: row.id,
            title: row.title,
            kind: models.ConversationKind.values[row.kind],
            sheetId: row.sheetId,
            sheetUrl: row.sheetUrl,
            archived: row.archived,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
        )
        .toList();
  }

  Future<void> archiveConversation(String conversationId) async {
    await (update(conversations)
      ..where((c) => c.id.equals(conversationId))).write(
      ConversationsCompanion(
        archived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> unarchiveConversation(String conversationId) async {
    await (update(conversations)
      ..where((c) => c.id.equals(conversationId))).write(
      ConversationsCompanion(
        archived: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Save AI chat message
  Future<void> saveAIChatMessage({
    required String messageId,
    required String conversationId,
    required String role, // 'user' or 'assistant'
    required String content,
    DateTime? timestamp,
  }) async {
    await into(aIChatMessages).insert(
      AIChatMessagesCompanion.insert(
        id: messageId,
        conversationId: conversationId,
        role: role,
        content: content,
        timestamp: Value(timestamp ?? DateTime.now()),
      ),
      mode: InsertMode.replace,
    );
  }

  /// Get AI chat messages for a conversation, ordered by timestamp
  /// [limit] - Maximum number of messages to return (for context window management)
  Future<List<AIChatMessage>> getAIChatMessages(
    String conversationId, {
    int? limit,
  }) async {
    var query =
        select(aIChatMessages)
          ..where((tbl) => tbl.conversationId.equals(conversationId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.timestamp)]);

    if (limit != null) {
      query = query..limit(limit);
    }

    return await query.get();
  }

  /// Delete all AI chat messages for a conversation
  Future<void> deleteAIChatMessages(String conversationId) async {
    await (delete(aIChatMessages)
      ..where((tbl) => tbl.conversationId.equals(conversationId))).go();
  }

  /// Get count of AI chat messages for a conversation
  Future<int> countAIChatMessages(String conversationId) async {
    final query =
        selectOnly(aIChatMessages)
          ..addColumns([aIChatMessages.id.count()])
          ..where(aIChatMessages.conversationId.equals(conversationId));
    final result = await query.getSingle();
    return result.read(aIChatMessages.id.count()) ?? 0;
  }

  Future<void> deleteConversation(String conversationId) async {
    // Delete AI chat messages
    await deleteAIChatMessages(conversationId);
    // Get all requests for this conversation
    final conversationRequests =
        await (select(requests)
          ..where((r) => r.conversationId.equals(conversationId))).get();

    // Delete related data for each request
    for (final request in conversationRequests) {
      final requestId = request.requestId;

      // 1. Delete processed messages
      await (delete(processedMessages)
        ..where((p) => p.requestId.equals(requestId))).go();

      // 2. Delete activity logs
      await (delete(activityLog)
        ..where((a) => a.requestId.equals(requestId))).go();

      // 3. Delete recipient statuses
      await (delete(recipientStatusTable)
        ..where((r) => r.requestId.equals(requestId))).go();
    }

    // 4. Delete all requests for this conversation
    await (delete(requests)
      ..where((r) => r.conversationId.equals(conversationId))).go();

    // 5. Finally, delete the conversation
    await (delete(conversations)
      ..where((c) => c.id.equals(conversationId))).go();
  }

  // Requests
  Future<void> insertRequest(models.DataRequest request) async {
    final schemaJson = jsonEncode(request.schema.toJson());
    final recipientsJson = jsonEncode(request.recipients);

    await into(requests).insert(
      RequestsCompanion.insert(
        requestId: request.requestId,
        conversationId: request.conversationId,
        title: request.title,
        description: Value(request.description),
        ownerEmail: request.ownerEmail,
        dueAt: request.dueAt,
        schemaJson: schemaJson,
        recipientsJson: recipientsJson,
        replyFormat: Value(request.replyFormat.index),
        gmailThreadId: Value(request.gmailThreadId),
        lastIngestAt: Value(request.lastIngestAt),
        templateRequestId: Value(request.templateRequestId),
        iterationNumber: Value(request.iterationNumber),
        isTemplate: Value(request.isTemplate),
      ),
      mode: InsertMode.replace,
    );
  }

  Future<models.DataRequest?> getRequest(String requestId) async {
    final row =
        await (select(requests)
          ..where((r) => r.requestId.equals(requestId))).getSingleOrNull();
    if (row == null) return null;

    final schema = RequestSchema.fromJson(
      jsonDecode(row.schemaJson) as Map<String, dynamic>,
    );
    final recipients =
        (jsonDecode(row.recipientsJson) as List<dynamic>).cast<String>();

    return models.DataRequest(
      requestId: row.requestId,
      conversationId: row.conversationId,
      title: row.title,
      description: row.description,
      ownerEmail: row.ownerEmail,
      dueAt: row.dueAt,
      schema: schema,
      recipients: recipients,
      replyFormat: models.ReplyFormat.values[row.replyFormat],
      gmailThreadId: row.gmailThreadId,
      lastIngestAt: row.lastIngestAt,
      templateRequestId: row.templateRequestId,
      iterationNumber: row.iterationNumber,
      isTemplate: row.isTemplate,
    );
  }

  /// Get all requests for a conversation
  Future<List<models.DataRequest>> getRequestsByConversation(
    String conversationId,
  ) async {
    final rows =
        await (select(requests)
              ..where((r) => r.conversationId.equals(conversationId))
              ..orderBy([(r) => OrderingTerm.desc(r.dueAt)]))
            .get();

    return rows.map((row) {
      final schema = RequestSchema.fromJson(
        jsonDecode(row.schemaJson) as Map<String, dynamic>,
      );
      final recipients =
          (jsonDecode(row.recipientsJson) as List<dynamic>).cast<String>();

      return models.DataRequest(
        requestId: row.requestId,
        conversationId: row.conversationId,
        title: row.title,
        description: row.description,
        ownerEmail: row.ownerEmail,
        dueAt: row.dueAt,
        schema: schema,
        recipients: recipients,
        replyFormat: models.ReplyFormat.values[row.replyFormat],
        gmailThreadId: row.gmailThreadId,
        lastIngestAt: row.lastIngestAt,
        templateRequestId: row.templateRequestId,
        iterationNumber: row.iterationNumber,
        isTemplate: row.isTemplate,
      );
    }).toList();
  }

  Future<void> updateRequest(
    String requestId,
    RequestsCompanion updateData,
  ) async {
    await (update(requests)
      ..where((r) => r.requestId.equals(requestId))).write(updateData);
  }

  /// Get all iterations for a template request
  Future<List<models.DataRequest>> getTemplateIterations(
    String templateRequestId,
  ) async {
    final rows =
        await (select(requests)
              ..where((r) => r.templateRequestId.equals(templateRequestId))
              ..orderBy([(r) => OrderingTerm.asc(r.iterationNumber)]))
            .get();

    return rows.map((row) {
      final schema = RequestSchema.fromJson(
        jsonDecode(row.schemaJson) as Map<String, dynamic>,
      );
      final recipients =
          (jsonDecode(row.recipientsJson) as List<dynamic>).cast<String>();

      return models.DataRequest(
        requestId: row.requestId,
        conversationId: row.conversationId,
        title: row.title,
        description: row.description,
        ownerEmail: row.ownerEmail,
        dueAt: row.dueAt,
        schema: schema,
        recipients: recipients,
        replyFormat: models.ReplyFormat.values[row.replyFormat],
        gmailThreadId: row.gmailThreadId,
        lastIngestAt: row.lastIngestAt,
        templateRequestId: row.templateRequestId,
        iterationNumber: row.iterationNumber,
        isTemplate: row.isTemplate,
      );
    }).toList();
  }

  /// Get the template request for an iteration
  Future<models.DataRequest?> getTemplateRequest(
    String iterationRequestId,
  ) async {
    final iteration = await getRequest(iterationRequestId);
    if (iteration == null || iteration.templateRequestId == null) {
      return null;
    }
    return await getRequest(iteration.templateRequestId!);
  }

  /// Count iterations for a template
  Future<int> countTemplateIterations(String templateRequestId) async {
    final count = requests.requestId.count();
    final query =
        selectOnly(requests)
          ..addColumns([count])
          ..where(requests.templateRequestId.equals(templateRequestId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  // Recipient Status
  Future<void> upsertRecipientStatus(models.RecipientStatus status) async {
    await into(recipientStatusTable).insert(
      RecipientStatusTableCompanion.insert(
        requestId: status.requestId,
        email: status.email,
        status: status.status.index,
        lastMessageId: Value(status.lastMessageId),
        lastResponseAt: Value(status.lastResponseAt),
        reminderSentAt: Value(status.reminderSentAt),
        note: Value(status.note),
      ),
      mode: InsertMode.replace,
    );
  }

  Future<List<models.RecipientStatus>> getRecipientStatuses(
    String requestId,
  ) async {
    final rows =
        await (select(recipientStatusTable)
          ..where((r) => r.requestId.equals(requestId))).get();
    return rows
        .map(
          (row) => models.RecipientStatus(
            requestId: row.requestId,
            email: row.email,
            status: models.RecipientState.values[row.status],
            lastMessageId: row.lastMessageId,
            lastResponseAt: row.lastResponseAt,
            reminderSentAt: row.reminderSentAt,
            note: row.note,
          ),
        )
        .toList();
  }

  /// Delete a recipient status entry
  Future<void> deleteRecipientStatus(String requestId, String email) async {
    await (delete(recipientStatusTable)..where(
      (r) => r.requestId.equals(requestId) & r.email.equals(email),
    )).go();
  }

  // Activity Log
  Future<void> insertActivityLog(models.ActivityLogEntry entry) async {
    await into(activityLog).insert(
      ActivityLogCompanion.insert(
        id: entry.id,
        requestId: entry.requestId,
        timestamp: entry.timestamp,
        type: entry.type.index,
        payloadJson: entry.payloadJson,
      ),
    );
  }

  Future<List<models.ActivityLogEntry>> getActivityLogs(
    String requestId,
  ) async {
    final rows =
        await (select(activityLog)
              ..where((a) => a.requestId.equals(requestId))
              ..orderBy([(a) => OrderingTerm.desc(a.timestamp)]))
            .get();

    return rows
        .map(
          (row) => models.ActivityLogEntry(
            id: row.id,
            requestId: row.requestId,
            timestamp: row.timestamp,
            type: models.ActivityType.values[row.type],
            payloadJson: row.payloadJson,
          ),
        )
        .toList();
  }

  // Processed Messages (deduplication)
  Future<void> markMessageProcessed(String requestId, String messageId) async {
    await into(processedMessages).insert(
      ProcessedMessagesCompanion.insert(
        requestId: requestId,
        messageId: messageId,
      ),
      mode: InsertMode.replace,
    );
  }

  /// Unmark a message as processed (for reparsing)
  Future<void> unmarkMessageProcessed(
    String requestId,
    String messageId,
  ) async {
    await (delete(processedMessages)..where(
      (p) => p.requestId.equals(requestId) & p.messageId.equals(messageId),
    )).go();
  }

  Future<bool> isMessageProcessed(String requestId, String messageId) async {
    final row =
        await (select(processedMessages)..where(
          (p) => p.requestId.equals(requestId) & p.messageId.equals(messageId),
        )).getSingleOrNull();
    return row != null;
  }

  // Credentials (cross-platform secure storage)
  Future<void> saveCredential(String key, String value) async {
    await into(credentials).insert(
      CredentialsCompanion.insert(
        key: key,
        value: value,
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.replace,
    );
  }

  Future<String?> getCredential(String key) async {
    final result =
        await (select(credentials)
          ..where((t) => t.key.equals(key))).getSingleOrNull();
    return result?.value;
  }

  Future<void> deleteCredential(String key) async {
    await (delete(credentials)..where((t) => t.key.equals(key))).go();
  }
}
