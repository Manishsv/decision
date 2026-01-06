/// Send section with email preview

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:decision_agent/features/request_builder/request_builder_controller.dart';
import 'package:decision_agent/features/home/conversation_page.dart';
import 'package:decision_agent/domain/email_protocol.dart';
import 'package:decision_agent/domain/models.dart' as models;
import 'package:decision_agent/data/db/app_db.dart';
import 'package:decision_agent/data/google/google_auth_service.dart';

class SendSection extends ConsumerWidget {
  const SendSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(requestBuilderControllerProvider);
    final controller = ref.watch(requestBuilderControllerProvider.notifier);

    // Build preview request (for email preview)
    // Note: conversationId is required but may not be set yet during preview
    models.DataRequest? previewRequest;
    if (state.requestId != null && state.schema.columns.isNotEmpty) {
      // For preview, we can use a placeholder conversationId
      // The actual conversationId will be set when the request is created
      previewRequest = models.DataRequest(
        requestId: state.requestId!,
        conversationId: 'preview', // Placeholder for preview
        title: state.title,
        description: state.instructions,
        ownerEmail: '', // Not needed for preview
        dueAt: state.dueDate ?? DateTime.now().add(const Duration(days: 7)),
        schema: state.schema,
        recipients: state.recipients,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Preview & Send',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review the email that will be sent to recipients',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: previewRequest == null
                ? const Center(
                    child: Text('Complete previous steps to see preview'),
                  )
                : SingleChildScrollView(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Subject: ${buildRequestSubject(previewRequest)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Divider(),
                            Text(
                              buildRequestEmailBody(previewRequest),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await controller.createDraft();
                    if (context.mounted) {
                      // Refresh conversations list
                      ref.invalidate(conversationsProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Draft saved')),
                      );
                      context.go('/home');
                    }
                  },
                  child: const Text('Save Draft'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: (state.sheetUrl == null || state.sheetUrl!.isEmpty || state.isLoading)
                      ? null
                      : () async {
                          // Show confirmation dialog
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Send Request?'),
                              content: Text(
                                'This will send emails to ${state.recipients.length} recipient(s). Continue?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Send'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed != true || !context.mounted) return;

                          // Send request
                          final results = await controller.sendRequest();

                          if (!context.mounted) return;

                          if (results == null) {
                            // Error occurred
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  state.error ?? 'Failed to send request',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            // Success
                            final sent = results['sent'] as int;
                            final failed = results['failed'] as int;
                            final errors = results['errors'] as List<String>;

                            // Refresh conversations list
                            ref.invalidate(conversationsProvider);
                            
                            if (failed == 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Successfully sent to $sent recipient(s)'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              // Navigate to home
                              context.go('/home');
                            } else {
                              // Some failed
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Send Results'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Sent: $sent'),
                                      Text('Failed: $failed'),
                                      if (errors.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ...errors.take(5).map((e) => Text('• $e', style: const TextStyle(fontSize: 12))),
                                        if (errors.length > 5)
                                          Text('... and ${errors.length - 5} more', style: const TextStyle(fontSize: 12)),
                                      ],
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text('OK'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        // Refresh conversations list
                                        ref.invalidate(conversationsProvider);
                                        context.go('/home');
                                      },
                                      child: const Text('View Request'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                  child: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Request'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
