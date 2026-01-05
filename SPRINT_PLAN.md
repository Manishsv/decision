# Sprint Plan: Data Request Agent Desktop App

**Status**: Ready for Implementation  
**Approach**: Sequential sprints with clear Definition of Done  
**Estimated Total**: 5-6 Sprints

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
     - `googleapis_auth` (OAuth)
     - `googleapis` (Gmail + Sheets)
     - `flutter_secure_storage` (token storage)
     - `go_router` (routing)
     - `intl` (date formatting)

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
- [ ] Create `tables.dart` with Drift table definitions:
  - `conversations`
  - `requests`
  - `recipient_status`
  - `activity_log`
  - `processed_messages`
- [ ] Create `app_db.dart` with Drift database class
- [ ] Create `dao.dart` with basic DAO methods:
  - `insertConversation`, `getConversations`
  - `insertRequest`, `getRequest`, `updateRequest`
  - `upsertRecipientStatus`, `getRecipientStatuses`
  - `insertActivityLog`, `getActivityLogs`
  - `markMessageProcessed`, `isMessageProcessed`

#### 1.2 Domain Models (`/lib/domain/`)
- [ ] Create `models.dart` with all enums:
  - `ConversationKind`, `RequestStatus`, `ColumnType`, `ReplyFormat`, `RecipientState`, `ActivityType`
- [ ] Create domain model classes:
  - `SchemaColumn`, `RequestSchema` (in `request_schema.dart`)
  - `Conversation`, `DataRequest`, `RecipientStatus`, `ActivityLogEntry` (in `models.dart`)
- [ ] Add converters for Drift (JSON serialization for schema, enums)

#### 1.3 Google Auth Service (`/lib/data/google/google_auth_service.dart`)
- [ ] Implement OAuth 2.0 installed app flow:
  - Launch browser for consent
  - Listen on localhost for redirect
  - Exchange auth code for tokens
  - Store refresh token in `flutter_secure_storage`
- [ ] Methods:
  - `Future<void> signIn()`
  - `Future<void> signOut()`
  - `Future<AuthClient> getAuthClient()`
  - `Future<String> getUserEmail()`
- [ ] Request scopes: `gmail.send`, `gmail.readonly`, `spreadsheets`

#### 1.4 UI Structure (`/lib/app/`, `/lib/features/`)
- [ ] Create `theme.dart` with app theme
- [ ] Create 3-pane layout widget (left sidebar, center content, right panel)
- [ ] Create `home_page.dart` with 3-pane layout
- [ ] Create placeholder widgets:
  - `conversation_list.dart` (left pane - empty for now)
  - `conversation_page.dart` (center pane - placeholder)
  - `inspector_panel.dart` (right pane - placeholder)

#### 1.5 Onboarding (`/lib/features/onboarding/`)
- [ ] Create `onboarding_page.dart`:
  - Google sign-in button
  - Optional OpenAI key input (secure storage)
  - "Workspace" concept (local-only, stored in DB/prefs)
  - Navigation to home on completion
- [ ] Create `onboarding_controller.dart` (Riverpod provider)
- [ ] Wire up auth service to onboarding

#### 1.6 Routing (`/lib/app/router.dart`)
- [ ] Set up routes:
  - `/onboarding` (initial if not authenticated)
  - `/home` (protected route)
- [ ] Add navigation guard (check auth state)

#### 1.7 App Entry Point (`/lib/app/app.dart`)
- [ ] Wrap app with Riverpod providers
- [ ] Set up theme
- [ ] Initialize router

### Definition of Done
- ✅ User can complete onboarding with Google sign-in
- ✅ User email stored and accessible
- ✅ Refresh token stored securely
- ✅ Database initialized with all tables
- ✅ Home page displays with 3-pane layout
- ✅ Routing works (onboarding → home)
- ✅ All DAO methods can insert/query test data

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
- [ ] Implement `createSheet(String title)`:
  - Create new spreadsheet via Sheets API
  - Return `{sheetId, sheetUrl}`
- [ ] Implement `ensureResponsesTabAndHeaders(String sheetId, RequestSchema schema)`:
  - Create "Responses" tab if needed
  - Write headers: `__receivedAt`, `__fromEmail`, `__messageId`, `__parseStatus`, then schema columns
- [ ] Implement `appendRows(String sheetId, List<List<Object?>> rows)`:
  - Batch append rows to Responses tab

#### 2.2 Request Service (`/lib/services/request_service.dart`)
- [ ] Implement `createDraftRequest(...)`:
  - Generate `requestId` (UUID)
  - Save to database
  - Create associated conversation
  - Return `requestId`
- [ ] Implement `createSheetForRequest(String requestId)`:
  - Create Google Sheet
  - Set up headers
  - Update request with `sheetId` and `sheetUrl`
- [ ] Implement basic request validation

#### 2.3 Request Builder UI (`/lib/features/request_builder/`)
- [ ] Create `request_builder_page.dart`:
  - Stepper or multi-step form
  - Navigation between steps
- [ ] Create `schema_editor.dart`:
  - Add/remove columns
  - Set column name, type (string/number/date), required flag
  - Live preview of schema
- [ ] Create `recipients_editor.dart`:
  - Multi-line text input for email addresses
  - Basic email validation
  - Show parsed recipient list
- [ ] Create `due_date_picker.dart`:
  - Date picker widget
  - Validation (future date)
- [ ] Create `sheet_section.dart`:
  - "Create Sheet" button
  - Show sheet URL when created
  - Status indicator
- [ ] Create `send_section.dart`:
  - Preview of email body (table)
  - "Save Draft" button
  - "Send Request" button (disabled until sheet created)
- [ ] Wire up to `RequestService`

#### 2.4 Email Protocol (`/lib/domain/email_protocol.dart`)
- [ ] Create `buildRequestEmailBody(DataRequest req)`:
  - Generate human instructions
  - Generate machine-readable block
  - Generate copy/paste table with headers
  - Format as markdown-style ASCII table
- [ ] Create `buildReminderEmailBody(DataRequest req)` (similar)
- [ ] Create subject line generator: `[DATA-REQ:<requestId>] <Title>`

#### 2.5 Navigation & Integration
- [ ] Add route for request builder (`/request/new`)
- [ ] Add "New Request" button to home page
- [ ] After draft creation, navigate to conversation view
- [ ] Update conversation list to show draft requests

### Definition of Done
- ✅ User can create a draft request with schema, recipients, due date
- ✅ Schema editor supports add/remove columns, set types
- ✅ Sheet creation works (new spreadsheet created)
- ✅ Headers written to "Responses" tab correctly
- ✅ Draft request saved to database
- ✅ Conversation appears in left pane
- ✅ "Open Sheet" link works (opens in browser)
- ✅ Email body preview shows correct table format

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
- [ ] Implement `sendEmail({to, subject, body})`:
  - Use Gmail API to send message
  - Handle multipart encoding (plain text)
  - Return message ID
- [ ] Implement `searchMessagesByRequestId(String requestId)`:
  - Gmail API search: `subject:"[DATA-REQ:<requestId>]"`
  - Return list of messages
- [ ] Implement helper methods:
  - `getPlainTextBody(GmailMessage msg)` - extract from multipart
  - `getFromEmail(GmailMessage msg)`
  - `getInternalDate(GmailMessage msg)`

#### 3.2 Request Service (Extend) (`/lib/services/request_service.dart`)
- [ ] Implement `sendRequest(String requestId)`:
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
- [ ] Create utility for activity logging:
  - `logActivity(String requestId, ActivityType type, Map<String, dynamic> payload)`
  - Store to database via DAO
  - Handle payload JSON serialization

#### 3.4 UI Integration
- [ ] Wire up "Send Request" button in request builder
- [ ] Show loading indicator during send
- [ ] Show success/error toast messages
- [ ] Update conversation view after send
- [ ] Update inspector panel to show activity log

#### 3.5 Conversation Page (Extend) (`/lib/features/home/conversation_page.dart`)
- [ ] Display request summary header:
  - Responded X/Y counts
  - Due date
  - Status badge
  - Buttons: "Open Sheet", "Check for responses", "Send reminder"
- [ ] Activity timeline:
  - Display activity log entries chronologically
  - Show sent, send errors, etc.

### Definition of Done
- ✅ User can send request emails to all recipients
- ✅ Emails contain correct subject line with requestId token
- ✅ Emails contain formatted table with schema columns
- ✅ Activity log shows send outcomes per recipient
- ✅ Recipient statuses initialized as `pending` or `bounced`
- ✅ Request status updates to `inProgress`
- ✅ Conversation view shows activity timeline
- ✅ Error handling works (failed sends marked as bounced)

---

## Sprint 4: Manual Ingestion + Parsing + Append

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
- [ ] Create `ids.dart`: UUID generation helper
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

## Sprint 5: Reminders + Parse Review + Polish

### Goals
- Send reminder emails to pending recipients
- Parse error review dialog
- Manual correction and append
- UI polish and error handling improvements

### Tasks

#### 5.1 Reminder Service (`/lib/services/reminder_service.dart`)
- [ ] Implement `sendReminderToPending(String requestId)`:
  - Load request from DB
  - Get all recipients with status `pending`
  - For each:
    - Generate reminder email body (same table format)
    - Call `GmailService.sendEmail()`
    - Update `RecipientStatus.reminderSentAt`
    - Log `ActivityType.reminderSent`

#### 5.2 Parse Review Dialog (`/lib/features/ingestion/parse_review_dialog.dart`)
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

#### 5.3 UI Integration
- [ ] Wire up "Send reminder now" button:
  - Show confirmation dialog
  - Call `ReminderService.sendReminderToPending()`
  - Show loading indicator
  - Show success/error toast
  - Update UI (reminderSentAt timestamps)
- [ ] Wire up parse review:
  - From Recipients tab, for ERROR status rows
  - "Review" button opens `ParseReviewDialog`
  - After correction, refresh recipient status
  - Show success toast

#### 5.4 Error Handling Improvements
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

#### 5.5 UI Polish
- [ ] Add status badges (colors for pending/responded/error)
- [ ] Format dates consistently (use intl)
- [ ] Add empty states (no conversations, no recipients, etc.)
- [ ] Improve loading indicators
- [ ] Add tooltips for buttons
- [ ] Ensure responsive layout (3-pane resizable)

#### 5.6 Testing Preparation
- [ ] Create basic test structure:
  - `parsing_service_test.dart` skeleton
  - `ingestion_service_test.dart` skeleton
- [ ] Document manual testing checklist

### Definition of Done
- ✅ "Send reminder now" button sends reminders to all pending recipients
- ✅ Reminder emails use same table format as request
- ✅ Recipient status shows reminderSentAt timestamp
- ✅ Parse error review dialog opens from ERROR recipients
- ✅ User can edit and correct parsed data
- ✅ "Append corrected row" adds row to sheet
- ✅ Recipient status updates from error to responded
- ✅ Error handling covers API failures with user-friendly messages
- ✅ UI is polished with status badges, empty states, tooltips
- ✅ All core flows work end-to-end

---

## Sprint 6: Testing & Documentation (Optional)

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
  googleapis_auth: ^1.x
  googleapis: ^10.x
  flutter_secure_storage: ^9.x
  go_router: ^13.x
  intl: ^0.19.x
  uuid: ^4.x
```

### Key Implementation Considerations

1. **OAuth Flow**: Use `googleapis_auth` with localhost redirect. Port 8080 is standard.

2. **Database Migrations**: Drift requires migrations for schema changes. Start with initial schema, add migrations as needed.

3. **Error Handling**: Wrap all API calls in try-catch, log errors, show user-friendly messages.

4. **Rate Limiting**: Add 100ms delay between Gmail sends. Consider batch limits for Sheets API (5000 cells per request).

5. **Table Parsing**: Be strict about format but tolerant of whitespace variations. Log parse errors clearly.

6. **Testing**: Focus on parsing and ingestion tests (business logic). UI tests can be added later.

---

## Success Criteria

The MVP is complete when:

1. ✅ User can create a request with schema, recipients, due date
2. ✅ Sheet is created with proper headers
3. ✅ Request emails are sent to 100+ recipients
4. ✅ Providers can reply with table via email (copy-paste)
5. ✅ User can manually ingest responses
6. ✅ Parsed data appears in Google Sheet
7. ✅ Response tracking shows responded/pending/error counts
8. ✅ Reminders can be sent to pending recipients
9. ✅ Parse errors can be reviewed and corrected
10. ✅ All data persists across app restarts

---

## Next Steps

1. Review this sprint plan
2. Confirm feasibility assessment
3. Start with Sprint 0 (setup) or Sprint 1 (if project structure already exists)
4. Implement sequentially, completing each sprint's Definition of Done before moving to next
5. Test incrementally (don't wait until Sprint 6 to test)
