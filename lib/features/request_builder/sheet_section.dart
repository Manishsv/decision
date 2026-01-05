/// Sheet creation section

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:decision_agent/features/request_builder/request_builder_controller.dart';

class SheetSection extends ConsumerWidget {
  const SheetSection({super.key});

  Future<void> _openSheet(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(requestBuilderControllerProvider);
    final controller = ref.watch(requestBuilderControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create Google Sheet',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'A Google Sheet will be created to collect responses',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          if (state.sheetId == null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.table_chart, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Sheet not created yet',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: state.isLoading
                          ? null
                          : () async {
                              await controller.createDraft();
                              await controller.createSheet();
                            },
                      icon: state.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(state.isLoading ? 'Creating...' : 'Create Sheet'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text(
                      'Sheet Created!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (state.sheetUrl != null)
                      OutlinedButton.icon(
                        onPressed: () => _openSheet(state.sheetUrl!),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open Sheet'),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                state.error!,
                style: TextStyle(color: Colors.red[800]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
