/// Database provider - singleton instance for AppDatabase

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/data/db/app_db.dart';

/// Global singleton instance for database
/// This ensures all parts of the app use the same instance,
/// which is critical for avoiding race conditions and database corruption
final _globalDb = AppDatabase();

/// Singleton provider for AppDatabase
/// This ensures all parts of the app use the same instance
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  // Use the same global singleton instance
  return _globalDb;
});

/// Export the global database instance for use in auth_provider
/// This allows auth_provider to use the same database instance
AppDatabase get globalDb => _globalDb;
