/// App database using Drift

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_db.g.dart';

/// Conversations table
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get kind => integer()(); // ConversationKind enum index
  TextColumn get requestId => text()();
  IntColumn get status => integer()(); // RequestStatus enum index
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Requests table
class Requests extends Table {
  TextColumn get requestId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get ownerEmail => text()();
  DateTimeColumn get dueAt => dateTime()();
  TextColumn get schemaJson => text()(); // JSON serialized RequestSchema
  TextColumn get recipientsJson => text()(); // JSON array of emails
  IntColumn get replyFormat => integer().withDefault(const Constant(0))(); // ReplyFormat enum index
  TextColumn get sheetId => text()();
  TextColumn get sheetUrl => text()();
  TextColumn get gmailThreadId => text().nullable()();
  DateTimeColumn get lastIngestAt => dateTime().nullable()();

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
  DateTimeColumn get processedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {requestId, messageId};
}

@DriftDatabase(tables: [
  Conversations,
  Requests,
  RecipientStatusTable,
  ActivityLog,
  ProcessedMessages,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Add migrations as needed
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'decision_agent.db'));
    return NativeDatabase(file);
  });
}
