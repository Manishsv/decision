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
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provider for chat messages by conversation - loads from database
final chatMessagesProvider = FutureProvider.family<List<AIMessage>, String?>((
  ref,
  conversationId,
) async {
  if (conversationId == null) return [];

  final db = ref.read(appDatabaseProvider);
  final dbMessages = await db.getAIChatMessages(conversationId);

  return dbMessages.map((m) {
    // Get imageBase64 from database (primary source)
    String? imageBase64 = m.imageBase64;
    String content = m.content;

    // Fallback: Extract image from content if present (for backward compatibility)
    if (imageBase64 == null || imageBase64.isEmpty) {
      final imageMatch = RegExp(
        r'!\[.*?\]\(data:image/[^;]+;base64,([A-Za-z0-9+/=]+)\)',
        dotAll: true,
      ).firstMatch(content);

      if (imageMatch != null) {
        imageBase64 = imageMatch.group(1);
        // Remove image from content
        content =
            content
                .replaceAll(
                  RegExp(r'!\[.*?\]\(data:image/[^)]+\)', dotAll: true),
                  '',
                )
                .trim();
      }
    }

    // Parse suggestions from JSON if present
    List<AnalysisSuggestion>? suggestions;
    if (m.suggestionsJson != null && m.suggestionsJson!.isNotEmpty) {
      try {
        debugPrint(
          '📖 Parsing suggestions JSON for message ${m.id}: ${m.suggestionsJson!.length} chars',
        );
        final suggestionsList = jsonDecode(m.suggestionsJson!) as List<dynamic>;
        suggestions =
            suggestionsList
                .map(
                  (s) => AnalysisSuggestion.fromJson(s as Map<String, dynamic>),
                )
                .toList();
        debugPrint(
          '✅ Successfully parsed ${suggestions.length} suggestions from DB for message ${m.id}: ${suggestions.map((s) => s.title).join(", ")}',
        );
      } catch (e) {
        debugPrint('❌ Error parsing suggestions JSON for message ${m.id}: $e');
        debugPrint(
          '   JSON content: ${m.suggestionsJson!.substring(0, m.suggestionsJson!.length.clamp(0, 200))}',
        );
      }
    } else {
      debugPrint('⚠️ Message ${m.id} has no suggestionsJson (null or empty)');
    }

    final message = AIMessage(
      role: m.role,
      content: content,
      timestamp: m.timestamp,
      imageBase64: imageBase64,
      suggestions: suggestions,
    );

    // Debug: Log if message has suggestions
    if (suggestions != null && suggestions.isNotEmpty) {
      debugPrint(
        '📋 Parsed message ${m.id} with ${suggestions.length} suggestions: ${suggestions.map((s) => s.title).join(", ")}',
      );
    }

    return message;
  }).toList();
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
  bool _isMerging = false; // Guard flag to prevent infinite loop
  DateTime?
  _lastMergeTime; // Track when we last merged to prevent rapid re-merges
  bool _hasSentIntroduction =
      false; // Guard flag to prevent duplicate introductions

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
      // Reset introduction flag when conversation changes
      _hasSentIntroduction = false;

      // Clear local messages first to ensure clean reload
      setState(() {
        _localMessages = [];
      });

      ref.read(chatMessagesProvider(selectedId).future).then((messages) {
        if (mounted) {
          setState(() {
            _localMessages = messages;
          });

          // Debug: Check if messages have suggestions
          final messagesWithSuggestions =
              messages
                  .where(
                    (m) => m.suggestions != null && m.suggestions!.isNotEmpty,
                  )
                  .toList();
          final messagesWithImages =
              messages
                  .where(
                    (m) => m.imageBase64 != null && m.imageBase64!.isNotEmpty,
                  )
                  .toList();

          debugPrint(
            '📋 Loaded ${messages.length} messages from DB for conversation $selectedId: '
            '${messagesWithSuggestions.length} with suggestions, '
            '${messagesWithImages.length} with images',
          );

          if (messagesWithSuggestions.isNotEmpty) {
            for (var msg in messagesWithSuggestions) {
              debugPrint(
                '  ✅ Message ${msg.timestamp} (${msg.role}): ${msg.suggestions!.length} suggestions - ${msg.suggestions!.map((s) => s.title).join(", ")}',
              );
            }
          } else {
            debugPrint(
              '  ⚠️ No messages with suggestions found. Total messages: ${messages.length}',
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
            // Auto-introduce if this is a new conversation with no messages
            // Only send if we haven't already sent an introduction for this conversation
            if (messages.isEmpty && !_hasSentIntroduction) {
              _sendAutoIntroduction();
            }
          });
        }
      });
    } else {
      setState(() {
        _localMessages = [];
      });
      _hasSentIntroduction = false;
    }
  }

  Future<void> _sendAutoIntroduction() async {
    if (!mounted) return;

    // Prevent duplicate introductions
    if (_hasSentIntroduction) {
      debugPrint('⚠️ Introduction already sent, skipping duplicate');
      return;
    }

    final selectedId = ref.read(selectedConversationIdProvider);
    if (selectedId == null) return;

    // Check if introduction already exists in database
    final db = ref.read(appDatabaseProvider);
    final existingMessages = await db.getAIChatMessages(selectedId);
    if (existingMessages.isNotEmpty) {
      debugPrint(
        '⚠️ Messages already exist in conversation, skipping introduction',
      );
      _hasSentIntroduction = true;
      return;
    }

    if (!mounted) return;
    final conversations = await db.getConversations(includeArchived: true);

    if (!mounted) return;
    conversations.firstWhere(
      (c) => c.id == selectedId,
      orElse: () => throw Exception('Conversation not found'),
    );

    // Mark as sent before proceeding
    _hasSentIntroduction = true;

    final introductionMessage =
        '''Hello! I'm your AI assistant for DIGIT Decision. I'm here to help you manage structured data requests via email and analyze your collected data.

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
- View collected data in real-time

📉 **Data Analysis & Visualization**
- Analyze collected data from Google Sheets
- Generate interactive charts and visualizations
- Suggest analyses based on your data
- Create trend analysis, distributions, and summaries
- Answer questions about your data
- All visualizations are saved and persist across sessions

I can guide you through the entire process step by step. Just tell me what you'd like to do!

For example, you can say:
- "I want to collect monthly finance data from 50 local bodies"
- "Set up a new data collection for program progress"
- "Show me revenue trends over time"
- "Generate a visualization comparing expenses by program"
- "Analyze the data and suggest insights"
- "Create a chart showing monthly trends"

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

    // Invalidate provider to trigger reload (but guard flag prevents duplicate)
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

      // Parse response for images and suggestions
      String? imageBase64;
      List<AnalysisSuggestion>? suggestions;
      String? savedAnalysisId;

      if (response.actionResult != null) {
        final result = response.actionResult as Map<String, dynamic>;

        // Check for visualization image
        if (result['image_base64'] != null) {
          imageBase64 = result['image_base64'] as String;
          debugPrint(
            '✅ Extracted imageBase64 from actionResult: ${imageBase64.substring(0, imageBase64.length.clamp(0, 50))}...',
          );
        } else {
          debugPrint(
            '⚠️ No image_base64 found in actionResult. Keys: ${result.keys.toList()}',
          );
        }

        // Check for saved analysis ID
        if (result['saved_analysis_id'] != null) {
          savedAnalysisId = result['saved_analysis_id'] as String;
        }

        // Check for suggestions
        if (result['suggestions'] != null) {
          final suggestionsList = result['suggestions'] as List<dynamic>;
          suggestions =
              suggestionsList
                  .map(
                    (s) =>
                        AnalysisSuggestion.fromJson(s as Map<String, dynamic>),
                  )
                  .toList();
        }
      }

      // Clean message content - remove image data URIs if image is already extracted
      String cleanedContent = response.message;

      // Also check if image is embedded in markdown content and extract it
      final imageInMarkdown = RegExp(
        r'!\[.*?\]\(data:image/[^;]+;base64,([A-Za-z0-9+/=]+)\)',
        dotAll: true,
      );
      final match = imageInMarkdown.firstMatch(cleanedContent);
      if (match != null && imageBase64 == null) {
        // Extract base64 from markdown if not already extracted from actionResult
        imageBase64 = match.group(1);
      }

      // Always clean image syntax from content, even if no image was extracted
      // This handles cases where AI includes incomplete markdown image syntax

      // Remove complete data URI images
      cleanedContent = cleanedContent.replaceAll(
        RegExp(r'!\[.*?\]\(data:image/[^)]+\)', dotAll: true),
        '',
      );
      // Remove incomplete markdown image syntax (handles various formats including incomplete ones)
      // This regex matches: ![text](anything or nothing) including incomplete cases
      cleanedContent = cleanedContent.replaceAll(
        RegExp(r'!\[[^\]]*\]\s*\([^)]*\)?', dotAll: true),
        '',
      );
      // Also handle cases where the closing paren might be on next line or missing
      cleanedContent = cleanedContent.replaceAll(
        RegExp(r'!\[[^\]]*\]\s*\([^\n]*', dotAll: true),
        '',
      );
      // Remove any standalone base64 image references
      cleanedContent = cleanedContent.replaceAll(
        RegExp(r'data:image/[^;]+;base64,[A-Za-z0-9+/=]+', dotAll: true),
        '',
      );
      // Remove lines that are just markdown image syntax (including incomplete ones)
      cleanedContent = cleanedContent
          .split('\n')
          .where((line) {
            final trimmed = line.trim();
            // Remove lines that start with ![ and contain image syntax (complete or incomplete)
            if (RegExp(r'^!\[.*?\]').hasMatch(trimmed)) {
              return false;
            }
            // Remove lines that contain incomplete image syntax like "]("
            if (trimmed.contains('](') && trimmed.contains('![')) {
              return false;
            }
            // Remove lines that are just "Here's the chart:" or similar followed by image syntax
            if ((trimmed.toLowerCase().contains('chart') ||
                    trimmed.toLowerCase().contains('visualization') ||
                    trimmed.toLowerCase().contains('here')) &&
                (trimmed.contains('![') || trimmed.contains(']('))) {
              return false;
            }
            return true;
          })
          .join('\n');
      cleanedContent = cleanedContent.trim();

      // Additional cleanup: remove any remaining fragments like "Here's the chart:"
      cleanedContent = cleanedContent.replaceAll(
        RegExp(r'Here.*?s?\s+the\s+chart:?\s*', caseSensitive: false),
        '',
      );
      cleanedContent = cleanedContent.trim();

      final assistantMessage = AIMessage(
        role: 'assistant',
        content: cleanedContent,
        timestamp: DateTime.now(),
        imageBase64: imageBase64,
        suggestions: suggestions,
        savedAnalysisId: savedAnalysisId,
      );

      debugPrint(
        '📝 Creating assistant message with imageBase64: ${imageBase64 != null ? "YES (length: ${imageBase64.length})" : "NO"}, '
        'suggestions: ${suggestions != null ? "${suggestions.length} items" : "none"}',
      );

      // Save assistant message to database (including imageBase64 and suggestions)
      final suggestionsJson =
          suggestions != null && suggestions.isNotEmpty
              ? jsonEncode(
                suggestions
                    .map(
                      (s) => {
                        'id': s.id,
                        'title': s.title,
                        'description': s.description,
                        'analysis_type': s.analysisType,
                        'parameters': s.parameters,
                      },
                    )
                    .toList(),
              )
              : null;

      debugPrint(
        '💾 Saving suggestions to DB: ${suggestionsJson != null ? "YES (${suggestionsJson.length} chars)" : "NO"}',
      );

      await db.saveAIChatMessage(
        messageId: assistantMessageId,
        conversationId: selectedId,
        role: 'assistant',
        content: cleanedContent,
        imageBase64: imageBase64, // Save image to database
        suggestionsJson: suggestionsJson, // Save suggestions as JSON
        timestamp: assistantMessage.timestamp,
      );

      // Update local cache - CRITICAL: This preserves imageBase64
      setState(() {
        _localMessages = [..._localMessages, assistantMessage];
      });

      debugPrint(
        '✅ Added message to _localMessages. Total messages: ${_localMessages.length}, '
        'Last message imageBase64: ${_localMessages.last.imageBase64 != null ? "YES (length: ${_localMessages.last.imageBase64!.length})" : "NO"}',
      );

      // Don't invalidate provider immediately if we have imageBase64
      // The imageBase64 is only in memory and will be lost if we reload from DB
      // Only invalidate if we don't have image data to preserve
      if (imageBase64 == null && suggestions == null) {
        ref.invalidate(chatMessagesProvider(selectedId));
      }

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

    // Listen to provider changes (only fires when value actually changes, not on every rebuild)
    // IMPORTANT: Preserve imageBase64 from _localMessages when merging with DB messages
    ref.listen<AsyncValue<List<AIMessage>>>(chatMessagesProvider(selectedId), (
      previous,
      next,
    ) {
      // Only process if we have data and it's different from previous
      final previousMessages = previous?.valueOrNull;
      final nextMessages = next.valueOrNull;

      if (previousMessages == nextMessages || nextMessages == null) {
        return; // No change, skip to prevent loop
      }

      // Prevent infinite loop and rapid re-merges
      if (_isMerging) {
        return;
      }

      // Throttle merges - don't merge more than once per second
      final now = DateTime.now();
      if (_lastMergeTime != null &&
          now.difference(_lastMergeTime!).inMilliseconds < 1000) {
        return;
      }

      final messages = nextMessages;

      // Check if DB messages have special data (suggestions or images) that should be loaded
      final dbHasSpecialData = messages.any(
        (m) =>
            (m.imageBase64 != null && m.imageBase64!.isNotEmpty) ||
            (m.suggestions != null && m.suggestions!.isNotEmpty),
      );

      // Check if we have any local messages with special data
      final hasLocalSpecialData =
          _localMessages.isNotEmpty &&
          _localMessages.any(
            (m) =>
                (m.imageBase64 != null && m.imageBase64!.isNotEmpty) ||
                (m.suggestions != null && m.suggestions!.isNotEmpty),
          );

      // Always allow merge if DB has special data OR if local messages are empty (initial load)
      // Only skip merge if local has special data AND DB doesn't have it (e.g., newly created message not yet saved)
      if (hasLocalSpecialData &&
          !dbHasSpecialData &&
          _localMessages.isNotEmpty) {
        // If we have local images/suggestions but DB doesn't yet, preserve local
        debugPrint(
          '🖼️ Preserving _localMessages with images/suggestions (DB not yet updated), skipping DB merge',
        );
        return;
      }

      // Always merge if DB has special data (persisted suggestions/images should be loaded)
      if (dbHasSpecialData) {
        debugPrint(
          '📥 DB has special data (suggestions/images), proceeding with merge',
        );
      }

      // Only merge if messages actually changed (compare by length and last timestamp)
      final messagesChanged =
          messages.length != _localMessages.length ||
          (messages.isNotEmpty &&
              _localMessages.isNotEmpty &&
              messages.last.timestamp.millisecondsSinceEpoch !=
                  _localMessages.last.timestamp.millisecondsSinceEpoch) ||
          (_localMessages.isEmpty && messages.isNotEmpty);

      if (!messagesChanged) {
        return;
      }

      _isMerging = true;
      _lastMergeTime = now;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _isMerging = false;
          return;
        }

        setState(() {
          // Simple merge: preserve local messages with images, use DB for others
          final mergedMessages = <AIMessage>[];

          // Index local messages by content+timestamp+role for quick lookup
          // This provides more reliable deduplication than timestamp alone
          final localMessagesByKey = <String, AIMessage>{};
          for (var msg in _localMessages) {
            // Only keep local message if it has imageBase64, suggestions, or savedAnalysisId
            if (msg.imageBase64 != null ||
                msg.suggestions != null ||
                msg.savedAnalysisId != null) {
              // Use content + role + timestamp as key for reliable deduplication
              final key = '${msg.role}|${msg.timestamp.millisecondsSinceEpoch}|${msg.content.substring(0, msg.content.length.clamp(0, 100))}';
              localMessagesByKey[key] = msg;
            }
          }

          // Process DB messages - prefer DB messages if they have special data (from persisted storage)
          for (var dbMsg in messages) {
            // Use content + role + timestamp as key for reliable deduplication
            final key = '${dbMsg.role}|${dbMsg.timestamp.millisecondsSinceEpoch}|${dbMsg.content.substring(0, dbMsg.content.length.clamp(0, 100))}';
            final localMsg = localMessagesByKey[key];

            if (localMsg != null) {
              // Prefer DB message if it has special data (persisted), otherwise use local
              final dbHasSpecial =
                  (dbMsg.imageBase64 != null &&
                      dbMsg.imageBase64!.isNotEmpty) ||
                  (dbMsg.suggestions != null && dbMsg.suggestions!.isNotEmpty);
              final localHasSpecial =
                  (localMsg.imageBase64 != null &&
                      localMsg.imageBase64!.isNotEmpty) ||
                  (localMsg.suggestions != null &&
                      localMsg.suggestions!.isNotEmpty);

              if (dbHasSpecial && !localHasSpecial) {
                // DB has special data but local doesn't - use DB
                mergedMessages.add(dbMsg);
              } else if (localHasSpecial && !dbHasSpecial) {
                // Local has special data but DB doesn't yet - use local (newly created)
                mergedMessages.add(localMsg);
              } else {
                // Both or neither have special data - prefer DB (more reliable)
                mergedMessages.add(dbMsg);
              }
            } else {
              // No local match - use DB message
              mergedMessages.add(dbMsg);
            }
          }

          // Add any local messages not in DB yet (newly added)
          // Use content + timestamp + role for more reliable deduplication
          for (var localMsg in _localMessages) {
            final isDuplicate = mergedMessages.any(
              (m) =>
                  m.timestamp.millisecondsSinceEpoch ==
                      localMsg.timestamp.millisecondsSinceEpoch &&
                  m.content == localMsg.content &&
                  m.role == localMsg.role,
            );
            if (!isDuplicate) {
              mergedMessages.add(localMsg);
            }
          }

          // Sort by timestamp
          mergedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

          _localMessages = mergedMessages;

          debugPrint(
            '🔄 Merged messages: ${mergedMessages.length} total, '
            '${mergedMessages.where((m) => m.imageBase64 != null && m.imageBase64!.isNotEmpty).length} with images',
          );
        });

        _isMerging = false;
      });
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
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              const Icon(Icons.smart_toy, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'AI Agent',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (messages.isEmpty)
                TextButton.icon(
                  onPressed: () {
                    // Show example queries
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Example Queries'),
                            content: const SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Questions:'),
                                  Text(
                                    '• How many participants have responded?',
                                  ),
                                  Text('• Who is pending?'),
                                  Text(
                                    '• How many requests are in this conversation?',
                                  ),
                                  SizedBox(height: 16),
                                  Text('Actions:'),
                                  Text(
                                    '• Send reminders to pending participants',
                                  ),
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
          child:
              messages.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation with the AI Agent',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ask questions or give instructions',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
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
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
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
                icon:
                    _isLoading
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

class _ChatBubble extends ConsumerWidget {
  final AIMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                color: isUser ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Render suggestions if present
                  if (!isUser &&
                      message.suggestions != null &&
                      message.suggestions!.isNotEmpty) ...[
                    _buildSuggestions(context, message.suggestions!, ref),
                    const SizedBox(height: 12),
                  ],
                  // Render image if present
                  if (!isUser &&
                      message.imageBase64 != null &&
                      message.imageBase64!.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        debugPrint(
                          '🖼️ Rendering image for message (imageBase64 length: ${message.imageBase64!.length}, first 50 chars: ${message.imageBase64!.substring(0, message.imageBase64!.length.clamp(0, 50))})',
                        );
                        return _buildImage(context, message.imageBase64!);
                      },
                    ),
                    const SizedBox(height: 12),
                  ] else if (!isUser && message.imageBase64 != null) ...[
                    // Debug: Show if imageBase64 is null or empty
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DEBUG: imageBase64 is null or empty',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  // Render markdown for assistant messages, plain text for user
                  if (isUser)
                    Text(
                      message.content,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } else {
                              // Fallback to native command
                              try {
                                if (Platform.isMacOS) {
                                  await Process.run('open', [href]);
                                } else if (Platform.isLinux) {
                                  await Process.run('xdg-open', [href]);
                                } else if (Platform.isWindows) {
                                  await Process.run('start', [
                                    href,
                                  ], runInShell: true);
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
                        listBullet: const TextStyle(color: Colors.black87),
                        blockquote: TextStyle(
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        blockquotePadding: const EdgeInsets.only(left: 16),
                        tableHead: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        tableBody: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                        tableHeadAlign: TextAlign.left,
                        tableBorder: TableBorder(
                          top: BorderSide(color: Colors.grey[400]!, width: 1),
                          bottom: BorderSide(
                            color: Colors.grey[400]!,
                            width: 1,
                          ),
                          left: BorderSide(color: Colors.grey[400]!, width: 1),
                          right: BorderSide(color: Colors.grey[400]!, width: 1),
                          horizontalInside: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                          verticalInside: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        tableCellsPadding: const EdgeInsets.all(8),
                        tableCellsDecoration: BoxDecoration(
                          color: Colors.white,
                        ),
                      ),
                      shrinkWrap: true,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: isUser ? Colors.white70 : Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                      if (!isUser)
                        IconButton(
                          icon: const Icon(Icons.content_copy, size: 16),
                          onPressed: () => _copyMessage(context),
                          tooltip: 'Copy message',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 16,
                          color: Colors.grey[600],
                        ),
                    ],
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

  void _copyMessage(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildImage(BuildContext context, String imageBase64) {
    try {
      final imageBytes = base64Decode(imageBase64);
      return GestureDetector(
        onTap: () {
          // Show full screen image
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => Scaffold(
                    backgroundColor: Colors.black87,
                    appBar: AppBar(
                      backgroundColor: Colors.black87,
                      iconTheme: const IconThemeData(color: Colors.white),
                    ),
                    body: Center(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.memory(
                          Uint8List.fromList(imageBytes),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  Uint8List.fromList(imageBytes),
                  fit: BoxFit.contain,
                ),
              ),
              // Add overlay hint for click
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Error displaying image: $e',
          style: TextStyle(color: Colors.red[700], fontSize: 12),
        ),
      );
    }
  }

  Widget _buildSuggestions(
    BuildContext context,
    List<AnalysisSuggestion> suggestions,
    WidgetRef ref,
  ) {
    final selectedId = ref.watch(selectedConversationIdProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suggested Analyses:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              suggestions.map((suggestion) {
                return _SuggestionCard(
                  suggestion: suggestion,
                  conversationId: selectedId,
                );
              }).toList(),
        ),
      ],
    );
  }
}

class _SuggestionCard extends ConsumerStatefulWidget {
  final AnalysisSuggestion suggestion;
  final String? conversationId;

  const _SuggestionCard({
    required this.suggestion,
    required this.conversationId,
  });

  @override
  ConsumerState<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends ConsumerState<_SuggestionCard> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isGenerating ? null : () => _handleSuggestionClick(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isGenerating ? Colors.grey[200] : Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isGenerating ? Colors.grey[300]! : Colors.blue[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isGenerating)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue[700]!,
                      ),
                    ),
                  )
                else
                  Icon(Icons.insights, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    widget.suggestion.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.blue[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.suggestion.description,
              style: TextStyle(fontSize: 11, color: Colors.blue[800]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSuggestionClick(BuildContext context) async {
    if (widget.conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No conversation selected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final aiAgent = ref.read(aiAgentServiceProvider);

      // Generate visualization using the suggestion's parameters
      final result = await aiAgent.generateVisualizationDirect(
        conversationId: widget.conversationId!,
        analysisType: widget.suggestion.analysisType,
        title: widget.suggestion.title,
        parameters: widget.suggestion.parameters,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Get the imageBase64 and other data from result
        final imageBase64 = result['image_base64'] as String?;
        final description =
            result['description'] as String? ?? widget.suggestion.title;
        final savedAnalysisId = result['saved_analysis_id'] as String?;

        // Create a new message with the visualization
        final db = ref.read(appDatabaseProvider);
        final messageId = generateId();
        final assistantMessage = AIMessage(
          role: 'assistant',
          content:
              'Visualization generated successfully! The chart showing "$description" is displayed above.',
          timestamp: DateTime.now(),
          imageBase64: imageBase64,
          savedAnalysisId: savedAnalysisId,
        );

        // Save to database
        await db.saveAIChatMessage(
          messageId: messageId,
          conversationId: widget.conversationId!,
          role: 'assistant',
          content: assistantMessage.content,
          imageBase64: imageBase64,
          timestamp: assistantMessage.timestamp,
        );

        // Refresh chat messages
        ref.invalidate(chatMessagesProvider(widget.conversationId!));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visualization generated!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error'] as String? ?? 'Failed to generate visualization',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}
