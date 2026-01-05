/// Recipients editor widget

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/features/request_builder/request_builder_controller.dart';

class RecipientsEditor extends ConsumerStatefulWidget {
  const RecipientsEditor({super.key});

  @override
  ConsumerState<RecipientsEditor> createState() => _RecipientsEditorState();
}

class _RecipientsEditorState extends ConsumerState<RecipientsEditor> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(requestBuilderControllerProvider);
    _textController.text = state.recipients.join('\n');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  List<String> _parseRecipients(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestBuilderControllerProvider);
    final controller = ref.watch(requestBuilderControllerProvider.notifier);

    final recipients = _parseRecipients(_textController.text);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Recipients',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter email addresses, one per line',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Email Addresses *',
              hintText: 'recipient1@example.com\nrecipient2@example.com',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 8,
            onChanged: (value) {
              controller.updateRecipients(_parseRecipients(value));
            },
          ),
          const SizedBox(height: 24),
          if (recipients.isNotEmpty) ...[
            const Text(
              'Parsed Recipients:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: recipients.length,
                itemBuilder: (context, index) {
                  final email = recipients[index];
                  final isValid = _isValidEmail(email);
                  return ListTile(
                    leading: Icon(
                      isValid ? Icons.check_circle : Icons.error,
                      color: isValid ? Colors.green : Colors.red,
                    ),
                    title: Text(email),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }
}
