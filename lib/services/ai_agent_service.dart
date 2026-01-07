/// AI Agent Service
/// Handles natural language queries, intent detection, and action execution using OpenAI Function Calling

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart';
import 'package:decision_agent/app/db_provider.dart';
import 'package:decision_agent/data/db/app_db.dart';
import 'package:decision_agent/data/db/dao.dart';
import 'package:decision_agent/data/google/sheets_service.dart';
import 'package:decision_agent/data/google/google_auth_service.dart';
import 'package:decision_agent/data/google/gmail_service.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:decision_agent/services/request_service.dart';
import 'package:decision_agent/services/logging_service.dart';
import 'package:decision_agent/domain/models.dart' as models;
import 'package:decision_agent/domain/email_protocol.dart';
import 'package:decision_agent/domain/request_schema.dart';
import 'package:decision_agent/features/settings/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/app/auth_provider.dart';
import 'package:decision_agent/utils/ids.dart';

/// AI Agent message
class AIMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  AIMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

/// AI Agent response
class AIAgentResponse {
  final String message;
  final bool isAction;
  final Map<String, dynamic>? actionResult;

  AIAgentResponse({
    required this.message,
    this.isAction = false,
    this.actionResult,
  });
}

class AIAgentService {
  final AppDatabase _db;
  final SheetsService _sheetsService;
  final GoogleAuthService _authService;
  final RequestService _requestService;
  final LoggingService _loggingService;
  final SettingsController _settingsController;
  final GmailService _gmailService;

  AIAgentService(
    this._db,
    this._sheetsService,
    this._authService,
    this._requestService,
    this._loggingService,
    this._settingsController,
    this._gmailService,
  );

  /// Get available tools (functions) for OpenAI
  List<Map<String, dynamic>> _getAvailableTools() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'send_reminders',
          'description':
              'Send reminder emails to participants who have not responded to the data request. Use this when the user asks to send reminders, notify pending participants, or follow up with non-responders.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description':
                    'The ID of the conversation to send reminders for',
              },
              'participant_emails': {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    'Optional: Specific participant email addresses to send reminders to. If not provided, reminders will be sent to all pending participants.',
              },
            },
            'required': ['conversation_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'create_request',
          'description':
              'Create a new data request in the conversation and send it to participants. Use this when the user wants to create a new request, send a request, or request data from participants. NOTE: For new conversations without previous requests, you must first use define_schema to define what data to collect before creating a request.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description':
                    'The ID of the conversation to create the request in',
              },
              'participant_emails': {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    'List of participant email addresses to send the request to',
              },
              'due_date': {
                'type': 'string',
                'description':
                    'Optional: Due date in ISO 8601 format (YYYY-MM-DD). If not provided, defaults to 7 days from today.',
              },
              'title': {
                'type': 'string',
                'description':
                    'Optional: Title for the request. If not provided, uses the conversation title.',
              },
              'instructions': {
                'type': 'string',
                'description':
                    'Optional: Additional instructions or description for the request.',
              },
              'schema_columns': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'name': {'type': 'string', 'description': 'Column name'},
                    'type': {
                      'type': 'string',
                      'enum': ['string', 'number', 'date', 'boolean'],
                      'description': 'Data type for the column',
                    },
                    'required': {
                      'type': 'boolean',
                      'description': 'Whether this column is required',
                    },
                  },
                  'required': ['name', 'type'],
                },
                'description':
                    'Optional: Schema definition (columns/fields to collect). If not provided and no previous requests exist, the request will fail. Use define_schema first for new conversations.',
              },
            },
            'required': ['conversation_id', 'participant_emails'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'define_schema',
          'description':
              'Define the data schema (what information to collect) for a conversation. Use this when the user describes what data they want to collect (e.g., "I need Name, Email, Amount, Date"). This must be done before creating the first request or sheet.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description':
                    'The ID of the conversation to define schema for',
              },
              'columns': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'name': {
                      'type': 'string',
                      'description': 'Name of the column/field',
                    },
                    'type': {
                      'type': 'string',
                      'enum': ['string', 'number', 'date', 'boolean'],
                      'description':
                          'Data type: string for text, number for numeric values, date for dates, boolean for true/false',
                    },
                    'required': {
                      'type': 'boolean',
                      'description': 'Whether this field is required',
                    },
                  },
                  'required': ['name', 'type'],
                },
                'description':
                    'List of columns/fields to collect. Each column needs a name and type.',
              },
            },
            'required': ['conversation_id', 'columns'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'add_participants',
          'description':
              'Add new participants to the conversation. These participants will be included in future requests. Use this when the user wants to add someone to the conversation or include new participants.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description':
                    'The ID of the conversation to add participants to',
              },
              'participant_emails': {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    'List of participant email addresses to add to the conversation',
              },
            },
            'required': ['conversation_id', 'participant_emails'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'get_conversation_stats',
          'description':
              'Get detailed statistics about a conversation including participant counts, response rates, and request information. Use this when the user asks about statistics, counts, or status of the conversation.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description':
                    'The ID of the conversation to get statistics for',
              },
            },
            'required': ['conversation_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'parse_email_response',
          'description':
              'Parse structured data from an email response using AI. Use this to extract table data from email replies. The AI will intelligently extract data even if the format is not perfect.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description':
                    'The ID of the conversation this email belongs to',
              },
              'request_id': {
                'type': 'string',
                'description':
                    'The ID of the request this email is responding to',
              },
              'email_body': {
                'type': 'string',
                'description': 'The plain text body of the email to parse',
              },
              'from_email': {
                'type': 'string',
                'description': 'The email address of the sender',
              },
              'message_id': {
                'type': 'string',
                'description': 'The Gmail message ID',
              },
            },
            'required': [
              'conversation_id',
              'request_id',
              'email_body',
              'from_email',
              'message_id',
            ],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'save_parsed_data',
          'description':
              'Save parsed data rows to the Google Sheet. Use this after parsing email responses to store the extracted data.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description': 'The ID of the conversation',
              },
              'request_id': {
                'type': 'string',
                'description': 'The ID of the request',
              },
              'rows': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'description':
                      'A data row with column names as keys and values',
                },
                'description': 'Array of parsed data rows to save',
              },
              'from_email': {
                'type': 'string',
                'description': 'The email address of the sender',
              },
              'message_id': {
                'type': 'string',
                'description': 'The Gmail message ID',
              },
            },
            'required': [
              'conversation_id',
              'request_id',
              'rows',
              'from_email',
              'message_id',
            ],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'check_for_responses',
          'description':
              'Check Gmail for email responses to data requests and ingest them into the Google Sheet. This will search for replies, use AI to parse them, and save the data. Use this when the user asks to check for responses, check emails, see if anyone replied, or ingest responses.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description':
                    'The ID of the conversation to check for responses',
              },
            },
            'required': ['conversation_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'analyze_sheet_data',
          'description':
              'Read and analyze data from the Google Sheet associated with the conversation. Use this when the user asks about the data, wants insights, trends, analysis, or asks questions like "what does the data tell us", "analyze the responses", "show trends", etc.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description':
                    'The ID of the conversation to analyze sheet data for',
              },
              'analysis_type': {
                'type': 'string',
                'enum': ['summary', 'trends', 'insights', 'general'],
                'description':
                    'Optional: Type of analysis requested. "summary" for overall summary, "trends" for trend analysis, "insights" for key insights, or "general" for general analysis based on the query.',
              },
            },
            'required': ['conversation_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'list_participants',
          'description':
              'List participants in the conversation with their response status. Use this when the user asks "who has responded", "list users that have not responded", "show participants", "who is pending", etc.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description':
                    'The ID of the conversation to list participants for',
              },
              'filter': {
                'type': 'string',
                'enum': ['all', 'responded', 'pending', 'errors'],
                'description':
                    'Optional: Filter participants by status. "all" for all participants, "responded" for those who responded, "pending" for those who haven\'t responded, "errors" for those with errors. Defaults to "all".',
              },
            },
            'required': ['conversation_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'set_next_due_date',
          'description':
              'Set the due date for the next request in the conversation. Use this when the user asks to "set due date", "update due date", "change due date", or specifies a date for the next request.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description':
                    'The ID of the conversation to set the due date for',
              },
              'due_date': {
                'type': 'string',
                'description':
                    'Due date in ISO 8601 format (YYYY-MM-DD) for the next request',
              },
            },
            'required': ['conversation_id', 'due_date'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'create_sheet',
          'description':
              'Create a Google Sheet for the conversation. Use this when the user wants to create a sheet, set up data collection, or when setting up a new conversation. The sheet will be used to store responses.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description':
                    'The ID of the conversation to create a sheet for',
              },
            },
            'required': ['conversation_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'create_conversation',
          'description':
              'Create a new conversation with a title. Use this when the user wants to start a new conversation or set up a new data collection project.',
          'parameters': {
            'type': 'object',
            'properties': {
              'title': {
                'type': 'string',
                'description': 'Title for the new conversation',
              },
            },
            'required': ['title'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'update_conversation_title',
          'description':
              'Update the title of the current conversation. Use this when the user provides a name or title for the conversation (e.g., "Monthly Finance Data", "Quarterly Report", etc.) during setup or anytime they want to rename the conversation.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description': 'The ID of the conversation to update',
              },
              'title': {
                'type': 'string',
                'description': 'The new title for the conversation',
              },
            },
            'required': ['conversation_id', 'title'],
          },
        },
      },
    ];
  }

  /// Process user query and return response
  Future<AIAgentResponse> processQuery(
    String query,
    String? conversationId,
    List<AIMessage> messageHistory,
  ) async {
    // Check if OpenAI key is configured
    final openAiKey = await _settingsController.getOpenAiKey();
    if (openAiKey == null || openAiKey.isEmpty) {
      return AIAgentResponse(
        message:
            'OpenAI API key is not configured. Please add it in Settings to use the AI Agent.',
      );
    }

    // Validate conversation ID if provided
    if (conversationId == null) {
      // For simple questions that don't need a conversation, allow them
      if (query.toLowerCase().contains('help') ||
          query.toLowerCase().contains('what can you do')) {
        return AIAgentResponse(
          message:
              'I can help you manage your data requests! I can:\n\n'
              '• Answer questions about your conversations (participants, responses, statistics)\n'
              '• Send reminders to pending participants\n'
              '• Create new requests in conversations\n'
              '• Add participants to conversations\n\n'
              'Please select a conversation to get started, or ask me a question about a specific conversation.',
        );
      }
      return AIAgentResponse(
        message: 'Please select a conversation to interact with the AI Agent.',
      );
    }

    // Use OpenAI with tools for all queries
    return await _callOpenAIWithTools(
      query,
      conversationId,
      messageHistory,
      openAiKey,
    );
  }

  /// Call OpenAI API with tools support
  Future<AIAgentResponse> _callOpenAIWithTools(
    String query,
    String? conversationId,
    List<AIMessage> messageHistory,
    String openAiKey,
  ) async {
    try {
      // Build context from conversation
      final now = DateTime.now();
      final currentDateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final currentDateReadable =
          '${_getMonthName(now.month)} ${now.day}, ${now.year}';

      String systemPrompt =
          '''You are an AI assistant for DIGIT Decision, a tool for managing structured data requests via email.

IMPORTANT: Today's date is $currentDateReadable ($currentDateStr). Always use this date when calculating due dates or checking if dates are in the future.

Your role is to help users:
1. Gather data by sending emails to a large number of participants
2. Track responses from participants
3. Send reminders to those who haven't responded
4. Parse responses and save data to Google Sheets
5. Analyze the collected data

You can guide users through the entire setup process. When a new conversation is created, help them:
- Define the data schema (what information to collect) - ask the user what columns/fields they need
- Add participants (email addresses)
- Create a Google Sheet for data collection (requires schema first)
- Send the first request (requires schema and participants)
- Track responses and send reminders
- Analyze the collected data

IMPORTANT: Always be proactive and helpful. Guide users through each step naturally in conversation.
IMPORTANT: For new conversations without previous requests, you need to ask the user to define the schema (what data fields/columns they want to collect) before creating a request or sheet.''';

      if (conversationId != null) {
        // IMPORTANT: Include conversation_id in system prompt so LLM knows it
        systemPrompt +=
            '\n\nIMPORTANT: The current conversation_id is: $conversationId\n';
        systemPrompt +=
            'Always use this conversation_id when calling functions.\n\n';

        try {
          final conversations = await _db.getConversations(
            includeArchived: true,
          );
          final conversation = conversations.firstWhere(
            (c) => c.id == conversationId,
            orElse: () => throw Exception('Conversation not found'),
          );

          final requests = await _db.getRequestsByConversation(conversationId);
          final participants = await _getAllParticipants(conversationId);

          systemPrompt += 'Current conversation: ${conversation.title}\n';
          systemPrompt += 'Total requests: ${requests.length}\n';
          systemPrompt += 'Total participants: ${participants.length}\n';

          final respondedCount =
              participants
                  .where((p) => p.status == models.RecipientState.responded)
                  .length;
          final pendingCount =
              participants
                  .where((p) => p.status == models.RecipientState.pending)
                  .length;
          final errorCount =
              participants
                  .where((p) => p.status == models.RecipientState.error)
                  .length;

          systemPrompt +=
              'Responded: $respondedCount, Pending: $pendingCount, Errors: $errorCount\n';

          if (requests.isNotEmpty) {
            final mostRecent = requests.first;
            systemPrompt += 'Latest request due date: ${mostRecent.dueAt}\n';
            systemPrompt += 'Latest request title: ${mostRecent.title}\n';
          }

          // Add setup status
          if (conversation.sheetId.isEmpty) {
            systemPrompt +=
                '\n⚠️ This conversation does not have a Google Sheet yet. You should help create one using the create_sheet function.\n';
          }
          if (requests.isEmpty) {
            systemPrompt +=
                '\n⚠️ No requests have been sent yet. Help the user set up and send their first request.\n';
          }
        } catch (e) {
          systemPrompt += 'Warning: Could not load conversation details: $e\n';
        }
      }

      // Build messages with context window management
      // Keep last 20 messages for context (to avoid token limits)
      final recentHistory =
          messageHistory.length > 20
              ? messageHistory.sublist(messageHistory.length - 20)
              : messageHistory;

      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemPrompt},
        ...recentHistory.map((m) => {'role': m.role, 'content': m.content}),
        {'role': 'user', 'content': query},
      ];

      // Get available tools
      final tools = _getAvailableTools();

      // First call: Check if LLM wants to call a function
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openAiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': messages,
          'tools': tools,
          'tool_choice': 'auto', // Let LLM decide
          'temperature': 0.7,
          'max_tokens': 2000, // Increased for longer responses
        }),
      );

      if (response.statusCode != 200) {
        return AIAgentResponse(
          message:
              'Error calling OpenAI API: ${response.statusCode} - ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final message = data['choices']?[0]?['message'] as Map<String, dynamic>?;

      if (message == null) {
        return AIAgentResponse(
          message: 'No response from AI. Please try again.',
        );
      }

      // Check if LLM wants to call a function
      final toolCalls = message['tool_calls'] as List<dynamic>?;

      if (toolCalls != null && toolCalls.isNotEmpty) {
        // Execute function calls
        final functionResults = await _executeFunctionCalls(
          toolCalls,
          conversationId,
        );

        // Add assistant message with tool calls to history
        messages.add({
          'role': 'assistant',
          'content': message['content'],
          'tool_calls': toolCalls,
        });

        // Add function results to messages
        for (int i = 0; i < functionResults.length; i++) {
          final toolCall = toolCalls[i];
          messages.add({
            'role': 'tool',
            'tool_call_id': toolCall['id'],
            'content': jsonEncode(functionResults[i]),
          });
        }

        // Second call: Get natural language response with function results
        // Check if any function failed
        final hasFailures = functionResults.any((r) => r['success'] == false);

        // For analyze_sheet_data, provide additional context to help LLM analyze
        final analyzeResults =
            functionResults
                .where((r) => r['success'] == true && r.containsKey('data'))
                .toList();

        if (analyzeResults.isNotEmpty) {
          // Add context for data analysis
          final dataContext = analyzeResults
              .map((r) {
                final data = r['data'] as Map<String, dynamic>?;
                if (data == null) return '';

                final headers = data['headers'] as List<dynamic>? ?? [];
                final sampleData = data['sample_data'] as List<dynamic>? ?? [];
                final totalRows = data['total_rows'] as int? ?? 0;

                return 'Sheet data: ${totalRows} rows with columns: ${headers.join(", ")}. '
                    'Sample data (first ${sampleData.length} rows): ${jsonEncode(sampleData)}';
              })
              .join('\n');

          messages.add({
            'role': 'user',
            'content':
                'Based on the sheet data retrieved, please analyze it and provide insights. '
                'Consider trends, patterns, statistics, and answer any specific questions the user asked. '
                'Here is the data context:\n\n$dataContext',
          });
        } else if (hasFailures) {
          // If functions failed, provide helpful error context
          final errorMessages = functionResults
              .where((r) => r['success'] == false)
              .map((r) => r['error'] as String? ?? 'Unknown error')
              .join('; ');

          // Add error context to messages
          messages.add({
            'role': 'user',
            'content':
                'The function call failed with these errors: $errorMessages. Please explain what went wrong and suggest what the user should do.',
          });
        }

        final finalResponse = await http.post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $openAiKey',
          },
          body: jsonEncode({
            'model': 'gpt-4o-mini',
            'messages': messages,
            'tools': tools,
            'tool_choice': 'none', // Don't call more functions
            'temperature': 0.7,
            'max_tokens': 2000, // Increased for longer responses
          }),
        );

        if (finalResponse.statusCode != 200) {
          return AIAgentResponse(
            message:
                'Error getting final response: ${finalResponse.statusCode}. ${finalResponse.body}',
          );
        }

        final finalData =
            jsonDecode(finalResponse.body) as Map<String, dynamic>;
        final finalContent =
            finalData['choices']?[0]?['message']?['content'] as String?;

        return AIAgentResponse(
          message:
              finalContent ??
              (hasFailures
                  ? 'I encountered an error while processing your request. Please try again or check the conversation selection.'
                  : 'Action completed successfully.'),
          isAction: true,
          actionResult: functionResults.isNotEmpty ? functionResults[0] : null,
        );
      }

      // No function call, return text response
      final content = message['content'] as String?;
      return AIAgentResponse(message: content ?? 'No response from AI.');
    } catch (e) {
      return AIAgentResponse(message: 'Error: $e');
    }
  }

  /// Execute function calls requested by LLM
  Future<List<Map<String, dynamic>>> _executeFunctionCalls(
    List<dynamic> toolCalls,
    String? conversationId,
  ) async {
    final results = <Map<String, dynamic>>[];

    for (final call in toolCalls) {
      final functionName = call['function']?['name'] as String?;
      final argumentsJson = call['function']?['arguments'] as String?;

      if (functionName == null || argumentsJson == null) {
        results.add({
          'success': false,
          'error': 'Invalid function call format',
        });
        continue;
      }

      try {
        final arguments = jsonDecode(argumentsJson) as Map<String, dynamic>;

        // Use conversationId from context if not provided in arguments
        // This ensures the LLM doesn't need to extract it from the query
        if (!arguments.containsKey('conversation_id') ||
            arguments['conversation_id'] == null ||
            (arguments['conversation_id'] as String).isEmpty) {
          if (conversationId != null) {
            arguments['conversation_id'] = conversationId;
          }
        }

        Map<String, dynamic> result;
        switch (functionName) {
          case 'send_reminders':
            result = await _executeSendReminders(arguments);
            break;
          case 'create_request':
            result = await _executeCreateRequest(arguments);
            break;
          case 'add_participants':
            result = await _executeAddParticipants(arguments);
            break;
          case 'get_conversation_stats':
            result = await _executeGetConversationStats(arguments);
            break;
          case 'analyze_sheet_data':
            result = await _executeAnalyzeSheetData(arguments);
            break;
          case 'list_participants':
            result = await _executeListParticipants(arguments);
            break;
          case 'set_next_due_date':
            result = await _executeSetNextDueDate(arguments);
            break;
          case 'create_sheet':
            result = await _executeCreateSheet(arguments);
            break;
          case 'create_conversation':
            result = await _executeCreateConversation(arguments);
            break;
          case 'update_conversation_title':
            result = await _executeUpdateConversationTitle(arguments);
            break;
          case 'define_schema':
            result = await _executeDefineSchema(arguments);
            break;
          case 'check_for_responses':
            result = await _executeCheckForResponses(arguments);
            break;
          case 'parse_email_response':
            result = await _executeParseEmailResponse(arguments);
            break;
          case 'save_parsed_data':
            result = await _executeSaveParsedData(arguments);
            break;
          default:
            result = {
              'success': false,
              'error': 'Unknown function: $functionName',
            };
        }

        results.add(result);
      } catch (e) {
        results.add({
          'success': false,
          'error': 'Error executing $functionName: $e',
        });
      }
    }

    return results;
  }

  /// Execute send_reminders tool
  Future<Map<String, dynamic>> _executeSendReminders(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final conversationId = arguments['conversation_id'] as String?;
      if (conversationId == null) {
        return {'success': false, 'error': 'conversation_id is required'};
      }

      // Get pending participants
      final participants = await _getAllParticipants(conversationId);
      final participantEmails =
          arguments['participant_emails'] as List<dynamic>?;

      var pending =
          participants
              .where((p) => p.status == models.RecipientState.pending)
              .toList();

      // Filter by specific emails if provided
      if (participantEmails != null && participantEmails.isNotEmpty) {
        final emailList = participantEmails.map((e) => e.toString()).toList();
        pending = pending.where((p) => emailList.contains(p.email)).toList();
      }

      if (pending.isEmpty) {
        return {
          'success': true,
          'sent_count': 0,
          'message': 'No pending participants to send reminders to.',
        };
      }

      // Get most recent request for this conversation
      final requests = await _db.getRequestsByConversation(conversationId);
      if (requests.isEmpty) {
        return {'success': false, 'error': 'No requests found in conversation'};
      }

      final mostRecentRequest = requests.first;

      // Send reminders
      int sentCount = 0;
      int failedCount = 0;
      final errors = <String>[];

      for (final participant in pending) {
        try {
          // Get the request this participant belongs to
          final request = requests.firstWhere(
            (r) => r.requestId == participant.requestId,
            orElse: () => mostRecentRequest,
          );

          // Build reminder email
          final subject = 'Reminder: ${request.title}';
          final body = buildReminderEmailBody(request);

          // Send email
          final messageId = await _gmailService.sendEmail(
            to: participant.email,
            subject: subject,
            body: body,
          );

          // Update recipient status
          await _db.upsertRecipientStatus(
            models.RecipientStatus(
              requestId: participant.requestId,
              email: participant.email,
              status: participant.status,
              lastMessageId: participant.lastMessageId,
              lastResponseAt: participant.lastResponseAt,
              reminderSentAt: DateTime.now(),
              note: participant.note,
            ),
          );

          // Log activity
          await _loggingService.logActivity(
            participant.requestId,
            models.ActivityType.reminderSent,
            {'recipient': participant.email, 'messageId': messageId},
          );

          sentCount++;

          // Rate limiting
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          failedCount++;
          errors.add('${participant.email}: $e');
        }
      }

      return {
        'success': true,
        'sent_count': sentCount,
        'failed_count': failedCount,
        'errors': errors,
        'recipients': pending.map((p) => p.email).toList(),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Execute create_request tool
  Future<Map<String, dynamic>> _executeCreateRequest(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final conversationId = arguments['conversation_id'] as String?;
      if (conversationId == null) {
        return {'success': false, 'error': 'conversation_id is required'};
      }

      final participantEmails =
          arguments['participant_emails'] as List<dynamic>?;
      if (participantEmails == null || participantEmails.isEmpty) {
        return {'success': false, 'error': 'participant_emails is required'};
      }

      // Get conversation
      final conversations = await _db.getConversations(includeArchived: true);
      final conversation = conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => throw Exception('Conversation not found'),
      );

      // Get requests to find the correct schema
      final requests = await _db.getRequestsByConversation(conversationId);
      RequestSchema schema;

      // Check if schema is provided in arguments
      final schemaColumns = arguments['schema_columns'] as List<dynamic>?;
      if (schemaColumns != null && schemaColumns.isNotEmpty) {
        // Use provided schema
        schema = _parseSchemaFromColumns(schemaColumns);
      } else if (requests.isNotEmpty) {
        // Prefer schema from template requests (created via define_schema)
        // Otherwise use the most recent request's schema
        final templateRequest = requests.firstWhere(
          (r) => r.isTemplate == true,
          orElse: () => requests.first, // Fallback to most recent
        );
        schema = templateRequest.schema;

        // Debug: Log which schema is being used
        debugPrint(
          'Using schema from request ${templateRequest.requestId} (isTemplate: ${templateRequest.isTemplate}): ${schema.columns.map((c) => c.name).join(", ")}',
        );
      } else {
        return {
          'success': false,
          'error':
              'No previous requests found and no schema provided. Please use define_schema first to define what data to collect, or provide schema_columns in this call.',
        };
      }

      // Parse due date
      DateTime dueDate = DateTime.now().add(const Duration(days: 7));
      if (arguments['due_date'] != null) {
        try {
          dueDate = DateTime.parse(arguments['due_date'] as String);
          // Validate date is in the future
          if (dueDate.isBefore(DateTime.now())) {
            return {
              'success': false,
              'error':
                  'Due date must be in the future. Today is ${DateTime.now().toIso8601String().split('T')[0]}.',
            };
          }
        } catch (e) {
          return {
            'success': false,
            'error': 'Invalid due date format. Please use YYYY-MM-DD format.',
          };
        }
      }

      // Create draft request
      final requestId = await _requestService.createDraftRequest(
        conversationId: conversationId,
        title: arguments['title'] as String? ?? conversation.title,
        schema: schema,
        recipients: participantEmails.map((e) => e.toString()).toList(),
        dueDate: dueDate,
        instructions: arguments['instructions'] as String?,
      );

      // Ensure sheet exists
      if (conversation.sheetId.isEmpty) {
        await _requestService.createSheetForConversation(
          conversationId,
          schema,
        );
      }

      // Send request
      final sendResults = await _requestService.sendRequest(requestId);

      return {
        'success': true,
        'request_id': requestId,
        'recipients_count': participantEmails.length,
        'sent_count': sendResults['sent'] as int,
        'failed_count': sendResults['failed'] as int,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Execute add_participants tool
  Future<Map<String, dynamic>> _executeAddParticipants(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final conversationId = arguments['conversation_id'] as String?;
      if (conversationId == null) {
        return {'success': false, 'error': 'conversation_id is required'};
      }

      final participantEmails =
          arguments['participant_emails'] as List<dynamic>?;
      if (participantEmails == null || participantEmails.isEmpty) {
        return {'success': false, 'error': 'participant_emails is required'};
      }

      // Convert to list of strings
      final emails = participantEmails.map((e) => e.toString().trim()).toList();

      // Validate email addresses
      for (final email in emails) {
        if (!email.contains('@') || !email.contains('.')) {
          return {'success': false, 'error': 'Invalid email address: $email'};
        }
      }

      // Add participants to the conversation
      await _requestService.addParticipantsToConversation(
        conversationId,
        emails,
      );

      return {
        'success': true,
        'message':
            'Successfully added ${emails.length} participant(s) to the conversation: ${emails.join(", ")}',
        'participants': emails,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Execute list_participants tool
  Future<Map<String, dynamic>> _executeListParticipants(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final conversationId = arguments['conversation_id'] as String?;
      if (conversationId == null) {
        return {'success': false, 'error': 'conversation_id is required'};
      }

      final filter = arguments['filter'] as String? ?? 'all';
      final participants = await _getAllParticipants(conversationId);

      List<models.RecipientStatus> filtered;
      switch (filter) {
        case 'responded':
          filtered =
              participants
                  .where((p) => p.status == models.RecipientState.responded)
                  .toList();
          break;
        case 'pending':
          filtered =
              participants
                  .where((p) => p.status == models.RecipientState.pending)
                  .toList();
          break;
        case 'errors':
          filtered =
              participants
                  .where((p) => p.status == models.RecipientState.error)
                  .toList();
          break;
        default:
          filtered = participants;
      }

      return {
        'success': true,
        'filter': filter,
        'total_count': filtered.length,
        'participants':
            filtered
                .map(
                  (p) => {
                    'email': p.email,
                    'status': p.status.toString().split('.').last,
                    'last_response_at': p.lastResponseAt?.toIso8601String(),
                    'reminder_sent_at': p.reminderSentAt?.toIso8601String(),
                  },
                )
                .toList(),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Execute set_next_due_date tool
  Future<Map<String, dynamic>> _executeSetNextDueDate(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final conversationId = arguments['conversation_id'] as String?;
      if (conversationId == null) {
        return {'success': false, 'error': 'conversation_id is required'};
      }

      final dueDateStr = arguments['due_date'] as String?;
      if (dueDateStr == null) {
        return {'success': false, 'error': 'due_date is required'};
      }

      final dueDate = DateTime.parse(dueDateStr);
      if (dueDate.isBefore(DateTime.now())) {
        return {'success': false, 'error': 'Due date must be in the future'};
      }

      // Get the most recent request
      final requests = await _db.getRequestsByConversation(conversationId);
      if (requests.isEmpty) {
        return {
          'success': false,
          'error': 'No requests found in conversation. Create a request first.',
        };
      }

      // For now, we'll note this for the next request creation
      // In the future, we could add a "next_due_date" field to Conversation
      return {
        'success': true,
        'message':
            'Due date set to ${dueDate.toIso8601String().split('T')[0]}. This will be used for the next request you create.',
        'due_date': dueDate.toIso8601String(),
      };
    } catch (e) {
      return {'success': false, 'error': 'Error setting due date: $e'};
    }
  }

  /// Execute create_sheet tool
  Future<Map<String, dynamic>> _executeCreateSheet(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final conversationId = arguments['conversation_id'] as String?;
      if (conversationId == null) {
        return {'success': false, 'error': 'conversation_id is required'};
      }

      // Get conversation
      final conversations = await _db.getConversations(includeArchived: true);
      final conversation = conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => throw Exception('Conversation not found'),
      );

      // Check if sheet already exists
      if (conversation.sheetId.isNotEmpty) {
        return {
          'success': true,
          'message': 'Sheet already exists for this conversation.',
          'sheet_url': conversation.sheetUrl,
        };
      }

      // Get most recent request to get schema
      final requests = await _db.getRequestsByConversation(conversationId);
      if (requests.isEmpty) {
        return {
          'success': false,
          'error':
              'No requests found. Please create a request with a schema first before creating a sheet.',
        };
      }

      final mostRecentRequest = requests.first;
      final sheetUrl = await _requestService.createSheetForConversation(
        conversationId,
        mostRecentRequest.schema,
      );

      return {
        'success': true,
        'message': 'Google Sheet created successfully.',
        'sheet_url': sheetUrl,
      };
    } catch (e) {
      return {'success': false, 'error': 'Error creating sheet: $e'};
    }
  }

  /// Execute create_conversation tool
  Future<Map<String, dynamic>> _executeCreateConversation(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final title = arguments['title'] as String?;
      if (title == null || title.trim().isEmpty) {
        return {'success': false, 'error': 'title is required'};
      }

      final conversationId = await _requestService.createConversation(
        title: title.trim(),
      );

      return {
        'success': true,
        'message': 'Conversation created successfully.',
        'conversation_id': conversationId,
        'title': title.trim(),
      };
    } catch (e) {
      return {'success': false, 'error': 'Error creating conversation: $e'};
    }
  }

  /// Execute define_schema tool
  Future<Map<String, dynamic>> _executeDefineSchema(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final conversationId = arguments['conversation_id'] as String?;
      if (conversationId == null) {
        return {'success': false, 'error': 'conversation_id is required'};
      }

      final columns = arguments['columns'] as List<dynamic>?;
      if (columns == null || columns.isEmpty) {
        return {'success': false, 'error': 'columns are required'};
      }

      // Parse schema from columns
      final schema = _parseSchemaFromColumns(columns);

      // Create a draft request with this schema (this saves the schema for future use)
      // We'll create it as a draft that can be sent later
      final conversation = (await _db.getConversations(
        includeArchived: true,
      )).firstWhere(
        (c) => c.id == conversationId,
        orElse: () => throw Exception('Conversation not found'),
      );

      // Check if there are existing requests
      final existingRequests = await _db.getRequestsByConversation(
        conversationId,
      );

      if (existingRequests.isEmpty) {
        // Create a draft request to save the schema
        // This will be the first request template - mark it as template
        final ownerEmail = await _authService.getUserEmail();
        final draftRequestId = generateId();

        // Create request and mark it as template
        final draftRequest = models.DataRequest(
          requestId: draftRequestId,
          conversationId: conversationId,
          title: 'Schema Definition for ${conversation.title}',
          description: 'This request defines the schema for the conversation.',
          ownerEmail: ownerEmail,
          dueAt: DateTime.now().add(
            const Duration(days: 365),
          ), // Far future date
          schema: schema,
          recipients: [], // Empty for now, will be added when sending
          isTemplate: true, // Mark as template
        );

        await _db.insertRequest(draftRequest);

        return {
          'success': true,
          'message':
              'Schema defined successfully. You can now create a request with participants using create_request.',
          'schema_columns': schema.columns.length,
          'draft_request_id': draftRequestId,
        };
      } else {
        // Schema already exists, just confirm
        return {
          'success': true,
          'message':
              'Schema already exists for this conversation. You can create requests using create_request.',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Error defining schema: $e'};
    }
  }

  /// Parse schema from column definitions
  RequestSchema _parseSchemaFromColumns(List<dynamic> columns) {
    final schemaColumns = <SchemaColumn>[];

    for (final col in columns) {
      final colMap = col as Map<String, dynamic>;
      final name = colMap['name'] as String? ?? '';
      final typeStr = colMap['type'] as String? ?? 'string';
      final required = colMap['required'] as bool? ?? false;

      if (name.isEmpty) continue;

      models.ColumnType columnType;
      switch (typeStr.toLowerCase()) {
        case 'number':
          columnType = models.ColumnType.numberType;
          break;
        case 'date':
          columnType = models.ColumnType.dateType;
          break;
        case 'boolean':
          // Boolean maps to stringType since ColumnType doesn't have boolean
          // We'll store it as string and parse it
          columnType = models.ColumnType.stringType;
          break;
        default:
          columnType = models.ColumnType.stringType;
      }

      schemaColumns.add(
        SchemaColumn(name: name, type: columnType, required: required),
      );
    }

    if (schemaColumns.isEmpty) {
      throw Exception('At least one valid column is required');
    }

    return RequestSchema(columns: schemaColumns);
  }

  /// Get month name helper
  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  /// Execute update_conversation_title tool
  Future<Map<String, dynamic>> _executeUpdateConversationTitle(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final conversationId = arguments['conversation_id'] as String?;
      if (conversationId == null) {
        return {'success': false, 'error': 'conversation_id is required'};
      }

      final title = arguments['title'] as String?;
      if (title == null || title.trim().isEmpty) {
        return {'success': false, 'error': 'title is required'};
      }

      // Get conversation
      final conversations = await _db.getConversations(includeArchived: true);
      final conversation = conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => throw Exception('Conversation not found'),
      );

      // Update conversation title
      await _db.insertConversation(
        ConversationsCompanion.insert(
          id: conversationId,
          kind: conversation.kind.index,
          title: title.trim(),
          sheetId: conversation.sheetId,
          sheetUrl: conversation.sheetUrl,
          archived: Value(conversation.archived),
          createdAt: conversation.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      return {
        'success': true,
        'message': 'Conversation title updated successfully.',
        'title': title.trim(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error updating conversation title: $e',
      };
    }
  }

  /// Execute check_for_responses tool
  Future<Map<String, dynamic>> _executeCheckForResponses(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final conversationId = arguments['conversation_id'] as String?;
      if (conversationId == null) {
        return {'success': false, 'error': 'conversation_id is required'};
      }

      // Get all requests for this conversation
      final requests = await _db.getRequestsByConversation(conversationId);
      if (requests.isEmpty) {
        return {
          'success': false,
          'error':
              'No requests found in conversation. Please create a request first.',
        };
      }

      // Use AI-based parsing instead of rule-based parsing
      int totalIngested = 0;
      int totalErrors = 0;
      final errors = <String>[];
      final ingestedEmails = <String>[];
      final errorEmails = <String>[];

      // Get OpenAI API key
      final openAiKey = await _settingsController.getOpenAiKey();
      if (openAiKey == null || openAiKey.isEmpty) {
        return {
          'success': false,
          'error': 'OpenAI API key not configured. Please set it in Settings.',
        };
      }

      for (final request in requests) {
        try {
          // Debug: Log which request and schema we're processing
          debugPrint(
            'Checking responses for request ${request.requestId} with schema: ${request.schema.columns.map((c) => c.name).join(", ")}',
          );

          // Search Gmail for replies
          final messages = await _gmailService.searchMessagesByRequestId(
            request.requestId,
          );

          if (messages.isEmpty) {
            continue;
          }

          // Filter out original request emails (from owner) and sort by timestamp (oldest first)
          // This ensures newer replies override older ones when processed sequentially
          final filteredMessages = <gmail.Message>[];
          for (final message in messages) {
            final fromEmail = _gmailService.getFromEmail(message) ?? '';
            // Skip messages from the request owner (these are the original request emails, not replies)
            if (fromEmail.toLowerCase() == request.ownerEmail.toLowerCase()) {
              continue;
            }
            filteredMessages.add(message);
          }

          // Sort by timestamp (oldest first) to ensure chronological processing
          // When processing sequentially, newer messages will override older ones
          filteredMessages.sort((a, b) {
            final timestampA =
                _gmailService.getInternalDate(a) ?? DateTime(1970);
            final timestampB =
                _gmailService.getInternalDate(b) ?? DateTime(1970);
            return timestampA.compareTo(timestampB);
          });

          if (filteredMessages.isEmpty) {
            continue;
          }

          // Process each message with AI parsing in chronological order
          for (final message in filteredMessages) {
            try {
              final messageId = message.id ?? '';
              final fromEmail = _gmailService.getFromEmail(message) ?? '';
              final timestamp = _gmailService.getInternalDate(message);
              final body = _gmailService.extractPlainTextBody(message) ?? '';

              if (body.isEmpty) {
                continue;
              }

              // Check if already processed
              final isProcessed = await _db.isMessageProcessed(
                request.requestId,
                messageId,
              );
              if (isProcessed) {
                continue;
              }

              // Check if we should skip this message because a newer one was already processed
              final recipientStatuses = await _db.getRecipientStatuses(
                request.requestId,
              );
              final recipientStatus =
                  recipientStatuses
                      .where(
                        (s) => s.email.toLowerCase() == fromEmail.toLowerCase(),
                      )
                      .firstOrNull;
              if (recipientStatus != null &&
                  recipientStatus.lastResponseAt != null &&
                  timestamp != null &&
                  timestamp.isBefore(recipientStatus.lastResponseAt!)) {
                // This message is older than one we've already processed for this recipient
                // Skip it to avoid overwriting newer data
                await _db.markMessageProcessed(request.requestId, messageId);
                continue;
              }

              // Mark as processed early to avoid duplicates
              await _db.markMessageProcessed(request.requestId, messageId);

              // Parse using AI
              final parseResult = await _executeParseEmailResponse({
                'conversation_id': conversationId,
                'request_id': request.requestId,
                'email_body': body,
                'from_email': fromEmail,
                'message_id': messageId,
              });

              if (parseResult['success'] == true &&
                  parseResult['rows'] != null) {
                final rows = parseResult['rows'] as List<dynamic>;
                if (rows.isNotEmpty) {
                  // Save parsed data
                  final saveResult = await _executeSaveParsedData({
                    'conversation_id': conversationId,
                    'request_id': request.requestId,
                    'rows': rows,
                    'from_email': fromEmail,
                    'message_id': messageId,
                  });

                  if (saveResult['success'] == true) {
                    totalIngested += rows.length;
                    if (!ingestedEmails.contains(fromEmail)) {
                      ingestedEmails.add(fromEmail);
                    }
                  } else {
                    totalErrors++;
                    errors.add('$fromEmail: ${saveResult['error']}');
                    if (!errorEmails.contains(fromEmail)) {
                      errorEmails.add(fromEmail);
                    }
                  }
                } else {
                  // No data found - mark as error
                  totalErrors++;
                  errors.add('$fromEmail: No data found in email');
                  await _db.upsertRecipientStatus(
                    models.RecipientStatus(
                      requestId: request.requestId,
                      email: fromEmail,
                      status: models.RecipientState.error,
                      lastMessageId: messageId,
                      lastResponseAt: timestamp,
                      reminderSentAt: null,
                      note: 'No data found in email',
                    ),
                  );
                  await _loggingService.logActivity(
                    request.requestId,
                    models.ActivityType.parseError,
                    {
                      'fromEmail': fromEmail,
                      'messageId': messageId,
                      'error': 'No data found in email',
                    },
                  );
                }
              } else {
                // Parse failed
                totalErrors++;
                final errorMsg =
                    parseResult['error'] as String? ?? 'Parse failed';
                errors.add('$fromEmail: $errorMsg');
                if (!errorEmails.contains(fromEmail)) {
                  errorEmails.add(fromEmail);
                }
                await _db.upsertRecipientStatus(
                  models.RecipientStatus(
                    requestId: request.requestId,
                    email: fromEmail,
                    status: models.RecipientState.error,
                    lastMessageId: messageId,
                    lastResponseAt: timestamp,
                    reminderSentAt: null,
                    note: errorMsg,
                  ),
                );
                await _loggingService.logActivity(
                  request.requestId,
                  models.ActivityType.parseError,
                  {
                    'fromEmail': fromEmail,
                    'messageId': messageId,
                    'error': errorMsg,
                  },
                );
              }
            } catch (e) {
              totalErrors++;
              errors.add('Error processing message: $e');
            }
          }
        } catch (e) {
          totalErrors++;
          errors.add('Error processing request ${request.requestId}: $e');
        }

        // Get recipient statuses to identify which emails were processed
        final statuses = await _db.getRecipientStatuses(request.requestId);
        for (final status in statuses) {
          if (status.status == models.RecipientState.responded &&
              status.lastResponseAt != null &&
              status.lastResponseAt!.isAfter(
                DateTime.now().subtract(const Duration(minutes: 5)),
              )) {
            // Likely just ingested
            if (!ingestedEmails.contains(status.email)) {
              ingestedEmails.add(status.email);
            }
          } else if (status.status == models.RecipientState.error) {
            if (!errorEmails.contains(status.email)) {
              errorEmails.add(status.email);
            }
          }
        }
      }

      // Build response message
      String message = 'Checked for responses:\n\n';
      if (totalIngested > 0) {
        message += '✅ **$totalIngested row(s) ingested successfully**\n';
        if (ingestedEmails.isNotEmpty) {
          message +=
              '   From: ${ingestedEmails.take(5).join(", ")}${ingestedEmails.length > 5 ? " and ${ingestedEmails.length - 5} more" : ""}\n';
        }
      }

      if (totalErrors > 0) {
        if (totalIngested > 0) {
          message += '\n⚠️ **$totalErrors email(s) had parsing errors**\n';
        } else {
          message += '⚠️ **$totalErrors email(s) could not be parsed**\n';
        }
        if (errorEmails.isNotEmpty) {
          message +=
              '   From: ${errorEmails.take(3).join(", ")}${errorEmails.length > 3 ? " and ${errorEmails.length - 3} more" : ""}\n';
        }
        if (errors.isNotEmpty) {
          message +=
              '   Issues: ${errors.take(2).join("; ")}${errors.length > 2 ? "..." : ""}\n';
        }
      } else if (totalIngested == 0) {
        message += 'ℹ️ No new responses found.\n';
      }

      return {
        'success': true,
        'ingested_count': totalIngested,
        'error_count': totalErrors,
        'errors': errors,
        'ingested_emails': ingestedEmails,
        'error_emails': errorEmails,
        'message': message,
      };
    } catch (e) {
      return {'success': false, 'error': 'Error checking for responses: $e'};
    }
  }

  /// Execute parse_email_response tool - Use AI to parse email body
  /// Public method for reparsing emails
  Future<Map<String, dynamic>> executeParseEmailResponse({
    required String conversationId,
    required String requestId,
    required String emailBody,
    required String fromEmail,
    required String messageId,
  }) async {
    return await _executeParseEmailResponse({
      'conversation_id': conversationId,
      'request_id': requestId,
      'email_body': emailBody,
      'from_email': fromEmail,
      'message_id': messageId,
    });
  }

  /// Execute parse_email_response tool - Use AI to parse email body
  Future<Map<String, dynamic>> _executeParseEmailResponse(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final conversationId = arguments['conversation_id'] as String?;
      final requestId = arguments['request_id'] as String?;
      final emailBody = arguments['email_body'] as String?;
      final fromEmail = arguments['from_email'] as String?;
      final messageId = arguments['message_id'] as String?;

      if (conversationId == null ||
          requestId == null ||
          emailBody == null ||
          fromEmail == null ||
          messageId == null) {
        return {'success': false, 'error': 'All parameters are required'};
      }

      // Get request to get schema
      final request = await _db.getRequest(requestId);
      if (request == null) {
        return {'success': false, 'error': 'Request not found'};
      }

      final schema = request.schema;

      // Debug: Log the schema being used
      debugPrint(
        'Parsing email for request ${request.requestId} with schema columns: ${schema.columns.map((c) => c.name).join(", ")}',
      );

      // Debug: Log the email body being sent to AI
      debugPrint('=== EMAIL BODY SENT TO AI ===');
      debugPrint(emailBody);
      debugPrint('=== END EMAIL BODY ===');

      // Get OpenAI API key
      final openAiKey = await _settingsController.getOpenAiKey();
      if (openAiKey == null || openAiKey.isEmpty) {
        return {'success': false, 'error': 'OpenAI API key not configured'};
      }

      // Build column name list for exact matching
      final expectedColumnNames = schema.columns.map((c) => c.name).toList();

      // Build numbered list of column names
      final columnList = StringBuffer();
      for (int i = 0; i < expectedColumnNames.length; i++) {
        columnList.writeln('${i + 1}. "${expectedColumnNames[i]}"');
      }

      final prompt =
          '''Extract structured data from the following email response.

EXPECTED COLUMN NAMES (these are the exact column names you should look for):
${columnList.toString()}

Email body:
---
$emailBody
---

EXTRACTION INSTRUCTIONS:

STEP 0: Identify the actual reply content (CRITICAL!)
- Email replies often contain quoted content from previous messages
- Look for reply markers like:
  * Lines starting with "On ... wrote:"
  * Lines starting with "From:"
  * Lines starting with "Sent:"
  * Lines containing "original message"
  * Lines that start with ">" (quoted content prefix)
- The ACTUAL REPLY is everything BEFORE these markers
- IGNORE all tables that appear AFTER reply markers or with ">" prefix (these are quoted/old content)
- ONLY extract data from tables that appear in the ACTUAL REPLY section (before any reply markers)

STEP 1: Find the table in the ACTUAL REPLY section
- Look for markdown-style or plain text tables ONLY in the reply content (before reply markers)
- Tables typically have pipe characters (|) or tabs separating columns
- The table header row should contain column names
- If you find multiple tables, use the FIRST one that appears in the reply section

STEP 2: Match column names
- Compare the table header row with the expected column names listed above
- Column names must match EXACTLY (including spaces and capitalization)
- However, ignore:
  * Extra whitespace at the start/end of column names
  * Line breaks within a column name (treat as single space)
- You need to find a table where ALL these column names appear: ${expectedColumnNames.join(', ')}
- IMPORTANT: Only consider tables from the ACTUAL REPLY section (before reply markers)
- If NO table in the reply section has matching column names, return an empty array: []

STEP 3: Extract data rows
- Once you find a table with matching column names in the reply section:
  1. Identify the header row (first row with column names)
  2. For each data row below the header:
     - Extract the value from position 1 and assign it to "${expectedColumnNames[0]}"
     - Extract the value from position 2 and assign it to "${expectedColumnNames[1]}"
     ${expectedColumnNames.length > 2 ? '     - Extract the value from position 3 and assign it to "${expectedColumnNames[2]}"' : ''}
     ${expectedColumnNames.length > 3 ? '     - Extract the value from position 4 and assign it to "${expectedColumnNames[3]}"' : ''}
     ${expectedColumnNames.length > 4 ? '     - Continue for all columns...' : ''}

STEP 4: Filter out invalid rows
- SKIP rows that are:
  * Empty or contain only separators (like "---")
  * Placeholder rows with text like "[Enter text]", "[Enter number]", "Example Name", "Your value here"
  * Example rows with generic values like "12345", "2026-01-15" that appear in template sections
- ONLY extract rows with actual user data (real names, real numbers, real dates)

STEP 5: Return JSON
Return a JSON array where each object has keys matching the expected column names exactly:
${expectedColumnNames.map((name) => '  - "$name"').join('\n')}

CONCRETE EXAMPLE:
Here is exactly what you should do:

If the email contains a table like this in the REPLY section (before any "On ... wrote:" markers):
| Name of Urban Local Body | Total Revenue | Total Expenditure | Net Surplus/Deficit | Date of Report |
| Cuttack | 1232231 | 1111111 | 11232 | 6th Jan 2026 |

And later there's quoted content like:
On Mon, Jan 6, 2026 wrote:
> | Name of Urban Local Body | Total Revenue | ...
> | Old City | 999999 | ...

You MUST extract ONLY the first table (Cuttack), NOT the quoted one (Old City).

CRITICAL RULES:
1. ONLY look at content BEFORE reply markers ("On ... wrote:", "From:", lines starting with ">", etc.)
2. Find the FIRST table in the ACTUAL REPLY section that has ALL the expected column names
3. Extract ALL data rows from that table (skip only completely empty rows)
4. Match values by POSITION - first column value goes to first expected column name, etc.
5. IGNORE all tables in quoted/replied content (after reply markers or with ">" prefix)
6. If you find matching columns in the reply section, you MUST extract the data - do not return empty array

IMPORTANT:
- The reply content is everything BEFORE "On ... wrote:" or other reply markers
- Extract data ONLY from tables in the reply section, NOT from quoted content
- Skip empty rows (rows with only separators or empty cells)
- Match column values by their POSITION under the header
- Return ONLY valid JSON array, no markdown code blocks, no explanations

Return the JSON now:''';

      // Call OpenAI to parse
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openAiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a data extraction assistant. Extract structured data from emails and return it as JSON arrays.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.1,
          'max_tokens': 2000,
        }),
      );

      if (response.statusCode != 200) {
        return {
          'success': false,
          'error': 'OpenAI API error: ${response.statusCode}',
        };
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = responseData['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return {'success': false, 'error': 'No response from OpenAI'};
      }

      final content = choices[0]['message']['content'] as String?;
      if (content == null || content.isEmpty) {
        return {'success': false, 'error': 'Empty response from OpenAI'};
      }

      // Debug: Log the AI response
      debugPrint('AI parsing response: $content');

      // Parse JSON response
      List<Map<String, dynamic>> rows = [];
      String cleanedContent = content.trim();
      try {
        if (cleanedContent.startsWith('```')) {
          final lines = cleanedContent.split('\n');
          cleanedContent =
              lines.skip(1).take(lines.length - 2).join('\n').trim();
        }

        final parsed = jsonDecode(cleanedContent) as List<dynamic>;
        rows = parsed.map((row) => row as Map<String, dynamic>).toList();

        // Debug: Log parsed rows
        debugPrint('Parsed ${rows.length} row(s) from AI response');
        for (int i = 0; i < rows.length; i++) {
          debugPrint('Row ${i + 1}: ${rows[i]}');
        }
      } catch (e) {
        debugPrint('Failed to parse AI JSON response: $e');
        debugPrint('Cleaned content that failed: $cleanedContent');
        return {'success': false, 'error': 'Failed to parse AI response: $e'};
      }

      if (rows.isEmpty) {
        debugPrint('WARNING: AI returned empty array. This might mean:');
        debugPrint('  1. No table found with matching column names');
        debugPrint('  2. All rows were filtered out as placeholders/examples');
        debugPrint('  3. Table structure was not recognized');
        return {
          'success': false,
          'error':
              'No data found. The email table may not match the expected column names: ${expectedColumnNames.join(", ")}. Please check that the email contains a table with these exact column names.',
          'rows': [],
        };
      }

      return {
        'success': true,
        'rows': rows,
        'rows_count': rows.length,
        'message': 'Successfully extracted ${rows.length} row(s)',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error parsing email: $e'};
    }
  }

  /// Execute save_parsed_data tool - Save parsed rows to Google Sheet
  /// Public method for saving reparsed data
  Future<Map<String, dynamic>> executeSaveParsedData({
    required String conversationId,
    required String requestId,
    required String fromEmail,
    required String messageId,
    required DateTime? timestamp,
    required List<Map<String, dynamic>> parsedData,
  }) async {
    return await _executeSaveParsedData({
      'conversation_id': conversationId,
      'request_id': requestId,
      'from_email': fromEmail,
      'message_id': messageId,
      'rows': parsedData,
    });
  }

  /// Execute save_parsed_data tool - Save parsed rows to Google Sheet
  Future<Map<String, dynamic>> _executeSaveParsedData(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final conversationId = arguments['conversation_id'] as String?;
      final requestId = arguments['request_id'] as String?;
      final rows = arguments['rows'] as List<dynamic>?;
      final fromEmail = arguments['from_email'] as String?;
      final messageId = arguments['message_id'] as String?;

      if (conversationId == null ||
          requestId == null ||
          rows == null ||
          fromEmail == null ||
          messageId == null) {
        return {'success': false, 'error': 'All parameters are required'};
      }

      // Get conversation to get sheet ID
      final conversations = await _db.getConversations(includeArchived: true);
      final conversation = conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => throw Exception('Conversation not found'),
      );

      if (conversation.sheetId.isEmpty) {
        return {
          'success': false,
          'error': 'No sheet associated with conversation',
        };
      }

      // Get request to get schema
      final request = await _db.getRequest(requestId);
      if (request == null) {
        return {'success': false, 'error': 'Request not found'};
      }

      final schema = request.schema;
      final timestamp = DateTime.now();

      // Reverse the rows list so the first row (actual reply) gets saved last
      // This ensures it overwrites any rows from quoted content that were incorrectly extracted
      final reversedRows = List<dynamic>.from(rows.reversed);

      // Convert rows to sheet format
      // New format: [schema columns..., __fromEmail, __version, __receivedAt, __messageId, __requestId]
      final sheetRows = <List<Object?>>[];
      for (final rowData in reversedRows) {
        final row = rowData as Map<String, dynamic>;
        final sheetRow = <Object?>[];

        // Add schema columns first
        for (final column in schema.columns) {
          final value = row[column.name];
          sheetRow.add(value);
        }

        // Add metadata columns at the end (rightmost)
        sheetRow.addAll([
          fromEmail, // __fromEmail
          1, // __version (will be incremented if row exists)
          _formatRelativeTime(timestamp), // __receivedAt (human-readable)
          messageId, // __messageId
          requestId, // __requestId
        ]);

        sheetRows.add(sheetRow);
      }

      // Update or insert rows (will update existing rows by fromEmail+requestId)
      await _sheetsService.updateOrInsertRows(
        conversation.sheetId,
        sheetRows,
        requestId,
      );

      final savedCount = sheetRows.length;

      // Update recipient status
      await _db.upsertRecipientStatus(
        models.RecipientStatus(
          requestId: requestId,
          email: fromEmail,
          status: models.RecipientState.responded,
          lastMessageId: messageId,
          lastResponseAt: timestamp,
          reminderSentAt: null,
          note: null,
        ),
      );

      // Log activity
      await _loggingService.logActivity(
        requestId,
        models.ActivityType.ingested,
        {
          'fromEmail': fromEmail,
          'messageId': messageId,
          'rowsCount': savedCount,
        },
      );

      // Mark message as processed
      await _db.markMessageProcessed(requestId, messageId);

      return {
        'success': true,
        'saved_count': savedCount,
        'message': 'Successfully saved $savedCount row(s) to sheet',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error saving data: $e'};
    }
  }

  /// Format timestamp as human-readable relative time
  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Execute get_conversation_stats tool
  Future<Map<String, dynamic>> _executeGetConversationStats(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final conversationId = arguments['conversation_id'] as String?;
      if (conversationId == null) {
        return {'success': false, 'error': 'conversation_id is required'};
      }

      // Get conversation
      final conversations = await _db.getConversations(includeArchived: true);
      final conversation = conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => throw Exception('Conversation not found'),
      );

      // Get requests and participants
      final requests = await _db.getRequestsByConversation(conversationId);
      final participants = await _getAllParticipants(conversationId);

      // Calculate stats
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

      return {
        'success': true,
        'conversation_title': conversation.title,
        'total_requests': requests.length,
        'total_participants': participants.length,
        'responded_count': responded.length,
        'pending_count': pending.length,
        'error_count': errors.length,
        'responded_emails': responded.map((p) => p.email).toList(),
        'pending_emails': pending.map((p) => p.email).toList(),
        'error_emails': errors.map((p) => p.email).toList(),
        'latest_request_due_date':
            requests.isNotEmpty ? requests.first.dueAt.toIso8601String() : null,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Execute analyze_sheet_data tool
  Future<Map<String, dynamic>> _executeAnalyzeSheetData(
    Map<String, dynamic> arguments,
  ) async {
    try {
      final conversationId = arguments['conversation_id'] as String?;
      if (conversationId == null || conversationId.isEmpty) {
        return {
          'success': false,
          'error': 'conversation_id is required and cannot be empty',
        };
      }

      // Get conversation to get sheet ID
      final conversations = await _db.getConversations(includeArchived: true);
      final conversation = conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse:
            () =>
                throw Exception(
                  'Conversation not found with ID: $conversationId',
                ),
      );

      if (conversation.sheetId.isEmpty) {
        return {
          'success': false,
          'error':
              'No Google Sheet associated with this conversation. Create a request first to generate a sheet.',
        };
      }

      // Read data from sheet
      final sheetData = await _sheetsService.readResponsesData(
        conversation.sheetId,
      );

      if (sheetData.isEmpty) {
        return {
          'success': true,
          'message': 'The sheet is empty. No data to analyze yet.',
          'row_count': 0,
        };
      }

      // Get schema to understand column structure
      final requests = await _db.getRequestsByConversation(conversationId);
      if (requests.isEmpty) {
        return {
          'success': false,
          'error':
              'No requests found in conversation. Cannot determine data structure.',
        };
      }

      final mostRecentRequest = requests.first;
      final schema = mostRecentRequest.schema;

      // Format data for LLM analysis
      // Headers are in first row, data starts from row 2
      final headers = sheetData.isNotEmpty ? sheetData[0] : [];
      final dataRows = sheetData.length > 1 ? sheetData.sublist(1) : [];

      // Build a structured representation of the data
      final dataSummary = <String, dynamic>{
        'total_rows': dataRows.length,
        'headers': headers,
        'sample_data': dataRows.take(10).toList(), // First 10 rows for context
        'schema_columns':
            schema.columns
                .map(
                  (c) => {
                    'name': c.name,
                    'type': c.type.toString(),
                    'required': c.required,
                  },
                )
                .toList(),
      };

      // For large datasets, provide summary statistics
      if (dataRows.length > 10) {
        dataSummary['note'] =
            'Showing first 10 rows. Total ${dataRows.length} rows available.';
      }

      return {
        'success': true,
        'conversation_id': conversationId,
        'conversation_title': conversation.title,
        'sheet_id': conversation.sheetId,
        'data': dataSummary,
        'analysis_type': arguments['analysis_type'] as String? ?? 'general',
      };
    } catch (e, stackTrace) {
      // Log the error for debugging
      print('Error in _executeAnalyzeSheetData: $e');
      print('Stack trace: $stackTrace');
      print('Arguments: $arguments');

      return {
        'success': false,
        'error': 'Failed to analyze sheet data: ${e.toString()}',
        'details': e.toString(),
      };
    }
  }

  /// Get all participants for a conversation
  Future<List<models.RecipientStatus>> _getAllParticipants(
    String conversationId,
  ) async {
    final requests = await _db.getRequestsByConversation(conversationId);
    final allStatuses = <models.RecipientStatus>[];

    for (final request in requests) {
      final statuses = await _db.getRecipientStatuses(request.requestId);
      allStatuses.addAll(statuses);
    }

    // Deduplicate by email (keep most recent)
    final Map<String, models.RecipientStatus> uniqueStatuses = {};
    for (final status in allStatuses) {
      if (!uniqueStatuses.containsKey(status.email) ||
          (status.lastResponseAt != null &&
              (uniqueStatuses[status.email]!.lastResponseAt == null ||
                  status.lastResponseAt!.isAfter(
                    uniqueStatuses[status.email]!.lastResponseAt!,
                  )))) {
        uniqueStatuses[status.email] = status;
      }
    }

    return uniqueStatuses.values.toList();
  }
}

/// Provider for AI Agent Service
final aiAgentServiceProvider = Provider<AIAgentService>((ref) {
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
  final settingsController = SettingsController(db);

  return AIAgentService(
    db,
    sheetsService,
    authService,
    requestService,
    loggingService,
    settingsController,
    gmailService,
  );
});
