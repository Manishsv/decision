# Feasibility Review: Data Request Agent Desktop App

## Overall Assessment: ✅ **FEASIBLE**

The specification is well-structured, comprehensive, and technically sound. The MVP scope is appropriately constrained and the tech stack choices are solid.

---

## Technical Feasibility

### ✅ Confirmed Feasible Components

1. **Flutter Desktop**: Stable on macOS, Windows, Linux
2. **Google OAuth**: `googleapis_auth` supports installed app flow with localhost redirect
3. **Gmail API**: Full support via `googleapis` package
4. **Sheets API**: Full support via `googleapis` package
5. **Drift + SQLite**: Mature, type-safe ORM
6. **Riverpod**: Excellent state management choice
7. **Table Parsing**: Deterministic parsing is straightforward

---

## Questions & Clarifications

### 1. **OAuth Implementation Approach**
- **Spec says**: `googleapis_auth + custom auth client`
- **Question**: Modern best practice is PKCE (desktopoauth2 package), but `googleapis_auth` with localhost redirect works fine for MVP
- **Recommendation**: Proceed with `googleapis_auth` as specified (simpler for MVP)

### 2. **Sheet Creation**
- **Spec says**: "create sheet" per request
- **Question**: Confirm this means a **new spreadsheet** (not a new tab in existing spreadsheet)
- **Assumption**: New spreadsheet per request ✅

### 3. **Gmail Search Performance**
- **Note**: Searching by subject token is correct, but Gmail search can return large result sets
- **MVP is fine**: Manual polling with requestId-scoped search is acceptable
- **Future consideration**: Could cache lastIngestAt timestamp for incremental queries

### 4. **Rate Limiting**
- **Spec mentions**: Basic throttle for sending hundreds of emails
- **Recommendation**: Implement ~100ms delay between sends or batch in groups of 50-100
- **Gmail API**: 1 billion quota units/day (sending ~10 quota units per email = 100M emails/day limit)
- **MVP fine**: Manual sending with basic throttle is sufficient

### 5. **Error Handling Scope**
- **Spec covers**: Parse errors ✅
- **Should add**: 
  - API quota errors (retry later)
  - Network errors (retry)
  - Sheet permission errors (user feedback)
- **Recommendation**: Add basic try-catch with user-visible error messages

### 6. **Table Parsing Edge Cases**
- **Spec covers**: Basic parsing ✅
- **Consider**: 
  - Empty rows (skip?)
  - Extra columns in reply (ignore?)
  - Partial tables (error or skip?)
- **Recommendation**: Handle empty rows (skip), extra columns (ignore), partial tables (error)

### 7. **Activity Log Storage**
- **Spec**: `payloadJson` field for flexible data
- **Question**: Should we limit size? Large parse errors could bloat DB
- **Recommendation**: Truncate payloadJson to ~10KB max in implementation

---

## Suggested Minor Changes

### 1. **Add to Domain Models**
```dart
// Add to RecipientStatus for better tracking
final int? reminderCount; // track how many reminders sent
```

### 2. **Add to Activity Log**
```dart
// Consider adding:
final String? errorMessage; // quick access without parsing JSON
```

### 3. **Parsing Service Enhancement**
- Add tolerance for leading/trailing whitespace in cells
- Allow empty separator rows between data sections (skip gracefully)
- Log parse warnings vs errors separately

### 4. **Gmail Service**
- Cache threadId when sending (Gmail API returns it)
- Store threadId in DataRequest.gmailThreadId ✅ (already in spec)
- Use threadId for faster searches if available (future optimization)

### 5. **UI Polish (Low Priority)**
- Add loading indicators during ingestion
- Show progress bar for multi-recipient sends
- Toast notifications for successful operations

---

## Implementation Risks (Low to Medium)

### Low Risk
- ✅ OAuth flow complexity (well-documented, standard pattern)
- ✅ Table parsing edge cases (can iterate based on real emails)
- ✅ Gmail multipart parsing (existing libraries help)

### Medium Risk
- ⚠️ **Gmail API quota limits**: Monitor during testing with 100+ recipients
- ⚠️ **Email client variations**: Outlook/Apple Mail may format tables differently (test with real clients)
- ⚠️ **Sheet API batch limits**: 5000 cells per request (MVP should be fine)

---

## Missing from Spec (Consider Adding)

1. **Migration/DB Versioning**: Drift requires schema migrations - plan for future schema changes
2. **Export/Backup**: MVP doesn't need, but consider for v2
3. **Logging/Diagnostics**: Add basic logging service for debugging
4. **Configuration**: Where to store sheet naming template, email template customization

---

## Recommended Sprint Structure

Break into 5-6 sprints as specified, but with these adjustments:

**Sprint 0 (Setup)** [Optional but recommended]
- Project initialization
- Dependency setup
- Basic app shell

**Sprint 1**: Shell + Auth + DB
**Sprint 2**: Request Builder + Sheet Creation
**Sprint 3**: Send Request Emails
**Sprint 4**: Manual Ingestion + Parsing + Append
**Sprint 5**: Reminders + Parse Review + Polish

---

## Conclusion

✅ **Proceed with implementation**

The specification is production-ready with minor clarifications needed. All technical components are feasible and well-supported. The MVP scope is appropriate for an initial release.

**Recommendation**: Start with Sprint 0 (setup) if needed, then proceed sequentially through the 5 sprints.
