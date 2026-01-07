/// Send section with email preview and participant selection

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:decision_agent/features/request_builder/request_builder_controller.dart';
import 'package:decision_agent/features/home/conversation_page.dart';
import 'package:decision_agent/features/home/inspector_panel.dart';
import 'package:decision_agent/domain/email_protocol.dart';
import 'package:decision_agent/domain/models.dart' as models;

class SendSection extends ConsumerStatefulWidget {
  const SendSection({super.key});

  @override
  ConsumerState<SendSection> createState() => _SendSectionState();
}

class _SendSectionState extends ConsumerState<SendSection> {
  final _newEmailController = TextEditingController();
  final Set<String> _selectedParticipants = {};

  @override
  void dispose() {
    _newEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestBuilderControllerProvider);
    final controller = ref.watch(requestBuilderControllerProvider.notifier);

    // Check if this is a new request in existing conversation
    final isNewRequest = state.conversationId != null && 
                        state.conversationId!.isNotEmpty &&
                        state.requestId == null;

    // Load existing participants if this is a new request
    final participantsAsync = isNewRequest && state.conversationId != null
        ? ref.watch(conversationParticipantsProvider(state.conversationId!))
        : null;

    // Build preview request (for email preview)
    models.DataRequest? previewRequest;
    if (state.requestId != null && state.schema.columns.isNotEmpty) {
      previewRequest = models.DataRequest(
        requestId: state.requestId!,
        conversationId: state.conversationId ?? 'preview',
        title: state.title,
        description: state.instructions,
        ownerEmail: '',
        dueAt: state.dueDate ?? DateTime.now().add(const Duration(days: 7)),
        schema: state.schema,
        recipients: state.recipients,
      );
    } else if (state.conversationId != null && state.schema.columns.isNotEmpty) {
      // For preview before request is created
      previewRequest = models.DataRequest(
        requestId: 'preview',
        conversationId: state.conversationId!,
        title: state.title,
        description: state.instructions,
        ownerEmail: '',
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
          
          // Participant selection for new requests
          if (isNewRequest && participantsAsync != null) ...[
            participantsAsync.when(
              data: (participants) {
                // Initialize selected participants with all existing participants
                if (_selectedParticipants.isEmpty && participants.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _selectedParticipants.addAll(
                        participants.map((p) => p.email).toSet(),
                      );
                      // Update controller with selected participants
                      controller.updateRecipients(_selectedParticipants.toList());
                    });
                  });
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'To:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Existing participants checkboxes
                        if (participants.isNotEmpty) ...[
                          const Text(
                            'Existing Participants:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...participants.map((participant) {
                            return CheckboxListTile(
                              title: Text(participant.email),
                              subtitle: Text(_getStatusText(participant.status)),
                              value: _selectedParticipants.contains(participant.email),
                              onChanged: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedParticipants.add(participant.email);
                                  } else {
                                    _selectedParticipants.remove(participant.email);
                                  }
                                  controller.updateRecipients(_selectedParticipants.toList());
                                });
                              },
                              dense: true,
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                        // Add new email
                        const Text(
                          'Add New Participants:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newEmailController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter email address',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onSubmitted: (email) {
                                  _addNewEmail(email.trim());
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                _addNewEmail(_newEmailController.text.trim());
                              },
                              tooltip: 'Add email',
                            ),
                          ],
                        ),
                        // Show added new emails
                        if (_selectedParticipants.length > participants.length) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedParticipants
                                .where((email) => !participants.any((p) => p.email == email))
                                .map((email) => Chip(
                                      label: Text(email),
                                      onDeleted: () {
                                        setState(() {
                                          _selectedParticipants.remove(email);
                                          controller.updateRecipients(_selectedParticipants.toList());
                                        });
                                      },
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('Error loading participants: $error'),
            ),
            const SizedBox(height: 16),
          ] else if (!isNewRequest) ...[
            // For new conversations, show recipients editor info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Recipients:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (state.recipients.isEmpty)
                      const Text(
                        'No recipients added. Please go back and add recipients.',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      ...state.recipients.map((email) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text('• $email'),
                          )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Email preview
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
                          // Validate recipients
                          if (state.recipients.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select at least one recipient'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  state.error ?? 'Failed to send request',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            final sent = results['sent'] as int;
                            final failed = results['failed'] as int;
                            final errors = results['errors'] as List<String>;

                            // Invalidate all related providers to refresh UI
                            ref.invalidate(conversationsProvider);
                            if (state.conversationId != null) {
                              ref.invalidate(conversationRequestsProvider(state.conversationId!));
                              ref.invalidate(conversationParticipantsProvider(state.conversationId!));
                              ref.invalidate(conversationActivityLogsProvider(state.conversationId!));
                            }
                            
                            if (failed == 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Successfully sent to $sent recipient(s)'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              context.go('/home');
                            } else {
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
                                        ref.invalidate(conversationsProvider);
                                        if (state.conversationId != null) {
                                          ref.invalidate(conversationRequestsProvider(state.conversationId!));
                                          ref.invalidate(conversationParticipantsProvider(state.conversationId!));
                                          ref.invalidate(conversationActivityLogsProvider(state.conversationId!));
                                        }
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

  void _addNewEmail(String email) {
    if (email.isEmpty) return;
    
    // Basic email validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _selectedParticipants.add(email);
      _newEmailController.clear();
      final controller = ref.read(requestBuilderControllerProvider.notifier);
      controller.updateRecipients(_selectedParticipants.toList());
    });
  }

  String _getStatusText(models.RecipientState status) {
    switch (status) {
      case models.RecipientState.responded:
        return 'Responded';
      case models.RecipientState.pending:
        return 'Pending';
      case models.RecipientState.error:
        return 'Error';
      case models.RecipientState.bounced:
        return 'Bounced';
    }
  }
}
