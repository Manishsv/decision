# Conversation Model - Architecture Update

## Current Model (Incorrect)
- Each request creates a new conversation
- Conversation is 1:1 with a request
- Sheet is tied to a request
- Recurring requests create new conversations

## Desired Model (Correct)
- **Conversation is created FIRST** with a name (e.g., "Finance Review")
- **Multiple requests** can be sent within the same conversation
- **Same sheet** is shared across all requests in a conversation
- **Recurring requests** = new requests within the same conversation
- User can:
  - Add more participants to existing conversation
  - Send reminders to pending participants
  - Send the same request again after weeks (creates new request in same conversation)
  - Interact with AI Agent to get insights and execute actions

## Data Model Changes Needed

### 1. Conversation Table
- Keep: `id`, `title`, `kind`, `archived`, `createdAt`, `updatedAt`
- **Remove**: `requestId` (conversation is independent)
- **Remove**: `status` (status is per-request, not per-conversation)
- **Add**: `sheetId` (sheet belongs to conversation)
- **Add**: `sheetUrl` (sheet belongs to conversation)

### 2. Requests Table
- Keep: All existing fields
- **Add**: `conversationId` (references conversation)
- **Remove**: `sheetId` (moved to conversation)
- **Remove**: `sheetUrl` (moved to conversation)
- Keep: `templateRequestId`, `iterationNumber`, `isTemplate` (for tracking iterations)

### 3. Conversation-Request Relationship
- **One-to-Many**: One conversation → Many requests
- Conversation has a primary/default request (the first one or most recent)
- All requests in a conversation share the same sheet

## Workflow Changes

### Creating a New Conversation
1. User clicks "New Conversation" (not "New Request")
2. User enters conversation name (e.g., "Finance Review")
3. User defines schema, recipients, due date
4. System creates:
   - Conversation (with name)
   - First request (linked to conversation)
   - Sheet (linked to conversation)
5. User can send the request

### Sending Request Again (Recurring)
1. User opens existing conversation
2. User clicks "Send Again"
3. System creates:
   - New request (linked to same conversation)
   - Reuses same sheet
   - Updates due date
   - Sends to same recipients (or user can modify)
4. New request appears in conversation history

### Adding More Participants
1. User opens existing conversation
2. User can:
   - Click "Add Participants" button in inspector panel, OR
   - Ask AI Agent: "Add john@example.com to this conversation"
3. System:
   - Adds participants to conversation
   - Can create new request with additional participants OR
   - Add to existing request
   - Sends emails to new participants
   - All responses go to same sheet

### AI Agent Interactions
1. User types question/instruction in center pane
2. AI Agent:
   - Understands context (current conversation, participants, requests)
   - Can query database for stats
   - Can read Google Sheets for data analysis
   - Can execute actions (send reminders, create requests)
   - Provides natural language responses
3. Examples:
   - "How many participants have responded?" → AI queries and responds
   - "Send reminders" → AI executes reminder service
   - "What does last week data tell us?" → AI reads sheet, analyzes, responds

## UI Changes Needed

### Home Page Layout (3-Pane)
- **Left Pane**: Conversations list
  - Shows all conversations (not requests)
  - Each conversation shows:
    - Name (e.g., "Finance Review")
    - Number of requests sent
    - Total participants
    - Response stats (aggregated across all requests)
    - Last activity date
  - "New Conversation" button

- **Center Pane**: AI Agent Chat Interface
  - Chat interface for interacting with AI Agent
  - User can ask questions or give instructions:
    - "How many people have responded to the last request?"
    - "Send reminders to those who haven't responded"
    - "Send request to all participants for monthly update"
    - "What does last week data tell us?"
  - AI Agent can:
    - Answer questions about conversation state
    - Execute actions (send reminders, create requests)
    - Analyze data from Google Sheets
    - Provide insights and recommendations

- **Right Pane**: Inspector Panel (Overview, Participants, Activities)
  - **Overview Tab**: Conversation summary, stats, key metrics
  - **Participants Tab**: List of all participants with their status
    - Shows response status per participant
    - Can filter by status (responded/pending/error)
    - Can add new participants
  - **Activities Tab**: Timeline of all activities
    - Request sent events
    - Response received events
    - Reminder sent events
    - Data ingestion events

### Terminology Changes
- **"Recipients" → "Participants"** (throughout the app)
  - Better reflects the conversation model
  - Participants are part of an ongoing conversation
  - Not just one-time recipients

## Migration Strategy

1. **Database Migration**:
   - Add `conversationId` to Requests table
   - Add `sheetId`, `sheetUrl` to Conversations table
   - Remove `requestId`, `status` from Conversations table
   - Migrate existing data:
     - Each existing conversation becomes a conversation
     - Each existing request gets the conversation's ID
     - Move sheetId/sheetUrl from request to conversation

2. **Service Layer Updates**:
   - `createConversation()` - creates conversation first
   - `createRequest()` - takes conversationId
   - `sendRequest()` - creates request in conversation
   - Update all queries to use conversationId

3. **UI Updates**:
   - Change "New Request" to "New Conversation"
   - Update request builder to work with conversations
   - Update conversation page to show multiple requests

## Benefits

1. **Better Mental Model**: Matches user's understanding
2. **Sheet Reuse**: Natural - same conversation = same sheet
3. **Better Tracking**: All related requests grouped together
4. **Easier Recurring**: Just create new request in same conversation
5. **Flexible Recipients**: Can add recipients over time

## AI Agent Requirements

### Capabilities Needed
1. **Question Answering**:
   - Query conversation state (participants, requests, responses)
   - Calculate statistics (response rates, pending counts)
   - Analyze data from Google Sheets

2. **Action Execution**:
   - Send reminders to pending participants
   - Create new requests in conversation
   - Add participants to conversation
   - Update due dates

3. **Data Analysis**:
   - Read and analyze Google Sheets data
   - Provide insights and trends
   - Answer questions about collected data

### Implementation Approach
- Use OpenAI API (already configured in settings)
- Create `AIAgentService` that:
  - Takes user query and conversation context
  - Determines intent (question vs action)
  - Executes appropriate service calls
  - Returns natural language response
- Chat UI in center pane for interaction

## Implementation Priority

This is a **major architectural change** that includes:
1. Conversation-first data model
2. AI Agent chat interface
3. Terminology updates (Recipients → Participants)
4. UI layout changes (3-pane with AI chat)

**Recommended Approach**:
1. Update data model and migration (conversation-first)
2. Update terminology throughout codebase
3. Implement AI Agent service
4. Update UI layout (center = AI chat, right = inspector)
5. Update service layer
6. Test thoroughly
