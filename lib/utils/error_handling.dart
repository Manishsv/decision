/// User-friendly error handling utilities
/// 
/// Provides functions to convert technical errors into user-friendly messages
/// and handle error scenarios gracefully.

import 'package:http/http.dart' as http;
import 'dart:io';

/// Converts technical exceptions into user-friendly error messages
class ErrorHandler {
  /// Get a user-friendly error message from an exception
  static String getUserFriendlyMessage(Object error) {
    final errorString = error.toString().toLowerCase();

    // Network-related errors
    if (errorString.contains('socketexception') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('internet') ||
        error is SocketException) {
      return 'Network connection failed. Please check your internet connection and try again.';
    }

    // HTTP errors
    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return 'Authentication failed. Please sign in again.';
    }

    if (errorString.contains('403') || errorString.contains('forbidden')) {
      return 'Access denied. Please check your permissions.';
    }

    if (errorString.contains('404') || errorString.contains('not found')) {
      return 'Resource not found. The item may have been deleted.';
    }

    if (errorString.contains('429') || errorString.contains('rate limit')) {
      return 'Too many requests. Please wait a moment and try again.';
    }

    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('server error')) {
      return 'Service temporarily unavailable. Please try again later.';
    }

    // OAuth/Google API errors
    if (errorString.contains('oauth') ||
        errorString.contains('client_id') ||
        errorString.contains('client_secret') ||
        errorString.contains('redirect_uri')) {
      return 'Authentication configuration error. Please check your OAuth settings.';
    }

    if (errorString.contains('invalid_grant') ||
        errorString.contains('token')) {
      return 'Your session has expired. Please sign in again.';
    }

    if (errorString.contains('quota') ||
        errorString.contains('limit exceeded')) {
      return 'API quota exceeded. Please try again later or contact support.';
    }

    // Database errors
    if (errorString.contains('database') ||
        errorString.contains('sqlite') ||
        errorString.contains('database is locked')) {
      return 'Database error. Please restart the app. If the problem persists, contact support.';
    }

    // File/IO errors
    if (errorString.contains('file') ||
        errorString.contains('permission denied') ||
        error is FileSystemException) {
      return 'File access error. Please check file permissions.';
    }

    // JSON/parsing errors
    if (errorString.contains('json') ||
        errorString.contains('parse') ||
        errorString.contains('invalid format')) {
      return 'Data format error. The received data may be corrupted.';
    }

    // Timeout errors
    if (errorString.contains('timeout') ||
        errorString.contains('timed out')) {
      return 'Request timed out. Please check your connection and try again.';
    }

    // Generic error - show original but make it more readable
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring(11); // Remove "Exception: " prefix
    }
    if (message.startsWith('Error: ')) {
      return message.substring(7); // Remove "Error: " prefix
    }

    return 'An unexpected error occurred: ${error.toString()}';
  }

  /// Get a detailed error message for debugging (development only)
  static String getDetailedError(Object error, [StackTrace? stackTrace]) {
    return 'Error: $error\n${stackTrace ?? ''}';
  }

  /// Check if error is recoverable (user can retry)
  static bool isRecoverable(Object error) {
    final errorString = error.toString().toLowerCase();

    // These errors are typically recoverable
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('429') ||
        errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        error is SocketException) {
      return true;
    }

    return false;
  }

  /// Get suggestion for error recovery
  static String? getRecoverySuggestion(Object error) {
    if (!isRecoverable(error)) {
      return null;
    }

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Check your internet connection and try again.';
    }

    if (errorString.contains('timeout')) {
      return 'The request took too long. Try again with a better connection.';
    }

    if (errorString.contains('429')) {
      return 'Too many requests. Wait a few minutes before trying again.';
    }

    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503')) {
      return 'The service is temporarily unavailable. Try again in a few minutes.';
    }

    return 'Please try again.';
  }
}
