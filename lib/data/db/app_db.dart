/// App database using Drift

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

part 'app_db.g.dart';

/// Conversations table
/// Conversation is created first, multiple requests can belong to one conversation
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get kind => integer()(); // ConversationKind enum index
  TextColumn get sheetId =>
      text()(); // Sheet belongs to conversation, not request
  TextColumn get sheetUrl => text()(); // Sheet URL belongs to conversation
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Requests table
/// Multiple requests can belong to one conversation
class Requests extends Table {
  TextColumn get requestId => text()();
  TextColumn get conversationId => text()(); // Links to conversation
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get ownerEmail => text()();
  DateTimeColumn get dueAt => dateTime()();
  TextColumn get schemaJson => text()(); // JSON serialized RequestSchema
  TextColumn get recipientsJson =>
      text()(); // JSON array of emails (participants)
  IntColumn get replyFormat =>
      integer().withDefault(const Constant(0))(); // ReplyFormat enum index
  TextColumn get gmailThreadId => text().nullable()();
  DateTimeColumn get lastIngestAt => dateTime().nullable()();
  TextColumn get templateRequestId => text().nullable()(); // Links to template
  IntColumn get iterationNumber => integer().nullable()(); // 1, 2, 3, etc.
  BoolColumn get isTemplate => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {requestId};
}

/// Recipient status table
class RecipientStatusTable extends Table {
  TextColumn get requestId => text()();
  TextColumn get email => text()();
  IntColumn get status => integer()(); // RecipientState enum index
  TextColumn get lastMessageId => text().nullable()();
  DateTimeColumn get lastResponseAt => dateTime().nullable()();
  DateTimeColumn get reminderSentAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {requestId, email};
}

/// Activity log table
class ActivityLog extends Table {
  TextColumn get id => text()();
  TextColumn get requestId => text()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get type => integer()(); // ActivityType enum index
  TextColumn get payloadJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Processed messages table (for deduplication)
class ProcessedMessages extends Table {
  TextColumn get requestId => text()();
  TextColumn get messageId => text()();
  DateTimeColumn get processedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {requestId, messageId};
}

/// Credentials table for storing sensitive data (OAuth tokens, API keys, etc.)
/// Cross-platform alternative to Keychain/secure storage
class Credentials extends Table {
  TextColumn get key => text()(); // e.g., 'google_access_token', 'openai_key'
  TextColumn get value => text()(); // The actual credential value
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// AI Chat Messages table
/// Stores conversation history with the AI Agent for each conversation
class AIChatMessages extends Table {
  TextColumn get id => text()(); // Unique message ID
  TextColumn get conversationId => text()(); // Links to conversation
  TextColumn get role => text()(); // 'user' or 'assistant'
  TextColumn get content => text()(); // Message content
  TextColumn get imageBase64 =>
      text().nullable()(); // Base64-encoded image for visualizations
  TextColumn get suggestionsJson =>
      text().nullable()(); // JSON array of analysis suggestions
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Saved Analyses table
/// Stores saved Python analysis scripts for reuse
class SavedAnalyses extends Table {
  TextColumn get id => text()(); // Unique analysis ID
  TextColumn get conversationId => text()(); // Links to conversation
  TextColumn get title => text()(); // User-friendly name
  TextColumn get pythonCode => text()(); // Generated Python code
  TextColumn get analysisType => text()(); // e.g., "trend", "distribution"
  TextColumn get parametersJson =>
      text().nullable()(); // Optional parameters as JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Conversations,
    Requests,
    RecipientStatusTable,
    ActivityLog,
    ProcessedMessages,
    Credentials,
    AIChatMessages,
    SavedAnalyses,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 11; // Bumped to 11 to add suggestionsJson to AIChatMessages

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Create indexes for better query performance
        await _createIndexes(m);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add Credentials table in version 2
          await m.createTable(credentials);
        }
        if (from < 3) {
          // Add archived column to Conversations table in version 3
          await m.addColumn(conversations, conversations.archived);
        }
        if (from < 4) {
          // Add recurring request fields in version 4
          await m.addColumn(requests, requests.templateRequestId);
          await m.addColumn(requests, requests.iterationNumber);
          await m.addColumn(requests, requests.isTemplate);
        }
        if (from < 5) {
          // Migration to conversation-first model in version 5
          // Since user doesn't need data migration, we'll recreate tables cleanly
          final executor = m.database.executor;

          // Step 1: Drop and recreate conversations table with new schema
          // This removes old request_id and status columns, adds sheetId/sheetUrl
          debugPrint('Migration v5: Dropping conversations table...');
          await executor.runCustom('DROP TABLE IF EXISTS conversations;', []);
          debugPrint('Migration v5: Recreating conversations table...');
          await m.createTable(conversations);
          debugPrint('Migration v5: Conversations table recreated');
        }
        if (from < 6) {
          // Force clean database - drop and recreate all tables
          debugPrint('Migration v6: Dropping all tables for clean start...');
          final executor = m.database.executor;
          await executor.runCustom('DROP TABLE IF EXISTS conversations;', []);
          await executor.runCustom('DROP TABLE IF EXISTS requests;', []);
          await executor.runCustom(
            'DROP TABLE IF EXISTS recipient_status_table;',
            [],
          );
          await executor.runCustom('DROP TABLE IF EXISTS activity_log;', []);
          await executor.runCustom(
            'DROP TABLE IF EXISTS processed_messages;',
            [],
          );
          debugPrint('Migration v6: Recreating all tables...');
          await m.createAll();
          debugPrint('Migration v6: All tables recreated successfully');

          // Step 2: Add conversationId to Requests (if it doesn't exist)
          try {
            final requestsInfo = await executor.runSelect(
              "PRAGMA table_info(requests);",
              [],
            );
            final hasConversationId = requestsInfo.any(
              (row) =>
                  row['name']?.toString().toLowerCase() == 'conversation_id',
            );

            if (!hasConversationId) {
              await m.addColumn(requests, requests.conversationId);
            }
          } catch (e) {
            // If check fails, try adding column anyway
            try {
              await m.addColumn(requests, requests.conversationId);
            } catch (_) {}
          }

          // Step 3: No data migration needed - tables are recreated cleanly
        }
        if (from < 7) {
          // Add AI Chat Messages table in version 7
          await m.createTable(aIChatMessages);
        }
        if (from < 8) {
          // Add database indexes in version 8 for better query performance
          await _createIndexes(m);
        }
        if (from < 9) {
          // Add SavedAnalyses table in version 9
          await m.createTable(savedAnalyses);
        }
        if (from < 10) {
          // Add imageBase64 column to AIChatMessages table in version 10
          await m.addColumn(aIChatMessages, aIChatMessages.imageBase64);
        }
        if (from < 11) {
          // Add suggestionsJson column to AIChatMessages table in version 11
          await m.addColumn(aIChatMessages, aIChatMessages.suggestionsJson);
        }
      },
    );
  }

  /// Create database indexes for frequently queried columns
  /// Uses actual table names as defined in the generated Drift code
  Future<void> _createIndexes(Migrator m) async {
    final executor = m.database.executor;

    try {
      // Index on Requests.conversationId (frequently queried)
      await executor.runCustom(
        'CREATE INDEX IF NOT EXISTS idx_requests_conversation_id ON requests(conversation_id);',
        [],
      );

      // Index on Requests.templateRequestId (for iteration queries)
      await executor.runCustom(
        'CREATE INDEX IF NOT EXISTS idx_requests_template_id ON requests(template_request_id);',
        [],
      );

      // Index on RecipientStatusTable.requestId
      // Note: Actual table name is recipient_status_table (from Drift generated code)
      await executor.runCustom(
        'CREATE INDEX IF NOT EXISTS idx_recipient_status_request_id ON recipient_status_table(request_id);',
        [],
      );

      // Index on RecipientStatusTable.email (for participant lookups)
      await executor.runCustom(
        'CREATE INDEX IF NOT EXISTS idx_recipient_status_email ON recipient_status_table(email);',
        [],
      );

      // Index on ActivityLog.requestId
      await executor.runCustom(
        'CREATE INDEX IF NOT EXISTS idx_activity_log_request_id ON activity_log(request_id);',
        [],
      );

      // Index on ActivityLog.timestamp (for sorting)
      await executor.runCustom(
        'CREATE INDEX IF NOT EXISTS idx_activity_log_timestamp ON activity_log(timestamp DESC);',
        [],
      );

      // Index on AIChatMessages.conversationId
      // Note: Actual table name is a_i_chat_messages (from Drift generated code)
      await executor.runCustom(
        'CREATE INDEX IF NOT EXISTS idx_ai_chat_messages_conversation_id ON a_i_chat_messages(conversation_id);',
        [],
      );

      // Index on AIChatMessages.timestamp (for sorting)
      await executor.runCustom(
        'CREATE INDEX IF NOT EXISTS idx_ai_chat_messages_timestamp ON a_i_chat_messages(timestamp);',
        [],
      );

      // Index on ProcessedMessages.requestId (for deduplication lookups)
      await executor.runCustom(
        'CREATE INDEX IF NOT EXISTS idx_processed_messages_request_id ON processed_messages(request_id);',
        [],
      );

      // Index on Conversations.archived (for filtering)
      await executor.runCustom(
        'CREATE INDEX IF NOT EXISTS idx_conversations_archived ON conversations(archived);',
        [],
      );

      // Composite index for recipient status lookups
      await executor.runCustom(
        'CREATE INDEX IF NOT EXISTS idx_recipient_status_request_email ON recipient_status_table(request_id, email);',
        [],
      );
    } catch (e) {
      // Log error but don't fail migration - indexes are performance optimizations
      // If tables don't exist yet, indexes will be created on next migration or onCreate
      debugPrint('Warning: Could not create some indexes: $e');
      debugPrint(
        'Indexes will be created automatically when tables are created.',
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'decision_agent.db'));
    return NativeDatabase(file);
  });
}
