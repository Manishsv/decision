# DIGIT Decision - Architecture Documentation

## Overview

DIGIT Decision is a Flutter-based desktop application for collecting structured data via email and Google Sheets. It uses an AI-powered assistant to help users manage the entire data collection process through natural language interactions.

### Core Purpose
The application enables organizations to:
- Send structured data collection requests via Gmail
- Automatically parse and organize responses in Google Sheets
- Track participant responses and send reminders
- Analyze collected data with AI-powered visualizations
- Manage multiple data collection workflows through conversations

## High-Level Architecture

The application follows a **layered architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  (Features: Home, Onboarding, Request Builder, Settings)    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer                             │
│  (AI Agent, Request, Ingestion, Visualization, Parsing)     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                                │
│  (Database, Google APIs: Gmail, Sheets, Auth)               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Domain Layer                              │
│  (Models, Schemas, Email Protocol)                          │
└─────────────────────────────────────────────────────────────┘
```

## Key Modules

### 1. Presentation Layer (`lib/features/`)

#### 1.1 Home Module (`lib/features/home/`)
**Purpose**: Main application interface for managing conversations and interactions.

**Components**:
- `home_page.dart`: Main landing page with conversation list and chat interface
- `conversation_page.dart`: Individual conversation view with AI chat panel and inspector
- `conversation_list.dart`: List of all conversations with search/filter
- `ai_chat_panel.dart`: AI chat interface with message display, suggestions, and visualizations
- `inspector_panel.dart`: Multi-tab panel showing:
  - Participants and their response status
  - Request history and timeline
  - Collected data from Google Sheets
  - Activity log
  - Saved analyses

**Responsibilities**:
- Render UI for conversations and messages
- Handle user input and display AI responses
- Show visualizations and suggestion cards
- Manage conversation selection and navigation

#### 1.2 Request Builder Module (`lib/features/request_builder/`)
**Purpose**: UI for creating and editing data collection requests.

**Components**:
- `request_builder_page.dart`: Main request creation/editing interface
- `request_builder_controller.dart`: State management for request builder
- `schema_editor.dart`: Define data fields and their types
- `recipients_editor.dart`: Add/manage email recipients
- `due_date_picker.dart`: Set due dates for requests
- `send_section.dart`: Preview and send requests
- `sheet_section.dart`: Google Sheet configuration

**Responsibilities**:
- Schema definition (field names, types, validation)
- Participant management (add/remove email addresses)
- Request configuration (due dates, sheet settings)
- Send requests via email

#### 1.3 Onboarding Module (`lib/features/onboarding/`)
**Purpose**: User authentication and initial setup.

**Components**:
- `onboarding_page.dart`: Google OAuth sign-in interface
- `onboarding_controller.dart`: Authentication flow management

**Responsibilities**:
- Handle Google OAuth 2.0 authentication
- Store authentication tokens
- Redirect authenticated users to home

#### 1.4 Settings Module (`lib/features/settings/`)
**Purpose**: Application configuration and user preferences.

**Components**:
- `settings_page.dart`: Settings UI
- `settings_controller.dart`: Settings state management

**Responsibilities**:
- Manage OpenAI API key
- Application preferences
- Theme settings

#### 1.5 Profile Module (`lib/features/profile/`)
**Purpose**: User profile information and account management.

**Components**:
- `profile_page.dart`: User profile display
- `profile_menu_button.dart`: Profile menu dropdown

**Responsibilities**:
- Display user information (name, email, picture)
- Sign out functionality

### 2. Service Layer (`lib/services/`)

#### 2.1 AI Agent Service (`lib/services/ai_agent_service.dart`)
**Purpose**: Core AI orchestration using OpenAI Function Calling for natural language understanding and action execution.

**Key Responsibilities**:
- Parse user natural language queries
- Detect intent and extract parameters using OpenAI Function Calling
- Execute actions via function calling (16+ tools available)
- Generate AI responses with context awareness
- Suggest analyses and generate visualizations
- Manage conversation context and history

**OpenAI Tools Integrated**:
- `create_conversation`: Create new data collection workflows
- `define_schema`: Define data fields for collection
- `add_participants`: Add email recipients
- `send_reminders`: Send reminder emails to pending participants
- `check_for_responses`: Check Gmail for new responses
- `parse_email_response`: Parse email replies using AI
- `save_parsed_data`: Save parsed data to Google Sheets
- `analyze_sheet_data`: Analyze data in Google Sheets
- `suggest_analyses`: Suggest visualizations and analyses
- `generate_visualization`: Generate Python-based data visualizations
- `get_conversation_stats`: Get statistics about conversations
- `list_participants`: List all participants in a conversation
- `set_next_due_date`: Set due dates for recurring requests
- `create_sheet`: Create Google Sheets for data storage
- `update_conversation_title`: Update conversation names
- `run_saved_analysis`: Re-run previously saved analyses

**Dependencies**:
- `AppDatabase`: Store conversation history and AI messages
- `SheetsService`: Read data from Google Sheets for analysis
- `RequestService`: Execute data collection operations
- `VisualizationService`: Generate data visualizations
- `GmailService`: Check for email responses
- `SettingsController`: Access OpenAI API key

**Interaction Flow**:
```
User Input → AI Agent Service → OpenAI API (Function Calling)
                                      ↓
                            Intent Detection & Tool Selection
                                      ↓
                            Execute Tool → Service Layer
                                      ↓
                            Format Response → User
```

#### 2.2 Request Service (`lib/services/request_service.dart`)
**Purpose**: Manage data collection requests (create, send, track).

**Key Responsibilities**:
- Create and manage conversations
- Generate and send request emails via Gmail
- Track request status and recipients
- Create Google Sheets for data storage
- Manage request schemas and configurations

**Dependencies**:
- `AppDatabase`: Store requests and conversations
- `SheetsService`: Create and manage Google Sheets
- `GmailService`: Send request emails
- `GoogleAuthService`: Authentication for API calls
- `LoggingService`: Log request activities

#### 2.3 Ingestion Service (`lib/services/ingestion_service.dart`)
**Purpose**: Process email replies and extract structured data.

**Key Responsibilities**:
- Search Gmail for replies to requests
- Parse email bodies to extract table data
- Update Google Sheets with parsed responses
- Track recipient status (responded, pending, error)
- Prevent duplicate processing of messages
- Log ingestion activities

**Dependencies**:
- `AppDatabase`: Check processed messages, update recipient status
- `GmailService`: Search and retrieve email messages
- `SheetsService`: Append/update rows in Google Sheets
- `ParsingService`: Parse email content to structured data
- `LoggingService`: Log ingestion activities

**Data Flow**:
```
Gmail Reply → Ingestion Service → Search Messages by Request ID
                                        ↓
                              Filter Unprocessed Messages
                                        ↓
                              Parse Email Body → Parsing Service
                                        ↓
                              Convert to Sheet Format
                                        ↓
                              Update Google Sheets
                                        ↓
                              Update Recipient Status in DB
```

#### 2.4 Parsing Service (`lib/services/parsing_service.dart`)
**Purpose**: Parse email text to extract structured data according to schemas.

**Key Responsibilities**:
- Parse table-formatted email replies
- Extract field values according to schema
- Validate data types
- Handle edge cases (quoted content, formatting variations)
- Return structured row data

**Dependencies**:
- `RequestSchema`: Schema definition for validation

#### 2.5 Visualization Service (`lib/services/visualization_service.dart`)
**Purpose**: Generate data visualizations using Python.

**Key Responsibilities**:
- Generate Python code for various chart types (trends, distributions, summaries)
- Execute Python scripts with data from Google Sheets
- Handle data aggregation (by time period, category)
- Return base64-encoded PNG images
- Manage temporary files and cleanup

**Dependencies**:
- `SheetsService`: Read data from Google Sheets
- `PythonService`: Check Python installation and execute scripts

**Visualization Types**:
- Trend Analysis: Time series with aggregation by month/week/day
- Distribution Analysis: Histograms, box plots, pie charts
- Summary Analysis: Statistical summaries, correlations
- Custom Analysis: User-defined Python code

#### 2.6 Python Service (`lib/services/python_service.dart`)
**Purpose**: Manage Python environment and execution.

**Key Responsibilities**:
- Check if Python is installed
- Verify required packages (pandas, matplotlib, seaborn)
- Provide installation guidance for users
- Execute Python scripts in a secure manner

#### 2.7 Logging Service (`lib/services/logging_service.dart`)
**Purpose**: Log application activities for audit and debugging.

**Key Responsibilities**:
- Log user actions (sent requests, ingested responses)
- Store activity metadata in database
- Provide activity history for conversations

**Dependencies**:
- `AppDatabase`: Store activity logs

### 3. Data Layer (`lib/data/`)

#### 3.1 Database (`lib/data/db/`)
**Purpose**: Local SQLite database for application state and metadata.

**Technology**: Drift (SQLite with type-safe Dart API)

**Key Tables**:
- `conversations`: Conversation/workflow metadata
- `requests`: Data collection requests
- `recipients`: Email recipients and their status
- `recipient_statuses`: Response status tracking
- `processed_messages`: Track processed Gmail messages
- `ai_chat_messages`: AI conversation history (with images and suggestions)
- `activities`: Activity log entries
- `user_settings`: Application settings (OpenAI key, etc.)
- `saved_analyses`: Saved analysis configurations

**DAO (`lib/data/db/dao.dart`)**:
- Type-safe database operations
- CRUD methods for all entities
- Complex queries (search, filters, pagination)

#### 3.2 Google Services (`lib/data/google/`)

**3.2.1 Google Auth Service (`lib/data/google/google_auth_service.dart`)**
- **Purpose**: Handle OAuth 2.0 authentication with Google
- **Responsibilities**:
  - Initiate OAuth flow with PKCE
  - Store and refresh access tokens
  - Provide authenticated HTTP client
  - Manage user profile information
- **Scopes**: Gmail (send, read), Sheets (read/write), Drive (create files)

**3.2.2 Gmail Service (`lib/data/google/gmail_service.dart`)**
- **Purpose**: Interact with Gmail API
- **Responsibilities**:
  - Send request emails with structured data templates
  - Search for replies by request ID
  - Extract email content (body, headers, attachments)
  - Mark messages as processed

**3.2.3 Sheets Service (`lib/data/google/sheets_service.dart`)**
- **Purpose**: Interact with Google Sheets API
- **Responsibilities**:
  - Create new Google Sheets for conversations
  - Read data from sheets (for analysis)
  - Append/update rows in sheets
  - Handle row deduplication (update existing rows by email+request)
  - Format sheets with headers and styling

### 4. Domain Layer (`lib/domain/`)

#### 4.1 Models (`lib/domain/models.dart`)
**Purpose**: Core domain entities and value objects.

**Key Models**:
- `Conversation`: Data collection workflow
- `Request`: Individual data collection request
- `RequestSchema`: Data field definitions
- `RecipientStatus`: Participant response tracking
- `Activity`: Activity log entries

#### 4.2 Request Schema (`lib/domain/request_schema.dart`)
**Purpose**: Define structured data collection schemas.

**Schema Structure**:
- Column definitions (name, type, required)
- Validation rules
- Default values

#### 4.3 Email Protocol (`lib/domain/email_protocol.dart`)
**Purpose**: Email formatting and parsing standards.

**Responsibilities**:
- Define email templates for requests
- Parse email replies according to protocol
- Handle quoted content and formatting

### 5. Core Infrastructure (`lib/app/`, `lib/core/`)

#### 5.1 App Configuration (`lib/app/`)
- `app.dart`: Main app widget with routing
- `router.dart`: GoRouter configuration with auth guards
- `auth_guard.dart`: Authentication status checking
- `auth_provider.dart`: Riverpod providers for auth state
- `db_provider.dart`: Database singleton provider
- `theme.dart`: Material Design theme configuration
- `splash_page.dart`: Loading screen during app initialization

#### 5.2 Core Configuration (`lib/core/config/`)
- `oauth_config.dart`: OAuth 2.0 credentials and configuration

### 6. Utilities (`lib/utils/`)
- `error_handling.dart`: Centralized error handling and user-friendly messages
- `ids.dart`: ID generation utilities
- `validation.dart`: Input validation helpers

## Module Interactions

### 1. User Creates a Data Collection Request

```
User (UI) → Request Builder Controller
              ↓
          Request Service
              ↓
    ┌─────────┴─────────┐
    ↓                   ↓
Database          Google Services
(Save Request)    (Create Sheet)
                        ↓
                  Gmail Service
                  (Send Email)
                        ↓
                  Recipients Notified
```

### 2. AI Assistant Processes User Query

```
User Input → AI Chat Panel
                ↓
          AI Agent Service
                ↓
          OpenAI API (Function Calling)
                ↓
          Intent Detection
                ↓
    ┌───────────┴───────────┐
    ↓                       ↓
Request Service      Ingestion Service
Sheets Service       Gmail Service
Visualization Service  Parsing Service
    ↓                       ↓
Execute Action         Update Database
    ↓                       ↓
Format Response ←───────────┘
    ↓
Display to User
```

### 3. Email Response Ingestion

```
Gmail Reply → Inspector Panel (Manual Trigger)
                      OR
              AI Agent (Auto Check)
                ↓
          Ingestion Service
                ↓
          Gmail Service (Search Messages)
                ↓
          Filter Unprocessed
                ↓
          Parsing Service (Extract Data)
                ↓
          Sheets Service (Update Sheet)
                ↓
          Database (Update Status)
                ↓
          Logging Service (Log Activity)
                ↓
          UI Update (Show New Response)
```

### 4. Data Visualization Generation

```
User/AI Request → AI Agent Service
                        ↓
                  Visualization Service
                        ↓
                  ┌─────┴─────┐
                  ↓           ↓
            Sheets Service  Python Service
            (Read Data)    (Execute Script)
                  ↓           ↓
                  └─────┬─────┘
                        ↓
                  Generate PNG
                        ↓
                  Base64 Encode
                        ↓
                  Save to Database
                        ↓
                  Display in Chat
```

### 5. Conversation Persistence

```
AI Chat Message → AI Chat Panel
                        ↓
                  Save to Database
                  (content, imageBase64, suggestionsJson)
                        ↓
                  Load on Reload
                        ↓
                  Parse JSON (suggestions)
                        ↓
                  Display in UI
```

## State Management

**Technology**: Riverpod (Flutter state management)

**Key Providers**:
- `googleAuthServiceProvider`: Singleton Google auth service
- `appDatabaseProvider`: Database instance
- `selectedConversationIdProvider`: Currently selected conversation
- `chatMessagesProvider`: AI conversation messages (async)
- `conversationsProvider`: List of all conversations
- `aiAgentServiceProvider`: AI service instance

**State Flow**:
- Providers are defined at the service/data layer
- UI components (`ConsumerWidget`, `ConsumerStatefulWidget`) subscribe to providers
- State changes trigger UI rebuilds automatically
- Async state handled with `AsyncValue` (loading, data, error)

## Data Flow Patterns

### 1. Unidirectional Data Flow
```
User Action → Service Method → Database/API Update → Provider Invalidation → UI Rebuild
```

### 2. Async Operations
- Services return `Future<T>`
- Providers use `FutureProvider` or `AsyncNotifierProvider`
- UI handles loading/error states with `AsyncValue.when()`

### 3. Caching Strategy
- Database as single source of truth
- Providers cache async results
- Manual invalidation triggers refresh
- Local UI state for immediate updates (merged with DB on reload)

## Security Architecture

### 1. Authentication
- OAuth 2.0 with PKCE (Proof Key for Code Exchange)
- Access tokens stored securely (platform-specific keychain)
- Token refresh handled automatically
- Scoped permissions (Gmail, Sheets, Drive only)

### 2. API Keys
- OpenAI API key stored in database (encrypted at rest by platform)
- Never logged or exposed in UI
- User can update/remove via Settings

### 3. Data Privacy
- All data stored locally (SQLite database)
- Google Sheets created in user's Drive (user controls sharing)
- No data sent to third parties except:
  - Google APIs (OAuth, Gmail, Sheets)
  - OpenAI API (for AI features, user can disable)

## Error Handling

### Strategy
- Centralized error handling via `ErrorHandler` utility
- User-friendly error messages
- Logging for debugging
- Graceful degradation (partial failures don't crash app)

### Error Types
- Network errors (API failures)
- Authentication errors (token expiry)
- Parsing errors (malformed email replies)
- Validation errors (schema mismatches)

## Technology Stack

### Frontend
- **Framework**: Flutter 3.7.2+
- **Language**: Dart 3.7.2+
- **State Management**: Riverpod
- **Routing**: GoRouter
- **UI Components**: Material Design 3

### Backend/Services
- **Local Database**: SQLite via Drift
- **Google APIs**: googleapis (Gmail, Sheets, Drive)
- **OAuth**: flutter_appauth
- **AI**: OpenAI API (Function Calling)

### External Services
- **Gmail API**: Send emails, search for replies
- **Google Sheets API**: Read/write structured data
- **OpenAI API**: Natural language understanding, intent detection, code generation

### Development Tools
- **Build System**: build_runner (for Drift code generation)
- **Package Manager**: pub (Dart package manager)

## Architecture Patterns

### 1. Repository Pattern
- Database operations abstracted through DAO
- Services don't directly access database tables
- Single source of truth (database)

### 2. Service Layer Pattern
- Business logic in services
- Services orchestrate multiple data sources
- UI components call services, not data layer directly

### 3. Provider Pattern (Riverpod)
- Dependency injection via providers
- Singleton services (auth, database)
- Scoped providers (conversation-specific data)

### 4. Function Calling Pattern (OpenAI)
- Natural language → Structured intent
- Tools/actions defined as functions
- LLM selects and calls appropriate functions
- Result formatted back to natural language

## Extension Points

### Adding New AI Tools
1. Define function schema in `ai_agent_service.dart`
2. Implement execution method `_execute{FunctionName}`
3. Add case in `_executeTool` switch statement
4. Update system prompt with tool description

### Adding New Visualization Types
1. Add method in `visualization_service.dart`
2. Generate Python code for chart type
3. Return base64-encoded image
4. Call from AI agent or UI directly

### Adding New Data Sources
1. Create service in `lib/data/`
2. Integrate with `RequestService` or `IngestionService`
3. Update database schema if needed
4. Add UI components in features

## Performance Considerations

### 1. Database
- Indexed queries for conversations and requests
- Pagination for large result sets
- Batch operations where possible

### 2. Network
- Caching of Google API responses where appropriate
- Async operations to prevent UI blocking
- Timeout handling for network requests

### 3. UI
- Lazy loading of conversation lists
- Virtual scrolling for large message histories
- Image caching for visualizations
- Debouncing for search inputs

### 4. Python Execution
- Temporary file cleanup after script execution
- Timeout for long-running scripts
- Error handling for missing Python/packages

## Testing Strategy

### Unit Tests
- Service layer business logic
- Parsing service edge cases
- Schema validation

### Integration Tests
- Database operations
- Google API interactions (with mocks)
- End-to-end request flow

### Widget Tests
- UI component rendering
- User interaction flows
- State management

## Deployment

### Desktop Platforms
- **macOS**: App bundle with proper entitlements
- **Windows**: Executable with installer
- **Linux**: AppImage or package format

### Configuration
- OAuth credentials via environment variables or config file
- Database migration on first launch
- Platform-specific secure storage for tokens

---

## Summary

DIGIT Decision follows a clean, layered architecture with:

1. **Clear separation of concerns**: UI, services, data, and domain layers
2. **Modular design**: Each feature is self-contained
3. **Type safety**: Drift for database, strong typing throughout
4. **Reactive state**: Riverpod for declarative UI updates
5. **Extensibility**: Easy to add new AI tools, visualizations, data sources
6. **Security**: OAuth 2.0, encrypted storage, scoped permissions

The architecture supports the core use case of email-based data collection while providing flexibility for future enhancements and extensions.
