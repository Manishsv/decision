# Recurring Requests Feature - Feasibility Assessment

## Use Case
Principal Secretary needs to send the same data request to 100+ local bodies every week/month for monthly reviews. The request structure (schema, recipients) remains the same, but the due date changes each iteration.

## Requirements
1. **Setup Once**: Create a request template with schema and recipients
2. **Reuse Template**: Send the same request multiple times (weekly/monthly)
3. **Update Due Date**: Ability to set a new due date for each iteration
4. **Track Iterations**: See history of when requests were sent
5. **Same Sheet or New Sheet**: Option to append to existing sheet or create new sheet per iteration

## Feasibility Assessment: ✅ **HIGHLY FEASIBLE**

### Why It's Feasible
1. **Existing Infrastructure**: All core functionality already exists:
   - Request creation ✅
   - Email sending ✅
   - Sheet creation ✅
   - Schema and recipient management ✅

2. **Minimal Data Model Changes**: Only need to add:
   - `templateRequestId` (nullable) - links iterations to template
   - `iterationNumber` (optional) - for display purposes
   - `isTemplate` (optional) - mark original as template

3. **Simple Workflow**: 
   - Create first request → mark as template (optional)
   - "Send Again" → create new request from template → update due date → send

4. **No Complex Logic**: Just reuse existing `createDraftRequest` and `sendRequest` methods

## Design Decision: Template-Based Approach

### Option A: Template-Based (Recommended) ✅
- Each iteration is a **new request** with new `requestId`
- Link iterations via `templateRequestId` pointing to original
- Each iteration can have:
  - Same or different due date
  - Same recipients (or allow updates)
  - Same or new sheet (user choice)
- **Pros**:
  - Clean separation of iterations
  - Easy to track response rates per iteration
  - Can compare performance across iterations
  - Each iteration has its own conversation/activity log
- **Cons**:
  - Multiple request records in DB (acceptable)

### Option B: Single Request with Iterations (Not Recommended)
- Reuse same `requestId`, just update due date and send again
- Track iterations in activity log
- **Pros**: Single request record
- **Cons**:
  - Harder to track per-iteration metrics
  - Sheet management becomes complex
  - Activity log becomes cluttered

## Implementation Plan

### Phase 1: Core Functionality (Sprint 5 or 6)
1. **Data Model Updates**:
   - Add `templateRequestId` to `DataRequest` model (nullable)
   - Add `iterationNumber` to `DataRequest` model (optional, for display)
   - Database migration (schema version 4)

2. **Service Layer**:
   - Add `createIterationFromTemplate(String templateRequestId, DateTime newDueDate)` method
   - Option to reuse existing sheet or create new sheet
   - Copy schema, recipients, title, description from template

3. **UI Changes**:
   - Add "Send Again" button in conversation page
   - Dialog to:
     - Update due date
     - Choose: reuse sheet or create new sheet
     - Confirm and send
   - Show iteration history (list of previous iterations)

### Phase 2: Enhancements (Post-MVP)
1. **Recurrence Patterns**:
   - Auto-schedule (weekly/monthly)
   - Reminder to send next iteration
   - Calendar integration

2. **Template Management**:
   - Dedicated templates section
   - Edit template (update recipients, schema)
   - Clone template

3. **Analytics**:
   - Compare response rates across iterations
   - Track trends over time

## Database Schema Changes

```dart
// Add to Requests table
TextColumn get templateRequestId => text().nullable()(); // Links to template
IntColumn get iterationNumber => integer().nullable()(); // 1, 2, 3, etc.
BoolColumn get isTemplate => boolean().withDefault(const Constant(false))(); // Mark as template
```

## API Changes

### New Methods in RequestService
```dart
/// Create a new iteration from a template request
Future<String> createIterationFromTemplate({
  required String templateRequestId,
  required DateTime newDueDate,
  bool reuseSheet = false, // If true, reuse template's sheet; if false, create new
}) async {
  // 1. Load template request
  // 2. Create new requestId
  // 3. Copy schema, recipients, title, description
  // 4. Set new due date
  // 5. Set templateRequestId to original
  // 6. Calculate iterationNumber (count existing iterations + 1)
  // 7. Create sheet (new or reuse)
  // 8. Create conversation
  // 9. Return new requestId
}

/// Get all iterations for a template
Future<List<DataRequest>> getTemplateIterations(String templateRequestId) async {
  // Query all requests where templateRequestId matches
  // Order by iterationNumber or createdAt
}
```

## UI Flow

1. **User creates first request** → sends it
2. **User clicks "Send Again"** on conversation page
3. **Dialog appears**:
   - "Create Next Iteration"
   - Due date picker (pre-filled with next week/month)
   - Checkbox: "Reuse existing sheet" (default: checked)
   - Button: "Create & Send"
4. **System creates new iteration**:
   - New requestId
   - Same schema, recipients, title
   - New due date
   - Same or new sheet (based on choice)
5. **Sends emails** to all recipients
6. **Shows in conversation list** as new conversation (or grouped view)

## Edge Cases to Handle

1. **Template Deletion**: What if user deletes template?
   - Option: Prevent deletion if iterations exist
   - Option: Cascade delete all iterations
   - Option: Mark as deleted but keep iterations

2. **Recipient Changes**: What if recipients list changes?
   - Option: Always use template's recipients (simplest)
   - Option: Allow updating recipients per iteration (more complex)

3. **Schema Changes**: What if schema needs to change?
   - Option: Create new template (recommended)
   - Option: Allow schema updates (affects all future iterations)

4. **Sheet Management**: Same sheet vs new sheet?
   - **Same Sheet**: All iterations append to same Responses tab (good for trend analysis)
   - **New Sheet**: Each iteration has its own sheet (good for isolation)
   - **Recommendation**: Default to same sheet, allow user choice

## Estimated Effort

- **Phase 1 (Core)**: 1-2 days
  - Data model: 2 hours
  - Service methods: 4 hours
  - UI changes: 6 hours
  - Testing: 2 hours

- **Phase 2 (Enhancements)**: 3-5 days (post-MVP)

## Recommendation

✅ **Implement in Sprint 5 or 6** (after core MVP is complete)

This feature is:
- High value for the use case
- Low complexity (reuses existing code)
- Natural extension of current functionality
- Can be added incrementally

**Priority**: High (core use case requirement)
