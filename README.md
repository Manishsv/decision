# DIGIT Decision

**A desktop application for collecting structured data via email and Google Sheets.**

DIGIT Decision helps organizations collect structured data from multiple participants through email requests. Responses are automatically parsed and stored in Google Sheets, with an AI-powered assistant to help manage the entire process.

## Features

- 📧 **Email-Based Data Collection**: Send structured data requests via Gmail
- 📊 **Google Sheets Integration**: Automatically organize responses in spreadsheets
- 🤖 **AI Assistant**: Natural language interface for managing data collection
- 👥 **Participant Management**: Track responses, send reminders, manage participants
- 📈 **Response Tracking**: Monitor who has responded and who is pending
- 🔄 **Iterative Requests**: Send recurring requests with updated due dates
- 🎨 **Modern UI**: Clean, intuitive interface with dark/light theme support

## Prerequisites

- Flutter SDK (3.7.2 or higher)
- Dart SDK (3.7.2 or higher)
- Google Cloud Platform account with:
  - Gmail API enabled
  - Google Sheets API enabled
  - OAuth 2.0 credentials configured
- (Optional) OpenAI API key for AI features

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/decision-agent.git
cd decision-agent
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment Variables

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` and add your Google OAuth credentials:

```env
GOOGLE_OAUTH_CLIENT_ID=your_client_id_here.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET=your_client_secret_here
GOOGLE_OAUTH_REDIRECT_URI=com.yourcompany.decisionagent:/oauth/callback
```

**How to Get OAuth Credentials:**

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - Gmail API
   - Google Sheets API
   - Google Drive API (for sheet creation)
4. Navigate to "APIs & Services" > "Credentials"
5. Click "Create Credentials" > "OAuth 2.0 Client ID"
6. Select "Desktop app" as application type
7. Add authorized redirect URI matching your `.env` configuration
8. Copy the Client ID and Client Secret to your `.env` file

**Important:** The `.env` file is gitignored for security. Never commit your actual credentials.

### 4. Update macOS Configuration (for macOS builds)

Edit `macos/Runner/Info.plist` and ensure the URL scheme matches your redirect URI:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.yourcompany.decisionagent</string>
    </array>
  </dict>
</array>
```

### 5. Run the Application

```bash
flutter run -d macos
# or
flutter run -d windows
# or
flutter run -d linux
```

## Usage

### Getting Started

1. **Sign In**: Launch the app and sign in with your Google account
2. **Create Conversation**: Click "New Conversation" to start
3. **Define Schema**: Use the AI assistant or manual builder to define data fields
4. **Add Participants**: Add email addresses of participants
5. **Send Request**: Send the data collection request via email
6. **Track Responses**: Monitor responses in the Inspector panel
7. **View Data**: Open the Google Sheet to see all collected responses

### Using the AI Assistant

The AI assistant can help you:
- Create new data collections
- Define schemas
- Add participants
- Send reminders
- Analyze responses
- Answer questions about your data

Simply type your request in natural language, e.g.:
- "Create a data collection for monthly finance reports"
- "Add john@example.com to this conversation"
- "Send reminders to pending participants"

## Configuration

### OpenAI API Key (Optional)

To use AI features, you'll need an OpenAI API key:

1. Get your API key from [OpenAI Platform](https://platform.openai.com/api-keys)
2. Add it to `.env`:
   ```env
   OPENAI_API_KEY=sk-your_key_here
   ```
   Or set it in the app Settings page after installation

### Google Sheets

The app automatically creates Google Sheets for each conversation. Sheets are created in your Google Drive and shared with participants automatically when requests are sent.

## Security Considerations

This application uses OAuth 2.0 with PKCE for secure authentication. However, as a desktop application, the OAuth client secret is bundled with the app. Please review [SECURITY_NOTES.md](SECURITY_NOTES.md) for detailed security information and recommendations.

**Important Security Notes:**
- Never share your `.env` file
- Use OAuth credentials with appropriate scopes
- Set up quota limits in Google Cloud Console
- Monitor OAuth usage regularly
- For production deployments, consider using an OAuth proxy server

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and contribution guidelines.

### Project Structure

```
lib/
├── app/              # App configuration, routing, theming
├── core/             # Core configuration (OAuth, etc.)
├── data/             # Data layer (database, Google APIs)
├── domain/           # Domain models and schemas
├── features/         # Feature modules
│   ├── home/         # Main app interface
│   ├── onboarding/   # Authentication flow
│   ├── profile/      # User profile
│   ├── request_builder/  # Request creation UI
│   └── settings/     # App settings
├── services/         # Business logic services
└── utils/            # Utility functions
```

### Building

```bash
# Build for macOS
flutter build macos

# Build for Windows
flutter build windows

# Build for Linux
flutter build linux
```

## Troubleshooting

### OAuth Errors

- **"Redirect URI mismatch"**: Ensure the redirect URI in `.env` matches your Google Cloud Console configuration and `Info.plist`
- **"Invalid client"**: Verify your Client ID and Secret are correct
- **"Access denied"**: Check that required APIs are enabled in Google Cloud Console

### Database Issues

If you encounter database errors:
- Delete the app's data directory (app will recreate on next launch)
- On macOS: `~/Library/Application Support/decision_agent/`
- Database will be automatically recreated

### API Errors

- **"Quota exceeded"**: Check your Google Cloud Console quotas
- **"Permission denied"**: Ensure OAuth scopes are correctly configured
- **Network errors**: Check your internet connection and firewall settings

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/decision-agent/issues)
- **Documentation**: See `/docs` directory
- **Security**: See [SECURITY_NOTES.md](SECURITY_NOTES.md)

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Uses [Drift](https://drift.simonbinder.eu/) for database management
- Integrates with Google APIs via [googleapis](https://pub.dev/packages/googleapis)

---

**Note**: This is an open source project. Use at your own risk. For production deployments, follow security best practices outlined in SECURITY_NOTES.md.
