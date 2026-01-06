/// Domain models and enums for DIGIT Decision

import 'package:decision_agent/domain/request_schema.dart';

enum ConversationKind {
  sentRequest,
  receivedRequest, // Future use
}

enum RequestStatus { draft, sent, inProgress, complete, overdue }

enum ColumnType { stringType, numberType, dateType }

enum ReplyFormat { table }

enum RecipientState { pending, responded, error, bounced }

enum ActivityType {
  sent,
  ingested,
  parseError,
  reminderSent,
  sendError,
  ingestionCheck,
  ingestionError,
}

/// Core conversation entity
/// Conversation is created first, multiple requests can belong to one conversation
class Conversation {
  final String id;
  final String title;
  final ConversationKind kind;
  final String sheetId; // Sheet belongs to conversation
  final String sheetUrl; // Sheet URL belongs to conversation
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.title,
    required this.kind,
    required this.sheetId,
    required this.sheetUrl,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Data request entity
/// Multiple requests can belong to one conversation
class DataRequest {
  final String requestId;
  final String conversationId; // Links to conversation
  final String title;
  final String? description;
  final String ownerEmail;
  final DateTime dueAt;
  final RequestSchema schema;
  final List<String> recipients; // TODO: Rename to participants in terminology
  final ReplyFormat replyFormat; // Always table in MVP
  final String? gmailThreadId;
  final DateTime? lastIngestAt;
  final String? templateRequestId; // Links to template if this is an iteration
  final int? iterationNumber; // 1, 2, 3, etc. for iterations
  final bool isTemplate; // True if this is a template for recurring requests

  DataRequest({
    required this.requestId,
    required this.conversationId,
    required this.title,
    this.description,
    required this.ownerEmail,
    required this.dueAt,
    required this.schema,
    required this.recipients,
    this.replyFormat = ReplyFormat.table,
    this.gmailThreadId,
    this.lastIngestAt,
    this.templateRequestId,
    this.iterationNumber,
    this.isTemplate = false,
  });
}

/// Recipient status tracking
class RecipientStatus {
  final String requestId;
  final String email;
  final RecipientState status;
  final String? lastMessageId;
  final DateTime? lastResponseAt;
  final DateTime? reminderSentAt;
  final String? note;

  RecipientStatus({
    required this.requestId,
    required this.email,
    required this.status,
    this.lastMessageId,
    this.lastResponseAt,
    this.reminderSentAt,
    this.note,
  });
}

/// Activity log entry
class ActivityLogEntry {
  final String id;
  final String requestId;
  final DateTime timestamp;
  final ActivityType type;
  final String payloadJson;

  ActivityLogEntry({
    required this.id,
    required this.requestId,
    required this.timestamp,
    required this.type,
    required this.payloadJson,
  });
}
