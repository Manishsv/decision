/// Left pane: Conversation list

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:decision_agent/features/home/conversation_page.dart';
import 'package:decision_agent/domain/models.dart' as models;
import 'package:decision_agent/app/db_provider.dart';
import 'package:decision_agent/data/db/dao.dart';

class ConversationList extends ConsumerWidget {
  const ConversationList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final selectedId = ref.watch(selectedConversationIdProvider);

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
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  // Refresh conversations list
                  ref.invalidate(conversationsProvider);
                },
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => context.go('/request/new'),
                tooltip: 'New Request',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List
        Expanded(
          child: conversationsAsync.when(
            data: (conversations) {
              if (conversations.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No conversations yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  final isSelected = conversation.id == selectedId;

                  return _ConversationListItem(
                    conversation: conversation,
                    isSelected: isSelected,
                    onTap: () {
                      ref.read(selectedConversationIdProvider.notifier).state = conversation.id;
                    },
                    onArchive: () async {
                      await _archiveConversation(ref, conversation.id);
                    },
                    onDelete: () async {
                      await _deleteConversation(context, ref, conversation);
                    },
                  );
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading conversations: $error',
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  Future<void> _archiveConversation(WidgetRef ref, String conversationId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db.archiveConversation(conversationId);
      // Refresh conversations list
      ref.invalidate(conversationsProvider);
      // Clear selection if this conversation was selected
      final selectedId = ref.read(selectedConversationIdProvider);
      if (selectedId == conversationId) {
        ref.read(selectedConversationIdProvider.notifier).state = null;
      }
    } catch (e) {
      // Error handling - could show a snackbar here
      debugPrint('Error archiving conversation: $e');
    }
  }

  Future<void> _deleteConversation(
    BuildContext context,
    WidgetRef ref,
    models.Conversation conversation,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation?'),
        content: Text(
          'Are you sure you want to delete "${conversation.title}"?\n\n'
          'This will permanently delete:\n'
          '• The conversation\n'
          '• The request and all its data\n'
          '• Recipient statuses\n'
          '• Activity logs\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = ref.read(appDatabaseProvider);
      await db.deleteConversation(conversation.id);
      // Refresh conversations list
      ref.invalidate(conversationsProvider);
      // Clear selection if this conversation was selected
      final selectedId = ref.read(selectedConversationIdProvider);
      if (selectedId == conversation.id) {
        ref.read(selectedConversationIdProvider.notifier).state = null;
      }
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _ConversationListItem extends StatelessWidget {
  final models.Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _ConversationListItem({
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onArchive,
    required this.onDelete,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: () {
        // Show context menu on long press
        showModalBottomSheet(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.archive),
                  title: const Text('Archive'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onArchive();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(context).pop();
                    onDelete();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    conversation.title,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Status removed - conversations don't have status, requests do
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(conversation.updatedAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Status indicator removed - conversations don't have status, requests do
