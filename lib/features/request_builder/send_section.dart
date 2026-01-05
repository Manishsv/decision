/// Send section with email preview

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:decision_agent/features/request_builder/request_builder_controller.dart';
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
    models.DataRequest? previewRequest;
    if (state.requestId != null && state.schema.columns.isNotEmpty) {
      previewRequest = models.DataRequest(
        requestId: state.requestId!,
        title: state.title,
        description: state.instructions,
        ownerEmail: '', // Not needed for preview
        dueAt: state.dueDate ?? DateTime.now().add(const Duration(days: 7)),
        schema: state.schema,
        recipients: state.recipients,
        sheetId: state.sheetId ?? '',
        sheetUrl: state.sheetUrl ?? '',
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
                  onPressed: state.sheetId == null
                      ? null
                      : () {
                          // TODO: Implement send in Sprint 3
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Send functionality will be available in Sprint 3'),
                            ),
                          );
                        },
                  child: const Text('Send Request'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
