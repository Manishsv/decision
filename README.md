# DIGIT Decision

**Accelerate data collection to decision-making using email and spreadsheets.**

DIGIT Decision is a powerful tool that helps organizations collect structured data in prespecified formats, track collection requests, ensure data quality and completeness, analyze responses, and track decisions to closure. By leveraging existing tools like email and Google Sheets, it streamlines the journey from data collection to informed decision-making.

The platform enables you to:
- **Define structured data formats** with validation rules to ensure data quality, completeness, and correctness
- **Track collection requests** and monitor response status across all participants
- **Automatically parse and validate** responses against your specified rules
- **Analyze collected data** with AI-powered insights and visualizations
- **Track decisions to closure** with complete audit trails and status monitoring

Ideal for government officers managing program data, NGOs tracking project outcomes, and businesses collecting operational metrics—any organization that needs to gather structured information from multiple stakeholders efficiently.

## Features

- 📋 **Prespecified Data Formats**: Define structured schemas with validation rules to ensure data quality, completeness, and correctness
- 📧 **Email-Based Data Collection**: Send structured data requests via Gmail to multiple participants
- 📊 **Google Sheets Integration**: Automatically organize and store validated responses in spreadsheets
- ✅ **Data Quality Assurance**: Enforce validation rules during format specification to ensure data correctness and completeness
- 🤖 **AI Assistant**: Natural language interface for managing data collection, analysis, and decision tracking
- 📈 **Data Analysis & Visualization**: Generate charts, insights, and visualizations from collected data
- 👥 **Participant Management**: Track responses, send reminders, manage participants, and monitor completion status
- 📉 **Request Tracking**: Monitor collection requests from initiation to closure with complete audit trails
- 🔄 **Iterative Requests**: Send recurring requests with updated due dates and track progress over time
- 🎯 **Decision Tracking**: Track decisions from data collection through analysis to final closure
- 💾 **Persistent Conversations**: All AI conversations, visualizations, and suggestions are saved
- 🎨 **Modern UI**: Clean, intuitive interface with dark/light theme support

## Prerequisites

- Flutter SDK (3.7.2 or higher)
- Dart SDK (3.7.2 or higher)
- Python 3.7+ (for data visualization features)
  - Required packages: `pandas`, `matplotlib`, `seaborn`
  - See [Python Installation Guide](docs/PYTHON_INSTALLATION.md) for setup instructions
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
2. **Create Conversation**: Click "New Conversation" to start a new data collection project
3. **Define Schema**: Use the AI assistant or manual builder to define data fields with validation rules (required fields, data types, formats)
4. **Add Participants**: Add email addresses of participants who will provide data
5. **Send Request**: Send the structured data collection request via email
6. **Track Responses**: Monitor response status, data quality, and completeness in the Inspector panel
7. **Validate Data**: Review parsed responses and ensure they meet your specified quality rules
8. **Analyze Data**: Use AI-powered analysis to gain insights from collected data
9. **Track to Closure**: Monitor the decision-making process from data collection through final closure
10. **View Data**: Open the Google Sheet to see all collected and validated responses

### Use Cases

**Government Officers**: Collect program data, track project outcomes, monitor compliance metrics, and make data-driven policy decisions.

**NGOs**: Gather project impact data, track beneficiary information, collect survey responses, and measure program effectiveness.

**Businesses**: Collect operational metrics, gather customer feedback, track performance indicators, and make informed business decisions.

### Using the AI Assistant

The AI assistant can help you:
- Create new data collections with structured formats
- Define schemas with validation rules for data quality
- Add participants and manage response tracking
- Send reminders to ensure data completeness
- Validate responses against your specified rules
- Analyze responses and generate visualizations
- Answer questions about your data quality and completeness
- Track decisions from collection to closure
- Suggest data analyses based on your data

Simply type your request in natural language, e.g.:
- "Create a data collection for monthly finance reports with required fields for amount, date, and category"
- "Add john@example.com to this conversation"
- "Send reminders to participants who haven't responded"
- "Check data quality and show me any incomplete or invalid responses"
- "Show me revenue trends over time"
- "Generate a visualization comparing expenses by program"
- "Track the status of this decision request"

The assistant can also suggest analyses and generate interactive charts that persist across app sessions, helping you move from raw data to actionable insights.

## Configuration

### OpenAI API Key (Optional)

To use AI features, you'll need an OpenAI API key:

1. Get your API key from [OpenAI Platform](https://platform.openai.com/api-keys)
2. Add it to `.env`:
   ```env
   OPENAI_API_KEY=sk-your_key_here
   ```
   Or set it in the app Settings page after installation

### Python Installation (Required for Visualizations)

The app uses Python to generate data visualizations. Python 3.7+ is required with the following packages:
- `pandas` - Data manipulation
- `matplotlib` - Chart generation
- `seaborn` - Statistical visualizations

The app will check for Python installation on first use and provide installation guidance if needed. See [Python Installation Guide](docs/PYTHON_INSTALLATION.md) for detailed setup instructions.

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

### Architecture

For a detailed overview of the application architecture, module interactions, and design patterns, see [ARCHITECTURE.md](docs/ARCHITECTURE.md).

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
│   ├── ai_agent_service.dart      # AI orchestration
│   ├── request_service.dart        # Request management
│   ├── ingestion_service.dart      # Email response processing
│   ├── visualization_service.dart  # Data visualization
│   └── parsing_service.dart        # Email parsing
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

### Python/Visualization Errors

- **"Python not found"**: Install Python 3.7+ and ensure it's in your PATH
- **"Missing packages"**: Install required packages: `pip install pandas matplotlib seaborn`
- **"Visualization not showing"**: Check that Python script executed successfully (check console logs)
- See [Python Installation Guide](docs/PYTHON_INSTALLATION.md) for detailed troubleshooting

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## Documentation

- **[Architecture Documentation](docs/ARCHITECTURE.md)**: Comprehensive overview of system architecture, modules, and interactions
- **[Python Installation Guide](docs/PYTHON_INSTALLATION.md)**: Detailed instructions for setting up Python and required packages
- **[Security Notes](SECURITY_NOTES.md)**: Security considerations and best practices
- **[Contributing Guide](CONTRIBUTING.md)**: Development setup and contribution guidelines

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/decision-agent/issues)
- **Documentation**: See `/docs` directory
- **Security**: See [SECURITY_NOTES.md](SECURITY_NOTES.md)

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Uses [Drift](https://drift.simonbinder.eu/) for database management
- Integrates with Google APIs via [googleapis](https://pub.dev/packages/googleapis)
- AI powered by [OpenAI](https://openai.com/) Function Calling
- Data visualization powered by Python (pandas, matplotlib, seaborn)

---

**Note**: This is an open source project. Use at your own risk. For production deployments, follow security best practices outlined in SECURITY_NOTES.md.
