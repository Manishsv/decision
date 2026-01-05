/// Request builder controller (Riverpod provider)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/data/db/app_db.dart';
import 'package:decision_agent/data/google/google_auth_service.dart';
import 'package:decision_agent/app/auth_provider.dart';
import 'package:decision_agent/data/google/sheets_service.dart';
import 'package:decision_agent/services/request_service.dart';
import 'package:decision_agent/domain/request_schema.dart';
import 'package:decision_agent/domain/models.dart' as models;
import 'package:decision_agent/utils/ids.dart';

class RequestBuilderState {
  final String title;
  final String? instructions;
  final RequestSchema schema;
  final List<String> recipients;
  final DateTime? dueDate;
  final String? sheetId;
  final String? sheetUrl;
  final String? requestId;
  final bool isLoading;
  final String? error;

  RequestBuilderState({
    this.title = '',
    this.instructions,
    RequestSchema? schema,
    List<String>? recipients,
    this.dueDate,
    this.sheetId,
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
    String? sheetId,
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
      sheetId: sheetId ?? this.sheetId,
      sheetUrl: sheetUrl ?? this.sheetUrl,
      requestId: requestId ?? this.requestId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class RequestBuilderController extends StateNotifier<RequestBuilderState> {
  final RequestService _requestService;

  RequestBuilderController(this._requestService)
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

      // Create draft
      final requestId = await _requestService.createDraftRequest(
        title: state.title,
        schema: state.schema,
        recipients: state.recipients,
        dueDate: state.dueDate ?? DateTime.now().add(const Duration(days: 7)),
        instructions: state.instructions,
      );

      state = state.copyWith(
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
    if (state.requestId == null) {
      await createDraft();
    }

    final requestId = state.requestId;
    if (requestId == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Request ID is missing. Please complete previous steps.',
      );
      return;
    }

    if (state.sheetId != null) {
      return; // Already created
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final sheetUrl = await _requestService.createSheetForRequest(requestId);

      // Extract sheet ID from URL
      final sheetId = _extractSheetIdFromUrl(sheetUrl);
      
      if (sheetId == null) {
        throw Exception('Failed to extract sheet ID from URL: $sheetUrl');
      }

      state = state.copyWith(
        sheetId: sheetId,
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
}

final requestBuilderControllerProvider =
    StateNotifierProvider<RequestBuilderController, RequestBuilderState>((ref) {
  final db = AppDatabase();
  // Use the shared provider instance instead of creating a new one
  final authService = ref.read(googleAuthServiceProvider);
  final sheetsService = SheetsService(authService);
  final requestService = RequestService(db, sheetsService, authService);
  return RequestBuilderController(requestService);
});
