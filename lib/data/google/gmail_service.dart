/// Gmail service for reading and sending emails

import 'dart:convert';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:decision_agent/data/google/google_auth_service.dart';

class GmailService {
  final GoogleAuthService _authService;

  GmailService(this._authService);

  /// Get Gmail API client
  Future<gmail.GmailApi> _getGmailApi() async {
    final httpClient = await _authService.getAuthClient();
    return gmail.GmailApi(httpClient);
  }

  /// Send an email
  /// [to] - Recipient email address(es) - comma-separated for multiple
  /// [subject] - Email subject
  /// [body] - Email body (plain text)
  /// [replyTo] - Optional reply-to email address
  /// Returns the message ID of the sent email
  Future<String> sendEmail({
    required String to,
    required String subject,
    required String body,
    String? replyTo,
  }) async {
    try {
      final api = await _getGmailApi();
      
      // Build the email message
      final message = gmail.Message();
      
      // Create email headers
      final headers = <String, String>{
        'To': to,
        'Subject': subject,
        'Content-Type': 'text/plain; charset=utf-8',
      };
      
      if (replyTo != null) {
        headers['Reply-To'] = replyTo;
      }
      
      // Build raw email message (RFC 2822 format)
      final emailParts = <String>[];
      headers.forEach((key, value) {
        emailParts.add('$key: $value');
      });
      emailParts.add(''); // Empty line between headers and body
      emailParts.add(body);
      
      final rawMessage = emailParts.join('\r\n');
      
      // Encode to base64url (Gmail API requirement)
      final bytes = utf8.encode(rawMessage);
      final base64Message = base64Url.encode(bytes);
      
      message.raw = base64Message;
      
      // Send the email
      final sentMessage = await api.users.messages.send(
        message,
        'me',
      );
      
      return sentMessage.id ?? '';
    } catch (e) {
      throw Exception('Failed to send email: $e');
    }
  }

  /// Search for messages matching a query
  /// [query] - Gmail search query (e.g., "subject:test", "from:example@gmail.com")
  /// Returns list of message IDs
  Future<List<String>> searchMessages(String query) async {
    try {
      final api = await _getGmailApi();
      
      final response = await api.users.messages.list(
        'me',
        q: query,
      );
      
      return response.messages?.map((m) => m.id ?? '').where((id) => id.isNotEmpty).toList() ?? [];
    } catch (e) {
      throw Exception('Failed to search messages: $e');
    }
  }

  /// Get a message by ID
  /// [messageId] - Gmail message ID
  /// Returns the message object
  Future<gmail.Message> getMessage(String messageId) async {
    try {
      final api = await _getGmailApi();
      
      final message = await api.users.messages.get(
        'me',
        messageId,
        format: 'full', // Get full message with body
      );
      
      return message;
    } catch (e) {
      throw Exception('Failed to get message: $e');
    }
  }

  /// Extract plain text body from a message
  /// [message] - Gmail message object
  /// Returns the plain text body, or null if not found
  String? extractPlainTextBody(gmail.Message message) {
    if (message.payload == null) return null;
    
    // Check if message has a plain text part
    final payload = message.payload!;
    
    if (payload.body?.data != null) {
      // Single part message
      return _decodeBase64Url(payload.body!.data!);
    }
    
    // Multi-part message - find text/plain part
    if (payload.parts != null) {
      for (final part in payload.parts!) {
        if (part.mimeType == 'text/plain' && part.body?.data != null) {
          return _decodeBase64Url(part.body!.data!);
        }
        
        // Check nested parts (for multipart/alternative)
        if (part.parts != null) {
          for (final nestedPart in part.parts!) {
            if (nestedPart.mimeType == 'text/plain' && nestedPart.body?.data != null) {
              return _decodeBase64Url(nestedPart.body!.data!);
            }
          }
        }
      }
    }
    
    return null;
  }

  /// Decode base64url encoded string
  String _decodeBase64Url(String encoded) {
    try {
      // Replace URL-safe characters
      final base64 = encoded.replaceAll('-', '+').replaceAll('_', '/');
      // Add padding if needed
      final padded = base64.padRight((base64.length + 3) ~/ 4 * 4, '=');
      final bytes = base64Decode(padded);
      return utf8.decode(bytes);
    } catch (e) {
      return '';
    }
  }
}
