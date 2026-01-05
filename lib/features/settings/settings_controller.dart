/// Settings controller (Riverpod provider)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const String _openAiKeyKey = 'openai_key';

class SettingsController extends StateNotifier<AsyncValue<void>> {
  SettingsController() : super(const AsyncValue.data(null));

  /// Get OpenAI API key
  Future<String?> getOpenAiKey() async {
    try {
      return await _storage.read(key: _openAiKeyKey);
    } catch (e) {
      return null;
    }
  }

  /// Save OpenAI API key
  Future<void> saveOpenAiKey(String? key) async {
    state = const AsyncValue.loading();
    try {
      if (key != null && key.isNotEmpty) {
        await _storage.write(key: _openAiKeyKey, value: key);
      } else {
        await _storage.delete(key: _openAiKeyKey);
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
  return SettingsController();
});
