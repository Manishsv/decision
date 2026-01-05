/// Request service for creating and managing data requests

import 'package:drift/drift.dart';
import 'package:decision_agent/data/db/app_db.dart';
import 'package:decision_agent/data/db/dao.dart';
import 'package:decision_agent/data/google/sheets_service.dart';
import 'package:decision_agent/data/google/google_auth_service.dart';
import 'package:decision_agent/domain/models.dart' as models;
import 'package:decision_agent/domain/request_schema.dart';
import 'package:decision_agent/utils/ids.dart';

class RequestService {
  final AppDatabase _db;
  final SheetsService _sheetsService;
  final GoogleAuthService _authService;

  RequestService(this._db, this._sheetsService, this._authService);

  /// Create a draft request
  /// Returns the requestId
  Future<String> createDraftRequest({
    required String title,
    required RequestSchema schema,
    required List<String> recipients,
    required DateTime dueDate,
    String? instructions,
  }) async {
    // Generate request ID
    final requestId = generateId();
    
    // Create conversation
    final conversationId = generateId();
    await _db.insertConversation(
      ConversationsCompanion.insert(
        id: conversationId,
        kind: models.ConversationKind.sentRequest.index,
        title: title,
        requestId: requestId,
        status: models.RequestStatus.draft.index,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    
    // Get user email for ownerEmail
    final ownerEmail = await _authService.getUserEmail();
    
    // Create data request (sheetId and sheetUrl will be empty until sheet is created)
    final request = models.DataRequest(
      requestId: requestId,
      title: title,
      description: instructions,
      ownerEmail: ownerEmail,
      dueAt: dueDate,
      schema: schema,
      recipients: recipients,
      sheetId: '', // Will be set when sheet is created
      sheetUrl: '', // Will be set when sheet is created
    );
    
    await _db.insertRequest(request);
    
    return requestId;
  }

  /// Create Google Sheet for a request
  /// [requestId] - Request ID
  /// Returns the sheet URL
  Future<String> createSheetForRequest(String requestId) async {
    // Get request from database
    final request = await _db.getRequest(requestId);
    if (request == null) {
      throw Exception('Request not found: $requestId');
    }
    
    // Create sheet with request title
    final sheetInfo = await _sheetsService.createSheet(request.title);
    final sheetId = sheetInfo['sheetId'];
    final sheetUrl = sheetInfo['sheetUrl'];
    
    if (sheetId == null || sheetId.isEmpty) {
      throw Exception('Failed to create sheet: no sheet ID returned');
    }
    
    if (sheetUrl == null || sheetUrl.isEmpty) {
      throw Exception('Failed to create sheet: no sheet URL returned');
    }
    
    // Set up Responses tab with headers
    await _sheetsService.ensureResponsesTabAndHeaders(sheetId, request.schema);
    
    // Update request with sheet info
    await _db.updateRequest(
      requestId,
      RequestsCompanion(
        sheetId: Value(sheetId),
        sheetUrl: Value(sheetUrl),
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
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }
}
