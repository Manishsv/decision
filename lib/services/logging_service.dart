/// Logging service for activity tracking

import 'package:decision_agent/data/db/app_db.dart';
import 'package:decision_agent/data/db/dao.dart';
import 'package:decision_agent/domain/models.dart' as models;
import 'dart:convert';
import 'package:decision_agent/utils/ids.dart';

class LoggingService {
  final AppDatabase _db;

  LoggingService(this._db);

  /// Log an activity
  /// [requestId] - Request ID this activity relates to
  /// [type] - Type of activity
  /// [payload] - Additional data (will be JSON serialized)
  Future<void> logActivity(
    String requestId,
    models.ActivityType type,
    Map<String, dynamic> payload,
  ) async {
    try {
      final id = generateId();
      final payloadJson = jsonEncode(payload);
      
      final entry = models.ActivityLogEntry(
        id: id,
        requestId: requestId,
        timestamp: DateTime.now(),
        type: type,
        payloadJson: payloadJson,
      );
      
      await _db.insertActivityLog(entry);
    } catch (e) {
      // Log error but don't throw - logging failures shouldn't break the app
      print('Error logging activity: $e');
    }
  }

  /// Get activity logs for a request
  /// [requestId] - Request ID
  /// [limit] - Maximum number of logs to return (default: 100)
  /// Returns list of activity log entries, most recent first
  Future<List<models.ActivityLogEntry>> getActivityLogs(
    String requestId, {
    int limit = 100,
  }) async {
    try {
      return await _db.getActivityLogs(requestId, limit: limit);
    } catch (e) {
      print('Error getting activity logs: $e');
      return [];
    }
  }
}
