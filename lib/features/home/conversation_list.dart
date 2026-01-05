/// Left pane: Conversation list

import 'package:flutter/material.dart';

class ConversationList extends StatelessWidget {
  const ConversationList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Conversations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  // TODO: Navigate to request builder
                },
                tooltip: 'New Request',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List (empty for now)
        Expanded(
          child: ListView(
            children: [
              // Placeholder
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No conversations yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
