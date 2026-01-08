/// Center pane: Conversation/Request view

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/app/db_provider.dart';
import 'package:decision_agent/app/auth_provider.dart';
import 'package:decision_agent/data/db/dao.dart';
import 'package:decision_agent/data/google/gmail_service.dart';
import 'package:decision_agent/data/google/sheets_service.dart';
import 'package:decision_agent/services/logging_service.dart';
import 'package:decision_agent/services/parsing_service.dart';
import 'package:decision_agent/services/ingestion_service.dart';
import 'package:decision_agent/services/request_service.dart';
import 'package:decision_agent/domain/models.dart' as models;
import 'package:decision_agent/features/home/ai_chat_panel.dart';
import 'package:decision_agent/features/home/conversation_list.dart';
import 'package:decision_agent/utils/error_handling.dart';
import 'dart:convert';
import 'dart:io';

/// Provider for selected conversation ID
final selectedConversationIdProvider = StateProvider<String?>((ref) => null);

/// Provider for requests by conversation
final conversationRequestsProvider =
    FutureProvider.family<List<models.DataRequest>, String>((
      ref,
      conversationId,
    ) async {
      final db = ref.read(appDatabaseProvider);
      return await db.getRequestsByConversation(conversationId);
    });

/// Provider for current request data (by requestId)
final currentRequestProvider =
    FutureProvider.family<models.DataRequest?, String>((ref, requestId) async {
      final db = ref.read(appDatabaseProvider);
      return await db.getRequest(requestId);
    });

/// Provider for activity logs
final activityLogsProvider =
    FutureProvider.family<List<models.ActivityLogEntry>, String>((
      ref,
      requestId,
    ) async {
      final db = ref.read(appDatabaseProvider);
      final loggingService = LoggingService(db);
      return await loggingService.getActivityLogs(requestId);
    });

/// Provider for recipient statuses
final recipientStatusesProvider =
    FutureProvider.family<List<models.RecipientStatus>, String>((
      ref,
      requestId,
    ) async {
      final db = ref.read(appDatabaseProvider);
      return await db.getRecipientStatuses(requestId);
    });

class ConversationPage extends ConsumerWidget {
  const ConversationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedConversationIdProvider);
    final conversationsAsync = ref.watch(conversationsProvider);

    if (selectedId == null) {
      return conversationsAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            // No conversations - show onboarding
            return _buildOnboardingView(context, ref);
          } else {
            // Has conversations but none selected - show guidance
            return _buildSelectConversationView(context);
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading conversations',
                    style: TextStyle(color: Colors.red[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
      );
    }

    // Reuse the conversationsAsync already loaded above
    return conversationsAsync.when(
      data: (conversations) {
        try {
          final conversation = conversations.firstWhere(
            (c) => c.id == selectedId,
          );
          return _buildConversationContent(conversation, ref);
        } catch (e) {
          // Conversation not found - might be newly created, refresh and try again
          ref.invalidate(conversationsProvider);
          return const Center(child: CircularProgressIndicator());
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    ErrorHandler.getUserFriendlyMessage(error),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (ErrorHandler.getRecoverySuggestion(error) != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      ErrorHandler.getRecoverySuggestion(error)!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildOnboardingView(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Main icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    size: 80,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  'Welcome to DIGIT Decision',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.headlineMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Subtitle
                Text(
                  'Your AI-powered assistant for collecting structured data via email',
                  style: TextStyle(
                    fontSize: 18,
                    color:
                        Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.7) ??
                        Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // CTA Button
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await ConversationListHelper.createNewConversation(
                        context,
                        ref,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating conversation: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text(
                    'Create Your First Conversation',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 64),
                // Features section
                Text(
                  'What you can do:',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 24),
                _buildFeatureItem(
                  Icons.table_chart,
                  'Define Data Schema',
                  'Create structured data requests with custom columns and fields',
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  Icons.email,
                  'Send via Email',
                  'Automatically send requests to participants via Gmail',
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  Icons.track_changes,
                  'Track Responses',
                  'Monitor who has responded and send reminders automatically',
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  Icons.analytics,
                  'Analyze Data',
                  'Get insights and analyze collected data with AI assistance',
                ),
                const SizedBox(height: 24),
                Text(
                  'Ready to get started? Click the button above to create your first conversation!',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.6) ??
                        Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectConversationView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color:
                    Theme.of(context).iconTheme.color?.withOpacity(0.5) ??
                    Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Select a Conversation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose a conversation from the left sidebar to start interacting with the AI Agent',
                style: TextStyle(
                  fontSize: 16,
                  color:
                      Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.7) ??
                      Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(
                    Theme.of(context).brightness == Brightness.dark
                        ? 0.15
                        : 0.05,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.3
                          : 0.2,
                    ),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Quick Tips',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTipItem(
                      context,
                      '💬 Ask the AI to create a new data collection',
                    ),
                    _buildTipItem(
                      context,
                      '📊 Define what data you want to collect',
                    ),
                    _buildTipItem(
                      context,
                      '👥 Add participants and send requests',
                    ),
                    _buildTipItem(
                      context,
                      '📈 Track responses and analyze results',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Builder(
      builder:
          (context) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.7) ??
                            Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildTipItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color:
              Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ??
              Colors.grey[700],
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildConversationContent(
    models.Conversation conversation,
    WidgetRef ref,
  ) {
    // Show AI Agent chat interface
    return const AIChatPanel();
  }

  Widget _buildRequestView(
    BuildContext context,
    WidgetRef ref,
    models.Conversation conversation,
    models.DataRequest request,
    String requestId,
    AsyncValue<List<models.ActivityLogEntry>> activityLogsAsync,
    AsyncValue<List<models.RecipientStatus>> recipientStatusesAsync,
  ) {
    return activityLogsAsync.when(
      data: (activityLogs) {
        return recipientStatusesAsync.when(
          data: (recipientStatuses) {
            return _buildRequestContent(
              context,
              ref,
              conversation,
              request,
              requestId,
              activityLogs,
              recipientStatuses,
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    ErrorHandler.getUserFriendlyMessage(error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                ErrorHandler.getUserFriendlyMessage(error),
                textAlign: TextAlign.center,
              ),
            ),
          ),
    );
  }

  Widget _buildRequestContent(
    BuildContext context,
    WidgetRef ref,
    models.Conversation conversation,
    models.DataRequest request,
    String requestId,
    List<models.ActivityLogEntry> activityLogs,
    List<models.RecipientStatus> recipientStatuses,
  ) {
    return _RequestView(
      requestId: requestId,
      conversation: conversation,
      request: request,
      activityLogsAsync: AsyncValue.data(activityLogs),
      recipientStatusesAsync: AsyncValue.data(recipientStatuses),
    );
  }
}

class _RequestView extends ConsumerWidget {
  final String requestId;
  final models.Conversation conversation;
  final models.DataRequest request;
  final AsyncValue<List<models.ActivityLogEntry>> activityLogsAsync;
  final AsyncValue<List<models.RecipientStatus>> recipientStatusesAsync;

  const _RequestView({
    required this.requestId,
    required this.conversation,
    required this.request,
    required this.activityLogsAsync,
    required this.recipientStatusesAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipientStatuses = recipientStatusesAsync.value ?? [];
    final respondedCount =
        recipientStatuses
            .where((r) => r.status == models.RecipientState.responded)
            .length;
    final pendingCount =
        recipientStatuses
            .where((r) => r.status == models.RecipientState.pending)
            .length;
    final errorCount =
        recipientStatuses
            .where((r) => r.status == models.RecipientState.error)
            .length;
    final totalRecipients = request.recipients.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Request Summary Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Status badge removed - conversations don't have status
                    ],
                  ),
                  if (request.description != null &&
                      request.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      request.description!,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Responded',
                          value: '$respondedCount',
                          total: '/$totalRecipients',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'Pending',
                          value: '$pendingCount',
                          total: '/$totalRecipients',
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'Errors',
                          value: '$errorCount',
                          total: '/$totalRecipients',
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Use Wrap to allow buttons to wrap to next line if needed
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Due: ${_formatDate(request.dueAt)}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                      if (conversation.sheetUrl.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _openSheet(conversation.sheetUrl),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open Sheet'),
                        ),
                      ElevatedButton.icon(
                        onPressed:
                            () => _checkForResponses(context, ref, requestId),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Check for responses'),
                      ),
                      // Show "Send Again" button if there are requests
                      ElevatedButton.icon(
                        onPressed:
                            () => _showSendAgainDialog(context, ref, request),
                        icon: const Icon(Icons.repeat, size: 16),
                        label: const Text('Send Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Iteration History (if this is a template or iteration)
          if (request.templateRequestId != null || request.isTemplate) ...[
            _IterationHistorySection(requestId: requestId, request: request),
            const SizedBox(height: 24),
          ],
          // Activity Timeline
          const Text(
            'Activity Timeline',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          activityLogsAsync.when(
            data: (logs) {
              if (logs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No activity yet')),
                  ),
                );
              }
              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  separatorBuilder:
                      (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return ListTile(
                      leading: _ActivityIcon(type: log.type),
                      title: Text(_getActivityTitle(log.type)),
                      subtitle: Text(
                        '${_formatDateTime(log.timestamp)}\n${_getActivityDetails(log)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
              );
            },
            loading:
                () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            error:
                (error, stack) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      ErrorHandler.getUserFriendlyMessage(error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getActivityTitle(models.ActivityType type) {
    switch (type) {
      case models.ActivityType.sent:
        return 'Email Sent';
      case models.ActivityType.ingested:
        return 'Response Ingested';
      case models.ActivityType.parseError:
        return 'Parse Error';
      case models.ActivityType.reminderSent:
        return 'Reminder Sent';
      case models.ActivityType.sendError:
        return 'Send Error';
      case models.ActivityType.ingestionCheck:
        return 'Checking for Responses';
      case models.ActivityType.ingestionError:
        return 'Ingestion Error';
    }
  }

  String _getActivityDetails(models.ActivityLogEntry log) {
    try {
      final payload = jsonDecode(log.payloadJson) as Map<String, dynamic>;
      if (log.type == models.ActivityType.sent) {
        return 'To: ${payload['recipient'] ?? 'Unknown'}';
      } else if (log.type == models.ActivityType.sendError) {
        return 'Error: ${payload['error'] ?? 'Unknown error'}';
      } else if (log.type == models.ActivityType.ingested) {
        return 'From: ${payload['fromEmail'] ?? 'Unknown'}';
      } else if (log.type == models.ActivityType.parseError) {
        return 'From: ${payload['fromEmail'] ?? 'Unknown'}';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  Future<void> _openSheet(String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('start', [url], runInShell: true);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _checkForResponses(
    BuildContext context,
    WidgetRef ref,
    String requestId,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Checking for responses...'),
              ],
            ),
          ),
    );

    try {
      // Get services
      final db = ref.read(appDatabaseProvider);
      final authService = ref.read(googleAuthServiceProvider);
      final gmailService = GmailService(authService);
      final sheetsService = SheetsService(authService);
      final parsingService = ParsingService();
      final loggingService = LoggingService(db);

      // Create ingestion service
      final ingestionService = IngestionService(
        db,
        gmailService,
        sheetsService,
        parsingService,
        loggingService,
      );

      // Ingest responses
      final result = await ingestionService.ingestResponses(requestId);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Refresh providers
      ref.invalidate(currentRequestProvider(requestId));
      ref.invalidate(activityLogsProvider(requestId));
      ref.invalidate(recipientStatusesProvider(requestId));

      // Show result
      if (context.mounted) {
        final message =
            result.ingestedCount > 0 || result.errorCount > 0
                ? 'Ingested ${result.ingestedCount} response(s), ${result.errorCount} error(s)'
                : 'No new responses found';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor:
                result.errorCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Show detailed errors if any
        if (result.errors.isNotEmpty) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Ingestion Errors'),
                  content: SingleChildScrollView(
                    child: Text(result.errors.join('\n')),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show user-friendly error
      if (context.mounted) {
        final errorMessage = ErrorHandler.getUserFriendlyMessage(e);
        final suggestion = ErrorHandler.getRecoverySuggestion(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                if (suggestion != null) ...[
                  const SizedBox(height: 4),
                  Text(suggestion, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _showSendAgainDialog(
    BuildContext context,
    WidgetRef ref,
    models.DataRequest request,
  ) async {
    // Determine template request ID (use this request's ID if it's a template, or the template ID if it's an iteration)
    final templateRequestId = request.templateRequestId ?? request.requestId;

    // Get iteration count
    final iterations = await ref
        .read(appDatabaseProvider)
        .getTemplateIterations(templateRequestId);
    final nextIterationNumber = iterations.length + 1;

    // Default due date: next week or next month (user can change)
    final defaultDueDate = request.dueAt.add(const Duration(days: 7));
    DateTime selectedDueDate = defaultDueDate;
    bool reuseSheet = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Create Next Iteration'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'This will create iteration #$nextIterationNumber with the same schema and recipients.',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 16),
                        // Due date picker
                        ListTile(
                          title: const Text('Due Date'),
                          subtitle: Text(
                            '${selectedDueDate.month}/${selectedDueDate.day}/${selectedDueDate.year}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDueDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDueDate = picked;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Sheet option
                        CheckboxListTile(
                          title: const Text('Reuse existing sheet'),
                          subtitle: const Text(
                            'Append responses to the same sheet',
                          ),
                          value: reuseSheet,
                          onChanged: (value) {
                            setState(() {
                              reuseSheet = value ?? true;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop({
                          'dueDate': selectedDueDate,
                          'reuseSheet': reuseSheet,
                        });
                      },
                      child: const Text('Create & Send'),
                    ),
                  ],
                ),
          ),
    );

    if (result == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Creating iteration...'),
              ],
            ),
          ),
    );

    try {
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

      // Create iteration
      final newRequestId = await requestService.createIterationFromTemplate(
        templateRequestId: templateRequestId,
        newDueDate: result['dueDate'] as DateTime,
        reuseSheet: result['reuseSheet'] as bool,
      );

      // Send the request
      final sendResults = await requestService.sendRequest(newRequestId);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Refresh conversations
      ref.invalidate(conversationsProvider);

      // Show result
      if (context.mounted) {
        final sent = sendResults['sent'] as int;
        final failed = sendResults['failed'] as int;

        if (failed == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Iteration #$nextIterationNumber created and sent to $sent recipient(s)',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Send Results'),
                  content: Text('Sent: $sent\nFailed: $failed'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show user-friendly error
      if (context.mounted) {
        final errorMessage = ErrorHandler.getUserFriendlyMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final models.RequestStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case models.RequestStatus.draft:
        color = Colors.grey;
        label = 'Draft';
        break;
      case models.RequestStatus.sent:
        color = Colors.blue;
        label = 'Sent';
        break;
      case models.RequestStatus.inProgress:
        color = Colors.orange;
        label = 'In Progress';
        break;
      case models.RequestStatus.complete:
        color = Colors.green;
        label = 'Complete';
        break;
      case models.RequestStatus.overdue:
        color = Colors.red;
        label = 'Overdue';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String total;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                total,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityIcon extends StatelessWidget {
  final models.ActivityType type;

  const _ActivityIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (type) {
      case models.ActivityType.sent:
        icon = Icons.send;
        color = Colors.blue;
        break;
      case models.ActivityType.ingested:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case models.ActivityType.parseError:
        icon = Icons.error;
        color = Colors.red;
        break;
      case models.ActivityType.reminderSent:
        icon = Icons.notifications;
        color = Colors.orange;
        break;
      case models.ActivityType.sendError:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
      case models.ActivityType.ingestionCheck:
        icon = Icons.refresh;
        color = Colors.blue;
        break;
      case models.ActivityType.ingestionError:
        icon = Icons.warning;
        color = Colors.orange;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// Pagination configuration
const int _conversationsPageSize = 50;

/// Provider for conversations list with pagination
/// Loads initial batch of conversations
final conversationsProvider =
    FutureProvider<List<models.Conversation>>((ref) async {
  final db = ref.read(appDatabaseProvider);
  return await db.getConversations(limit: _conversationsPageSize);
});

/// Provider for total conversation count
final conversationCountProvider =
    FutureProvider<int>((ref) async {
  final db = ref.read(appDatabaseProvider);
  return await db.countConversations();
});

/// Provider for template iterations
final templateIterationsProvider =
    FutureProvider.family<List<models.DataRequest>, String>((
      ref,
      templateRequestId,
    ) async {
      final db = ref.read(appDatabaseProvider);
      return await db.getTemplateIterations(templateRequestId);
    });

/// Widget to display iteration history
class _IterationHistorySection extends ConsumerWidget {
  final String requestId;
  final models.DataRequest request;

  const _IterationHistorySection({
    required this.requestId,
    required this.request,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateRequestId = request.templateRequestId ?? requestId;
    final iterationsAsync = ref.watch(
      templateIterationsProvider(templateRequestId),
    );

    return iterationsAsync.when(
      data: (iterations) {
        if (iterations.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Iteration History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...iterations.map((iteration) {
                  final isCurrent = iteration.requestId == requestId;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          isCurrent ? Colors.blue : Colors.grey[300],
                      child: Text(
                        '${iteration.iterationNumber ?? '?'}',
                        style: TextStyle(
                          color: isCurrent ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      'Iteration ${iteration.iterationNumber ?? '?'}',
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      'Due: ${_formatDate(iteration.dueAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing:
                        isCurrent
                            ? Chip(
                              label: const Text(
                                'Current',
                                style: TextStyle(fontSize: 10),
                              ),
                              backgroundColor: Colors.blue[100],
                            )
                            : null,
                    onTap: () {
                      // Navigate to iteration conversation
                      final conversationsAsync = ref.read(
                        conversationsProvider,
                      );
                      conversationsAsync.whenData((conversations) {
                        // Find conversation by conversationId from iteration
                        final iterationConversation = conversations.firstWhere(
                          (c) => c.id == iteration.conversationId,
                          orElse: () => conversations.first,
                        );
                        ref
                            .read(selectedConversationIdProvider.notifier)
                            .state = iterationConversation.id;
                      });
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
      loading:
          () => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
