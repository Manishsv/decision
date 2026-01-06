/// Parsing service for deterministic table parsing from email replies

import 'package:decision_agent/domain/request_schema.dart';
import 'package:decision_agent/domain/models.dart';

/// Result of parsing a table reply
class ParseResult {
  final bool success;
  final List<Map<String, dynamic>> rows;
  final List<String> errors;
  final String? rawTable;

  ParseResult({
    required this.success,
    required this.rows,
    required this.errors,
    this.rawTable,
  });

  /// Create a successful parse result
  factory ParseResult.success(
    List<Map<String, dynamic>> rows,
    String? rawTable,
  ) {
    return ParseResult(
      success: true,
      rows: rows,
      errors: [],
      rawTable: rawTable,
    );
  }

  /// Create a failed parse result
  factory ParseResult.failure(List<String> errors, String? rawTable) {
    return ParseResult(
      success: false,
      rows: [],
      errors: errors,
      rawTable: rawTable,
    );
  }
}

/// Parsing service for extracting structured data from email table replies
class ParsingService {
  /// Parse a table reply from email body
  ///
  /// Looks for markdown-style ASCII tables (lines starting with `|`)
  /// and extracts data rows matching the schema.
  ///
  /// [body] - The email body text
  /// [schema] - The request schema defining expected columns
  ///
  /// Returns ParseResult with success status, parsed rows, and any errors
  ParseResult parseTableReply(String body, RequestSchema schema) {
    final errors = <String>[];

    // Step 1: Extract the table block
    final tableBlock = _extractTableBlock(body);
    if (tableBlock == null) {
      return ParseResult.failure([
        'No table found in email body. Expected markdown-style table with lines starting with |',
      ], null);
    }

    // Step 2: Parse rows from the table block
    final lines =
        tableBlock
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();

    if (lines.isEmpty) {
      return ParseResult.failure(['Table block is empty'], tableBlock);
    }

    // Step 3: Extract header row (first non-separator line)
    String? headerLine;
    int headerIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isSeparatorRow(line)) {
        continue;
      }
      if (line.startsWith('|') && line.endsWith('|')) {
        headerLine = line;
        headerIndex = i;
        break;
      }
    }

    if (headerLine == null || headerIndex == -1) {
      return ParseResult.failure([
        'No valid header row found in table',
      ], tableBlock);
    }

    // Step 4: Parse header and validate against schema
    final headerCells = _parseRow(headerLine);
    final headerValidation = _validateHeaders(headerCells, schema);
    if (!headerValidation.success) {
      return ParseResult.failure(headerValidation.errors, tableBlock);
    }

    // Step 5: Parse data rows (everything after header, skipping separators)
    final dataRows = <Map<String, dynamic>>[];
    for (int i = headerIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      if (_isSeparatorRow(line)) {
        continue; // Skip separator rows
      }
      if (!line.startsWith('|') || !line.endsWith('|')) {
        break; // End of table
      }

      final rowCells = _parseRow(line);
      if (rowCells.length != headerCells.length) {
        errors.add(
          'Row ${dataRows.length + 1}: Expected ${headerCells.length} columns, got ${rowCells.length}',
        );
        continue;
      }

      // Check if this row is empty (all cells are empty or whitespace)
      final isEmptyRow = rowCells.every((cell) => cell.trim().isEmpty);
      if (isEmptyRow) {
        continue; // Skip empty rows
      }

      // Coerce cells to match schema types
      final rowData = <String, dynamic>{};
      bool rowHasErrors = false;

      for (int j = 0; j < headerCells.length; j++) {
        final headerCell = headerCells[j];
        final cellValue = rowCells[j];
        final column = headerValidation.columnMap[headerCell];

        if (column == null) {
          // Skip columns not in schema
          continue;
        }

        final coerced = _coerceCell(cellValue, column);
        if (coerced.error != null) {
          errors.add(
            'Row ${dataRows.length + 1}, column "${column.name}": ${coerced.error}',
          );
          rowHasErrors = true;
        } else {
          rowData[column.name] = coerced.value;
        }
      }

      // Only add row if it has no errors and all required fields are present
      if (!rowHasErrors && _hasRequiredFields(rowData, schema)) {
        dataRows.add(rowData);
      } else if (rowHasErrors) {
        // Track which required fields are missing
        final missing =
            schema.columns
                .where((col) => col.required && !rowData.containsKey(col.name))
                .map((col) => col.name)
                .toList();
        if (missing.isNotEmpty) {
          errors.add(
            'Row ${dataRows.length + 1}: Missing required fields: ${missing.join(", ")}',
          );
        }
      }
    }

    if (dataRows.isEmpty && errors.isEmpty) {
      return ParseResult.failure([
        'No valid data rows found in table',
      ], tableBlock);
    }

    if (dataRows.isEmpty) {
      return ParseResult.failure(errors, tableBlock);
    }

    return ParseResult.success(dataRows, tableBlock);
  }

  /// Extract the first valid table block from email reply
  /// Skips the original request table and finds the reply table
  String? _extractTableBlock(String body) {
    final lines = body.split('\n');

    // Strategy: Find the data-request block first, then look for tables
    // Tables BEFORE the data-request block are likely the reply
    // Tables AFTER the data-request block are likely the original request (skip them)

    int? dataRequestEndIndex;

    // Find the data-request block
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('```data-request') ||
          (line.contains('```') && line.contains('data-request'))) {
        // Find the closing marker
        for (int j = i + 1; j < lines.length; j++) {
          if (lines[j].trim().contains('```')) {
            dataRequestEndIndex = j;
            break;
          }
        }
        break;
      }
    }

    // Also look for common email reply markers
    int? replyMarkerIndex;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim().toLowerCase();
      if (line.startsWith('on ') && line.contains('wrote:') ||
          line.startsWith('from:') ||
          line.startsWith('sent:') ||
          line.contains('original message')) {
        replyMarkerIndex = i;
        break;
      }
    }

    // Determine the cutoff point: anything after data-request or reply markers is likely original request
    final cutoffIndex =
        dataRequestEndIndex != null
            ? dataRequestEndIndex
            : (replyMarkerIndex != null ? replyMarkerIndex : lines.length);

    // Now find the first table block BEFORE the cutoff (this is likely the reply)
    // Priority: Look for tables at the very top of the email first
    int? startIndex;
    int? endIndex;

    for (int i = 0; i < cutoffIndex; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.startsWith('|')) {
        if (startIndex == null) {
          startIndex = i;
        }
        endIndex = i;
      } else if (startIndex != null) {
        // We've found the start of a table, now check if we should end it
        if (trimmed.isEmpty) {
          // Blank line after table - end of table, but check if it's valid first
          if (endIndex != null && endIndex >= startIndex) {
            final potentialTable = lines
                .sublist(startIndex, endIndex + 1)
                .join('\n');
            final tableLines =
                potentialTable
                    .split('\n')
                    .map((l) => l.trim())
                    .where((l) => l.isNotEmpty && !_isSeparatorRow(l))
                    .toList();

            // If we have at least header + 1 data row, this is valid - use it
            if (tableLines.length >= 2) {
              break; // Found valid table
            }
          }
          // Otherwise, reset and continue searching
          startIndex = null;
          endIndex = null;
        } else if (!trimmed.startsWith('|') && !trimmed.startsWith('>')) {
          // Non-table line after table (and not a quote marker) - end of table
          if (endIndex != null && endIndex >= startIndex) {
            // We have a complete table, check if it's valid
            final potentialTable = lines
                .sublist(startIndex, endIndex + 1)
                .join('\n');
            final tableLines =
                potentialTable
                    .split('\n')
                    .map((l) => l.trim())
                    .where((l) => l.isNotEmpty && !_isSeparatorRow(l))
                    .toList();

            // If we have at least header + 1 data row, this is valid
            if (tableLines.length >= 2) {
              break; // Found valid table
            }
          }
          // Otherwise, reset and continue searching
          startIndex = null;
          endIndex = null;
        }
      }
    }

    if (startIndex == null || endIndex == null) {
      return null;
    }

    final tableBlock = lines.sublist(startIndex, endIndex + 1).join('\n');

    // Validate that this table has actual data (not just headers or empty)
    final tableLines =
        tableBlock
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && !_isSeparatorRow(l))
            .toList();

    // Need at least header + 1 data row
    if (tableLines.length < 2) {
      return null;
    }

    return tableBlock;
  }

  /// Check if a line is a separator row (contains only dashes and pipes)
  bool _isSeparatorRow(String line) {
    final cleaned = line.replaceAll(RegExp(r'[|\s-]'), '');
    return cleaned.isEmpty && line.contains('|') && line.contains('-');
  }

  /// Parse a table row into cells
  List<String> _parseRow(String row) {
    // Remove leading and trailing |
    final cleaned = row
        .replaceFirst(RegExp(r'^\|'), '')
        .replaceFirst(RegExp(r'\|$'), '');
    return cleaned.split('|').map((cell) => cell.trim()).toList();
  }

  /// Validate headers against schema
  _HeaderValidation _validateHeaders(
    List<String> headerCells,
    RequestSchema schema,
  ) {
    final errors = <String>[];
    final columnMap = <String, SchemaColumn>{};

    // Normalize headers: trim, lowercase
    final normalizedHeaders =
        headerCells.map((h) => _normalizeHeader(h)).toList();
    final schemaColumnMap = <String, SchemaColumn>{};

    for (final column in schema.columns) {
      final normalized = _normalizeHeader(column.name);
      schemaColumnMap[normalized] = column;
    }

    // Check each header cell
    for (int i = 0; i < normalizedHeaders.length; i++) {
      final normalized = normalizedHeaders[i];
      final original = headerCells[i];

      if (schemaColumnMap.containsKey(normalized)) {
        columnMap[original] = schemaColumnMap[normalized]!;
      }
    }

    // Check for missing required columns
    final foundColumns = columnMap.values.toSet();
    final missingRequired =
        schema.columns
            .where((col) => col.required && !foundColumns.contains(col))
            .toList();

    if (missingRequired.isNotEmpty) {
      errors.add(
        'Missing required columns: ${missingRequired.map((c) => c.name).join(", ")}',
      );
    }

    // Warn about extra columns (not an error, just ignore them)
    // This is handled by skipping them in row parsing

    return _HeaderValidation(
      success: errors.isEmpty,
      errors: errors,
      columnMap: columnMap,
    );
  }

  /// Normalize header name for comparison
  String _normalizeHeader(String header) {
    return header.trim().toLowerCase();
  }

  /// Coerce a cell value to match the column type
  _CoercionResult _coerceCell(String cellValue, SchemaColumn column) {
    final trimmed = cellValue.trim();

    // Handle empty cells
    if (trimmed.isEmpty) {
      if (column.required) {
        return _CoercionResult.error('Required field is empty');
      }
      return _CoercionResult.value(null);
    }

    switch (column.type) {
      case ColumnType.stringType:
        return _CoercionResult.value(trimmed);

      case ColumnType.numberType:
        // Remove commas and parse
        final cleaned = trimmed.replaceAll(',', '');
        final number = double.tryParse(cleaned);
        if (number == null) {
          return _CoercionResult.error('Invalid number: "$trimmed"');
        }
        return _CoercionResult.value(number);

      case ColumnType.dateType:
        // Only accept ISO8601 format (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)
        final iso8601Pattern = RegExp(
          r'^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}(\.\d{3})?Z?)?$',
        );
        if (!iso8601Pattern.hasMatch(trimmed)) {
          return _CoercionResult.error(
            'Invalid date format. Expected ISO8601 (YYYY-MM-DD): "$trimmed"',
          );
        }
        // Return as string (Sheets will handle date formatting)
        return _CoercionResult.value(trimmed);
    }
  }

  /// Check if row has all required fields
  bool _hasRequiredFields(Map<String, dynamic> rowData, RequestSchema schema) {
    for (final column in schema.columns) {
      if (column.required && !rowData.containsKey(column.name)) {
        return false;
      }
    }
    return true;
  }
}

/// Internal class for header validation result
class _HeaderValidation {
  final bool success;
  final List<String> errors;
  final Map<String, SchemaColumn> columnMap;

  _HeaderValidation({
    required this.success,
    required this.errors,
    required this.columnMap,
  });
}

/// Internal class for cell coercion result
class _CoercionResult {
  final dynamic value;
  final String? error;

  _CoercionResult.value(this.value) : error = null;
  _CoercionResult.error(this.error) : value = null;
}
