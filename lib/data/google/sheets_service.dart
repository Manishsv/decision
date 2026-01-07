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
      
      // Build header row
      // Order: Schema columns first, then metadata columns at the end
      final headers = <String>[];
      
      // Add schema columns first
      for (final column in schema.columns) {
        headers.add(column.name);
      }
      
      // Add metadata columns at the end (rightmost)
      headers.addAll([
        '__fromEmail',
        '__version',
        '__receivedAt',
        '__messageId',
        '__requestId',
      ]);
      
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

  /// Update or insert rows in the Responses tab
  /// For a new message from a sender, replaces all existing rows from that sender for this request
  /// and inserts all new rows. This allows multiple rows per sender (e.g., multiple programs).
  /// [sheetId] - Google Sheet ID
  /// [rows] - List of rows, where each row is a list of cell values
  /// [requestId] - Request ID to match against
  /// Row format: [schema columns..., __fromEmail, __version, __receivedAt, __messageId, __requestId]
  Future<void> updateOrInsertRows(
    String sheetId,
    List<List<Object?>> rows,
    String requestId,
  ) async {
    try {
      if (rows.isEmpty) return;

      final api = await _getSheetsApi();

      // Read existing data to find matching rows
      final existingData = await readResponsesData(sheetId);
      if (existingData.isEmpty) {
        // No headers yet, just append
        await _appendRows(sheetId, rows);
        return;
      }

      // Find header row and column indices
      final headers = existingData[0];
      final fromEmailIndex = headers.indexOf('__fromEmail');
      final requestIdIndex = headers.indexOf('__requestId');
      final versionIndex = headers.indexOf('__version');

      if (fromEmailIndex == -1 || requestIdIndex == -1 || versionIndex == -1) {
        // Old format, just append
        await _appendRows(sheetId, rows);
        return;
      }

      // Get fromEmail from first new row (all rows in a batch should have same fromEmail)
      final firstRow = rows[0];
      final newFromEmail = firstRow[fromEmailIndex].toString();

      // Find all existing rows from this sender for this request
      // We'll delete them and insert new ones to handle multiple rows per sender
      // Always delete all rows from this sender for this request, regardless of messageId
      // The new rows will replace all of them
      final rowsToDelete = <int>[]; // Row indices (1-based, including header)
      int maxVersion = 0; // Track max version from deleted rows
      
      for (int i = 1; i < existingData.length; i++) {
        final existingRow = existingData[i];
        if (existingRow.length > fromEmailIndex &&
            existingRow.length > requestIdIndex) {
          final existingFromEmail = existingRow[fromEmailIndex].toString();
          final existingRequestId = existingRow[requestIdIndex].toString();
          
          // Delete all rows from this sender for this request
          // We're replacing them all with the new rows
          if (existingFromEmail == newFromEmail &&
              existingRequestId == requestId) {
            rowsToDelete.add(i + 1); // +1 because row 1 is headers
            
            // Track the maximum version from rows we're deleting
            if (existingRow.length > versionIndex) {
              final existingVersion = int.tryParse(
                    existingRow[versionIndex].toString(),
                  ) ??
                  0;
              if (existingVersion > maxVersion) {
                maxVersion = existingVersion;
              }
            }
          }
        }
      }

      // Delete existing rows (delete from bottom to top in one batch to preserve indices)
      if (rowsToDelete.isNotEmpty) {
        rowsToDelete.sort((a, b) => b.compareTo(a)); // Sort descending
        
        // Get the actual sheet ID for the Responses tab
        final spreadsheet = await api.spreadsheets.get(sheetId);
        int? responsesSheetId;
        for (final sheet in spreadsheet.sheets ?? []) {
          if (sheet.properties?.title == 'Responses') {
            responsesSheetId = sheet.properties?.sheetId;
            break;
          }
        }
        
        if (responsesSheetId == null) {
          throw Exception('Responses tab not found in spreadsheet');
        }
        
        // Create batch delete request for all rows
        final deleteRequests = rowsToDelete.map((rowIndex) {
          return sheets.Request()
            ..deleteDimension = (sheets.DeleteDimensionRequest()
              ..range = (sheets.DimensionRange()
                ..sheetId = responsesSheetId!
                ..dimension = 'ROWS'
                ..startIndex = rowIndex - 1 // 0-based index
                ..endIndex = rowIndex));
        }).toList();
        
        final deleteRequest = sheets.BatchUpdateSpreadsheetRequest();
        deleteRequest.requests = deleteRequests;
        
        await api.spreadsheets.batchUpdate(deleteRequest, sheetId);
      }

      // Insert all new rows with incremented version
      // If we deleted rows, use max version + 1, otherwise start at 1
      final newVersion = maxVersion + 1;
      final newRows = <List<Object?>>[];
      for (final newRow in rows) {
        final newRowWithVersion = List<Object?>.from(newRow);
        newRowWithVersion[versionIndex] = newVersion;
        newRows.add(newRowWithVersion);
      }

      if (newRows.isNotEmpty) {
        await _appendRows(sheetId, newRows);
      }
    } catch (e) {
      throw Exception('Failed to update or insert rows: $e');
    }
  }

  /// Append rows to the Responses tab (internal helper)
  Future<void> _appendRows(String sheetId, List<List<Object?>> rows) async {
    if (rows.isEmpty) return;

    final api = await _getSheetsApi();

    final valueRange = sheets.ValueRange();
    valueRange.values =
        rows.map((row) => row.map((cell) => cell?.toString() ?? '').toList()).toList();

    await api.spreadsheets.values.append(
      valueRange,
      sheetId,
      'Responses!A:A',
      valueInputOption: 'RAW',
      insertDataOption: 'INSERT_ROWS',
    );
  }

  /// Append rows to the Responses tab (legacy method - kept for compatibility)
  /// [sheetId] - Google Sheet ID
  /// [rows] - List of rows, where each row is a list of cell values
  @Deprecated('Use updateOrInsertRows instead')
  Future<void> appendRows(String sheetId, List<List<Object?>> rows) async {
    await _appendRows(sheetId, rows);
  }

  /// Get sheet URL from sheet ID
  String getSheetUrl(String sheetId) {
    return 'https://docs.google.com/spreadsheets/d/$sheetId';
  }

  /// Read data from the Responses tab
  /// [sheetId] - Google Sheet ID
  /// Returns a list of rows, where each row is a list of cell values
  /// First row contains headers
  Future<List<List<String>>> readResponsesData(String sheetId) async {
    try {
      final api = await _getSheetsApi();
      
      // Read all data from Responses tab
      final valueRange = await api.spreadsheets.values.get(
        sheetId,
        'Responses!A:Z', // Read columns A through Z (adjust if needed)
      );
      
      if (valueRange.values == null || valueRange.values!.isEmpty) {
        return [];
      }
      
      // Convert to List<List<String>>
      return valueRange.values!.map((row) {
        return row.map((cell) => cell?.toString() ?? '').toList();
      }).toList();
    } catch (e) {
      throw Exception('Failed to read sheet data: $e');
    }
  }
}
