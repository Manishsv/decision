/// Domain models and enums for DIGIT Decision

import 'package:decision_agent/domain/request_schema.dart';

enum ConversationKind {
  sentRequest,
  receivedRequest, // Future use
}

enum RequestStatus {
  draft,
  sent,
  inProgress,
  complete,
  overdue,
}

enum ColumnType {
  stringType,
  numberType,
  dateType,
}

enum ReplyFormat {
  table,
}

enum RecipientState {
  pending,
  responded,
  error,
  bounced,
}

enum ActivityType {
  sent,
  ingested,
  parseError,
  reminderSent,
  sendError,
}

/// Core conversation entity
class Conversation {
  final String id;
  final String title;
  final ConversationKind kind;
  final String requestId;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.title,
    required this.kind,
    required this.requestId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Data request entity
class DataRequest {
  final String requestId;
  final String title;
  final String? description;
  final String ownerEmail;
  final DateTime dueAt;
  final RequestSchema schema;
  final List<String> recipients;
  final ReplyFormat replyFormat; // Always table in MVP
  final String sheetId;
  final String sheetUrl;
  final String? gmailThreadId;
  final DateTime? lastIngestAt;

  DataRequest({
    required this.requestId,
    required this.title,
    this.description,
    required this.ownerEmail,
    required this.dueAt,
    required this.schema,
    required this.recipients,
    this.replyFormat = ReplyFormat.table,
    required this.sheetId,
    required this.sheetUrl,
    this.gmailThreadId,
    this.lastIngestAt,
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
