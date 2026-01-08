/// Left pane: Conversation list

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/features/home/conversation_page.dart';
import 'package:decision_agent/domain/models.dart' as models;
import 'package:decision_agent/app/db_provider.dart';
import 'package:decision_agent/data/db/dao.dart';
import 'package:decision_agent/app/auth_provider.dart';
import 'package:decision_agent/services/request_service.dart';
import 'package:decision_agent/data/google/sheets_service.dart';
import 'package:decision_agent/data/google/gmail_service.dart';
import 'package:decision_agent/services/logging_service.dart';
import 'package:decision_agent/utils/error_handling.dart';

class ConversationList extends ConsumerStatefulWidget {
  const ConversationList({super.key});

  @override
  ConsumerState<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends ConsumerState<ConversationList> {
  final List<models.Conversation> _loadedConversations = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    // Load initial conversations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversations(ref, append: false);
    });
  }

  Future<void> _loadConversations(
    WidgetRef ref, {
    bool append = true,
  }) async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final db = ref.read(appDatabaseProvider);
      final offset = append ? _loadedConversations.length : 0;
      final newConversations = await db.getConversations(
        limit: 50, // _conversationsPageSize
        offset: offset,
      );

      setState(() {
        if (append) {
          _loadedConversations.addAll(newConversations);
        } else {
          _loadedConversations.clear();
          _loadedConversations.addAll(newConversations);
        }
        _hasMore = newConversations.length >= 50; // _conversationsPageSize
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  _loadConversations(ref, append: false);
                  // Also invalidate the provider for other components
                  ref.invalidate(conversationsProvider);
                },
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  try {
                    await ConversationListHelper.createNewConversation(context, ref);
                    // Refresh after creating
                    _loadConversations(ref, append: false);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ErrorHandler.getUserFriendlyMessage(e)),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                tooltip: 'New Conversation',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List
        Expanded(
          child: _loadedConversations.isEmpty && _isLoadingMore
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _loadedConversations.isEmpty
                  ? Center(
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
                    )
                  : ListView.builder(
                      itemCount: _loadedConversations.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show "Load More" button at the end
                        if (index == _loadedConversations.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: _isLoadingMore
                                  ? const CircularProgressIndicator()
                                  : ElevatedButton.icon(
                                      onPressed: () {
                                        _loadConversations(ref, append: true);
                                      },
                                      icon: const Icon(Icons.expand_more),
                                      label: const Text('Load More'),
                                    ),
                            ),
                          );
                        }

                        final conversation = _loadedConversations[index];
                        final isSelected = conversation.id == selectedId;

                        return _ConversationListItem(
                          conversation: conversation,
                          isSelected: isSelected,
                          onTap: () {
                            ref.read(selectedConversationIdProvider.notifier).state = conversation.id;
                          },
                          onArchive: () async {
                            await _archiveConversation(context, ref, conversation.id);
                            // Refresh list after archiving
                            _loadConversations(ref, append: false);
                          },
                          onDelete: () async {
                            await _deleteConversation(context, ref, conversation);
                            // Refresh list after deleting
                            _loadConversations(ref, append: false);
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _archiveConversation(
    BuildContext context,
    WidgetRef ref,
    String conversationId,
  ) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db.archiveConversation(conversationId);
      // Clear selection if this conversation was selected
      final selectedId = ref.read(selectedConversationIdProvider);
      if (selectedId == conversationId) {
        ref.read(selectedConversationIdProvider.notifier).state = null;
      }
    } catch (e) {
      if (context.mounted) {
        final errorMessage = ErrorHandler.getUserFriendlyMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
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

/// Helper class for ConversationList actions
class ConversationListHelper {
  static Future<void> createNewConversation(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
