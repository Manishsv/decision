# Security Notes: OAuth Client Secret in Desktop Apps

## Current Implementation

The app currently stores the OAuth Client Secret in the `.env` file, which is bundled with the app. This is a **known security limitation** for desktop applications.

## Security Considerations

### ⚠️ Client Secret Exposure Risk

1. **Desktop apps can be reverse-engineered**: Even if stored in `.env`, the secret can be extracted from the compiled app
2. **`.env` file is bundled as an asset**: The file is included in the app bundle and can be read
3. **No perfect protection**: Obfuscation doesn't prevent determined attackers

### ✅ Current Mitigations

1. **PKCE (Proof Key for Code Exchange)**: Using `flutter_appauth` with PKCE adds security
2. **Redirect URI restrictions**: Limits where OAuth callbacks can go
3. **Google's rate limiting**: Google has abuse detection and rate limits
4. **User consent required**: Attackers still need user consent to access data
5. **Not in git**: `.env` is gitignored, so not committed to version control

### 🔒 Best Practice (For Production)

**Option 1: Backend OAuth Proxy (Most Secure)**
- Create a backend server that holds the client secret
- Desktop app sends authorization code to backend
- Backend exchanges code for tokens
- Backend returns tokens to desktop app
- **Pros**: Secret never exposed to client
- **Cons**: Requires backend infrastructure, more complex

**Option 2: Accept the Risk (Current Approach)**
- Accept that desktop apps cannot fully protect secrets
- Use PKCE and redirect URI restrictions
- Monitor for abuse in Google Cloud Console
- Set up quota limits and alerts
- **Pros**: Simpler, works for MVP
- **Cons**: Secret can be extracted

**Option 3: OAuth Device Flow**
- Use OAuth 2.0 Device Flow (Google supports this)
- User enters code on web browser
- No client secret needed
- **Pros**: No secret in app
- **Cons**: Less user-friendly, requires web component

## Recommendation for MVP

For MVP, **Option 2 (Current Approach)** is acceptable because:
1. Google requires client secret for desktop apps
2. DataInbox uses the same approach
3. The risk is manageable with mitigations
4. Most desktop apps face this limitation
5. Users still control access (must grant consent)

## For Production/Scale

Consider implementing **Option 1 (Backend Proxy)** if:
- Handling sensitive data at scale
- Need better security guarantees
- Have backend infrastructure
- Want to monitor/control access centrally

## Google Cloud Console Recommendations

1. **Set up OAuth consent screen properly**
   - Use internal/trusted testers only if possible
   - Clearly describe app permissions

2. **Enable quota limits and alerts**
   - Set daily quota limits
   - Configure alerts for unusual activity

3. **Restrict redirect URIs**
   - Only allow your specific redirect URI
   - Don't use wildcards

4. **Monitor usage**
   - Review OAuth usage regularly
   - Check for unauthorized access

5. **Consider OAuth app restrictions**
   - Limit to specific IPs if possible (not feasible for desktop apps)
   - Use domain verification if applicable

## References

- [Google OAuth 2.0 for Desktop Apps](https://developers.google.com/identity/protocols/oauth2/native-app)
- [PKCE RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636)
- [OAuth 2.0 Security Best Practices](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics)
