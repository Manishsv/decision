/// Home page with 3-pane layout

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/features/home/conversation_list.dart';
import 'package:decision_agent/features/home/conversation_page.dart';
import 'package:decision_agent/features/home/inspector_panel.dart';
import 'package:decision_agent/features/profile/profile_menu_button.dart';
import 'package:decision_agent/app/db_provider.dart';
import 'package:decision_agent/app/auth_provider.dart';
import 'package:decision_agent/services/request_service.dart';
import 'package:decision_agent/data/google/sheets_service.dart';
import 'package:decision_agent/data/google/gmail_service.dart';
import 'package:decision_agent/services/logging_service.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // Refresh conversations when page is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(conversationsProvider);
    });
  }

  Future<void> _createNewConversation(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get services
      final db = ref.read(appDatabaseProvider);
      final authService = ref.read(googleAuthServiceProvider);
      final sheetsService = SheetsService(authService);
      final gmailService = GmailService(authService);
      final loggingService = LoggingService(db);
      final requestService = RequestService(
        db,
        sheetsService,
        authService,
        gmailService,
        loggingService,
      );

      // Create conversation with default name
      final conversationId = await requestService.createConversation(
        title: 'New Conversation',
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Refresh conversations list
      ref.invalidate(conversationsProvider);

      // Select the new conversation
      ref.read(selectedConversationIdProvider.notifier).state = conversationId;

      // The auto-introduction will kick in automatically
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        // Command+N on macOS, Ctrl+N on Windows/Linux
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _NewConversationIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _NewConversationIntent(),
      },
      child: Actions(
        actions: {
          _NewConversationIntent: CallbackAction<_NewConversationIntent>(
            onInvoke: (_) {
              _createNewConversation(context);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
          appBar: AppBar(
            title: const Text('DIGIT Decision'),
            actions: [
              const ProfileMenuButton(),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _createNewConversation(context),
            icon: const Icon(Icons.add),
            label: const Text('New Conversation'),
          ),
          body: Row(
        children: [
          // Left pane: Conversation list
          const SizedBox(
            width: 280,
            child: ConversationList(),
          ),
          // Divider
          const VerticalDivider(width: 1),
          // Center pane: Conversation/Request view
          const Expanded(
            child: ConversationPage(),
          ),
          // Divider (only show if inspector is visible)
          Consumer(
            builder: (context, ref, child) {
              final isVisible = ref.watch(inspectorPanelVisibleProvider);
              return isVisible ? const VerticalDivider(width: 1) : const SizedBox.shrink();
            },
          ),
          // Right pane: Inspector (collapsible)
          const InspectorPanel(),
        ],
      ),
          ),
        ),
      ),
    );
  }
}

/// Intent for creating a new conversation
class _NewConversationIntent extends Intent {
  const _NewConversationIntent();
}
