/// Settings controller (Riverpod provider)

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/app/db_provider.dart';
import 'package:decision_agent/data/db/app_db.dart';
import 'package:decision_agent/data/db/dao.dart';

const String _openAiKeyKey = 'openai_key';

class SettingsController extends StateNotifier<AsyncValue<void>> {
  final AppDatabase _db;
  
  SettingsController(AppDatabase db) 
      : _db = db,
        super(const AsyncValue.data(null));
  
  // Memory cache for performance
  String? _cachedOpenAiKey;

  /// Get OpenAI API key
  Future<String?> getOpenAiKey() async {
    // First check memory cache (performance optimization)
    if (_cachedOpenAiKey != null && _cachedOpenAiKey!.isNotEmpty) {
      return _cachedOpenAiKey;
    }

    // Get from database (cross-platform)
    try {
      final stored = await _db.getCredential(_openAiKeyKey);
      if (stored != null && stored.isNotEmpty) {
        // Update cache for future use
        _cachedOpenAiKey = stored;
        return stored;
      }
    } catch (e) {
      debugPrint('Error reading OpenAI key from database: $e');
    }

    return null;
  }

  /// Save OpenAI API key
  Future<void> saveOpenAiKey(String? key) async {
    state = const AsyncValue.loading();
    try {
      if (key != null && key.isNotEmpty) {
        // Store in database (cross-platform)
        await _db.saveCredential(_openAiKeyKey, key);
        _cachedOpenAiKey = key; // Update memory cache
        debugPrint('OpenAI key stored in database');
      } else {
        // Delete key
        await _db.deleteCredential(_openAiKeyKey);
        _cachedOpenAiKey = null; // Clear memory cache
        debugPrint('OpenAI key deleted from database');
      }
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Delete OpenAI API key
  Future<void> deleteOpenAiKey() async {
    await saveOpenAiKey(null);
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AsyncValue<void>>((ref) {
  final db = ref.read(appDatabaseProvider);
  return SettingsController(db);
});
