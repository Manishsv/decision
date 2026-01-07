/// AI Agent Chat Interface for center pane

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:decision_agent/features/home/conversation_page.dart';
import 'package:decision_agent/services/ai_agent_service.dart';
import 'package:decision_agent/app/db_provider.dart';
import 'package:decision_agent/data/db/dao.dart';
import 'package:decision_agent/utils/ids.dart';
import 'package:decision_agent/utils/error_handling.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

/// Provider for chat messages by conversation - loads from database
final chatMessagesProvider = FutureProvider.family<List<AIMessage>, String?>((ref, conversationId) async {
  if (conversationId == null) return [];
  
  final db = ref.read(appDatabaseProvider);
  final dbMessages = await db.getAIChatMessages(conversationId);
  
  return dbMessages.map((m) => AIMessage(
    role: m.role,
    content: m.content,
    timestamp: m.timestamp,
  )).toList();
});

class AIChatPanel extends ConsumerStatefulWidget {
  const AIChatPanel({super.key});

  @override
  ConsumerState<AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends ConsumerState<AIChatPanel> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  List<AIMessage> _localMessages = []; // Local cache for immediate UI updates

  @override
  void initState() {
    super.initState();
    // Load messages when conversation changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessages() {
    final selectedId = ref.read(selectedConversationIdProvider);
    if (selectedId != null) {
      ref.read(chatMessagesProvider(selectedId).future).then((messages) {
        if (mounted) {
          setState(() {
            _localMessages = messages;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
            // Auto-introduce if this is a new conversation with no messages
            if (messages.isEmpty) {
              _sendAutoIntroduction();
            }
          });
        }
      });
    } else {
      setState(() {
        _localMessages = [];
      });
    }
  }

  Future<void> _sendAutoIntroduction() async {
    if (!mounted) return;
    
    final selectedId = ref.read(selectedConversationIdProvider);
    if (selectedId == null) return;

    if (!mounted) return;
    final db = ref.read(appDatabaseProvider);
    
    if (!mounted) return;
    final conversations = await db.getConversations(includeArchived: true);
    
    if (!mounted) return;
    final conversation = conversations.firstWhere(
      (c) => c.id == selectedId,
      orElse: () => throw Exception('Conversation not found'),
    );

    final introductionMessage = '''Hello! I'm your AI assistant for DIGIT Decision. I'm here to help you manage structured data requests via email.

Here's what I can help you with:

📊 **Data Collection Setup**
- Define what data you want to collect (schema)
- Add participants (email addresses)
- Create a Google Sheet for storing responses
- Send requests to participants

📈 **Tracking & Management**
- Track who has responded and who hasn't
- Send reminders to pending participants
- Monitor response status

📉 **Data Analysis**
- Analyze collected data
- Provide insights and trends
- Answer questions about your data

I can guide you through the entire process step by step. Just tell me what you'd like to do!

For example, you can say:
- "I want to collect monthly finance data from 50 local bodies"
- "Set up a new data collection for program progress"
- "Help me create a request for participant information"

What would you like to start with?''';

    if (!mounted) return;
    
    // Save introduction message
    final introId = generateId();
    await db.saveAIChatMessage(
      messageId: introId,
      conversationId: selectedId,
      role: 'assistant',
      content: introductionMessage,
      timestamp: DateTime.now(),
    );

    if (!mounted) return;
    
    // Update local cache
    setState(() {
      _localMessages = [
        AIMessage(
          role: 'assistant',
          content: introductionMessage,
          timestamp: DateTime.now(),
        ),
      ];
    });

    if (!mounted) return;
    
    // Invalidate provider
    ref.invalidate(chatMessagesProvider(selectedId));

    if (mounted) {
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final query = _messageController.text.trim();
    if (query.isEmpty || _isLoading) return;

    final selectedId = ref.read(selectedConversationIdProvider);
    if (selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a conversation first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final db = ref.read(appDatabaseProvider);
    final userMessageId = generateId();
    final userMessage = AIMessage(
      role: 'user',
      content: query,
      timestamp: DateTime.now(),
    );
    
    // Save user message to database
    await db.saveAIChatMessage(
      messageId: userMessageId,
      conversationId: selectedId,
      role: 'user',
      content: query,
      timestamp: userMessage.timestamp,
    );
    
    // Update local cache for immediate UI update
    setState(() {
      _localMessages = [..._localMessages, userMessage];
    });
    
    _messageController.clear();
    setState(() {
      _isLoading = true;
    });
    
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      // Get AI Agent service
      final aiAgent = ref.read(aiAgentServiceProvider);
      
      // Process query with current message history
      final response = await aiAgent.processQuery(
        query,
        selectedId,
        _localMessages,
      );

      final assistantMessageId = generateId();
      final assistantMessage = AIMessage(
        role: 'assistant',
        content: response.message,
        timestamp: DateTime.now(),
      );
      
      // Save assistant message to database
      await db.saveAIChatMessage(
        messageId: assistantMessageId,
        conversationId: selectedId,
        role: 'assistant',
        content: response.message,
        timestamp: assistantMessage.timestamp,
      );
      
      // Update local cache
      setState(() {
        _localMessages = [..._localMessages, assistantMessage];
      });
      
      // Invalidate provider to refresh if needed
      ref.invalidate(chatMessagesProvider(selectedId));
      
      // Invalidate conversation requests provider (schema might have been defined)
      ref.invalidate(conversationRequestsProvider(selectedId));
      
      // Invalidate conversations provider (sheet might have been created)
      ref.invalidate(conversationsProvider);
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      // Add user-friendly error message
      final errorMessageId = generateId();
      final userFriendlyError = ErrorHandler.getUserFriendlyMessage(e);
      final errorMessage = AIMessage(
        role: 'assistant',
        content: userFriendlyError,
        timestamp: DateTime.now(),
      );
      
      // Save error message to database
      await db.saveAIChatMessage(
        messageId: errorMessageId,
        conversationId: selectedId,
        role: 'assistant',
        content: 'Error: $e',
        timestamp: errorMessage.timestamp,
      );
      
      // Update local cache
      setState(() {
        _localMessages = [..._localMessages, errorMessage];
      });
      
      // Invalidate provider
      ref.invalidate(chatMessagesProvider(selectedId));
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedConversationIdProvider);
    
    // Watch for conversation changes and reload messages
    ref.listen(selectedConversationIdProvider, (previous, next) {
      if (previous != next) {
        _loadMessages();
      }
    });
    
    // Use local messages for immediate UI, but also watch provider for updates
    final messagesAsync = ref.watch(chatMessagesProvider(selectedId));
    
    // Update local messages when provider updates (e.g., on initial load)
    messagesAsync.whenData((messages) {
      if (messages.length != _localMessages.length || 
          (messages.isNotEmpty && messages.last.timestamp != _localMessages.lastOrNull?.timestamp)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _localMessages = messages;
            });
          }
        });
      }
    });
    
    final messages = _localMessages;

    if (selectedId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'AI Agent',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a conversation to interact with the AI Agent',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            Text(
              'Ask questions, get insights, and execute actions',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.smart_toy, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'AI Agent',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (messages.isEmpty)
                TextButton.icon(
                  onPressed: () {
                    // Show example queries
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Example Queries'),
                        content: const SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Questions:'),
                              Text('• How many participants have responded?'),
                              Text('• Who is pending?'),
                              Text('• How many requests are in this conversation?'),
                              SizedBox(height: 16),
                              Text('Actions:'),
                              Text('• Send reminders to pending participants'),
                              Text('• Create a new request'),
                              SizedBox(height: 16),
                              Text('Analysis:'),
                              Text('• What does the data tell us?'),
                              Text('• Analyze the responses'),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('Examples'),
                ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Start a conversation with the AI Agent',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ask questions or give instructions',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _ChatBubble(message: message);
                  },
                ),
        ),
        // Input area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Ask a question or give an instruction...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !_isLoading,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                tooltip: 'Send',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final AIMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(Icons.smart_toy, size: 18, color: Colors.blue),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.blue
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Render markdown for assistant messages, plain text for user
                  if (isUser)
                    Text(
                      message.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    )
                  else
                    MarkdownBody(
                      data: message.content,
                      onTapLink: (text, href, title) async {
                        if (href != null) {
                          // Try to launch URL
                          final uri = Uri.tryParse(href);
                          if (uri != null) {
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              // Fallback to native command
                              try {
                                if (Platform.isMacOS) {
                                  await Process.run('open', [href]);
                                } else if (Platform.isLinux) {
                                  await Process.run('xdg-open', [href]);
                                } else if (Platform.isWindows) {
                                  await Process.run('start', [href], runInShell: true);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error opening link: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          }
                        }
                      },
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        h1: const TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: const TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        strong: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        em: const TextStyle(
                          color: Colors.black87,
                          fontStyle: FontStyle.italic,
                        ),
                        code: TextStyle(
                          color: Colors.black87,
                          backgroundColor: Colors.grey[200],
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        listBullet: const TextStyle(
                          color: Colors.black87,
                        ),
                        blockquote: TextStyle(
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        blockquotePadding: const EdgeInsets.only(left: 16),
                      ),
                      shrinkWrap: true,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: isUser
                          ? Colors.white70
                          : Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
