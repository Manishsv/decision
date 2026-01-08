/// Right pane: Inspector panel
/// Shows Overview, Participants, and Activities for selected conversation
/// Collapsible panel that can be hidden to focus on center content

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:decision_agent/app/db_provider.dart';
import 'package:decision_agent/app/auth_provider.dart';
import 'package:decision_agent/data/db/dao.dart';
import 'package:decision_agent/data/google/gmail_service.dart';
import 'package:decision_agent/data/google/sheets_service.dart';
import 'package:decision_agent/services/logging_service.dart';
import 'package:decision_agent/services/parsing_service.dart';
import 'package:decision_agent/services/ingestion_service.dart';
import 'package:decision_agent/services/request_service.dart';
import 'package:decision_agent/services/ai_agent_service.dart';
import 'package:decision_agent/features/settings/settings_controller.dart';
import 'package:decision_agent/domain/email_protocol.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:decision_agent/domain/models.dart' as models;
import 'package:decision_agent/domain/request_schema.dart';
import 'package:decision_agent/features/home/conversation_page.dart';
import 'package:decision_agent/utils/error_handling.dart';
import 'package:decision_agent/utils/validation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

/// Provider for inspector panel visibility
final inspectorPanelVisibleProvider = StateProvider<bool>((ref) => true);

/// Provider for all participants across all requests in a conversation
final conversationParticipantsProvider = FutureProvider.family<
  List<models.RecipientStatus>,
  String
>((ref, conversationId) async {
  final db = ref.read(appDatabaseProvider);
  // Get all requests for this conversation
  final requests = await db.getRequestsByConversation(conversationId);

  // Collect all explicitly added recipient emails from requests
  final Set<String> explicitRecipients = {};
  for (final request in requests) {
    explicitRecipients.addAll(request.recipients);
  }

  if (explicitRecipients.isEmpty) {
    return [];
  }

  // Get recipient statuses only for explicitly added recipients
  // Optimize: Use batch query to avoid N+1 queries
  final Map<String, models.RecipientStatus> uniqueStatuses = {};
  final requestIds = requests.map((r) => r.requestId).toList();

  // Batch query all recipient statuses for all requests in one query
  final allStatuses = await db.getRecipientStatusesBatch(requestIds);
  for (final status in allStatuses) {
    // Only include statuses for emails that were explicitly added as recipients
    if (explicitRecipients.contains(status.email)) {
      if (!uniqueStatuses.containsKey(status.email) ||
          (status.lastResponseAt != null &&
              (uniqueStatuses[status.email]!.lastResponseAt == null ||
                  status.lastResponseAt!.isAfter(
                    uniqueStatuses[status.email]!.lastResponseAt!,
                  )))) {
        uniqueStatuses[status.email] = status;
      }
    }
  }

  // Ensure all explicitly added recipients have a status entry
  // (even if they haven't responded yet)
  for (final email in explicitRecipients) {
    if (!uniqueStatuses.containsKey(email)) {
      // Find the most recent request that includes this email
      for (final request in requests.reversed) {
        if (request.recipients.contains(email)) {
          // Create a pending status for this recipient
          uniqueStatuses[email] = models.RecipientStatus(
            requestId: request.requestId,
            email: email,
            status: models.RecipientState.pending,
            lastMessageId: null,
            lastResponseAt: null,
            reminderSentAt: null,
            note: null,
          );
          break;
        }
      }
    }
  }

  return uniqueStatuses.values.toList();
});

/// Pagination configuration for activity logs
const int _activityLogsInitialLimit = 50;
const int _activityLogsMaxLimit = 200;

/// Provider for all activity logs across all requests in a conversation
/// Loads initial batch of 50 logs
final conversationActivityLogsProvider = FutureProvider.family<
  List<models.ActivityLogEntry>,
  String
>((ref, conversationId) async {
  final db = ref.read(appDatabaseProvider);
  final loggingService = LoggingService(db);

  // Get all requests for this conversation
  final requests = await db.getRequestsByConversation(conversationId);

  if (requests.isEmpty) {
    return [];
  }

  // Get activity logs for all requests
  // Limit per request to get ~50 total logs initially
  final limitPerRequest =
      (_activityLogsInitialLimit / requests.length).ceil().clamp(10, 100);

  final allLogs = <models.ActivityLogEntry>[];
  for (final request in requests) {
    final logs = await loggingService.getActivityLogs(
      request.requestId,
      limit: limitPerRequest,
    );
    allLogs.addAll(logs);
  }

  // Sort by timestamp (most recent first)
  allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  // Limit to initial page size
  return allLogs.take(_activityLogsInitialLimit).toList();
});

class InspectorPanel extends ConsumerStatefulWidget {
  const InspectorPanel({super.key});

  @override
  ConsumerState<InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends ConsumerState<InspectorPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedConversationIdProvider);
    final isVisible = ref.watch(inspectorPanelVisibleProvider);

    if (!isVisible) {
      // Collapsed state - show only a button to expand
      return Container(
        width: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(left: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                ref.read(inspectorPanelVisibleProvider.notifier).state = true;
              },
              tooltip: 'Show Inspector',
            ),
          ],
        ),
      );
    }

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(left: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          // Header with collapse button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                const Text(
                  'Inspector',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: () {
                    ref.read(inspectorPanelVisibleProvider.notifier).state =
                        false;
                  },
                  tooltip: 'Hide Inspector',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                ),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.onSurface,
            unselectedLabelColor:
                Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.6) ??
                Colors.grey[600],
            indicatorColor: Theme.of(context).primaryColor,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.normal,
            ),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Participants'),
              Tab(text: 'Schema'),
              Tab(text: 'Activity'),
            ],
          ),
          // Tab views
          Expanded(
            child:
                selectedId == null
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Select a conversation to view details',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : TabBarView(
                      controller: _tabController,
                      children: [
                        _OverviewTab(conversationId: selectedId),
                        _ParticipantsTab(conversationId: selectedId),
                        _SchemaTab(conversationId: selectedId),
                        _ActivityTab(conversationId: selectedId),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}

/// Overview Tab: Conversation summary, stats, key metrics
class _OverviewTab extends ConsumerWidget {
  final String conversationId;

  const _OverviewTab({required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final requestsAsync = ref.watch(
      conversationRequestsProvider(conversationId),
    );
    final participantsAsync = ref.watch(
      conversationParticipantsProvider(conversationId),
    );

    return conversationsAsync.when(
      data: (conversations) {
        try {
          final conversation = conversations.firstWhere(
            (c) => c.id == conversationId,
          );

          return requestsAsync.when(
            data: (requests) {
              return participantsAsync.when(
                data: (participants) {
                  // Calculate aggregated stats
                  final respondedCount =
                      participants
                          .where(
                            (p) => p.status == models.RecipientState.responded,
                          )
                          .length;
                  final pendingCount =
                      participants
                          .where(
                            (p) => p.status == models.RecipientState.pending,
                          )
                          .length;
                  final errorCount =
                      participants
                          .where((p) => p.status == models.RecipientState.error)
                          .length;
                  final totalParticipants = participants.length;

                  // Get most recent request
                  final mostRecentRequest =
                      requests.isNotEmpty ? requests.first : null;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Conversation Title with Rename button
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                conversation.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[900],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed:
                                  () => _OverviewTabHelper.renameConversation(
                                    context,
                                    ref,
                                    conversation,
                                  ),
                              tooltip: 'Rename conversation',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Stats Cards - cleaner design
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Responded',
                                value: '$respondedCount',
                                total: '/$totalParticipants',
                                color: const Color(0xFF10B981), // Subtle green
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatCard(
                                label: 'Pending',
                                value: '$pendingCount',
                                total: '/$totalParticipants',
                                color: const Color(0xFFF59E0B), // Subtle orange
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatCard(
                                label: 'Errors',
                                value: '$errorCount',
                                total: '/$totalParticipants',
                                color: const Color(0xFFEF4444), // Subtle red
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Key Metrics - simplified card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[700]!
                                      : Colors.grey[200]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Metrics',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.color,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _MetricRow(
                                label: 'Requests',
                                value: '${requests.length}',
                              ),
                              const SizedBox(height: 8),
                              _MetricRow(
                                label: 'Participants',
                                value: '$totalParticipants',
                              ),
                              if (mostRecentRequest != null) ...[
                                const SizedBox(height: 8),
                                _MetricRow(
                                  label: 'Due Date',
                                  value: _formatDate(mostRecentRequest.dueAt),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Action Buttons - cleaner design
                        _ActionButton(
                          icon: Icons.open_in_new,
                          label: 'Open Sheet',
                          onPressed:
                              () => _OverviewTabHelper.openSheet(
                                context,
                                ref,
                                conversation,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _ActionButton(
                          icon: Icons.refresh,
                          label: 'Check for responses',
                          onPressed:
                              () => _OverviewTabHelper.checkForResponses(
                                context,
                                ref,
                                conversationId,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _ActionButton(
                          icon: Icons.send,
                          label: 'Send Again',
                          onPressed:
                              mostRecentRequest != null
                                  ? () =>
                                      _OverviewTabHelper.showSendAgainDialog(
                                        context,
                                        ref,
                                        mostRecentRequest,
                                      )
                                  : null,
                          isPrimary: true,
                        ),
                        const SizedBox(height: 8),
                        _ActionButton(
                          icon: Icons.add,
                          label: 'New Request',
                          onPressed:
                              () => _OverviewTabHelper.createNewRequest(
                                context,
                                conversationId,
                              ),
                          isPrimary: true,
                        ),
                        const SizedBox(height: 16),
                        // Conversation Info - minimal
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[700]!
                                      : Colors.grey[200]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Created',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color
                                                  ?.withOpacity(0.7) ??
                                              Colors.grey[400]
                                          : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(conversation.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, stack) => Center(
                      child: Text(
                        'Error: $error',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, stack) => Center(
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
          );
        } catch (e) {
          // Conversation not found - might be newly created, refresh and try again
          ref.invalidate(conversationsProvider);
          return const Center(child: CircularProgressIndicator());
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stack) => Center(
            child: Text(
              ErrorHandler.getUserFriendlyMessage(error),
              style: const TextStyle(fontSize: 12),
            ),
          ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

/// Stat Card - cleaner design
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
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.8) ??
                          Colors.grey[300]
                      : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                total,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6) ??
                      Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Metric Row - simple row display
class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.8) ??
                        Colors.grey[300]
                    : Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.7) ??
                        Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }
}

/// Action Button - consistent styling
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[700],
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: Colors.grey[300]!),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

/// Helper class for Overview Tab actions
class _OverviewTabHelper {
  static Future<void> openSheet(
    BuildContext context,
    WidgetRef ref,
    models.Conversation conversation,
  ) async {
    if (conversation.sheetUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No sheet associated with this conversation'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(conversation.sheetUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to native command
        if (Platform.isMacOS) {
          await Process.run('open', [conversation.sheetUrl]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [conversation.sheetUrl]);
        } else if (Platform.isWindows) {
          await Process.run('start', [conversation.sheetUrl], runInShell: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error opening sheet: $e\nURL: ${conversation.sheetUrl}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  static void checkForResponses(
    BuildContext context,
    WidgetRef ref,
    String conversationId,
  ) async {
    // Show loading
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
      // Get all requests for this conversation
      final db = ref.read(appDatabaseProvider);
      final requests = await db.getRequestsByConversation(conversationId);

      if (requests.isEmpty) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No requests found in conversation'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Get services
      final authService = ref.read(googleAuthServiceProvider);
      final gmailService = GmailService(authService);
      final sheetsService = SheetsService(authService);
      final parsingService = ParsingService();
      final loggingService = LoggingService(db);
      final ingestionService = IngestionService(
        db,
        gmailService,
        sheetsService,
        parsingService,
        loggingService,
      );

      // Ingest responses for all requests
      int totalIngested = 0;
      int totalErrors = 0;
      final errors = <String>[];

      for (final request in requests) {
        final result = await ingestionService.ingestResponses(
          request.requestId,
        );
        totalIngested += result.ingestedCount;
        totalErrors += result.errorCount;
        errors.addAll(result.errors);
      }

      if (context.mounted) {
        Navigator.of(context).pop();

        // Refresh conversations
        ref.invalidate(conversationsProvider);

        // Show results
        if (totalErrors == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ingested $totalIngested response(s)'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ingested $totalIngested response(s), $totalErrors error(s)',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        final errorMessage = ErrorHandler.getUserFriendlyMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  static void showSendAgainDialog(
    BuildContext context,
    WidgetRef ref,
    models.DataRequest request,
  ) async {
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 7));
    bool reuseSheet = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Send Again'),
                  content: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Create a new iteration of this request?'),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Due Date'),
                          subtitle: Text(_formatDate(selectedDueDate)),
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
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Reuse existing sheet'),
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
        templateRequestId: request.requestId,
        newDueDate: result['dueDate'] as DateTime,
        reuseSheet: result['reuseSheet'] as bool,
      );

      // Send the new request
      await requestService.sendRequest(newRequestId);

      if (context.mounted) {
        Navigator.of(context).pop();
        ref.invalidate(conversationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New iteration created and sent'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        final errorMessage = ErrorHandler.getUserFriendlyMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  static void createNewRequest(BuildContext context, String conversationId) {
    // Navigate to request builder with conversationId
    context.go('/request/new?conversationId=$conversationId&type=request');
  }

  static String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  static void renameConversation(
    BuildContext context,
    WidgetRef ref,
    models.Conversation conversation,
  ) async {
    final titleController = TextEditingController(text: conversation.title);

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rename Conversation'),
            content: TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Conversation Title',
                hintText: 'Enter conversation name',
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(context).pop(value.trim());
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newTitle = titleController.text.trim();
                  if (newTitle.isNotEmpty) {
                    Navigator.of(context).pop(newTitle);
                  }
                },
                child: const Text('Rename'),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const AlertDialog(
                content: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Renaming conversation...'),
                  ],
                ),
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

        // Update conversation title
        await requestService.updateConversationTitle(
          conversationId: conversation.id,
          title: result,
        );

        // Refresh conversations
        ref.invalidate(conversationsProvider);

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation renamed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ErrorHandler.getUserFriendlyMessage(e)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Participants Tab: List of all participants with their status
class _ParticipantsTab extends ConsumerWidget {
  final String conversationId;

  const _ParticipantsTab({required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(
      conversationParticipantsProvider(conversationId),
    );

    return participantsAsync.when(
      data: (participants) {
        if (participants.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No participants yet',
                style: TextStyle(
                  color:
                      Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6) ??
                      Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ),
          );
        }

        // Group by status
        final responded =
            participants
                .where((p) => p.status == models.RecipientState.responded)
                .toList();
        final pending =
            participants
                .where((p) => p.status == models.RecipientState.pending)
                .toList();
        final errors =
            participants
                .where((p) => p.status == models.RecipientState.error)
                .toList();

        return Column(
          children: [
            // Add Participant button
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      () => _showAddParticipantDialog(
                        context,
                        ref,
                        conversationId,
                      ),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Add Participant'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusChip(
                    label: 'All',
                    count: participants.length,
                    isSelected: true,
                  ),
                  _StatusChip(
                    label: 'Responded',
                    count: responded.length,
                    color: const Color(0xFF10B981),
                  ),
                  _StatusChip(
                    label: 'Pending',
                    count: pending.length,
                    color: const Color(0xFFF59E0B),
                  ),
                  _StatusChip(
                    label: 'Errors',
                    count: errors.length,
                    color: const Color(0xFFEF4444),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Participants list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final participant = participants[index];
                  return _ParticipantTile(
                    participant: participant,
                    conversationId: conversationId,
                    onRemove:
                        () => _removeParticipant(
                          context,
                          ref,
                          conversationId,
                          participant.email,
                        ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stack) => Center(
            child: Text(
              ErrorHandler.getUserFriendlyMessage(error),
              style: const TextStyle(fontSize: 12),
            ),
          ),
    );
  }
}

/// Status Chip - cleaner design
class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color? color;
  final bool isSelected;
  final VoidCallback? onSelected;

  const _StatusChip({
    required this.label,
    required this.count,
    this.color,
    this.isSelected = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: onSelected != null ? (_) => onSelected!() : null,
      selectedColor: color?.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? color : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected && color != null ? color! : Colors.grey[300]!,
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

// Helper functions for participant management
void _showAddParticipantDialog(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
) {
  final emailController = TextEditingController();

  showDialog(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Add Participant'),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'participant@example.com',
            ),
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            onSubmitted:
                (_) => _handleAddParticipant(
                  dialogContext,
                  ref,
                  conversationId,
                  emailController.text,
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed:
                  () => _handleAddParticipant(
                    dialogContext,
                    ref,
                    conversationId,
                    emailController.text,
                  ),
              child: const Text('Add'),
            ),
          ],
        ),
  );
}

Future<void> _handleAddParticipant(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
  String email,
) async {
  // Validate email address
  final emailValidation = validateEmail(email);
  if (!emailValidation.isValid) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(emailValidation.errorMessage!),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  try {
    final db = ref.read(appDatabaseProvider);
    final authService = ref.read(googleAuthServiceProvider);
    final gmailService = GmailService(authService);
    final sheetsService = SheetsService(authService);
    final loggingService = LoggingService(db);
    final requestService = RequestService(
      db,
      sheetsService,
      authService,
      gmailService,
      loggingService,
    );

    await requestService.addParticipantsToConversation(conversationId, [
      email.trim(),
    ]);

    // Invalidate providers to refresh UI
    ref.invalidate(conversationParticipantsProvider(conversationId));

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${email.trim()} to conversation')),
      );
    }
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
}

Future<void> _removeParticipant(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
  String email,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Remove Participant'),
          content: Text(
            'Are you sure you want to remove $email from this conversation?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        ),
  );

  if (confirmed != true) return;

  try {
    final db = ref.read(appDatabaseProvider);
    final authService = ref.read(googleAuthServiceProvider);
    final gmailService = GmailService(authService);
    final sheetsService = SheetsService(authService);
    final loggingService = LoggingService(db);
    final requestService = RequestService(
      db,
      sheetsService,
      authService,
      gmailService,
      loggingService,
    );

    await requestService.removeParticipantsFromConversation(conversationId, [
      email,
    ]);

    // Invalidate providers to refresh UI
    ref.invalidate(conversationParticipantsProvider(conversationId));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed $email from conversation')),
      );
    }
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
}

/// Participant Tile - cleaner design
class _ParticipantTile extends StatelessWidget {
  final models.RecipientStatus participant;
  final String conversationId;
  final VoidCallback onRemove;

  const _ParticipantTile({
    required this.participant,
    required this.conversationId,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (participant.status) {
      case models.RecipientState.responded:
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        statusText = 'Responded';
        break;
      case models.RecipientState.pending:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending;
        statusText = 'Pending';
        break;
      case models.RecipientState.error:
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.error;
        statusText = 'Error';
        break;
      case models.RecipientState.bounced:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        statusText = 'Bounced';
        break;
    }

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(statusIcon, size: 16, color: statusColor),
      ),
      title: Text(
        participant.email,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle:
          participant.lastResponseAt != null
              ? Text(
                'Responded ${_formatRelativeTime(participant.lastResponseAt!)}',
                style: TextStyle(
                  fontSize: 11,
                  color:
                      Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6) ??
                      Colors.grey[600],
                ),
              )
              : participant.reminderSentAt != null
              ? Text(
                'Reminder sent ${_formatRelativeTime(participant.reminderSentAt!)}',
                style: TextStyle(
                  fontSize: 11,
                  color:
                      Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6) ??
                      Colors.grey[600],
                ),
              )
              : Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  color:
                      Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6) ??
                      Colors.grey[600],
                ),
              ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18),
        color: Colors.grey[600],
        onPressed: onRemove,
        tooltip: 'Remove participant',
      ),
    );
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Schema Tab: Display the defined columns/schema for the conversation
class _SchemaTab extends ConsumerWidget {
  final String conversationId;

  const _SchemaTab({required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(
      conversationRequestsProvider(conversationId),
    );

    return requestsAsync.when(
      data: (requests) {
        debugPrint(
          'SchemaTab: Found ${requests.length} request(s) for conversation $conversationId',
        );
        for (final req in requests) {
          debugPrint(
            '  - Request ${req.requestId}: isTemplate=${req.isTemplate}, schema columns=${req.schema.columns.length}',
          );
        }

        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No schema defined yet.\nUse the AI agent to define a schema, or create a request to define the schema.',
                style: TextStyle(
                  color:
                      Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6) ??
                      Colors.grey[600],
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Get the most recent request's schema (prefer template requests)
        models.DataRequest schemaRequest;

        // First, try to find a template request
        final templateRequests =
            requests.where((r) => r.isTemplate == true).toList();
        if (templateRequests.isNotEmpty) {
          // Sort by dueAt descending to get most recent (requests are already sorted, but ensure template is most recent)
          templateRequests.sort((a, b) => b.dueAt.compareTo(a.dueAt));
          schemaRequest = templateRequests.first;
          debugPrint(
            'SchemaTab: Using template request ${schemaRequest.requestId}',
          );
        } else {
          // Use the most recent request (already sorted by dueAt desc)
          schemaRequest = requests.first;
          debugPrint(
            'SchemaTab: Using most recent request ${schemaRequest.requestId} (isTemplate: ${schemaRequest.isTemplate})',
          );
        }

        final schema = schemaRequest.schema;
        debugPrint(
          'SchemaTab: Displaying schema with ${schema.columns.length} column(s): ${schema.columns.map((c) => c.name).join(", ")}',
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Data Schema',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Columns defined for this conversation',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6) ??
                      Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              // Columns list
              if (schema.columns.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[700]!
                              : Colors.grey[200]!,
                    ),
                  ),
                  child: Text(
                    'No columns defined',
                    style: TextStyle(
                      color:
                          Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withOpacity(0.6) ??
                          Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                )
              else
                ...schema.columns.asMap().entries.map((entry) {
                  final index = entry.key;
                  final column = entry.value;
                  return _SchemaColumnCard(index: index + 1, column: column);
                }).toList(),
              const SizedBox(height: 16),
              // Schema info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This schema is used for all requests in this conversation. Use the AI agent to modify the schema.',
                        style: TextStyle(fontSize: 11, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stack) => Center(
            child: Text(
              ErrorHandler.getUserFriendlyMessage(error),
              style: const TextStyle(fontSize: 12),
            ),
          ),
    );
  }
}

/// Schema Column Card - displays a single column definition
class _SchemaColumnCard extends StatelessWidget {
  final int index;
  final SchemaColumn column;

  const _SchemaColumnCard({required this.index, required this.column});

  @override
  Widget build(BuildContext context) {
    // Determine column type display
    String typeDisplay;
    IconData typeIcon;
    Color typeColor;

    switch (column.type) {
      case models.ColumnType.stringType:
        typeDisplay = 'Text';
        typeIcon = Icons.text_fields;
        typeColor = const Color(0xFF3B82F6);
        break;
      case models.ColumnType.numberType:
        typeDisplay = 'Number';
        typeIcon = Icons.numbers;
        typeColor = const Color(0xFF10B981);
        break;
      case models.ColumnType.dateType:
        typeDisplay = 'Date';
        typeIcon = Icons.calendar_today;
        typeColor = const Color(0xFFF59E0B);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[700]!
                  : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          // Column number
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Column info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        column.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (column.required)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(typeIcon, size: 12, color: typeColor),
                    const SizedBox(width: 4),
                    Text(
                      typeDisplay,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            Theme.of(
                              context,
                            ).textTheme.bodySmall?.color?.withOpacity(0.6) ??
                            Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Activity Tab: Timeline of all activities with pagination
class _ActivityTab extends ConsumerStatefulWidget {
  final String conversationId;

  const _ActivityTab({required this.conversationId});

  @override
  ConsumerState<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<_ActivityTab> {
  final List<models.ActivityLogEntry> _loadedLogs = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    // Load initial logs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActivityLogs(ref, append: false);
    });
  }

  Future<void> _loadActivityLogs(
    WidgetRef ref, {
    bool append = true,
  }) async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
      _isInitialLoad = false;
    });

    try {
      final db = ref.read(appDatabaseProvider);
      final loggingService = LoggingService(db);

      // Get all requests for this conversation
      final requests = await db.getRequestsByConversation(widget.conversationId);

      if (requests.isEmpty) {
        setState(() {
          _loadedLogs.clear();
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      // Calculate how many logs to fetch per request
      final currentLimit = append
          ? _loadedLogs.length + _activityLogsInitialLimit
          : _activityLogsInitialLimit;
      final totalLimit = currentLimit.clamp(0, _activityLogsMaxLimit);
      final limitPerRequest =
          (totalLimit / requests.length).ceil().clamp(10, 100);

      final allLogs = <models.ActivityLogEntry>[];
      for (final request in requests) {
        final logs = await loggingService.getActivityLogs(
          request.requestId,
          limit: limitPerRequest,
        );
        allLogs.addAll(logs);
      }

      // Sort by timestamp (most recent first)
      allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Limit to max
      final limitedLogs = allLogs.take(totalLimit).toList();

      setState(() {
        if (append) {
          // Merge with existing, removing duplicates
          final existingIds = _loadedLogs.map((l) => l.id).toSet();
          final newLogs =
              limitedLogs.where((l) => !existingIds.contains(l.id)).toList();
          _loadedLogs.addAll(newLogs);
          _loadedLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        } else {
          _loadedLogs.clear();
          _loadedLogs.addAll(limitedLogs);
        }
        _hasMore = limitedLogs.length >= totalLimit &&
            totalLimit < _activityLogsMaxLimit;
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
    if (_isInitialLoad && _loadedLogs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadedLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No activity yet',
            style: TextStyle(
              color:
                  Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6) ??
                  Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _loadedLogs.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show "Load More" button at the end
        if (index == _loadedLogs.length) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: () {
                        _loadActivityLogs(ref, append: true);
                      },
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load More Activity'),
                    ),
            ),
          );
        }

        final log = _loadedLogs[index];
        return _ActivityItem(log: log, conversationId: widget.conversationId);
      },
    );
  }
}

/// Activity Item - cleaner design with details and reparse for errors
class _ActivityItem extends ConsumerWidget {
  final models.ActivityLogEntry log;
  final String conversationId;

  const _ActivityItem({required this.log, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = jsonDecode(log.payloadJson) as Map<String, dynamic>;

    IconData icon;
    Color color;
    String description;
    String? detailText;
    bool showReparse = false;

    switch (log.type) {
      case models.ActivityType.sent:
        icon = Icons.send;
        color = const Color(0xFF3B82F6);
        description = 'Sent to ${payload['recipient'] ?? 'recipient'}';
        break;
      case models.ActivityType.ingested:
        icon = Icons.check_circle;
        color = const Color(0xFF10B981);
        description =
            'Response ingested from ${payload['fromEmail'] ?? 'participant'}';
        if (payload['rowsCount'] != null) {
          detailText = '${payload['rowsCount']} row(s) added';
        }
        break;
      case models.ActivityType.parseError:
        icon = Icons.error;
        color = const Color(0xFFEF4444);
        final fromEmail = payload['fromEmail'] ?? 'unknown';
        final error = payload['error'] ?? 'Unknown error';
        description = 'Parse error from $fromEmail';
        detailText = error;
        showReparse = true;
        break;
      case models.ActivityType.reminderSent:
        icon = Icons.notifications;
        color = const Color(0xFFF59E0B);
        description =
            'Reminder sent to ${payload['recipient'] ?? 'participant'}';
        break;
      case models.ActivityType.sendError:
        icon = Icons.error_outline;
        color = const Color(0xFFEF4444);
        description = 'Send failed: ${payload['error'] ?? 'Unknown error'}';
        if (payload['recipient'] != null) {
          detailText = 'To: ${payload['recipient']}';
        }
        break;
      case models.ActivityType.ingestionCheck:
        icon = Icons.refresh;
        color = const Color(0xFF3B82F6);
        description = 'Checked for responses';
        break;
      case models.ActivityType.ingestionError:
        icon = Icons.warning;
        color = const Color(0xFFF59E0B);
        description = 'Ingestion error: ${payload['error'] ?? 'Unknown error'}';
        if (payload['fromEmail'] != null) {
          detailText = 'From: ${payload['fromEmail']}';
        }
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (detailText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detailText,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatTime(log.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            Theme.of(
                              context,
                            ).textTheme.bodySmall?.color?.withOpacity(0.6) ??
                            Colors.grey[600],
                      ),
                    ),
                    if (showReparse) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed:
                            () => _reparseEmail(context, ref, log, payload),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Reparse',
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reparseEmail(
    BuildContext context,
    WidgetRef ref,
    models.ActivityLogEntry log,
    Map<String, dynamic> payload,
  ) async {
    final messageId = payload['messageId'] as String?;
    final fromEmail = payload['fromEmail'] as String?;

    if (messageId == null || fromEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot reparse: Missing message ID or email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
                Text('Reparsing email...'),
              ],
            ),
          ),
    );

    try {
      // Get services
      final db = ref.read(appDatabaseProvider);
      final authService = ref.read(googleAuthServiceProvider);
      final gmailService = GmailService(authService);

      // Get the message from Gmail first to extract request ID
      gmail.Message message;
      try {
        message = await gmailService.getMessage(messageId);
      } catch (e) {
        throw Exception('Failed to retrieve email from Gmail: $e');
      }

      final body = gmailService.extractPlainTextBody(message) ?? '';
      final timestamp = gmailService.getInternalDate(message);

      if (body.isEmpty) {
        throw Exception('Email body is empty. Cannot parse an empty email.');
      }

      // Debug: Log the email body being parsed
      debugPrint('=== EMAIL BODY BEING PARSED ===');
      debugPrint(body);
      debugPrint('=== END EMAIL BODY ===');

      // Try to find the correct request ID from the email
      // 1. Check email subject for request ID
      String? correctRequestId;
      final subject =
          message.payload?.headers
              ?.firstWhere(
                (h) => h.name?.toLowerCase() == 'subject',
                orElse: () => throw Exception('No subject found'),
              )
              .value;

      if (subject != null) {
        final extractedId = extractRequestIdFromSubject(subject);
        if (extractedId != null) {
          correctRequestId = extractedId;
          debugPrint('Found request ID from subject: $correctRequestId');
        }
      }

      // 2. If not in subject, try to extract from email body
      if (correctRequestId == null) {
        final requestIdMatch = RegExp(
          r'Request ID:\s*([a-f0-9-]+)',
        ).firstMatch(body);
        if (requestIdMatch != null) {
          correctRequestId = requestIdMatch.group(1);
          debugPrint('Found request ID from body: $correctRequestId');
        }
      }

      // 3. Use the correct request ID, or fall back to the log's request ID
      final requestIdToUse = correctRequestId ?? log.requestId;
      debugPrint(
        'Using request ID: $requestIdToUse (from log: ${log.requestId})',
      );

      // Get the request with the correct ID
      final request = await db.getRequest(requestIdToUse);
      if (request == null) {
        throw Exception(
          'Request not found: $requestIdToUse. The email may be replying to a different request.',
        );
      }

      // Verify this request belongs to the same conversation
      if (request.conversationId != conversationId) {
        throw Exception(
          'Request $requestIdToUse belongs to a different conversation.',
        );
      }

      debugPrint(
        'Using schema from request $requestIdToUse: ${request.schema.columns.map((c) => c.name).join(", ")}',
      );

      // Get AI agent service
      final sheetsService = SheetsService(authService);
      final loggingService = LoggingService(db);
      final requestService = RequestService(
        db,
        sheetsService,
        authService,
        gmailService,
        loggingService,
      );
      final settingsController = SettingsController(db);
      final aiAgentService = AIAgentService(
        db,
        sheetsService,
        authService,
        requestService,
        loggingService,
        settingsController,
        gmailService,
      );

      // Unmark message as processed for both the old and new request IDs
      await db.unmarkMessageProcessed(log.requestId, messageId);
      if (requestIdToUse != log.requestId) {
        await db.unmarkMessageProcessed(requestIdToUse, messageId);
      }

      // Reparse using AI with the correct request ID
      final parseResult = await aiAgentService.executeParseEmailResponse(
        conversationId: conversationId,
        requestId: requestIdToUse,
        emailBody: body,
        fromEmail: fromEmail,
        messageId: messageId,
      );

      if (parseResult['success'] != true) {
        final errorMsg =
            parseResult['error'] as String? ?? 'Unknown parsing error';
        throw Exception('AI parsing failed: $errorMsg');
      }

      // Check for both 'parsed_data' and 'rows' keys (for compatibility)
      final parsedRows =
          (parseResult['parsed_data'] ?? parseResult['rows']) as List<dynamic>?;

      if (parsedRows == null || parsedRows.isEmpty) {
        // Get more details from parse result
        final errorDetail =
            parseResult['error'] as String? ??
            'No data found. The AI parser returned an empty result.';
        throw Exception(errorDetail);
      }
      // Save parsed data using the correct request ID
      final saveResult = await aiAgentService.executeSaveParsedData(
        conversationId: conversationId,
        requestId: requestIdToUse,
        fromEmail: fromEmail,
        messageId: messageId,
        timestamp: timestamp,
        parsedData: parsedRows.map((r) => r as Map<String, dynamic>).toList(),
      );

      if (saveResult['success'] != true) {
        final errorMsg = saveResult['error'] as String? ?? 'Unknown save error';
        throw Exception('Failed to save parsed data to sheet: $errorMsg');
      }

      // Mark as processed for the correct request ID
      await db.markMessageProcessed(requestIdToUse, messageId);

      if (context.mounted) {
        Navigator.of(context).pop();
        ref.invalidate(conversationActivityLogsProvider(conversationId));
        ref.invalidate(conversationParticipantsProvider(conversationId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully reparsed and saved ${parsedRows.length} row(s)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reparse failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _formatTime(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
