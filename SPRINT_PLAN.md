# Sprint Plan: DIGIT Decision Desktop App

**Status**: In Progress (Sprints 0-4 Complete, Sprint 5 In Progress)  
**Approach**: Sequential sprints with clear Definition of Done  
**Estimated Total**: 5-6 Sprints  
**Current Sprint**: Sprint 5 (Recurring Requests Complete, Reminders + Parse Review Remaining)

---

## Sprint 0: Project Setup & Foundation (Optional but Recommended)

### Goals
- Initialize Flutter desktop project
- Set up dependencies
- Create project structure
- Basic app shell (no functionality yet)

### Tasks
1. **Project Initialization**
   - Create Flutter desktop project
   - Configure for macOS (Windows/Linux optional for MVP)
   - Set up `.gitignore`

2. **Dependencies**
   - Add to `pubspec.yaml`:
     - `flutter_riverpod` (state management)
     - `drift` + `drift/native` (SQLite)
     - `flutter_appauth` (OAuth - replaced googleapis_auth)
     - `googleapis` (Gmail + Sheets)
     - `flutter_secure_storage` (optional fallback)
     - `go_router` (routing)
     - `intl` (date formatting)
     - `flutter_dotenv` (environment variables)

3. **Project Structure**
   - Create folder structure per spec:
     ```
     /lib
       /app
       /features
       /domain
       /data
       /services
       /utils
     /test
     /docs
     ```

4. **Basic App Shell**
   - `main.dart` entry point
   - `app.dart` with basic Material/Cupertino theme
   - `router.dart` with go_router setup (empty routes for now)
   - Run and verify desktop app launches

### Definition of Done
- ✅ Project compiles and runs on macOS
- ✅ All dependencies resolve
- ✅ Folder structure matches spec
- ✅ Basic router initialized
- ✅ App shell displays (blank screen is OK)

---

## Sprint 1: Shell + Auth + DB

### Goals
- 3-pane layout UI structure
- Google OAuth authentication
- Secure token storage
- Drift database setup
- Onboarding flow
- Basic home page

### Tasks

#### 1.1 Database Setup (`/lib/data/db/`)
- [x] Create `app_db.dart` with Drift table definitions:
  - `conversations`
  - `requests`
  - `recipient_status`
  - `activity_log`
  - `processed_messages`
  - `credentials` (for cross-platform credential storage)
- [x] Create `app_db.dart` with Drift database class (schema version 3)
- [x] Create `dao.dart` with basic DAO methods:
  - `insertConversation`, `getConversations`, `archiveConversation`, `deleteConversation`
  - `insertRequest`, `getRequest`, `updateRequest`
  - `upsertRecipientStatus`, `getRecipientStatuses`
  - `insertActivityLog`, `getActivityLogs`
  - `markMessageProcessed`, `isMessageProcessed`
  - `saveCredential`, `getCredential`, `deleteCredential`

#### 1.2 Domain Models (`/lib/domain/`)
- [x] Create `models.dart` with all enums:
  - `ConversationKind`, `RequestStatus`, `ColumnType`, `ReplyFormat`, `RecipientState`, `ActivityType`
- [x] Create domain model classes:
  - `SchemaColumn`, `RequestSchema` (in `request_schema.dart`)
  - `Conversation`, `DataRequest`, `RecipientStatus`, `ActivityLogEntry` (in `models.dart`)
- [x] Add converters for Drift (JSON serialization for schema, enums)
- [x] Added `archived` field to `Conversation` model

#### 1.3 Google Auth Service (`/lib/data/google/google_auth_service.dart`)
- [x] Implement OAuth 2.0 installed app flow:
  - Launch browser for consent
  - Listen on localhost for redirect
  - Exchange auth code for tokens
  - Store tokens in SQLite database (cross-platform)
- [x] Methods:
  - `Future<void> signIn()`
  - `Future<void> signOut()`
  - `Future<http.Client> getAuthClient()`
  - `Future<String> getUserEmail()`
  - `Future<String?> getAccessToken()`
  - `Future<bool> isAuthenticated()`
- [x] Request scopes: `userinfo.email`, `userinfo.profile`, `mail.google.com`, `spreadsheets`, `drive`

#### 1.4 UI Structure (`/lib/app/`, `/lib/features/`)
- [x] Create `theme.dart` with app theme
- [x] Create 3-pane layout widget (left sidebar, center content, right panel)
- [x] Create `home_page.dart` with 3-pane layout
- [x] Create widgets:
  - `conversation_list.dart` (left pane - displays conversations with selection)
  - `conversation_page.dart` (center pane - shows request details and activity timeline)
  - `inspector_panel.dart` (right pane - placeholder)

#### 1.5 Onboarding (`/lib/features/onboarding/`)
- [x] Create `onboarding_page.dart`:
  - Google sign-in button
  - Navigation to home on completion
- [x] Create `onboarding_controller.dart` (Riverpod provider)
- [x] Wire up auth service to onboarding
- [x] OpenAI key moved to Settings page

#### 1.6 Routing (`/lib/app/router.dart`)
- [x] Set up routes:
  - `/` (splash page)
  - `/onboarding` (initial if not authenticated)
  - `/home` (protected route)
  - `/settings` (protected route)
  - `/request/new` (protected route)
- [x] Add navigation guard (check auth state)
- [x] Splash page for initial auth check

#### 1.7 App Entry Point (`/lib/app/app.dart`)
- [x] Wrap app with Riverpod providers
- [x] Set up theme
- [x] Initialize router
- [x] Load environment variables from `.env` file

#### 1.8 Database Singleton (`/lib/app/db_provider.dart`)
- [x] Create singleton database provider
- [x] Export `appDatabaseProvider` for Riverpod
- [x] Export `globalDb` for use in `auth_provider.dart`
- [x] Update all services to use singleton instance

### Definition of Done
- ✅ User can complete onboarding with Google sign-in
- ✅ User email stored and accessible
- ✅ Refresh token stored securely (in SQLite database, cross-platform)
- ✅ Database initialized with all tables (including Credentials table)
- ✅ Home page displays with 3-pane layout
- ✅ Routing works (onboarding → home)
- ✅ All DAO methods can insert/query test data
- ✅ Settings page with OpenAI API key management
- ✅ Database singleton pattern implemented (prevents race conditions)

---

## Sprint 2: Request Builder + Sheet Creation

### Goals
- Request creation UI
- Schema editor
- Recipients editor
- Due date picker
- Google Sheet creation integration
- Draft request persistence

### Tasks

#### 2.1 Sheets Service (`/lib/data/google/sheets_service.dart`)
- [x] Implement `createSheet(String title)`:
  - Create new spreadsheet via Sheets API
  - Return `{sheetId, sheetUrl}`
- [x] Implement `ensureResponsesTabAndHeaders(String sheetId, RequestSchema schema)`:
  - Create "Responses" tab if needed
  - Write headers: `__receivedAt`, `__fromEmail`, `__messageId`, `__parseStatus`, then schema columns
- [x] Implement `appendRows(String sheetId, List<List<Object?>> rows)`:
  - Batch append rows to Responses tab

#### 2.2 Request Service (`/lib/services/request_service.dart`)
- [x] Implement `createDraftRequest(...)`:
  - Generate `requestId` (UUID)
  - Save to database
  - Create associated conversation
  - Return `requestId`
- [x] Implement `createSheetForRequest(String requestId)`:
  - Create Google Sheet
  - Set up headers
  - Update request with `sheetId` and `sheetUrl`
- [x] Implement basic request validation

#### 2.3 Request Builder UI (`/lib/features/request_builder/`)
- [x] Create `request_builder_page.dart`:
  - Multi-step form with PageView
  - Navigation between steps
  - Back button and cancel button with confirmation
- [x] Create `schema_editor.dart`:
  - Add/remove columns
  - Set column name, type (string/number/date), required flag
- [x] Create `recipients_editor.dart`:
  - Multi-line text input for email addresses
  - Basic email validation
- [x] Create `due_date_picker.dart`:
  - Date picker widget
  - Validation (future date)
- [x] Create `sheet_section.dart`:
  - "Create Sheet" button
  - Show sheet URL when created
  - Open sheet in browser (native command)
- [x] Create `send_section.dart`:
  - Preview of email body (table)
  - "Save Draft" button
  - "Send Request" button (disabled until sheet created)
- [x] Wire up to `RequestService`

#### 2.4 Email Protocol (`/lib/domain/email_protocol.dart`)
- [x] Create `buildRequestEmailBody(DataRequest req)`:
  - Generate human instructions
  - Generate machine-readable block
  - Generate copy/paste table with headers
  - Format as markdown-style ASCII table
- [x] Create `buildReminderEmailBody(DataRequest req)` (similar)
- [x] Create subject line generator: `[DATA-REQ:<requestId>] <Title>`
- [x] Create `extractRequestIdFromSubject(String subject)` helper

#### 2.5 Navigation & Integration
- [x] Add route for request builder (`/request/new`)
- [x] Add "New Request" button to home page
- [x] After draft creation, navigate to conversation view (via Save Draft)
- [x] Conversation list shows all conversations (including drafts)

### Definition of Done
- ✅ User can create a draft request with schema, recipients, due date
- ✅ Schema editor supports add/remove columns, set types
- ✅ Sheet creation works (new spreadsheet created)
- ✅ Headers written to "Responses" tab correctly
- ✅ Draft request saved to database
- ✅ Conversation appears in left pane (conversation list implemented)
- ✅ "Open Sheet" link works (opens in browser via native command)
- ✅ Email body preview shows correct table format
- ✅ Settings page has back button to return to home
- ✅ Credentials stored in SQLite (cross-platform, no Keychain dependency)
- ✅ Cancel/close button in request builder with confirmation dialog

---

## Sprint 3: Send Request Emails

### Goals
- Gmail service implementation
- Send emails to recipients
- Activity logging
- Recipient status initialization
- Error handling for send failures

### Tasks

#### 3.1 Gmail Service (`/lib/data/google/gmail_service.dart`)
- [x] Implement `sendEmail({to, subject, body})`:
  - Use Gmail API to send message
  - Handle multipart encoding (plain text)
  - Return message ID
- [x] Implement `searchMessagesByRequestId(String requestId)`:
  - Gmail API search: `subject:"[DATA-REQ:<requestId>]"`
  - Return list of messages
- [x] Implement helper methods:
  - `getPlainTextBody(GmailMessage msg)` - extract from multipart
  - `getFromEmail(GmailMessage msg)`
  - `getInternalDate(GmailMessage msg)`

#### 3.2 Request Service (Extend) (`/lib/services/request_service.dart`)
- [x] Implement `sendRequest(String requestId)`:
  - Load request from DB
  - For each recipient:
    - Generate email body (via `email_protocol.dart`)
    - Call `GmailService.sendEmail()`
    - On success: log `ActivityType.sent`, mark recipient as `pending`
    - On failure: log `ActivityType.sendError`, mark recipient as `bounced`
  - Update request status: `draft` → `sent` → `inProgress`
  - Store Gmail thread ID if available (optional)
  - Add basic rate limiting (100ms delay between sends)

#### 3.3 Logging Service (`/lib/services/logging_service.dart`)
- [x] Create utility for activity logging:
  - `logActivity(String requestId, ActivityType type, Map<String, dynamic> payload)`
  - Store to database via DAO
  - Handle payload JSON serialization
  - `getActivityLogs(String requestId)` method

#### 3.4 UI Integration
- [x] Wire up "Send Request" button in request builder
- [x] Show loading indicator during send
- [x] Show success/error toast messages with detailed results
- [x] Update conversation view after send
- [x] Confirmation dialog before sending
- [ ] Update inspector panel to show activity log (pending)

#### 3.5 Conversation Page (Extend) (`/lib/features/home/conversation_page.dart`)
- [x] Display request summary header:
  - Responded X/Y counts
  - Pending X/Y counts
  - Error X/Y counts
  - Due date
  - Status badge
  - "Open Sheet" button
- [x] Activity timeline:
  - Display activity log entries chronologically
  - Show sent, send errors, etc. with icons and details
- [ ] Buttons: "Check for responses", "Send reminder" (pending Sprint 4/5)

#### 3.6 Conversation Management
- [x] Archive functionality (hide from main list)
- [x] Delete functionality (removes all related data)
- [x] Context menu for archive/delete actions
- [x] Filter conversations by archived status

### Definition of Done
- ✅ User can send request emails to all recipients
- ✅ Emails contain correct subject line with requestId token
- ✅ Emails contain formatted table with schema columns
- ✅ Activity log shows send outcomes per recipient
- ✅ Recipient statuses initialized as `pending` or `bounced`
- ✅ Request status updates to `inProgress`
- ✅ Conversation view shows activity timeline
- ✅ Error handling works (failed sends marked as bounced)
- ✅ Conversation list displays all conversations with selection
- ✅ Request summary shows responded/pending/error counts
- ✅ Activity timeline displays all logged activities
- ✅ Archive and delete functionality for conversations

---

## Sprint 4: Manual Ingestion + Parsing + Append (Next)

**Status**: Ready to Start

### Goals
- Parse table replies from emails
- Deterministic table parsing service
- Append parsed rows to Google Sheet
- Update recipient statuses
- Message deduplication

### Tasks

#### 4.1 Parsing Service (`/lib/services/parsing_service.dart`)
- [ ] Create `ParseResult` class:
  - `success: bool`
  - `rows: List<Map<String, dynamic>>`
  - `errors: List<String>`
  - `rawTable: String?`
- [ ] Implement `parseTableReply({body, schema})`:
  - Detect first contiguous block of lines starting with `|`
  - Extract block until blank or non-`|` line
  - Parse rows: split by newline, ignore separator rows (dashes/pipes)
  - Row 0 = headers, rows 1..N = data
  - Header validation: normalize (trim + lowercase), match schema columns
  - Cell coercion:
    - `string`: as-is
    - `number`: remove commas, parse to double
    - `date`: ISO8601 only
    - `empty`: error if required, else null
  - Multi-row support: return list of row maps
  - Error handling: no table found, header mismatch, required field missing, type coercion failure

#### 4.2 Ingestion Service (`/lib/services/ingestion_service.dart`)
- [ ] Implement `ingestResponses(String requestId)`:
  - Load request from DB
  - Call `GmailService.searchMessagesByRequestId(requestId)`
  - For each message:
    - Check `isMessageProcessed(requestId, messageId)` → skip if processed
    - Extract: `fromEmail`, `messageId`, `timestamp`, `body`
    - Call `ParsingService.parseTableReply(body, schema)`
    - If success:
      - Convert parsed rows to sheet rows:
        - System fields: `__receivedAt`, `__fromEmail`, `__messageId`, `__parseStatus="OK"`
        - Then schema columns in order
      - Call `SheetsService.appendRows(sheetId, rows)`
      - Update `RecipientStatus` to `responded`
      - Log `ActivityType.ingested`
    - If failure:
      - Update `RecipientStatus` to `error`
      - Store raw table snippet in note (truncate to ~500 chars)
      - Log `ActivityType.parseError`
    - Mark message as processed: `markMessageProcessed(requestId, messageId)`

#### 4.3 Utils (`/lib/utils/`)
- [x] Create `ids.dart`: UUID generation helper
- [ ] Create `result.dart`: Result<T, E> type for error handling (optional)
- [ ] Create `datetime.dart`: Date formatting helpers
- [ ] Create `text.dart`: String manipulation helpers (truncate, normalize)

#### 4.4 UI Integration
- [ ] Wire up "Check for responses" button in conversation page
- [ ] Show loading indicator during ingestion
- [ ] Show toast with results: "X responses ingested, Y errors"
- [ ] Update responded/pending/error counts in UI
- [ ] Refresh conversation view and inspector panel

#### 4.5 Inspector Panel (Extend) (`/lib/features/home/inspector_panel.dart`)
- [ ] Recipients tab:
  - Table showing all recipients
  - Columns: Email, Status (badge), Last Response At, Reminder Sent At, Note
  - Highlight error recipients
- [ ] Activity log tab:
  - Chronological list of activity entries
  - Show type, timestamp, details

### Definition of Done
- ✅ "Check for responses" button works
- ✅ Gmail search finds replies by requestId token
- ✅ Table parsing works for single-row and multi-row replies
- ✅ Parsed rows appended to Google Sheet correctly
- ✅ System columns (receivedAt, fromEmail, etc.) included
- ✅ Recipient statuses update: `pending` → `responded` or `error`
- ✅ Activity log shows ingested and parse error entries
- ✅ Message deduplication works (no duplicate processing)
- ✅ Parse errors stored with raw table snippet
- ✅ UI updates show new response counts

---

## Sprint 5: Reminders + Recurring Requests + Parse Review + Polish

**Status**: In Progress (Recurring Requests Complete)

### Goals
- Send reminder emails to pending recipients
- **Recurring requests: Create iterations from templates** ✅
- Parse error review dialog
- Manual correction and append
- UI polish and error handling improvements

### Tasks

#### 5.1 Recurring Requests (NEW) ✅ COMPLETE
- [x] **Data Model Updates**:
  - ✅ Add `templateRequestId` (nullable) to `DataRequest` model
  - ✅ Add `iterationNumber` (nullable) to `DataRequest` model
  - ✅ Add `isTemplate` (boolean) to `DataRequest` model
  - ✅ Database migration (schema version 4)
- [x] **Service Layer** (`/lib/services/request_service.dart`):
  - ✅ Implement `createIterationFromTemplate(String templateRequestId, DateTime newDueDate, bool reuseSheet)`:
    - ✅ Load template request
    - ✅ Create new requestId
    - ✅ Copy schema, recipients, title, description
    - ✅ Set new due date
    - ✅ Link to template via `templateRequestId`
    - ✅ Calculate `iterationNumber` (count existing + 1)
    - ✅ Create or reuse sheet based on `reuseSheet` flag
    - ✅ Create new conversation
    - ✅ Return new requestId
  - ✅ Implement `getTemplateIterations(String templateRequestId)`:
    - ✅ Query all requests where `templateRequestId` matches
    - ✅ Return sorted list of iterations
- [x] **UI Changes** (`/lib/features/home/conversation_page.dart`):
  - ✅ Add "Send Again" button (only for sent requests)
  - ✅ Create iteration dialog:
    - ✅ Due date picker (pre-filled: next week/month)
    - ✅ Checkbox: "Reuse existing sheet" (default: checked)
    - ✅ "Create & Send" button
  - ✅ Show iteration history (list of previous iterations with dates)
  - ⏳ Group iterations in conversation list (optional enhancement - deferred)

#### 5.4 Reminder Service (`/lib/services/reminder_service.dart`)
- [ ] Implement `sendReminderToPending(String conversationId)`:
  - Load conversation from DB
  - Get all participants with status `pending` (across all requests)
  - For each:
    - Generate reminder email body (same table format)
    - Call `GmailService.sendEmail()`
    - Update `RecipientStatus.reminderSentAt` (rename to ParticipantStatus)
    - Log `ActivityType.reminderSent`
- [ ] Can be called via:
  - UI button: "Send Reminders"
  - AI Agent: "Send reminders to pending participants"

#### 5.3 Parse Review Dialog (`/lib/features/ingestion/parse_review_dialog.dart`)
- [ ] Create dialog widget:
  - Show raw extracted table block (read-only)
  - Editable form with one input per schema column
  - Pre-fill with parsed values if available (partial parse)
  - Validation (required fields, type coercion)
  - "Append corrected row" button
  - "Cancel" button
- [ ] On append:
  - Convert form data to sheet row (same format as parsing)
  - Call `SheetsService.appendRows()`
  - Update `RecipientStatus` to `responded`
  - Clear error status and note
  - Log correction activity

#### 5.4 UI Integration
- [ ] Wire up "Send reminder now" button:
  - Show confirmation dialog
  - Call `ReminderService.sendReminderToPending()`
  - Show loading indicator
  - Show success/error toast
  - Update UI (reminderSentAt timestamps)
- [ ] Wire up parse review:
  - From Participants tab, for ERROR status rows
  - "Review" button opens `ParseReviewDialog`
  - After correction, refresh participant status
  - Show success toast
- [ ] Wire up AI Agent:
  - Chat interface in center pane
  - Send button triggers AI Agent service
  - Display responses in chat
  - Show loading states

#### 5.5 Error Handling Improvements
- [ ] Add error handling for API failures:
  - Network errors → retry suggestion
  - Quota errors → user-friendly message
  - Permission errors → re-auth prompt
- [ ] Add loading states throughout:
  - Send request (progress for multi-recipient)
  - Ingestion (progress indicator)
  - Sheet creation (loading state)
- [ ] Add toast notifications:
  - Success: "X emails sent", "X responses ingested"
  - Errors: User-friendly error messages

#### 5.8 UI Polish
- [ ] Add status badges (colors for pending/responded/error)
- [ ] Format dates consistently (use intl)
- [ ] Add empty states (no conversations, no recipients, etc.)
- [ ] Improve loading indicators
- [ ] Add tooltips for buttons
- [ ] Ensure responsive layout (3-pane resizable)

#### 5.9 Testing Preparation
- [ ] Create basic test structure:
  - `parsing_service_test.dart` skeleton
  - `ingestion_service_test.dart` skeleton
- [ ] Document manual testing checklist

### Definition of Done
- ✅ **"Send Again" button creates new iteration from template**
- ✅ **Iteration dialog allows updating due date and sheet choice**
- ✅ **New iteration is created with same schema/recipients but new due date**
- ✅ **Iteration history is displayed in conversation view**
- ✅ **Template requests are linked to their iterations**
- ✅ **Database migration to version 4 completed**
- ✅ **Duplicate draft prevention implemented**
- ✅ **OAuth token refresh fixed**
- ✅ **Layout overflow issues resolved**
- ✅ **Enhanced table parsing for top-of-email replies**
- ⏳ "Send reminder now" button sends reminders to all pending recipients
- ⏳ Reminder emails use same table format as request
- ⏳ Recipient status shows reminderSentAt timestamp
- ⏳ Parse error review dialog opens from ERROR recipients
- ⏳ User can edit and correct parsed data
- ⏳ "Append corrected row" adds row to sheet
- ⏳ Recipient status updates from error to responded
- ⏳ Error handling covers API failures with user-friendly messages
- ⏳ UI is polished with status badges, empty states, tooltips
- ✅ All core flows work end-to-end

---

## Sprint 6: Testing & Documentation (Optional)

**Status**: Pending

### Goals
- Unit tests for critical services
- Documentation
- Final polish

### Tasks

#### 6.1 Unit Tests
- [ ] `parsing_service_test.dart`:
  - Parses single-row table
  - Parses multi-row table
  - Detects header mismatch
  - Handles missing required fields
  - Handles number coercion with commas
  - Handles date parsing (ISO8601)
  - Handles empty cells (required vs optional)
- [ ] `ingestion_service_test.dart`:
  - Mock GmailService
  - Ensures dedupe works (skips processed messages)
  - Ensures appendRows called correct number of times
  - Ensures recipient status updates correctly
  - Handles parse errors correctly

#### 6.2 Documentation
- [ ] Create `/docs/spec.md` (this sprint plan)
- [ ] Create `/docs/email_protocol.md`:
  - Email format specification
  - Table format requirements
  - Example emails
- [ ] Create `/docs/sheet_schema.md`:
  - Sheet structure
  - Column meanings
  - System columns explanation
- [ ] Create `README.md`:
  - Setup instructions
  - How to run
  - How to build
  - Configuration

#### 6.3 Final Polish
- [ ] Code review and cleanup
- [ ] Remove debug prints
- [ ] Add code comments for complex logic
- [ ] Verify all error paths work
- [ ] Test with real Gmail accounts (2-3 test recipients)
- [ ] Test with different email clients (Gmail, Outlook, Apple Mail)

### Definition of Done
- ✅ Core parsing logic has unit tests
- ✅ Ingestion logic has unit tests
- ✅ Documentation complete
- ✅ Code is clean and commented
- ✅ End-to-end tested with real email accounts
- ✅ MVP is ready for user acceptance testing

---

## Implementation Notes

### Dependencies Summary
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.x
  drift: ^2.x
  drift/native: ^2.x
  googleapis: ^11.x
  flutter_appauth: ^11.x  # Replaced googleapis_auth
  flutter_secure_storage: ^9.x  # Optional fallback, primary storage is SQLite
  go_router: ^13.x
  intl: ^0.19.x
  uuid: ^4.x
  flutter_dotenv: ^6.x
  url_launcher: ^6.x  # Optional, using native commands for desktop
```

### Key Implementation Considerations

1. **OAuth Flow**: Use `flutter_appauth` with PKCE and localhost redirect. More robust for desktop apps.
2. **Credential Storage**: All credentials (OAuth tokens, API keys) stored in SQLite database for cross-platform compatibility. No Keychain dependency.
3. **Database Singleton**: Single `AppDatabase` instance via `appDatabaseProvider` to prevent race conditions.
4. **Archive/Delete**: Conversations can be archived (hidden) or deleted (removes all related data).
5. **Database Migrations**: Drift requires migrations for schema changes. Start with initial schema, add migrations as needed.
6. **Error Handling**: Wrap all API calls in try-catch, log errors, show user-friendly messages.
7. **Rate Limiting**: Add 100ms delay between Gmail sends. Consider batch limits for Sheets API (5000 cells per request).
8. **Table Parsing**: Be strict about format but tolerant of whitespace variations. Log parse errors clearly.
9. **Testing**: Focus on parsing and ingestion tests (business logic). UI tests can be added later.

---

## Success Criteria

The MVP is complete when:

1. ✅ User can create a request with schema, recipients, due date
2. ✅ Sheet is created with proper headers
3. ✅ Request emails are sent to recipients (ready for 100+)
4. ✅ Providers can reply with table via email (copy-paste)
5. ✅ User can manually ingest responses
6. ✅ Parsed data appears in Google Sheet
7. ✅ Response tracking shows responded/pending/error counts
8. ✅ **User can create recurring requests (send same request multiple times)**
9. ✅ **User can update due date for next iteration**
10. ✅ **Iteration history is tracked and displayed**
11. ⏳ Reminders can be sent to pending recipients - Sprint 5 (Remaining)
12. ⏳ Parse errors can be reviewed and corrected - Sprint 5 (Remaining)
13. ✅ All data persists across app restarts
14. ✅ Conversations can be archived or deleted
15. ✅ Enhanced parsing handles various email reply formats

---

## Completed Sprints Summary

### Sprint 0: ✅ Complete
- Project initialized, dependencies configured
- Basic app shell working

### Sprint 1: ✅ Complete
- Database setup with all tables (including Credentials for cross-platform storage)
- Google OAuth authentication with SQLite credential storage
- 3-pane layout UI
- Onboarding flow
- Settings page with OpenAI API key management
- Database singleton pattern implemented (`appDatabaseProvider`)
- Conversation list with selection

### Sprint 2: ✅ Complete
- Request builder UI (all steps)
- Schema editor, recipients editor, due date picker
- Google Sheet creation and header setup
- Email protocol implementation
- Cancel/close functionality with confirmation

### Sprint 3: ✅ Complete
- Gmail service with send and search functionality
- Request sending to all recipients
- Activity logging
- Conversation list and detail view
- Request summary with stats (responded/pending/error counts)
- Activity timeline display
- Archive and delete functionality for conversations

### Sprint 4: ✅ Complete
- Manual ingestion service
- Table parsing with deterministic logic
- Response appending to Google Sheets
- Message deduplication
- Parse error handling
- Enhanced parsing for various email reply formats

### Sprint 5: In Progress
- ✅ **Recurring Requests**: Create iterations from templates for weekly/monthly data collection
  - "Send Again" button to create new iterations
  - Update due date for each iteration
  - Option to reuse existing sheet or create new sheet
  - Track iteration history
- ⏳ **Reminders**: Send reminder emails to pending recipients
- ⏳ **Parse Error Review**: Manual correction dialog for failed parses

### Additional Features Implemented
- **Archive/Delete**: Conversations can be archived (hidden from main list) or deleted (removes all related data)
- **Database Singleton**: Fixed multiple database instance warning by implementing singleton pattern via `appDatabaseProvider`
- **Cross-Platform Storage**: All credentials stored in SQLite (works on Windows, macOS, Linux)
- **Settings Page**: OpenAI API key management with back navigation
- **Auto-Refresh**: Conversation list refreshes automatically after creating/sending requests
- **Smart Table Parsing**: Skips original request table in replies, only parses user's response table
- **Duplicate Prevention**: Prevents creating duplicate drafts when navigating away and back
- **Token Refresh Fix**: Fixed OAuth token refresh to include client secret
- **Layout Improvements**: Fixed button overflow issues with Wrap widget
- **Enhanced Parsing**: Improved table extraction to handle replies at the top of email

## Next Steps

1. ✅ Sprint 0-4 Complete
2. ✅ Sprint 5: Recurring Requests - Complete
3. **⚠️ ARCHITECTURE REFACTOR NEEDED**: Conversation Model Update (See `CONVERSATION_MODEL.md`)
   - Current: Each request creates a conversation (1:1)
   - Desired: Conversation created first, multiple requests per conversation
   - Impact: Significant data model and service layer changes
4. **Sprint 5 (Remaining)**: Reminders + Parse Review + Polish
5. **Sprint 6**: Testing & Documentation (Optional)
6. Test incrementally (don't wait until Sprint 6 to test)

## ⚠️ Important: Conversation Model Clarification

**User's Mental Model** (Correct):
- Conversation is created FIRST with a name (e.g., "Finance Review")
- Multiple requests can be sent within the same conversation
- Same sheet is shared across all requests in a conversation
- Recurring requests = new requests within the same conversation
- Can add more recipients over time
- Can send reminders to pending recipients

**Current Implementation** (Needs Refactor):
- Each request creates a new conversation (1:1 relationship)
- Sheet is tied to request, not conversation
- Recurring requests create new conversations

**See `CONVERSATION_MODEL.md` for detailed architecture changes needed.**

## Recent Bug Fixes & Improvements

### Database & Persistence
- ✅ Fixed database migration to version 4 (recurring request fields)
- ✅ Fixed duplicate conversation creation when navigating away from request builder
- ✅ Improved draft detection to reuse existing drafts within 1 hour

### Authentication
- ✅ Fixed OAuth token refresh to include client secret (required for desktop apps)

### UI/UX
- ✅ Fixed layout overflow in conversation page (buttons now wrap properly)
- ✅ Improved error messages for missing request ID

### Parsing
- ✅ Enhanced table extraction to handle replies at top of email (before reply markers)
- ✅ Improved logic to skip original request table and find user's actual reply
- ✅ Better handling of empty rows and edge cases
