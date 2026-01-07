/// Email protocol for data requests
/// Generates email bodies in the specified markdown-style ASCII table format

import 'package:decision_agent/domain/models.dart';
import 'package:decision_agent/domain/request_schema.dart';

/// Generate email subject line for a data request
/// Format: [DATA-REQ:<requestId>] <Title>
String buildRequestSubject(DataRequest request) {
  return '[DATA-REQ:${request.requestId}] ${request.title}';
}

/// Generate email subject line for a data request (overload with requestId and title)
String buildRequestSubjectFromId(String requestId, String title) {
  return '[DATA-REQ:$requestId] $title';
}

/// Generate email subject line for a reminder
/// Format: [DATA-REQ:<requestId>] Reminder: <Title>
String buildReminderSubject(DataRequest request) {
  return '[DATA-REQ:${request.requestId}] Reminder: ${request.title}';
}

/// Generate email body for a data request
/// Clean, user-friendly format with clear instructions
String buildRequestEmailBody(DataRequest request) {
  final buffer = StringBuffer();
  
  // Validate schema has columns
  if (request.schema.columns.isEmpty) {
    throw Exception('Request schema is empty. Cannot generate email body.');
  }
  
  // Greeting
  buffer.writeln('Hello,');
  buffer.writeln();
  
  // Main request message
  buffer.writeln('We are requesting the following information from you. Please fill out the table below and reply to this email.');
  buffer.writeln();
  
  // Description/instructions if provided
  if (request.description != null && request.description!.isNotEmpty) {
    buffer.writeln(request.description);
    buffer.writeln();
  }
  
  // Due date
  buffer.writeln('**Due date:** ${_formatDate(request.dueAt)}');
  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln();
  
  // Instructions for filling the table
  buffer.writeln('Please fill out the table below with your data:');
  buffer.writeln('1. Copy ONLY the header row (the first row with column names)');
  buffer.writeln('2. Add your data row below it with your actual values');
  buffer.writeln('3. Reply to this email with the completed table');
  buffer.writeln();
  buffer.writeln('Example format (replace with your actual data):');
  buffer.writeln();
  
  // Table with example row - but make it clear it's an example
  buffer.writeln(_buildTable(request.schema));
  buffer.writeln();
  buffer.writeln('Note: The row above is just an example. Replace the example values with your actual data.');
  buffer.writeln();
  
  // Closing
  buffer.writeln('Thank you for your cooperation!');
  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln('Request ID: ${request.requestId}');
  
  return buffer.toString();
}

/// Generate email body for a reminder
String buildReminderEmailBody(DataRequest request) {
  final buffer = StringBuffer();
  
  buffer.writeln('Hello,');
  buffer.writeln();
  buffer.writeln('This is a friendly reminder that we are still waiting for your response to our data request.');
  buffer.writeln();
  buffer.writeln('**Request:** ${request.title}');
  buffer.writeln('**Due date:** ${_formatDate(request.dueAt)}');
  buffer.writeln();
  
  if (request.description != null && request.description!.isNotEmpty) {
    buffer.writeln(request.description);
    buffer.writeln();
  }
  
  buffer.writeln('---');
  buffer.writeln();
  
  // Instructions
  buffer.writeln('Please fill out the table below with your data and reply to this email:');
  buffer.writeln();
  
  // Table
  buffer.writeln(_buildTable(request.schema));
  buffer.writeln();
  buffer.writeln('Thank you!');
  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln('Request ID: ${request.requestId}');
  
  return buffer.toString();
}

/// Build markdown-style ASCII table with example row
String _buildTable(RequestSchema schema) {
  if (schema.columns.isEmpty) {
    return '';
  }
  
  final buffer = StringBuffer();
  
  // Header row - use exact column names from schema
  final headers = schema.columns.map((col) => col.name).toList();
  buffer.writeln(_buildTableRow(headers));
  
  // Separator row
  buffer.writeln(_buildTableSeparator(headers.length));
  
  // Example row with placeholders - but make it clear it's an example
  // Use shorter, clearer placeholders
  final exampleRow = schema.columns.map((col) {
    switch (col.type) {
      case ColumnType.stringType:
        return 'Your value here';
      case ColumnType.numberType:
        return '12345';
      case ColumnType.dateType:
        return '2026-01-15';
    }
  }).toList();
  buffer.writeln(_buildTableRow(exampleRow));
  
  return buffer.toString();
}

/// Build a table row
String _buildTableRow(List<String> cells) {
  return '| ${cells.map((cell) => cell.isEmpty ? ' ' : cell).join(' | ')} |';
}

/// Build table separator row
String _buildTableSeparator(int columnCount) {
  return '| ${List.filled(columnCount, '---').join(' | ')} |';
}

/// Format date for display
String _formatDate(DateTime date) {
  // Format: "January 5, 2025"
  final months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Convert schema to JSON string for machine-readable block
String _schemaToJsonString(RequestSchema schema) {
  final columnsJson = schema.columns.map((col) {
    return '{"name":"${col.name}","type":"${col.type.name}","required":${col.required}}';
  }).join(',');
  
  return '{"columns":[$columnsJson]}';
}

/// Extract request ID from email subject
/// Returns null if subject doesn't match the expected format
String? extractRequestIdFromSubject(String subject) {
  final regex = RegExp(r'\[DATA-REQ:([^\]]+)\]');
  final match = regex.firstMatch(subject);
  return match?.group(1);
}
