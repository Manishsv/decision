/// Settings page

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:decision_agent/features/settings/settings_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _openAiKeyController = TextEditingController();
  bool _keyLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadOpenAiKey();
  }

  @override
  void dispose() {
    _openAiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadOpenAiKey() async {
    final controller = ref.read(settingsControllerProvider.notifier);
    final key = await controller.getOpenAiKey();
    if (mounted) {
      _openAiKeyController.text = key ?? '';
      setState(() {
        _keyLoaded = true;
      });
    }
  }

  Future<void> _saveOpenAiKey() async {
    final controller = ref.read(settingsControllerProvider.notifier);
    final state = ref.watch(settingsControllerProvider);
    
    await controller.saveOpenAiKey(_openAiKeyController.text);
    
    if (mounted && context.mounted) {
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${state.error}'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OpenAI API key saved')),
        );
      }
    }
  }

  Future<void> _deleteOpenAiKey() async {
    final controller = ref.read(settingsControllerProvider.notifier);
    await controller.deleteOpenAiKey();
    
    if (mounted) {
      _openAiKeyController.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OpenAI API key deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: _keyLoaded
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'OpenAI API Key',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Optional: Used for summarization features',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _openAiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'OpenAI API Key',
                    hintText: 'sk-...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key),
                    helperText: 'Used for summarization features (optional)',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: state.isLoading ? null : _saveOpenAiKey,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: state.isLoading
                          ? null
                          : _openAiKeyController.text.isEmpty
                              ? null
                              : _deleteOpenAiKey,
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        'Error: ${state.error}',
                        style: TextStyle(color: Colors.red[800]),
                      ),
                    ),
                  ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
