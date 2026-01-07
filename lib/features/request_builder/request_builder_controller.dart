/// Request builder controller (Riverpod provider)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/app/db_provider.dart';
import 'package:decision_agent/data/db/app_db.dart';
import 'package:decision_agent/data/db/dao.dart';
import 'package:decision_agent/data/google/google_auth_service.dart';
import 'package:decision_agent/app/auth_provider.dart';
import 'package:decision_agent/data/google/sheets_service.dart';
import 'package:decision_agent/data/google/gmail_service.dart';
import 'package:decision_agent/services/request_service.dart';
import 'package:decision_agent/services/logging_service.dart';
import 'package:decision_agent/domain/request_schema.dart';
import 'package:decision_agent/domain/models.dart' as models;
import 'package:decision_agent/utils/ids.dart';

class RequestBuilderState {
  final String title;
  final String? instructions;
  final RequestSchema schema;
  final List<String> recipients;
  final DateTime? dueDate;
  final String? conversationId; // Conversation ID (sheet belongs to conversation)
  final String? sheetUrl; // Sheet URL (from conversation)
  final String? requestId;
  final bool isLoading;
  final String? error;

  RequestBuilderState({
    this.title = '',
    this.instructions,
    RequestSchema? schema,
    List<String>? recipients,
    this.dueDate,
    this.conversationId,
    this.sheetUrl,
    this.requestId,
    this.isLoading = false,
    this.error,
  })  : schema = schema ?? const RequestSchema(columns: []),
        recipients = recipients ?? [];

  RequestBuilderState copyWith({
    String? title,
    String? instructions,
    RequestSchema? schema,
    List<String>? recipients,
    DateTime? dueDate,
    String? conversationId,
    String? sheetUrl,
    String? requestId,
    bool? isLoading,
    String? error,
  }) {
    return RequestBuilderState(
      title: title ?? this.title,
      instructions: instructions ?? this.instructions,
      schema: schema ?? this.schema,
      recipients: recipients ?? this.recipients,
      dueDate: dueDate ?? this.dueDate,
      conversationId: conversationId ?? this.conversationId,
      sheetUrl: sheetUrl ?? this.sheetUrl,
      requestId: requestId ?? this.requestId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class RequestBuilderController extends StateNotifier<RequestBuilderState> {
  final RequestService _requestService;
  final AppDatabase _db;

  RequestBuilderController(this._requestService, this._db)
      : super(RequestBuilderState());

  void updateTitle(String title) {
    state = state.copyWith(title: title);
  }

  void updateInstructions(String? instructions) {
    state = state.copyWith(instructions: instructions);
  }

  void updateSchema(RequestSchema schema) {
    state = state.copyWith(schema: schema);
  }

  void updateRecipients(List<String> recipients) {
    state = state.copyWith(recipients: recipients);
  }

  void updateDueDate(DateTime dueDate) {
    state = state.copyWith(dueDate: dueDate);
  }

  void setConversationId(String conversationId) {
    state = state.copyWith(conversationId: conversationId);
  }

  /// Load conversation data for new request (schema, title, etc. from most recent request)
  Future<void> loadConversationData(String conversationId) async {
    try {
      // Get all requests for this conversation
      final requests = await _db.getRequestsByConversation(conversationId);
      if (requests.isEmpty) {
        throw Exception('No requests found in conversation');
      }
      
      // Use the most recent request as template
      final mostRecentRequest = requests.first;
      
      // Get conversation to get title
      final conversations = await _db.getConversations(includeArchived: true);
      final conversation = conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => throw Exception('Conversation not found'),
      );
      
      // Update state with conversation data
      state = state.copyWith(
        title: conversation.title, // Use conversation title
        schema: mostRecentRequest.schema, // Reuse schema from most recent request
        sheetUrl: conversation.sheetUrl.isNotEmpty ? conversation.sheetUrl : null,
        // Recipients will be set by user in Send section
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to load conversation data: $e');
    }
  }

  Future<void> createDraft() async {
    if (state.requestId != null) {
      return; // Already created
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Validate
      final errors = _requestService.validateRequest(
        title: state.title,
        schema: state.schema,
        recipients: state.recipients,
        dueDate: state.dueDate ?? DateTime.now().add(const Duration(days: 7)),
      );

      if (errors.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: errors.join('\n'),
        );
        return;
      }

      // Create conversation first (if not already created)
      String conversationId = state.conversationId ?? '';
      if (conversationId.isEmpty) {
        conversationId = await _requestService.createConversation(
          title: state.title,
        );
      }

      // Create draft request in conversation
      final requestId = await _requestService.createDraftRequest(
        conversationId: conversationId,
        title: state.title,
        schema: state.schema,
        recipients: state.recipients,
        dueDate: state.dueDate ?? DateTime.now().add(const Duration(days: 7)),
        instructions: state.instructions,
      );

      state = state.copyWith(
        conversationId: conversationId,
        requestId: requestId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> createSheet() async {
    // Ensure draft is created first
    if (state.requestId == null) {
      await createDraft();
      // Check if draft creation was successful
      if (state.error != null) {
        // Draft creation failed, don't proceed
        return;
      }
      // Wait a bit for state to update (Riverpod state updates are synchronous but this ensures consistency)
      if (state.requestId == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Request ID is missing. Please complete previous steps (title, schema, recipients, due date).',
        );
        return;
      }
    }

    final requestId = state.requestId;
    if (requestId == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Request ID is missing. Please complete previous steps.',
      );
      return;
    }

    // Ensure conversation exists
    if (state.conversationId == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Conversation ID is missing. Please complete previous steps.',
      );
      return;
    }

    if (state.sheetUrl != null && state.sheetUrl!.isNotEmpty) {
      return; // Already created
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Create sheet for conversation
      final sheetUrl = await _requestService.createSheetForConversation(
        state.conversationId!,
        state.schema,
      );

      state = state.copyWith(
        sheetUrl: sheetUrl,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  String? _extractSheetIdFromUrl(String url) {
    // Extract from URL like: https://docs.google.com/spreadsheets/d/SHEET_ID/edit
    final regex = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  Future<Map<String, dynamic>?> sendRequest() async {
    if (state.requestId == null) {
      state = state.copyWith(
        error: 'Request ID is missing. Please complete previous steps.',
      );
      return null;
    }

    if (state.sheetUrl == null || state.sheetUrl!.isEmpty) {
      state = state.copyWith(
        error: 'Sheet must be created before sending request.',
      );
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final results = await _requestService.sendRequest(state.requestId!);
      state = state.copyWith(isLoading: false);
      return results;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }
}

final requestBuilderControllerProvider =
    StateNotifierProvider<RequestBuilderController, RequestBuilderState>((ref) {
  final db = ref.read(appDatabaseProvider);
  // Use the shared provider instance instead of creating a new one
  final authService = ref.read(googleAuthServiceProvider);
  final sheetsService = SheetsService(authService);
  final gmailService = GmailService(authService);
  final loggingService = LoggingService(db);
  final requestService = RequestService(
    db,
    sheetsService,
    authService,
    gmailService,
    loggingService,
  );
  return RequestBuilderController(requestService, db);
});
