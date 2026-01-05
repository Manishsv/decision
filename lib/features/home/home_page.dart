/// Home page with 3-pane layout

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:decision_agent/features/home/conversation_list.dart';
import 'package:decision_agent/features/home/conversation_page.dart';
import 'package:decision_agent/features/home/inspector_panel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DIGIT Decision'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/request/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: const Row(
        children: [
          // Left pane: Conversation list
          SizedBox(
            width: 280,
            child: ConversationList(),
          ),
          // Divider
          VerticalDivider(width: 1),
          // Center pane: Conversation/Request view
          Expanded(
            child: ConversationPage(),
          ),
          // Divider
          VerticalDivider(width: 1),
          // Right pane: Inspector
          SizedBox(
            width: 320,
            child: InspectorPanel(),
          ),
        ],
      ),
    );
  }
}
