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
/// Includes human instructions, machine-readable block, and copy/paste table
String buildRequestEmailBody(DataRequest request) {
  final buffer = StringBuffer();
  
  // Human-readable instructions
  buffer.writeln('Hello,');
  buffer.writeln();
  buffer.writeln('We are requesting data from you. Please fill out the table below and reply to this email.');
  buffer.writeln();
  
  if (request.description != null && request.description!.isNotEmpty) {
    buffer.writeln(request.description);
    buffer.writeln();
  }
  
  buffer.writeln('Due date: ${_formatDate(request.dueAt)}');
  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln();
  
  // Machine-readable block (for parsing)
  buffer.writeln('```data-request');
  buffer.writeln('requestId: ${request.requestId}');
  buffer.writeln('schema: ${_schemaToJsonString(request.schema)}');
  buffer.writeln('```');
  buffer.writeln();
  
  // Copy/paste table with headers
  buffer.writeln('Please fill out this table and reply:');
  buffer.writeln();
  buffer.writeln(_buildTable(request.schema));
  buffer.writeln();
  buffer.writeln('Thank you!');
  
  return buffer.toString();
}

/// Generate email body for a reminder
String buildReminderEmailBody(DataRequest request) {
  final buffer = StringBuffer();
  
  buffer.writeln('Hello,');
  buffer.writeln();
  buffer.writeln('This is a reminder that we are still waiting for your response to our data request.');
  buffer.writeln();
  buffer.writeln('Request: ${request.title}');
  buffer.writeln('Due date: ${_formatDate(request.dueAt)}');
  buffer.writeln();
  
  if (request.description != null && request.description!.isNotEmpty) {
    buffer.writeln(request.description);
    buffer.writeln();
  }
  
  buffer.writeln('---');
  buffer.writeln();
  
  // Machine-readable block
  buffer.writeln('```data-request');
  buffer.writeln('requestId: ${request.requestId}');
  buffer.writeln('schema: ${_schemaToJsonString(request.schema)}');
  buffer.writeln('```');
  buffer.writeln();
  
  // Copy/paste table
  buffer.writeln('Please fill out this table and reply:');
  buffer.writeln();
  buffer.writeln(_buildTable(request.schema));
  buffer.writeln();
  buffer.writeln('Thank you!');
  
  return buffer.toString();
}

/// Build markdown-style ASCII table
String _buildTable(RequestSchema schema) {
  if (schema.columns.isEmpty) {
    return '';
  }
  
  final buffer = StringBuffer();
  
  // Header row
  final headers = schema.columns.map((col) => col.name).toList();
  buffer.writeln(_buildTableRow(headers));
  
  // Separator row
  buffer.writeln(_buildTableSeparator(headers.length));
  
  // Empty data row (for recipient to fill)
  buffer.writeln(_buildTableRow(List.filled(headers.length, '')));
  
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
