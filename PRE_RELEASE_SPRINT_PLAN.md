# Pre-Release Sprint Plan

## Overview
This sprint plan outlines all tasks required to prepare DIGIT Decision for open source release.

---

## Sprint 1: Documentation & Licensing (High Priority)

### 1.1 Remove Internal Documentation
- [ ] Delete `SPRINT_PLAN.md` (internal planning)
- [ ] Delete `AI_AGENT_TOOLS_PLAN.md` (internal design)
- [ ] Delete `CONVERSATION_MODEL.md` (internal architecture)
- [ ] Delete `RECURRING_REQUESTS_FEASIBILITY.md` (internal feasibility study)
- [ ] Delete `FEASIBILITY_REVIEW.md` (internal review)
- [ ] Keep `SECURITY_NOTES.md` (public-facing security documentation)
- [ ] Keep or move `docs/CODE_SIGNING_FIX.md` to main docs if user-relevant

### 1.2 Add MIT License
- [ ] Create `LICENSE` file with MIT License
- [ ] Include copyright notice with year and author

### 1.3 Create README.md
- [ ] Write comprehensive README with:
  - Project description and features
  - Screenshots/demo
  - Prerequisites
  - Installation instructions
  - Configuration (.env setup)
  - Usage guide
  - Contributing guidelines (link to CONTRIBUTING.md)
  - License info
  - Support/Issues links

### 1.4 Create .env.example
- [ ] Create `.env.example` template file
- [ ] Include all required environment variables with comments
- [ ] Add instructions for obtaining OAuth credentials
- [ ] Note security considerations

### 1.5 Create CONTRIBUTING.md
- [ ] Code style guidelines
- [ ] Development setup
- [ ] Testing requirements
- [ ] Pull request process
- [ ] Code of conduct

---

## Sprint 2: Code Quality & Cleanup (High Priority)

### 2.1 Remove Dead Code
- [ ] Remove `@Deprecated` methods (e.g., `appendRows` in sheets_service.dart)
- [ ] Remove TODO comments or convert to GitHub issues
  - [ ] `conversation_page.dart` line 632: TODO comment about checking if request was sent
- [ ] Remove unused imports
- [ ] Remove commented-out code blocks

### 2.2 Improve Debug Logging
- [ ] Replace `debugPrint` with proper logging framework or conditional logging
- [ ] Create `lib/utils/logger.dart` utility
- [ ] Use logger levels (info, warning, error)
- [ ] Keep debug prints only for development, remove from production builds

### 2.3 Code Comments & Documentation
- [ ] Add dartdoc comments to public APIs
- [ ] Document complex algorithms
- [ ] Add README to complex modules

---

## Sprint 3: Error Handling & User Experience (High Priority)

### 3.1 User-Friendly Error Messages
- [ ] Create error message utility for consistent formatting
- [ ] Replace technical error messages with user-friendly ones
- [ ] Add error recovery suggestions
- [ ] Map common exceptions to helpful messages:
  - [ ] OAuth errors → "Please check your internet connection and try again"
  - [ ] Google API errors → "Google service temporarily unavailable"
  - [ ] Database errors → "Data error. Please restart the app."
  - [ ] Network errors → "Network connection failed"

### 3.2 Error Handling Coverage
- [ ] Add try-catch blocks where missing
- [ ] Add null safety checks
- [ ] Validate user inputs (email formats, dates, etc.)
- [ ] Handle edge cases (empty lists, null values)

### 3.3 Loading States
- [ ] Ensure all async operations show loading indicators
- [ ] Add timeout handling for long-running operations
- [ ] Add progress indicators for batch operations

---

## Sprint 4: Database Performance & Optimization (Medium Priority)

### 4.1 Add Database Indexes
- [ ] Add index on `Requests.conversationId` (frequently queried)
- [ ] Add index on `RecipientStatusTable.requestId`
- [ ] Add index on `RecipientStatusTable.email`
- [ ] Add index on `ActivityLog.requestId`
- [ ] Add index on `AIChatMessages.conversationId`
- [ ] Add index on `ProcessedMessages.requestId`
- [ ] Add index on `Requests.templateRequestId` (for iteration queries)
- [ ] Add index on `Conversations.archived` (for filtering)

### 4.2 Implement Pagination
- [ ] Add pagination to `getConversations()` (limit/offset)
- [ ] Add pagination to `getActivityLogs()` (show last 50 by default)
- [ ] Add pagination to `getAIChatMessages()` (limit context window)
- [ ] Add pagination to conversation activity logs (inspector panel)
- [ ] Add "Load More" UI where appropriate

### 4.3 Query Optimization
- [ ] Review N+1 query patterns in `conversationParticipantsProvider`
- [ ] Batch queries where possible
- [ ] Cache frequently accessed data
- [ ] Add query result limits where appropriate

---

## Sprint 5: Security Improvements (High Priority)

### 5.1 Review SECURITY_NOTES.md
- [ ] Update with current security posture
- [ ] Add recommendations for production deployment
- [ ] Document known limitations clearly

### 5.2 Input Validation
- [ ] Validate email addresses
- [ ] Sanitize user inputs
- [ ] Validate OAuth redirect URIs
- [ ] Validate Google Sheet IDs

### 5.3 Secure Storage Review
- [ ] Verify credentials are stored securely
- [ ] Review token refresh logic
- [ ] Add token expiration handling

### 5.4 API Key Security
- [ ] Ensure OpenAI API key is stored securely
- [ ] Add key validation before saving
- [ ] Mask keys in UI

---

## Sprint 6: Performance & Scalability (Medium Priority)

### 6.1 Memory Management
- [ ] Review large object caching
- [ ] Add cleanup for unused data
- [ ] Optimize image loading (if any)

### 6.2 Network Optimization
- [ ] Add request retry logic with exponential backoff
- [ ] Implement request caching where appropriate
- [ ] Batch API calls where possible

### 6.3 UI Performance
- [ ] Review widget rebuilds
- [ ] Optimize list rendering (use ListView.builder properly)
- [ ] Add lazy loading for large lists

---

## Sprint 7: Testing & Quality Assurance (Medium Priority)

### 7.1 Add Unit Tests
- [ ] Test database operations
- [ ] Test data validation
- [ ] Test error handling

### 7.2 Add Integration Tests
- [ ] Test OAuth flow
- [ ] Test data ingestion flow
- [ ] Test AI agent interactions

### 7.3 Manual Testing Checklist
- [ ] Test on fresh install
- [ ] Test error scenarios
- [ ] Test with large datasets
- [ ] Test dark/light theme
- [ ] Test all user flows

---

## Sprint 8: Developer Experience (Low Priority)

### 8.1 Development Tools
- [ ] Add pre-commit hooks (formatting, linting)
- [ ] Add code formatting configuration
- [ ] Add linting rules documentation

### 8.2 Documentation
- [ ] Add architecture overview
- [ ] Document key design decisions
- [ ] Add API documentation
- [ ] Create developer onboarding guide

### 8.3 Build & Release
- [ ] Create release checklist
- [ ] Document build process
- [ ] Add version management strategy

---

## Priority Ranking

### Must Have Before Release (P0)
1. ✅ Sprint 1: Documentation & Licensing
2. ✅ Sprint 3: Error Handling & User Experience (critical parts)
3. ✅ Sprint 5: Security Improvements (review & documentation)
4. ✅ Sprint 2: Remove Dead Code

### Should Have Before Release (P1)
5. Sprint 4: Database Performance (indexes are critical)
6. Sprint 6: Performance (critical operations)

### Nice to Have (P2)
7. Sprint 7: Testing (basic tests)
8. Sprint 8: Developer Experience

---

## Estimated Timeline

- **Sprint 1**: 1-2 days
- **Sprint 2**: 1 day
- **Sprint 3**: 2-3 days
- **Sprint 4**: 1-2 days
- **Sprint 5**: 1 day
- **Sprint 6**: 1-2 days
- **Sprint 7**: 2-3 days (can be ongoing)
- **Sprint 8**: 1 day (can be ongoing)

**Total**: ~10-15 days for P0 + P1 items

---

## Next Steps

1. Review and prioritize this plan
2. Start with Sprint 1 (documentation)
3. Create GitHub issues for tracking
4. Begin implementation
