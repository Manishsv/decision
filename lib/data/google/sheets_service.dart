/// Google Sheets service for creating and managing spreadsheets

import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:decision_agent/data/google/google_auth_service.dart';
import 'package:decision_agent/domain/request_schema.dart';

class SheetsService {
  final GoogleAuthService _authService;

  SheetsService(this._authService);

  /// Get Sheets API client
  Future<sheets.SheetsApi> _getSheetsApi() async {
    final httpClient = await _authService.getAuthClient();
    return sheets.SheetsApi(httpClient);
  }

  /// Create a new Google Sheet
  /// [title] - Title of the spreadsheet
  /// Returns a map with 'sheetId' and 'sheetUrl'
  Future<Map<String, String>> createSheet(String title) async {
    try {
      final api = await _getSheetsApi();
      
      final spreadsheet = sheets.Spreadsheet();
      spreadsheet.properties = sheets.SpreadsheetProperties()
        ..title = title;
      
      final created = await api.spreadsheets.create(spreadsheet);
      
      final sheetId = created.spreadsheetId ?? '';
      final sheetUrl = created.spreadsheetUrl ?? '';
      
      if (sheetId.isEmpty) {
        throw Exception('Failed to create sheet: no sheet ID returned');
      }
      
      return {
        'sheetId': sheetId,
        'sheetUrl': sheetUrl,
      };
    } catch (e) {
      throw Exception('Failed to create sheet: $e');
    }
  }

  /// Ensure "Responses" tab exists and has correct headers
  /// [sheetId] - Google Sheet ID
  /// [schema] - Request schema defining the columns
  Future<void> ensureResponsesTabAndHeaders(String sheetId, RequestSchema schema) async {
    try {
      final api = await _getSheetsApi();
      
      // Get spreadsheet to check if Responses tab exists
      final spreadsheet = await api.spreadsheets.get(sheetId);
      
      // Find or create Responses sheet
      sheets.Sheet? responsesSheet;
      for (final sheet in spreadsheet.sheets ?? []) {
        if (sheet.properties?.title == 'Responses') {
          responsesSheet = sheet;
          break;
        }
      }
      
      // Create Responses sheet if it doesn't exist
      if (responsesSheet == null) {
        final addSheetRequest = sheets.AddSheetRequest();
        addSheetRequest.properties = sheets.SheetProperties()
          ..title = 'Responses';
        
        final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest();
        batchUpdateRequest.requests = [
          sheets.Request()..addSheet = addSheetRequest,
        ];
        
        await api.spreadsheets.batchUpdate(batchUpdateRequest, sheetId);
        
        // Get the sheet ID of the newly created sheet
        final updatedSpreadsheet = await api.spreadsheets.get(sheetId);
        for (final sheet in updatedSpreadsheet.sheets ?? []) {
          if (sheet.properties?.title == 'Responses') {
            responsesSheet = sheet;
            break;
          }
        }
      }
      
      if (responsesSheet == null) {
        throw Exception('Failed to create or find Responses sheet');
      }
      
      final properties = responsesSheet.properties;
      if (properties == null || properties.sheetId == null) {
        throw Exception('Failed to get Responses sheet properties');
      }
      
      final responsesSheetId = properties.sheetId!;
      
      // Build header row
      final headers = <String>[
        '__receivedAt',
        '__fromEmail',
        '__messageId',
        '__parseStatus',
      ];
      
      // Add schema columns
      for (final column in schema.columns) {
        headers.add(column.name);
      }
      
      // Write headers to row 1
      final updateRequest = sheets.ValueRange();
      updateRequest.values = [headers];
      
      await api.spreadsheets.values.update(
        updateRequest,
        sheetId,
        'Responses!A1',
        valueInputOption: 'RAW',
      );
      
      // Note: Header formatting (bold, freeze) is optional for MVP
      // Can be added later if needed using BatchUpdateSpreadsheetRequest
    } catch (e) {
      throw Exception('Failed to set up Responses tab: $e');
    }
  }

  /// Append rows to the Responses tab
  /// [sheetId] - Google Sheet ID
  /// [rows] - List of rows, where each row is a list of cell values
  Future<void> appendRows(String sheetId, List<List<Object?>> rows) async {
    try {
      if (rows.isEmpty) return;
      
      final api = await _getSheetsApi();
      
      final valueRange = sheets.ValueRange();
      valueRange.values = rows.map((row) => row.map((cell) => cell?.toString() ?? '').toList()).toList();
      
      await api.spreadsheets.values.append(
        valueRange,
        sheetId,
        'Responses!A:A',
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      );
    } catch (e) {
      throw Exception('Failed to append rows: $e');
    }
  }

  /// Get sheet URL from sheet ID
  String getSheetUrl(String sheetId) {
    return 'https://docs.google.com/spreadsheets/d/$sheetId';
  }
}
