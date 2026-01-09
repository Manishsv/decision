/// Settings page

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:decision_agent/features/settings/settings_controller.dart';
import 'package:decision_agent/services/python_service.dart' as python;
import 'package:decision_agent/utils/error_handling.dart';
import 'package:decision_agent/utils/validation.dart';

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
    
    // Validate OpenAI key format if provided
    final keyValidation = validateOpenAiKey(_openAiKeyController.text);
    if (!keyValidation.isValid) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(keyValidation.errorMessage!),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    
    await controller.saveOpenAiKey(_openAiKeyController.text);
    
    if (mounted && context.mounted) {
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserFriendlyMessage(state.error!)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ErrorHandler.getUserFriendlyMessage(state.error!),
                            style: TextStyle(color: Colors.red[800]),
                          ),
                          if (ErrorHandler.getRecoverySuggestion(state.error!) != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              ErrorHandler.getRecoverySuggestion(state.error!)!,
                              style: TextStyle(
                                color: Colors.red[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 48),
                const Divider(),
                const SizedBox(height: 24),
                _PythonInstallationSection(),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

/// Python Installation Check Section
class _PythonInstallationSection extends ConsumerStatefulWidget {
  const _PythonInstallationSection();

  @override
  ConsumerState<_PythonInstallationSection> createState() => _PythonInstallationSectionState();
}

class _PythonInstallationSectionState extends ConsumerState<_PythonInstallationSection> {
  python.PythonCheckResult? _checkResult;
  bool _isChecking = false;
  bool _isInstalling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPython();
    });
  }

  Future<void> _checkPython() async {
    setState(() {
      _isChecking = true;
    });

    try {
      final pythonService = ref.read(python.pythonServiceProvider);
      final result = await pythonService.checkPythonInstallation();
      if (mounted) {
        setState(() {
          _checkResult = result;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkResult = python.PythonCheckResult(
            isInstalled: false,
            hasRequiredPackages: false,
            error: e.toString(),
          );
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _installPython() async {
    setState(() {
      _isInstalling = true;
    });

    try {
      final pythonService = ref.read(python.pythonServiceProvider);
      final result = await pythonService.installPython();
      
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Python installed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Recheck after installation
          await Future.delayed(const Duration(seconds: 2));
          await _checkPython();
        } else {
          // Show installation instructions
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Python Installation'),
              content: SingleChildScrollView(
                child: Text(result.message ?? result.error ?? 'Installation failed'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInstalling = false;
        });
      }
    }
  }

  Future<void> _installPackages() async {
    setState(() {
      _isInstalling = true;
    });

    try {
      final pythonService = ref.read(python.pythonServiceProvider);
      final result = await pythonService.installRequiredPackages();
      
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Packages installed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          await _checkPython();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? result.error ?? 'Installation failed'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInstalling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.code, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Python Environment',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (_isChecking)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isInstalling ? null : _checkPython,
                tooltip: 'Refresh',
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Required for data visualization features',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        if (_checkResult == null && _isChecking)
          const Center(child: CircularProgressIndicator())
        else if (_checkResult != null)
          _buildStatusCard(context),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final result = _checkResult!;
    final isReady = result.isReady;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReady ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReady ? Colors.green[200]! : Colors.orange[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReady ? Icons.check_circle : Icons.warning,
                color: isReady ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                isReady ? 'Python is ready!' : 'Python setup required',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isReady ? Colors.green[800] : Colors.orange[800],
                ),
              ),
            ],
          ),
          if (result.isInstalled && result.version != null) ...[
            const SizedBox(height: 12),
            Text('Version: ${result.version}'),
            if (result.executablePath != null)
              Text(
                'Path: ${result.executablePath}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
          if (!result.isInstalled) ...[
            const SizedBox(height: 12),
            const Text(
              'Python is not installed on your system.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isInstalling ? null : _installPython,
              icon: _isInstalling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_isInstalling ? 'Installing...' : 'Install Python'),
            ),
          ],
          if (result.isInstalled && !result.hasRequiredPackages) ...[
            const SizedBox(height: 12),
            Text(
              'Missing packages: ${result.missingPackages.join(', ')}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isInstalling ? null : _installPackages,
              icon: _isInstalling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.install_mobile),
              label: Text(_isInstalling ? 'Installing...' : 'Install Packages'),
            ),
          ],
          if (result.error != null) ...[
            const SizedBox(height: 8),
            Text(
              'Error: ${result.error}',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
