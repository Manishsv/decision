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

  Future<List<models.Conversation>> getConversations() async {
    final rows = await select(conversations).get();
    return rows.map((row) => models.Conversation(
      id: row.id,
      title: row.title,
      kind: models.ConversationKind.values[row.kind],
      requestId: row.requestId,
      status: models.RequestStatus.values[row.status],
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    )).toList();
  }

  // Requests
  Future<void> insertRequest(models.DataRequest request) async {
    final schemaJson = jsonEncode(request.schema.toJson());
    final recipientsJson = jsonEncode(request.recipients);
    
    await into(requests).insert(RequestsCompanion.insert(
      requestId: request.requestId,
      title: request.title,
      description: Value(request.description),
      ownerEmail: request.ownerEmail,
      dueAt: request.dueAt,
      schemaJson: schemaJson,
      recipientsJson: recipientsJson,
      replyFormat: Value(request.replyFormat.index),
      sheetId: request.sheetId,
      sheetUrl: request.sheetUrl,
      gmailThreadId: Value(request.gmailThreadId),
      lastIngestAt: Value(request.lastIngestAt),
    ), mode: InsertMode.replace);
  }

  Future<models.DataRequest?> getRequest(String requestId) async {
    final row = await (select(requests)..where((r) => r.requestId.equals(requestId))).getSingleOrNull();
    if (row == null) return null;

    final schema = RequestSchema.fromJson(jsonDecode(row.schemaJson) as Map<String, dynamic>);
    final recipients = (jsonDecode(row.recipientsJson) as List<dynamic>).cast<String>();

    return models.DataRequest(
      requestId: row.requestId,
      title: row.title,
      description: row.description,
      ownerEmail: row.ownerEmail,
      dueAt: row.dueAt,
      schema: schema,
      recipients: recipients,
      replyFormat: models.ReplyFormat.values[row.replyFormat],
      sheetId: row.sheetId,
      sheetUrl: row.sheetUrl,
      gmailThreadId: row.gmailThreadId,
      lastIngestAt: row.lastIngestAt,
    );
  }

  Future<void> updateRequest(String requestId, RequestsCompanion updateData) async {
    await (update(requests)..where((r) => r.requestId.equals(requestId))).write(updateData);
  }

  // Recipient Status
  Future<void> upsertRecipientStatus(models.RecipientStatus status) async {
    await into(recipientStatusTable).insert(RecipientStatusTableCompanion.insert(
      requestId: status.requestId,
      email: status.email,
      status: status.status.index,
      lastMessageId: Value(status.lastMessageId),
      lastResponseAt: Value(status.lastResponseAt),
      reminderSentAt: Value(status.reminderSentAt),
      note: Value(status.note),
    ), mode: InsertMode.replace);
  }

  Future<List<models.RecipientStatus>> getRecipientStatuses(String requestId) async {
    final rows = await (select(recipientStatusTable)..where((r) => r.requestId.equals(requestId))).get();
    return rows.map((row) => models.RecipientStatus(
      requestId: row.requestId,
      email: row.email,
      status: models.RecipientState.values[row.status],
      lastMessageId: row.lastMessageId,
      lastResponseAt: row.lastResponseAt,
      reminderSentAt: row.reminderSentAt,
      note: row.note,
    )).toList();
  }

  // Activity Log
  Future<void> insertActivityLog(models.ActivityLogEntry entry) async {
    await into(activityLog).insert(ActivityLogCompanion.insert(
      id: entry.id,
      requestId: entry.requestId,
      timestamp: entry.timestamp,
      type: entry.type.index,
      payloadJson: entry.payloadJson,
    ));
  }

  Future<List<models.ActivityLogEntry>> getActivityLogs(String requestId) async {
    final rows = await (select(activityLog)
      ..where((a) => a.requestId.equals(requestId))
      ..orderBy([(a) => OrderingTerm.desc(a.timestamp)])).get();
    
    return rows.map((row) => models.ActivityLogEntry(
      id: row.id,
      requestId: row.requestId,
      timestamp: row.timestamp,
      type: models.ActivityType.values[row.type],
      payloadJson: row.payloadJson,
    )).toList();
  }

  // Processed Messages (deduplication)
  Future<void> markMessageProcessed(String requestId, String messageId) async {
    await into(processedMessages).insert(ProcessedMessagesCompanion.insert(
      requestId: requestId,
      messageId: messageId,
    ), mode: InsertMode.replace);
  }

  Future<bool> isMessageProcessed(String requestId, String messageId) async {
    final row = await (select(processedMessages)
      ..where((p) => p.requestId.equals(requestId) & p.messageId.equals(messageId)))
      .getSingleOrNull();
    return row != null;
  }
}
