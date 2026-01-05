// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    kind,
    requestId,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Conversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      kind:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}kind'],
          )!,
      requestId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}request_id'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}status'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final String id;
  final String title;
  final int kind;
  final String requestId;
  final int status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Conversation({
    required this.id,
    required this.title,
    required this.kind,
    required this.requestId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['kind'] = Variable<int>(kind);
    map['request_id'] = Variable<String>(requestId);
    map['status'] = Variable<int>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      title: Value(title),
      kind: Value(kind),
      requestId: Value(requestId),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      kind: serializer.fromJson<int>(json['kind']),
      requestId: serializer.fromJson<String>(json['requestId']),
      status: serializer.fromJson<int>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'kind': serializer.toJson<int>(kind),
      'requestId': serializer.toJson<String>(requestId),
      'status': serializer.toJson<int>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Conversation copyWith({
    String? id,
    String? title,
    int? kind,
    String? requestId,
    int? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Conversation(
    id: id ?? this.id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    requestId: requestId ?? this.requestId,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      kind: data.kind.present ? data.kind.value : this.kind,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('requestId: $requestId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, kind, requestId, status, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.title == this.title &&
          other.kind == this.kind &&
          other.requestId == this.requestId &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> kind;
  final Value<String> requestId;
  final Value<int> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.kind = const Value.absent(),
    this.requestId = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    required String title,
    required int kind,
    required String requestId,
    required int status,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       kind = Value(kind),
       requestId = Value(requestId),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Conversation> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? kind,
    Expression<String>? requestId,
    Expression<int>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (kind != null) 'kind': kind,
      if (requestId != null) 'request_id': requestId,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<int>? kind,
    Value<String>? requestId,
    Value<int>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      requestId: requestId ?? this.requestId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('requestId: $requestId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RequestsTable extends Requests with TableInfo<$RequestsTable, Request> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RequestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerEmailMeta = const VerificationMeta(
    'ownerEmail',
  );
  @override
  late final GeneratedColumn<String> ownerEmail = GeneratedColumn<String>(
    'owner_email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaJsonMeta = const VerificationMeta(
    'schemaJson',
  );
  @override
  late final GeneratedColumn<String> schemaJson = GeneratedColumn<String>(
    'schema_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientsJsonMeta = const VerificationMeta(
    'recipientsJson',
  );
  @override
  late final GeneratedColumn<String> recipientsJson = GeneratedColumn<String>(
    'recipients_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _replyFormatMeta = const VerificationMeta(
    'replyFormat',
  );
  @override
  late final GeneratedColumn<int> replyFormat = GeneratedColumn<int>(
    'reply_format',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sheetIdMeta = const VerificationMeta(
    'sheetId',
  );
  @override
  late final GeneratedColumn<String> sheetId = GeneratedColumn<String>(
    'sheet_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sheetUrlMeta = const VerificationMeta(
    'sheetUrl',
  );
  @override
  late final GeneratedColumn<String> sheetUrl = GeneratedColumn<String>(
    'sheet_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gmailThreadIdMeta = const VerificationMeta(
    'gmailThreadId',
  );
  @override
  late final GeneratedColumn<String> gmailThreadId = GeneratedColumn<String>(
    'gmail_thread_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastIngestAtMeta = const VerificationMeta(
    'lastIngestAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastIngestAt = GeneratedColumn<DateTime>(
    'last_ingest_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    requestId,
    title,
    description,
    ownerEmail,
    dueAt,
    schemaJson,
    recipientsJson,
    replyFormat,
    sheetId,
    sheetUrl,
    gmailThreadId,
    lastIngestAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'requests';
  @override
  VerificationContext validateIntegrity(
    Insertable<Request> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('owner_email')) {
      context.handle(
        _ownerEmailMeta,
        ownerEmail.isAcceptableOrUnknown(data['owner_email']!, _ownerEmailMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerEmailMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('schema_json')) {
      context.handle(
        _schemaJsonMeta,
        schemaJson.isAcceptableOrUnknown(data['schema_json']!, _schemaJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_schemaJsonMeta);
    }
    if (data.containsKey('recipients_json')) {
      context.handle(
        _recipientsJsonMeta,
        recipientsJson.isAcceptableOrUnknown(
          data['recipients_json']!,
          _recipientsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientsJsonMeta);
    }
    if (data.containsKey('reply_format')) {
      context.handle(
        _replyFormatMeta,
        replyFormat.isAcceptableOrUnknown(
          data['reply_format']!,
          _replyFormatMeta,
        ),
      );
    }
    if (data.containsKey('sheet_id')) {
      context.handle(
        _sheetIdMeta,
        sheetId.isAcceptableOrUnknown(data['sheet_id']!, _sheetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sheetIdMeta);
    }
    if (data.containsKey('sheet_url')) {
      context.handle(
        _sheetUrlMeta,
        sheetUrl.isAcceptableOrUnknown(data['sheet_url']!, _sheetUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sheetUrlMeta);
    }
    if (data.containsKey('gmail_thread_id')) {
      context.handle(
        _gmailThreadIdMeta,
        gmailThreadId.isAcceptableOrUnknown(
          data['gmail_thread_id']!,
          _gmailThreadIdMeta,
        ),
      );
    }
    if (data.containsKey('last_ingest_at')) {
      context.handle(
        _lastIngestAtMeta,
        lastIngestAt.isAcceptableOrUnknown(
          data['last_ingest_at']!,
          _lastIngestAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {requestId};
  @override
  Request map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Request(
      requestId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}request_id'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      ownerEmail:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}owner_email'],
          )!,
      dueAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}due_at'],
          )!,
      schemaJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}schema_json'],
          )!,
      recipientsJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}recipients_json'],
          )!,
      replyFormat:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}reply_format'],
          )!,
      sheetId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}sheet_id'],
          )!,
      sheetUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}sheet_url'],
          )!,
      gmailThreadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gmail_thread_id'],
      ),
      lastIngestAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_ingest_at'],
      ),
    );
  }

  @override
  $RequestsTable createAlias(String alias) {
    return $RequestsTable(attachedDatabase, alias);
  }
}

class Request extends DataClass implements Insertable<Request> {
  final String requestId;
  final String title;
  final String? description;
  final String ownerEmail;
  final DateTime dueAt;
  final String schemaJson;
  final String recipientsJson;
  final int replyFormat;
  final String sheetId;
  final String sheetUrl;
  final String? gmailThreadId;
  final DateTime? lastIngestAt;
  const Request({
    required this.requestId,
    required this.title,
    this.description,
    required this.ownerEmail,
    required this.dueAt,
    required this.schemaJson,
    required this.recipientsJson,
    required this.replyFormat,
    required this.sheetId,
    required this.sheetUrl,
    this.gmailThreadId,
    this.lastIngestAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['request_id'] = Variable<String>(requestId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['owner_email'] = Variable<String>(ownerEmail);
    map['due_at'] = Variable<DateTime>(dueAt);
    map['schema_json'] = Variable<String>(schemaJson);
    map['recipients_json'] = Variable<String>(recipientsJson);
    map['reply_format'] = Variable<int>(replyFormat);
    map['sheet_id'] = Variable<String>(sheetId);
    map['sheet_url'] = Variable<String>(sheetUrl);
    if (!nullToAbsent || gmailThreadId != null) {
      map['gmail_thread_id'] = Variable<String>(gmailThreadId);
    }
    if (!nullToAbsent || lastIngestAt != null) {
      map['last_ingest_at'] = Variable<DateTime>(lastIngestAt);
    }
    return map;
  }

  RequestsCompanion toCompanion(bool nullToAbsent) {
    return RequestsCompanion(
      requestId: Value(requestId),
      title: Value(title),
      description:
          description == null && nullToAbsent
              ? const Value.absent()
              : Value(description),
      ownerEmail: Value(ownerEmail),
      dueAt: Value(dueAt),
      schemaJson: Value(schemaJson),
      recipientsJson: Value(recipientsJson),
      replyFormat: Value(replyFormat),
      sheetId: Value(sheetId),
      sheetUrl: Value(sheetUrl),
      gmailThreadId:
          gmailThreadId == null && nullToAbsent
              ? const Value.absent()
              : Value(gmailThreadId),
      lastIngestAt:
          lastIngestAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastIngestAt),
    );
  }

  factory Request.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Request(
      requestId: serializer.fromJson<String>(json['requestId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      ownerEmail: serializer.fromJson<String>(json['ownerEmail']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      schemaJson: serializer.fromJson<String>(json['schemaJson']),
      recipientsJson: serializer.fromJson<String>(json['recipientsJson']),
      replyFormat: serializer.fromJson<int>(json['replyFormat']),
      sheetId: serializer.fromJson<String>(json['sheetId']),
      sheetUrl: serializer.fromJson<String>(json['sheetUrl']),
      gmailThreadId: serializer.fromJson<String?>(json['gmailThreadId']),
      lastIngestAt: serializer.fromJson<DateTime?>(json['lastIngestAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'requestId': serializer.toJson<String>(requestId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'ownerEmail': serializer.toJson<String>(ownerEmail),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'schemaJson': serializer.toJson<String>(schemaJson),
      'recipientsJson': serializer.toJson<String>(recipientsJson),
      'replyFormat': serializer.toJson<int>(replyFormat),
      'sheetId': serializer.toJson<String>(sheetId),
      'sheetUrl': serializer.toJson<String>(sheetUrl),
      'gmailThreadId': serializer.toJson<String?>(gmailThreadId),
      'lastIngestAt': serializer.toJson<DateTime?>(lastIngestAt),
    };
  }

  Request copyWith({
    String? requestId,
    String? title,
    Value<String?> description = const Value.absent(),
    String? ownerEmail,
    DateTime? dueAt,
    String? schemaJson,
    String? recipientsJson,
    int? replyFormat,
    String? sheetId,
    String? sheetUrl,
    Value<String?> gmailThreadId = const Value.absent(),
    Value<DateTime?> lastIngestAt = const Value.absent(),
  }) => Request(
    requestId: requestId ?? this.requestId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    ownerEmail: ownerEmail ?? this.ownerEmail,
    dueAt: dueAt ?? this.dueAt,
    schemaJson: schemaJson ?? this.schemaJson,
    recipientsJson: recipientsJson ?? this.recipientsJson,
    replyFormat: replyFormat ?? this.replyFormat,
    sheetId: sheetId ?? this.sheetId,
    sheetUrl: sheetUrl ?? this.sheetUrl,
    gmailThreadId:
        gmailThreadId.present ? gmailThreadId.value : this.gmailThreadId,
    lastIngestAt: lastIngestAt.present ? lastIngestAt.value : this.lastIngestAt,
  );
  Request copyWithCompanion(RequestsCompanion data) {
    return Request(
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      ownerEmail:
          data.ownerEmail.present ? data.ownerEmail.value : this.ownerEmail,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      schemaJson:
          data.schemaJson.present ? data.schemaJson.value : this.schemaJson,
      recipientsJson:
          data.recipientsJson.present
              ? data.recipientsJson.value
              : this.recipientsJson,
      replyFormat:
          data.replyFormat.present ? data.replyFormat.value : this.replyFormat,
      sheetId: data.sheetId.present ? data.sheetId.value : this.sheetId,
      sheetUrl: data.sheetUrl.present ? data.sheetUrl.value : this.sheetUrl,
      gmailThreadId:
          data.gmailThreadId.present
              ? data.gmailThreadId.value
              : this.gmailThreadId,
      lastIngestAt:
          data.lastIngestAt.present
              ? data.lastIngestAt.value
              : this.lastIngestAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Request(')
          ..write('requestId: $requestId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('ownerEmail: $ownerEmail, ')
          ..write('dueAt: $dueAt, ')
          ..write('schemaJson: $schemaJson, ')
          ..write('recipientsJson: $recipientsJson, ')
          ..write('replyFormat: $replyFormat, ')
          ..write('sheetId: $sheetId, ')
          ..write('sheetUrl: $sheetUrl, ')
          ..write('gmailThreadId: $gmailThreadId, ')
          ..write('lastIngestAt: $lastIngestAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    requestId,
    title,
    description,
    ownerEmail,
    dueAt,
    schemaJson,
    recipientsJson,
    replyFormat,
    sheetId,
    sheetUrl,
    gmailThreadId,
    lastIngestAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Request &&
          other.requestId == this.requestId &&
          other.title == this.title &&
          other.description == this.description &&
          other.ownerEmail == this.ownerEmail &&
          other.dueAt == this.dueAt &&
          other.schemaJson == this.schemaJson &&
          other.recipientsJson == this.recipientsJson &&
          other.replyFormat == this.replyFormat &&
          other.sheetId == this.sheetId &&
          other.sheetUrl == this.sheetUrl &&
          other.gmailThreadId == this.gmailThreadId &&
          other.lastIngestAt == this.lastIngestAt);
}

class RequestsCompanion extends UpdateCompanion<Request> {
  final Value<String> requestId;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> ownerEmail;
  final Value<DateTime> dueAt;
  final Value<String> schemaJson;
  final Value<String> recipientsJson;
  final Value<int> replyFormat;
  final Value<String> sheetId;
  final Value<String> sheetUrl;
  final Value<String?> gmailThreadId;
  final Value<DateTime?> lastIngestAt;
  final Value<int> rowid;
  const RequestsCompanion({
    this.requestId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.ownerEmail = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.schemaJson = const Value.absent(),
    this.recipientsJson = const Value.absent(),
    this.replyFormat = const Value.absent(),
    this.sheetId = const Value.absent(),
    this.sheetUrl = const Value.absent(),
    this.gmailThreadId = const Value.absent(),
    this.lastIngestAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RequestsCompanion.insert({
    required String requestId,
    required String title,
    this.description = const Value.absent(),
    required String ownerEmail,
    required DateTime dueAt,
    required String schemaJson,
    required String recipientsJson,
    this.replyFormat = const Value.absent(),
    required String sheetId,
    required String sheetUrl,
    this.gmailThreadId = const Value.absent(),
    this.lastIngestAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : requestId = Value(requestId),
       title = Value(title),
       ownerEmail = Value(ownerEmail),
       dueAt = Value(dueAt),
       schemaJson = Value(schemaJson),
       recipientsJson = Value(recipientsJson),
       sheetId = Value(sheetId),
       sheetUrl = Value(sheetUrl);
  static Insertable<Request> custom({
    Expression<String>? requestId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? ownerEmail,
    Expression<DateTime>? dueAt,
    Expression<String>? schemaJson,
    Expression<String>? recipientsJson,
    Expression<int>? replyFormat,
    Expression<String>? sheetId,
    Expression<String>? sheetUrl,
    Expression<String>? gmailThreadId,
    Expression<DateTime>? lastIngestAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (requestId != null) 'request_id': requestId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (ownerEmail != null) 'owner_email': ownerEmail,
      if (dueAt != null) 'due_at': dueAt,
      if (schemaJson != null) 'schema_json': schemaJson,
      if (recipientsJson != null) 'recipients_json': recipientsJson,
      if (replyFormat != null) 'reply_format': replyFormat,
      if (sheetId != null) 'sheet_id': sheetId,
      if (sheetUrl != null) 'sheet_url': sheetUrl,
      if (gmailThreadId != null) 'gmail_thread_id': gmailThreadId,
      if (lastIngestAt != null) 'last_ingest_at': lastIngestAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RequestsCompanion copyWith({
    Value<String>? requestId,
    Value<String>? title,
    Value<String?>? description,
    Value<String>? ownerEmail,
    Value<DateTime>? dueAt,
    Value<String>? schemaJson,
    Value<String>? recipientsJson,
    Value<int>? replyFormat,
    Value<String>? sheetId,
    Value<String>? sheetUrl,
    Value<String?>? gmailThreadId,
    Value<DateTime?>? lastIngestAt,
    Value<int>? rowid,
  }) {
    return RequestsCompanion(
      requestId: requestId ?? this.requestId,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      dueAt: dueAt ?? this.dueAt,
      schemaJson: schemaJson ?? this.schemaJson,
      recipientsJson: recipientsJson ?? this.recipientsJson,
      replyFormat: replyFormat ?? this.replyFormat,
      sheetId: sheetId ?? this.sheetId,
      sheetUrl: sheetUrl ?? this.sheetUrl,
      gmailThreadId: gmailThreadId ?? this.gmailThreadId,
      lastIngestAt: lastIngestAt ?? this.lastIngestAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (ownerEmail.present) {
      map['owner_email'] = Variable<String>(ownerEmail.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (schemaJson.present) {
      map['schema_json'] = Variable<String>(schemaJson.value);
    }
    if (recipientsJson.present) {
      map['recipients_json'] = Variable<String>(recipientsJson.value);
    }
    if (replyFormat.present) {
      map['reply_format'] = Variable<int>(replyFormat.value);
    }
    if (sheetId.present) {
      map['sheet_id'] = Variable<String>(sheetId.value);
    }
    if (sheetUrl.present) {
      map['sheet_url'] = Variable<String>(sheetUrl.value);
    }
    if (gmailThreadId.present) {
      map['gmail_thread_id'] = Variable<String>(gmailThreadId.value);
    }
    if (lastIngestAt.present) {
      map['last_ingest_at'] = Variable<DateTime>(lastIngestAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RequestsCompanion(')
          ..write('requestId: $requestId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('ownerEmail: $ownerEmail, ')
          ..write('dueAt: $dueAt, ')
          ..write('schemaJson: $schemaJson, ')
          ..write('recipientsJson: $recipientsJson, ')
          ..write('replyFormat: $replyFormat, ')
          ..write('sheetId: $sheetId, ')
          ..write('sheetUrl: $sheetUrl, ')
          ..write('gmailThreadId: $gmailThreadId, ')
          ..write('lastIngestAt: $lastIngestAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipientStatusTableTable extends RecipientStatusTable
    with TableInfo<$RecipientStatusTableTable, RecipientStatusTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipientStatusTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastMessageIdMeta = const VerificationMeta(
    'lastMessageId',
  );
  @override
  late final GeneratedColumn<String> lastMessageId = GeneratedColumn<String>(
    'last_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastResponseAtMeta = const VerificationMeta(
    'lastResponseAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastResponseAt =
      GeneratedColumn<DateTime>(
        'last_response_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reminderSentAtMeta = const VerificationMeta(
    'reminderSentAt',
  );
  @override
  late final GeneratedColumn<DateTime> reminderSentAt =
      GeneratedColumn<DateTime>(
        'reminder_sent_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    requestId,
    email,
    status,
    lastMessageId,
    lastResponseAt,
    reminderSentAt,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipient_status_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecipientStatusTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('last_message_id')) {
      context.handle(
        _lastMessageIdMeta,
        lastMessageId.isAcceptableOrUnknown(
          data['last_message_id']!,
          _lastMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('last_response_at')) {
      context.handle(
        _lastResponseAtMeta,
        lastResponseAt.isAcceptableOrUnknown(
          data['last_response_at']!,
          _lastResponseAtMeta,
        ),
      );
    }
    if (data.containsKey('reminder_sent_at')) {
      context.handle(
        _reminderSentAtMeta,
        reminderSentAt.isAcceptableOrUnknown(
          data['reminder_sent_at']!,
          _reminderSentAtMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {requestId, email};
  @override
  RecipientStatusTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipientStatusTableData(
      requestId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}request_id'],
          )!,
      email:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}email'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}status'],
          )!,
      lastMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_id'],
      ),
      lastResponseAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_response_at'],
      ),
      reminderSentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reminder_sent_at'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $RecipientStatusTableTable createAlias(String alias) {
    return $RecipientStatusTableTable(attachedDatabase, alias);
  }
}

class RecipientStatusTableData extends DataClass
    implements Insertable<RecipientStatusTableData> {
  final String requestId;
  final String email;
  final int status;
  final String? lastMessageId;
  final DateTime? lastResponseAt;
  final DateTime? reminderSentAt;
  final String? note;
  const RecipientStatusTableData({
    required this.requestId,
    required this.email,
    required this.status,
    this.lastMessageId,
    this.lastResponseAt,
    this.reminderSentAt,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['request_id'] = Variable<String>(requestId);
    map['email'] = Variable<String>(email);
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || lastMessageId != null) {
      map['last_message_id'] = Variable<String>(lastMessageId);
    }
    if (!nullToAbsent || lastResponseAt != null) {
      map['last_response_at'] = Variable<DateTime>(lastResponseAt);
    }
    if (!nullToAbsent || reminderSentAt != null) {
      map['reminder_sent_at'] = Variable<DateTime>(reminderSentAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  RecipientStatusTableCompanion toCompanion(bool nullToAbsent) {
    return RecipientStatusTableCompanion(
      requestId: Value(requestId),
      email: Value(email),
      status: Value(status),
      lastMessageId:
          lastMessageId == null && nullToAbsent
              ? const Value.absent()
              : Value(lastMessageId),
      lastResponseAt:
          lastResponseAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastResponseAt),
      reminderSentAt:
          reminderSentAt == null && nullToAbsent
              ? const Value.absent()
              : Value(reminderSentAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory RecipientStatusTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipientStatusTableData(
      requestId: serializer.fromJson<String>(json['requestId']),
      email: serializer.fromJson<String>(json['email']),
      status: serializer.fromJson<int>(json['status']),
      lastMessageId: serializer.fromJson<String?>(json['lastMessageId']),
      lastResponseAt: serializer.fromJson<DateTime?>(json['lastResponseAt']),
      reminderSentAt: serializer.fromJson<DateTime?>(json['reminderSentAt']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'requestId': serializer.toJson<String>(requestId),
      'email': serializer.toJson<String>(email),
      'status': serializer.toJson<int>(status),
      'lastMessageId': serializer.toJson<String?>(lastMessageId),
      'lastResponseAt': serializer.toJson<DateTime?>(lastResponseAt),
      'reminderSentAt': serializer.toJson<DateTime?>(reminderSentAt),
      'note': serializer.toJson<String?>(note),
    };
  }

  RecipientStatusTableData copyWith({
    String? requestId,
    String? email,
    int? status,
    Value<String?> lastMessageId = const Value.absent(),
    Value<DateTime?> lastResponseAt = const Value.absent(),
    Value<DateTime?> reminderSentAt = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => RecipientStatusTableData(
    requestId: requestId ?? this.requestId,
    email: email ?? this.email,
    status: status ?? this.status,
    lastMessageId:
        lastMessageId.present ? lastMessageId.value : this.lastMessageId,
    lastResponseAt:
        lastResponseAt.present ? lastResponseAt.value : this.lastResponseAt,
    reminderSentAt:
        reminderSentAt.present ? reminderSentAt.value : this.reminderSentAt,
    note: note.present ? note.value : this.note,
  );
  RecipientStatusTableData copyWithCompanion(
    RecipientStatusTableCompanion data,
  ) {
    return RecipientStatusTableData(
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      email: data.email.present ? data.email.value : this.email,
      status: data.status.present ? data.status.value : this.status,
      lastMessageId:
          data.lastMessageId.present
              ? data.lastMessageId.value
              : this.lastMessageId,
      lastResponseAt:
          data.lastResponseAt.present
              ? data.lastResponseAt.value
              : this.lastResponseAt,
      reminderSentAt:
          data.reminderSentAt.present
              ? data.reminderSentAt.value
              : this.reminderSentAt,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipientStatusTableData(')
          ..write('requestId: $requestId, ')
          ..write('email: $email, ')
          ..write('status: $status, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('lastResponseAt: $lastResponseAt, ')
          ..write('reminderSentAt: $reminderSentAt, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    requestId,
    email,
    status,
    lastMessageId,
    lastResponseAt,
    reminderSentAt,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipientStatusTableData &&
          other.requestId == this.requestId &&
          other.email == this.email &&
          other.status == this.status &&
          other.lastMessageId == this.lastMessageId &&
          other.lastResponseAt == this.lastResponseAt &&
          other.reminderSentAt == this.reminderSentAt &&
          other.note == this.note);
}

class RecipientStatusTableCompanion
    extends UpdateCompanion<RecipientStatusTableData> {
  final Value<String> requestId;
  final Value<String> email;
  final Value<int> status;
  final Value<String?> lastMessageId;
  final Value<DateTime?> lastResponseAt;
  final Value<DateTime?> reminderSentAt;
  final Value<String?> note;
  final Value<int> rowid;
  const RecipientStatusTableCompanion({
    this.requestId = const Value.absent(),
    this.email = const Value.absent(),
    this.status = const Value.absent(),
    this.lastMessageId = const Value.absent(),
    this.lastResponseAt = const Value.absent(),
    this.reminderSentAt = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipientStatusTableCompanion.insert({
    required String requestId,
    required String email,
    required int status,
    this.lastMessageId = const Value.absent(),
    this.lastResponseAt = const Value.absent(),
    this.reminderSentAt = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : requestId = Value(requestId),
       email = Value(email),
       status = Value(status);
  static Insertable<RecipientStatusTableData> custom({
    Expression<String>? requestId,
    Expression<String>? email,
    Expression<int>? status,
    Expression<String>? lastMessageId,
    Expression<DateTime>? lastResponseAt,
    Expression<DateTime>? reminderSentAt,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (requestId != null) 'request_id': requestId,
      if (email != null) 'email': email,
      if (status != null) 'status': status,
      if (lastMessageId != null) 'last_message_id': lastMessageId,
      if (lastResponseAt != null) 'last_response_at': lastResponseAt,
      if (reminderSentAt != null) 'reminder_sent_at': reminderSentAt,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipientStatusTableCompanion copyWith({
    Value<String>? requestId,
    Value<String>? email,
    Value<int>? status,
    Value<String?>? lastMessageId,
    Value<DateTime?>? lastResponseAt,
    Value<DateTime?>? reminderSentAt,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return RecipientStatusTableCompanion(
      requestId: requestId ?? this.requestId,
      email: email ?? this.email,
      status: status ?? this.status,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastResponseAt: lastResponseAt ?? this.lastResponseAt,
      reminderSentAt: reminderSentAt ?? this.reminderSentAt,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (lastMessageId.present) {
      map['last_message_id'] = Variable<String>(lastMessageId.value);
    }
    if (lastResponseAt.present) {
      map['last_response_at'] = Variable<DateTime>(lastResponseAt.value);
    }
    if (reminderSentAt.present) {
      map['reminder_sent_at'] = Variable<DateTime>(reminderSentAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipientStatusTableCompanion(')
          ..write('requestId: $requestId, ')
          ..write('email: $email, ')
          ..write('status: $status, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('lastResponseAt: $lastResponseAt, ')
          ..write('reminderSentAt: $reminderSentAt, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActivityLogTable extends ActivityLog
    with TableInfo<$ActivityLogTable, ActivityLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    requestId,
    timestamp,
    type,
    payloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityLogData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      requestId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}request_id'],
          )!,
      timestamp:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}timestamp'],
          )!,
      type:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}type'],
          )!,
      payloadJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}payload_json'],
          )!,
    );
  }

  @override
  $ActivityLogTable createAlias(String alias) {
    return $ActivityLogTable(attachedDatabase, alias);
  }
}

class ActivityLogData extends DataClass implements Insertable<ActivityLogData> {
  final String id;
  final String requestId;
  final DateTime timestamp;
  final int type;
  final String payloadJson;
  const ActivityLogData({
    required this.id,
    required this.requestId,
    required this.timestamp,
    required this.type,
    required this.payloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['request_id'] = Variable<String>(requestId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['type'] = Variable<int>(type);
    map['payload_json'] = Variable<String>(payloadJson);
    return map;
  }

  ActivityLogCompanion toCompanion(bool nullToAbsent) {
    return ActivityLogCompanion(
      id: Value(id),
      requestId: Value(requestId),
      timestamp: Value(timestamp),
      type: Value(type),
      payloadJson: Value(payloadJson),
    );
  }

  factory ActivityLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityLogData(
      id: serializer.fromJson<String>(json['id']),
      requestId: serializer.fromJson<String>(json['requestId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      type: serializer.fromJson<int>(json['type']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'requestId': serializer.toJson<String>(requestId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'type': serializer.toJson<int>(type),
      'payloadJson': serializer.toJson<String>(payloadJson),
    };
  }

  ActivityLogData copyWith({
    String? id,
    String? requestId,
    DateTime? timestamp,
    int? type,
    String? payloadJson,
  }) => ActivityLogData(
    id: id ?? this.id,
    requestId: requestId ?? this.requestId,
    timestamp: timestamp ?? this.timestamp,
    type: type ?? this.type,
    payloadJson: payloadJson ?? this.payloadJson,
  );
  ActivityLogData copyWithCompanion(ActivityLogCompanion data) {
    return ActivityLogData(
      id: data.id.present ? data.id.value : this.id,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      type: data.type.present ? data.type.value : this.type,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityLogData(')
          ..write('id: $id, ')
          ..write('requestId: $requestId, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, requestId, timestamp, type, payloadJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityLogData &&
          other.id == this.id &&
          other.requestId == this.requestId &&
          other.timestamp == this.timestamp &&
          other.type == this.type &&
          other.payloadJson == this.payloadJson);
}

class ActivityLogCompanion extends UpdateCompanion<ActivityLogData> {
  final Value<String> id;
  final Value<String> requestId;
  final Value<DateTime> timestamp;
  final Value<int> type;
  final Value<String> payloadJson;
  final Value<int> rowid;
  const ActivityLogCompanion({
    this.id = const Value.absent(),
    this.requestId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.type = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivityLogCompanion.insert({
    required String id,
    required String requestId,
    required DateTime timestamp,
    required int type,
    required String payloadJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       requestId = Value(requestId),
       timestamp = Value(timestamp),
       type = Value(type),
       payloadJson = Value(payloadJson);
  static Insertable<ActivityLogData> custom({
    Expression<String>? id,
    Expression<String>? requestId,
    Expression<DateTime>? timestamp,
    Expression<int>? type,
    Expression<String>? payloadJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (requestId != null) 'request_id': requestId,
      if (timestamp != null) 'timestamp': timestamp,
      if (type != null) 'type': type,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivityLogCompanion copyWith({
    Value<String>? id,
    Value<String>? requestId,
    Value<DateTime>? timestamp,
    Value<int>? type,
    Value<String>? payloadJson,
    Value<int>? rowid,
  }) {
    return ActivityLogCompanion(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      payloadJson: payloadJson ?? this.payloadJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityLogCompanion(')
          ..write('id: $id, ')
          ..write('requestId: $requestId, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProcessedMessagesTable extends ProcessedMessages
    with TableInfo<$ProcessedMessagesTable, ProcessedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProcessedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _processedAtMeta = const VerificationMeta(
    'processedAt',
  );
  @override
  late final GeneratedColumn<DateTime> processedAt = GeneratedColumn<DateTime>(
    'processed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [requestId, messageId, processedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'processed_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProcessedMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('processed_at')) {
      context.handle(
        _processedAtMeta,
        processedAt.isAcceptableOrUnknown(
          data['processed_at']!,
          _processedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {requestId, messageId};
  @override
  ProcessedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProcessedMessage(
      requestId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}request_id'],
          )!,
      messageId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}message_id'],
          )!,
      processedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}processed_at'],
          )!,
    );
  }

  @override
  $ProcessedMessagesTable createAlias(String alias) {
    return $ProcessedMessagesTable(attachedDatabase, alias);
  }
}

class ProcessedMessage extends DataClass
    implements Insertable<ProcessedMessage> {
  final String requestId;
  final String messageId;
  final DateTime processedAt;
  const ProcessedMessage({
    required this.requestId,
    required this.messageId,
    required this.processedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['request_id'] = Variable<String>(requestId);
    map['message_id'] = Variable<String>(messageId);
    map['processed_at'] = Variable<DateTime>(processedAt);
    return map;
  }

  ProcessedMessagesCompanion toCompanion(bool nullToAbsent) {
    return ProcessedMessagesCompanion(
      requestId: Value(requestId),
      messageId: Value(messageId),
      processedAt: Value(processedAt),
    );
  }

  factory ProcessedMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProcessedMessage(
      requestId: serializer.fromJson<String>(json['requestId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      processedAt: serializer.fromJson<DateTime>(json['processedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'requestId': serializer.toJson<String>(requestId),
      'messageId': serializer.toJson<String>(messageId),
      'processedAt': serializer.toJson<DateTime>(processedAt),
    };
  }

  ProcessedMessage copyWith({
    String? requestId,
    String? messageId,
    DateTime? processedAt,
  }) => ProcessedMessage(
    requestId: requestId ?? this.requestId,
    messageId: messageId ?? this.messageId,
    processedAt: processedAt ?? this.processedAt,
  );
  ProcessedMessage copyWithCompanion(ProcessedMessagesCompanion data) {
    return ProcessedMessage(
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      processedAt:
          data.processedAt.present ? data.processedAt.value : this.processedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProcessedMessage(')
          ..write('requestId: $requestId, ')
          ..write('messageId: $messageId, ')
          ..write('processedAt: $processedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(requestId, messageId, processedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessedMessage &&
          other.requestId == this.requestId &&
          other.messageId == this.messageId &&
          other.processedAt == this.processedAt);
}

class ProcessedMessagesCompanion extends UpdateCompanion<ProcessedMessage> {
  final Value<String> requestId;
  final Value<String> messageId;
  final Value<DateTime> processedAt;
  final Value<int> rowid;
  const ProcessedMessagesCompanion({
    this.requestId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProcessedMessagesCompanion.insert({
    required String requestId,
    required String messageId,
    this.processedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : requestId = Value(requestId),
       messageId = Value(messageId);
  static Insertable<ProcessedMessage> custom({
    Expression<String>? requestId,
    Expression<String>? messageId,
    Expression<DateTime>? processedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (requestId != null) 'request_id': requestId,
      if (messageId != null) 'message_id': messageId,
      if (processedAt != null) 'processed_at': processedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProcessedMessagesCompanion copyWith({
    Value<String>? requestId,
    Value<String>? messageId,
    Value<DateTime>? processedAt,
    Value<int>? rowid,
  }) {
    return ProcessedMessagesCompanion(
      requestId: requestId ?? this.requestId,
      messageId: messageId ?? this.messageId,
      processedAt: processedAt ?? this.processedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (processedAt.present) {
      map['processed_at'] = Variable<DateTime>(processedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProcessedMessagesCompanion(')
          ..write('requestId: $requestId, ')
          ..write('messageId: $messageId, ')
          ..write('processedAt: $processedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $RequestsTable requests = $RequestsTable(this);
  late final $RecipientStatusTableTable recipientStatusTable =
      $RecipientStatusTableTable(this);
  late final $ActivityLogTable activityLog = $ActivityLogTable(this);
  late final $ProcessedMessagesTable processedMessages =
      $ProcessedMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    conversations,
    requests,
    recipientStatusTable,
    activityLog,
    processedMessages,
  ];
}

typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      required String id,
      required String title,
      required int kind,
      required String requestId,
      required int status,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<int> kind,
      Value<String> requestId,
      Value<int> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationsTable,
          Conversation,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (
            Conversation,
            BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>,
          ),
          Conversation,
          PrefetchHooks Function()
        > {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ConversationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String> requestId = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                title: title,
                kind: kind,
                requestId: requestId,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required int kind,
                required String requestId,
                required int status,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                title: title,
                kind: kind,
                requestId: requestId,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationsTable,
      Conversation,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (
        Conversation,
        BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>,
      ),
      Conversation,
      PrefetchHooks Function()
    >;
typedef $$RequestsTableCreateCompanionBuilder =
    RequestsCompanion Function({
      required String requestId,
      required String title,
      Value<String?> description,
      required String ownerEmail,
      required DateTime dueAt,
      required String schemaJson,
      required String recipientsJson,
      Value<int> replyFormat,
      required String sheetId,
      required String sheetUrl,
      Value<String?> gmailThreadId,
      Value<DateTime?> lastIngestAt,
      Value<int> rowid,
    });
typedef $$RequestsTableUpdateCompanionBuilder =
    RequestsCompanion Function({
      Value<String> requestId,
      Value<String> title,
      Value<String?> description,
      Value<String> ownerEmail,
      Value<DateTime> dueAt,
      Value<String> schemaJson,
      Value<String> recipientsJson,
      Value<int> replyFormat,
      Value<String> sheetId,
      Value<String> sheetUrl,
      Value<String?> gmailThreadId,
      Value<DateTime?> lastIngestAt,
      Value<int> rowid,
    });

class $$RequestsTableFilterComposer
    extends Composer<_$AppDatabase, $RequestsTable> {
  $$RequestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerEmail => $composableBuilder(
    column: $table.ownerEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schemaJson => $composableBuilder(
    column: $table.schemaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientsJson => $composableBuilder(
    column: $table.recipientsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get replyFormat => $composableBuilder(
    column: $table.replyFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sheetId => $composableBuilder(
    column: $table.sheetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sheetUrl => $composableBuilder(
    column: $table.sheetUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gmailThreadId => $composableBuilder(
    column: $table.gmailThreadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastIngestAt => $composableBuilder(
    column: $table.lastIngestAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RequestsTableOrderingComposer
    extends Composer<_$AppDatabase, $RequestsTable> {
  $$RequestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerEmail => $composableBuilder(
    column: $table.ownerEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schemaJson => $composableBuilder(
    column: $table.schemaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientsJson => $composableBuilder(
    column: $table.recipientsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get replyFormat => $composableBuilder(
    column: $table.replyFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sheetId => $composableBuilder(
    column: $table.sheetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sheetUrl => $composableBuilder(
    column: $table.sheetUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gmailThreadId => $composableBuilder(
    column: $table.gmailThreadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastIngestAt => $composableBuilder(
    column: $table.lastIngestAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RequestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RequestsTable> {
  $$RequestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerEmail => $composableBuilder(
    column: $table.ownerEmail,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<String> get schemaJson => $composableBuilder(
    column: $table.schemaJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientsJson => $composableBuilder(
    column: $table.recipientsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get replyFormat => $composableBuilder(
    column: $table.replyFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sheetId =>
      $composableBuilder(column: $table.sheetId, builder: (column) => column);

  GeneratedColumn<String> get sheetUrl =>
      $composableBuilder(column: $table.sheetUrl, builder: (column) => column);

  GeneratedColumn<String> get gmailThreadId => $composableBuilder(
    column: $table.gmailThreadId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastIngestAt => $composableBuilder(
    column: $table.lastIngestAt,
    builder: (column) => column,
  );
}

class $$RequestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RequestsTable,
          Request,
          $$RequestsTableFilterComposer,
          $$RequestsTableOrderingComposer,
          $$RequestsTableAnnotationComposer,
          $$RequestsTableCreateCompanionBuilder,
          $$RequestsTableUpdateCompanionBuilder,
          (Request, BaseReferences<_$AppDatabase, $RequestsTable, Request>),
          Request,
          PrefetchHooks Function()
        > {
  $$RequestsTableTableManager(_$AppDatabase db, $RequestsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$RequestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$RequestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$RequestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> requestId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> ownerEmail = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<String> schemaJson = const Value.absent(),
                Value<String> recipientsJson = const Value.absent(),
                Value<int> replyFormat = const Value.absent(),
                Value<String> sheetId = const Value.absent(),
                Value<String> sheetUrl = const Value.absent(),
                Value<String?> gmailThreadId = const Value.absent(),
                Value<DateTime?> lastIngestAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RequestsCompanion(
                requestId: requestId,
                title: title,
                description: description,
                ownerEmail: ownerEmail,
                dueAt: dueAt,
                schemaJson: schemaJson,
                recipientsJson: recipientsJson,
                replyFormat: replyFormat,
                sheetId: sheetId,
                sheetUrl: sheetUrl,
                gmailThreadId: gmailThreadId,
                lastIngestAt: lastIngestAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String requestId,
                required String title,
                Value<String?> description = const Value.absent(),
                required String ownerEmail,
                required DateTime dueAt,
                required String schemaJson,
                required String recipientsJson,
                Value<int> replyFormat = const Value.absent(),
                required String sheetId,
                required String sheetUrl,
                Value<String?> gmailThreadId = const Value.absent(),
                Value<DateTime?> lastIngestAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RequestsCompanion.insert(
                requestId: requestId,
                title: title,
                description: description,
                ownerEmail: ownerEmail,
                dueAt: dueAt,
                schemaJson: schemaJson,
                recipientsJson: recipientsJson,
                replyFormat: replyFormat,
                sheetId: sheetId,
                sheetUrl: sheetUrl,
                gmailThreadId: gmailThreadId,
                lastIngestAt: lastIngestAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RequestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RequestsTable,
      Request,
      $$RequestsTableFilterComposer,
      $$RequestsTableOrderingComposer,
      $$RequestsTableAnnotationComposer,
      $$RequestsTableCreateCompanionBuilder,
      $$RequestsTableUpdateCompanionBuilder,
      (Request, BaseReferences<_$AppDatabase, $RequestsTable, Request>),
      Request,
      PrefetchHooks Function()
    >;
typedef $$RecipientStatusTableTableCreateCompanionBuilder =
    RecipientStatusTableCompanion Function({
      required String requestId,
      required String email,
      required int status,
      Value<String?> lastMessageId,
      Value<DateTime?> lastResponseAt,
      Value<DateTime?> reminderSentAt,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$RecipientStatusTableTableUpdateCompanionBuilder =
    RecipientStatusTableCompanion Function({
      Value<String> requestId,
      Value<String> email,
      Value<int> status,
      Value<String?> lastMessageId,
      Value<DateTime?> lastResponseAt,
      Value<DateTime?> reminderSentAt,
      Value<String?> note,
      Value<int> rowid,
    });

class $$RecipientStatusTableTableFilterComposer
    extends Composer<_$AppDatabase, $RecipientStatusTableTable> {
  $$RecipientStatusTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastResponseAt => $composableBuilder(
    column: $table.lastResponseAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reminderSentAt => $composableBuilder(
    column: $table.reminderSentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecipientStatusTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipientStatusTableTable> {
  $$RecipientStatusTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastResponseAt => $composableBuilder(
    column: $table.lastResponseAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reminderSentAt => $composableBuilder(
    column: $table.reminderSentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecipientStatusTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipientStatusTableTable> {
  $$RecipientStatusTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastResponseAt => $composableBuilder(
    column: $table.lastResponseAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get reminderSentAt => $composableBuilder(
    column: $table.reminderSentAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$RecipientStatusTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipientStatusTableTable,
          RecipientStatusTableData,
          $$RecipientStatusTableTableFilterComposer,
          $$RecipientStatusTableTableOrderingComposer,
          $$RecipientStatusTableTableAnnotationComposer,
          $$RecipientStatusTableTableCreateCompanionBuilder,
          $$RecipientStatusTableTableUpdateCompanionBuilder,
          (
            RecipientStatusTableData,
            BaseReferences<
              _$AppDatabase,
              $RecipientStatusTableTable,
              RecipientStatusTableData
            >,
          ),
          RecipientStatusTableData,
          PrefetchHooks Function()
        > {
  $$RecipientStatusTableTableTableManager(
    _$AppDatabase db,
    $RecipientStatusTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$RecipientStatusTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$RecipientStatusTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$RecipientStatusTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> requestId = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<String?> lastMessageId = const Value.absent(),
                Value<DateTime?> lastResponseAt = const Value.absent(),
                Value<DateTime?> reminderSentAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipientStatusTableCompanion(
                requestId: requestId,
                email: email,
                status: status,
                lastMessageId: lastMessageId,
                lastResponseAt: lastResponseAt,
                reminderSentAt: reminderSentAt,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String requestId,
                required String email,
                required int status,
                Value<String?> lastMessageId = const Value.absent(),
                Value<DateTime?> lastResponseAt = const Value.absent(),
                Value<DateTime?> reminderSentAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipientStatusTableCompanion.insert(
                requestId: requestId,
                email: email,
                status: status,
                lastMessageId: lastMessageId,
                lastResponseAt: lastResponseAt,
                reminderSentAt: reminderSentAt,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecipientStatusTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipientStatusTableTable,
      RecipientStatusTableData,
      $$RecipientStatusTableTableFilterComposer,
      $$RecipientStatusTableTableOrderingComposer,
      $$RecipientStatusTableTableAnnotationComposer,
      $$RecipientStatusTableTableCreateCompanionBuilder,
      $$RecipientStatusTableTableUpdateCompanionBuilder,
      (
        RecipientStatusTableData,
        BaseReferences<
          _$AppDatabase,
          $RecipientStatusTableTable,
          RecipientStatusTableData
        >,
      ),
      RecipientStatusTableData,
      PrefetchHooks Function()
    >;
typedef $$ActivityLogTableCreateCompanionBuilder =
    ActivityLogCompanion Function({
      required String id,
      required String requestId,
      required DateTime timestamp,
      required int type,
      required String payloadJson,
      Value<int> rowid,
    });
typedef $$ActivityLogTableUpdateCompanionBuilder =
    ActivityLogCompanion Function({
      Value<String> id,
      Value<String> requestId,
      Value<DateTime> timestamp,
      Value<int> type,
      Value<String> payloadJson,
      Value<int> rowid,
    });

class $$ActivityLogTableFilterComposer
    extends Composer<_$AppDatabase, $ActivityLogTable> {
  $$ActivityLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivityLogTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivityLogTable> {
  $$ActivityLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivityLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivityLogTable> {
  $$ActivityLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );
}

class $$ActivityLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivityLogTable,
          ActivityLogData,
          $$ActivityLogTableFilterComposer,
          $$ActivityLogTableOrderingComposer,
          $$ActivityLogTableAnnotationComposer,
          $$ActivityLogTableCreateCompanionBuilder,
          $$ActivityLogTableUpdateCompanionBuilder,
          (
            ActivityLogData,
            BaseReferences<_$AppDatabase, $ActivityLogTable, ActivityLogData>,
          ),
          ActivityLogData,
          PrefetchHooks Function()
        > {
  $$ActivityLogTableTableManager(_$AppDatabase db, $ActivityLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ActivityLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ActivityLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$ActivityLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> requestId = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityLogCompanion(
                id: id,
                requestId: requestId,
                timestamp: timestamp,
                type: type,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String requestId,
                required DateTime timestamp,
                required int type,
                required String payloadJson,
                Value<int> rowid = const Value.absent(),
              }) => ActivityLogCompanion.insert(
                id: id,
                requestId: requestId,
                timestamp: timestamp,
                type: type,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivityLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivityLogTable,
      ActivityLogData,
      $$ActivityLogTableFilterComposer,
      $$ActivityLogTableOrderingComposer,
      $$ActivityLogTableAnnotationComposer,
      $$ActivityLogTableCreateCompanionBuilder,
      $$ActivityLogTableUpdateCompanionBuilder,
      (
        ActivityLogData,
        BaseReferences<_$AppDatabase, $ActivityLogTable, ActivityLogData>,
      ),
      ActivityLogData,
      PrefetchHooks Function()
    >;
typedef $$ProcessedMessagesTableCreateCompanionBuilder =
    ProcessedMessagesCompanion Function({
      required String requestId,
      required String messageId,
      Value<DateTime> processedAt,
      Value<int> rowid,
    });
typedef $$ProcessedMessagesTableUpdateCompanionBuilder =
    ProcessedMessagesCompanion Function({
      Value<String> requestId,
      Value<String> messageId,
      Value<DateTime> processedAt,
      Value<int> rowid,
    });

class $$ProcessedMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $ProcessedMessagesTable> {
  $$ProcessedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProcessedMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProcessedMessagesTable> {
  $$ProcessedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProcessedMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProcessedMessagesTable> {
  $$ProcessedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => column,
  );
}

class $$ProcessedMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProcessedMessagesTable,
          ProcessedMessage,
          $$ProcessedMessagesTableFilterComposer,
          $$ProcessedMessagesTableOrderingComposer,
          $$ProcessedMessagesTableAnnotationComposer,
          $$ProcessedMessagesTableCreateCompanionBuilder,
          $$ProcessedMessagesTableUpdateCompanionBuilder,
          (
            ProcessedMessage,
            BaseReferences<
              _$AppDatabase,
              $ProcessedMessagesTable,
              ProcessedMessage
            >,
          ),
          ProcessedMessage,
          PrefetchHooks Function()
        > {
  $$ProcessedMessagesTableTableManager(
    _$AppDatabase db,
    $ProcessedMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ProcessedMessagesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$ProcessedMessagesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$ProcessedMessagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> requestId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<DateTime> processedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProcessedMessagesCompanion(
                requestId: requestId,
                messageId: messageId,
                processedAt: processedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String requestId,
                required String messageId,
                Value<DateTime> processedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProcessedMessagesCompanion.insert(
                requestId: requestId,
                messageId: messageId,
                processedAt: processedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProcessedMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProcessedMessagesTable,
      ProcessedMessage,
      $$ProcessedMessagesTableFilterComposer,
      $$ProcessedMessagesTableOrderingComposer,
      $$ProcessedMessagesTableAnnotationComposer,
      $$ProcessedMessagesTableCreateCompanionBuilder,
      $$ProcessedMessagesTableUpdateCompanionBuilder,
      (
        ProcessedMessage,
        BaseReferences<
          _$AppDatabase,
          $ProcessedMessagesTable,
          ProcessedMessage
        >,
      ),
      ProcessedMessage,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$RequestsTableTableManager get requests =>
      $$RequestsTableTableManager(_db, _db.requests);
  $$RecipientStatusTableTableTableManager get recipientStatusTable =>
      $$RecipientStatusTableTableTableManager(_db, _db.recipientStatusTable);
  $$ActivityLogTableTableManager get activityLog =>
      $$ActivityLogTableTableManager(_db, _db.activityLog);
  $$ProcessedMessagesTableTableManager get processedMessages =>
      $$ProcessedMessagesTableTableManager(_db, _db.processedMessages);
}
