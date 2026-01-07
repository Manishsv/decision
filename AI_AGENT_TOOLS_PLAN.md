# AI Agent Tools Integration Plan

## Overview

We'll use **OpenAI Function Calling** (also called "Tools") to enable the AI Agent to execute actions like sending reminders, creating requests, and adding participants. This allows the LLM to intelligently decide when to call these functions based on natural language queries.

## Current Approach vs. Tools Approach

### Current Approach (Manual Intent Detection)
```
User Query → Manual Intent Detection → Execute Action → Return Response
```
**Limitations:**
- Requires hardcoded keyword matching
- Doesn't handle variations in phrasing well
- Limited to predefined patterns
- Can't extract complex parameters

### Tools Approach (OpenAI Function Calling)
```
User Query → LLM Decides to Call Tool → Extract Parameters → Execute Action → LLM Formats Response
```
**Benefits:**
- Natural language understanding
- Handles variations and synonyms
- Automatically extracts parameters
- Can chain multiple tools
- Better error handling and clarification

## How OpenAI Function Calling Works

### 1. Tool Definition
We define each capability as a "function" with:
- **Name**: e.g., `send_reminders`
- **Description**: What it does (helps LLM decide when to use it)
- **Parameters**: JSON schema defining inputs

### 2. LLM Decision
When user sends a query:
- LLM analyzes the query
- Decides if it should call a tool
- Extracts parameters from the query
- Returns a function call request

### 3. Execution
- We receive the function call request
- Execute the actual action (e.g., send emails)
- Return results to LLM

### 4. Response
- LLM receives execution results
- Formats a natural language response
- Returns to user

## Tools We'll Implement

### 1. `send_reminders`
**Purpose**: Send reminder emails to pending participants

**Parameters**:
```json
{
  "conversation_id": "string (required)",
  "participant_emails": "array of strings (optional, if empty sends to all pending)"
}
```

**Example Queries**:
- "Send reminders to all pending participants"
- "Remind john@example.com and jane@example.com"
- "Send a reminder to those who haven't responded"

### 2. `create_request`
**Purpose**: Create a new data request in the conversation

**Parameters**:
```json
{
  "conversation_id": "string (required)",
  "title": "string (optional, uses conversation title if not provided)",
  "due_date": "string ISO date (optional, defaults to 7 days from now)",
  "participant_emails": "array of strings (required)",
  "instructions": "string (optional)"
}
```

**Example Queries**:
- "Create a new request for all participants due next week"
- "Send a request to john@example.com and jane@example.com"
- "Create a monthly update request due on the 15th"

### 3. `add_participants`
**Purpose**: Add new participants to the conversation

**Parameters**:
```json
{
  "conversation_id": "string (required)",
  "participant_emails": "array of strings (required)"
}
```

**Example Queries**:
- "Add john@example.com to this conversation"
- "Add these participants: john@example.com, jane@example.com"
- "Include the finance team in this conversation"

### 4. `get_conversation_stats`
**Purpose**: Get detailed statistics about the conversation (already partially implemented)

**Parameters**:
```json
{
  "conversation_id": "string (required)"
}
```

**Returns**: Detailed stats (responded count, pending count, error count, etc.)

### 5. `analyze_sheet_data` (Future)
**Purpose**: Read and analyze data from the Google Sheet

**Parameters**:
```json
{
  "conversation_id": "string (required)",
  "analysis_type": "string (optional: 'summary', 'trends', 'insights')"
}
```

## Implementation Architecture

### Flow Diagram

```
┌─────────────┐
│ User Query  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────┐
│  AIAgentService         │
│  processQuery()         │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│  Build System Prompt    │
│  + Conversation Context │
│  + Available Tools      │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│  Call OpenAI API         │
│  with tools parameter    │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│  Check Response Type     │
│  - Function Call?        │
│  - Text Response?        │
└──────┬──────────────────┘
       │
       ├─── Function Call ────┐
       │                       │
       ▼                       ▼
┌─────────────────┐   ┌──────────────────┐
│ Execute Tool    │   │ Return Text      │
│ - Validate      │   │ Response         │
│ - Call Service  │   └──────────────────┘
│ - Get Results   │
└──────┬──────────┘
       │
       ▼
┌─────────────────────────┐
│  Call OpenAI Again       │
│  with Function Results   │
│  (for natural response)  │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│  Return to User          │
└─────────────────────────┘
```

### Code Structure

```dart
class AIAgentService {
  // Define available tools
  List<Map<String, dynamic>> _getAvailableTools() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'send_reminders',
          'description': 'Send reminder emails to participants who have not responded',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {'type': 'string', 'description': '...'},
              'participant_emails': {'type': 'array', 'items': {'type': 'string'}},
            },
            'required': ['conversation_id'],
          },
        },
      },
      // ... other tools
    ];
  }

  Future<AIAgentResponse> processQuery(...) async {
    // 1. Build messages with tools
    final messages = [...];
    final tools = _getAvailableTools();
    
    // 2. Call OpenAI with tools
    final response = await _callOpenAI(messages, tools);
    
    // 3. Check if LLM wants to call a function
    if (response['choices'][0]['message']['tool_calls'] != null) {
      // 4. Execute function calls
      final functionResults = await _executeFunctionCalls(
        response['choices'][0]['message']['tool_calls'],
      );
      
      // 5. Call OpenAI again with function results
      return await _callOpenAIWithResults(messages, functionResults);
    }
    
    // 6. Return text response
    return AIAgentResponse(message: response['choices'][0]['message']['content']);
  }

  Future<List<Map<String, dynamic>>> _executeFunctionCalls(
    List<dynamic> toolCalls,
  ) async {
    final results = [];
    
    for (final call in toolCalls) {
      final functionName = call['function']['name'];
      final arguments = jsonDecode(call['function']['arguments']);
      
      switch (functionName) {
        case 'send_reminders':
          results.add(await _executeSendReminders(arguments));
          break;
        case 'create_request':
          results.add(await _executeCreateRequest(arguments));
          break;
        // ... other cases
      }
    }
    
    return results;
  }
}
```

## Tool Implementation Details

### 1. send_reminders

**Service Integration**:
```dart
Future<Map<String, dynamic>> _executeSendReminders(
  Map<String, dynamic> arguments,
) async {
  final conversationId = arguments['conversation_id'] as String;
  final participantEmails = arguments['participant_emails'] as List<dynamic>?;
  
  // Get pending participants
  final participants = await _getAllParticipants(conversationId);
  final pending = participants.where((p) => 
    p.status == models.RecipientState.pending &&
    (participantEmails == null || participantEmails.contains(p.email))
  ).toList();
  
  // TODO: Call ReminderService.sendReminders()
  // For now, return placeholder
  return {
    'success': true,
    'sent_count': pending.length,
    'recipients': pending.map((p) => p.email).toList(),
  };
}
```

### 2. create_request

**Service Integration**:
```dart
Future<Map<String, dynamic>> _executeCreateRequest(
  Map<String, dynamic> arguments,
) async {
  final conversationId = arguments['conversation_id'] as String;
  final participantEmails = (arguments['participant_emails'] as List<dynamic>)
      .map((e) => e.toString())
      .toList();
  
  // Get conversation to reuse schema
  final requests = await _db.getRequestsByConversation(conversationId);
  if (requests.isEmpty) {
    return {
      'success': false,
      'error': 'No previous requests found. Cannot reuse schema.',
    };
  }
  
  final mostRecentRequest = requests.first;
  
  // Create new request
  final requestId = await _requestService.createDraftRequest(
    conversationId: conversationId,
    title: arguments['title'] ?? mostRecentRequest.title,
    schema: mostRecentRequest.schema,
    recipients: participantEmails,
    dueDate: arguments['due_date'] != null
        ? DateTime.parse(arguments['due_date'])
        : DateTime.now().add(const Duration(days: 7)),
    instructions: arguments['instructions'],
  );
  
  // Send request
  await _requestService.sendRequest(requestId);
  
  return {
    'success': true,
    'request_id': requestId,
    'recipients_count': participantEmails.length,
  };
}
```

### 3. add_participants

**Service Integration**:
```dart
Future<Map<String, dynamic>> _executeAddParticipants(
  Map<String, dynamic> arguments,
) async {
  final conversationId = arguments['conversation_id'] as String;
  final participantEmails = (arguments['participant_emails'] as List<dynamic>)
      .map((e) => e.toString())
      .toList();
  
  // Get most recent request to add participants to
  final requests = await _db.getRequestsByConversation(conversationId);
  if (requests.isEmpty) {
    return {
      'success': false,
      'error': 'No requests found. Create a request first.',
    };
  }
  
  // For now, participants are added when creating a new request
  // This tool will prepare for future "add to existing request" feature
  return {
    'success': true,
    'message': 'Participants will be added when you create the next request',
    'participants': participantEmails,
  };
}
```

## Error Handling

### Validation
- Validate `conversation_id` exists
- Validate email formats
- Validate dates are in the future
- Check permissions (user owns conversation)

### Error Responses
```dart
{
  'success': false,
  'error': 'Conversation not found',
  'error_code': 'CONVERSATION_NOT_FOUND',
}
```

### LLM Error Handling
- LLM receives error in function result
- LLM can explain error to user naturally
- LLM can suggest corrections

## Security Considerations

1. **Conversation Ownership**: Verify user owns the conversation before executing actions
2. **Parameter Validation**: Strict validation of all inputs
3. **Rate Limiting**: Prevent abuse of API calls
4. **Audit Logging**: Log all tool executions for debugging

## Testing Strategy

### Unit Tests
- Tool parameter extraction
- Function execution logic
- Error handling

### Integration Tests
- End-to-end tool calls
- LLM response formatting
- Service integration

### Manual Testing
- Natural language variations
- Edge cases (missing parameters, invalid data)
- Error scenarios

## Migration Path

1. **Phase 1**: Implement tool definitions and basic execution
2. **Phase 2**: Add all tools (send_reminders, create_request, add_participants)
3. **Phase 3**: Add advanced tools (analyze_sheet_data)
4. **Phase 4**: Remove manual intent detection (keep as fallback)

## Benefits Summary

✅ **Natural Language**: Users can phrase requests naturally  
✅ **Parameter Extraction**: LLM extracts emails, dates, etc. automatically  
✅ **Error Handling**: LLM can explain errors and suggest fixes  
✅ **Extensibility**: Easy to add new tools  
✅ **Consistency**: Same pattern for all actions  
✅ **User Experience**: More conversational and intuitive  

## Next Steps

1. Implement tool definitions in `AIAgentService`
2. Update `_callOpenAI` to include `tools` parameter
3. Implement `_executeFunctionCalls` method
4. Implement individual tool execution methods
5. Update response handling to support function calls
6. Test with various natural language queries
7. Add error handling and validation
