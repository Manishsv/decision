# Contributing to DIGIT Decision

Thank you for your interest in contributing to DIGIT Decision! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Respect different viewpoints and experiences

## Getting Started

### Prerequisites

- Flutter SDK 3.7.2 or higher
- Dart SDK 3.7.2 or higher
- Git
- Google Cloud Platform account (for testing)

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/yourusername/decision-agent.git
   cd decision-agent
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Set Up Environment**
   ```bash
   cp .env.example .env
   # Edit .env with your credentials (see README.md)
   ```

4. **Run the App**
   ```bash
   flutter run -d macos
   ```

### Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `dart format` to format code before committing
- Follow existing code patterns and conventions
- Add comments for complex logic

### Running Linters

```bash
flutter analyze
```

## Making Changes

### Branch Naming

Use descriptive branch names:
- `feature/description` for new features
- `fix/description` for bug fixes
- `docs/description` for documentation
- `refactor/description` for refactoring

### Commit Messages

Write clear, descriptive commit messages:
```
Short summary (50 chars or less)

More detailed explanation if needed. Explain what and why,
not how. Wrap at 72 characters.
```

### Pull Request Process

1. **Create a Branch**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make Your Changes**
   - Write clear, tested code
   - Update documentation as needed
   - Add tests if applicable

3. **Test Your Changes**
   ```bash
   flutter test
   flutter analyze
   ```

4. **Commit and Push**
   ```bash
   git add .
   git commit -m "Add feature description"
   git push origin feature/my-feature
   ```

5. **Create Pull Request**
   - Use the PR template
   - Describe what changes you made and why
   - Reference any related issues
   - Add screenshots for UI changes

### Pull Request Guidelines

- Keep PRs focused and reasonably sized
- Ensure all tests pass
- Update documentation as needed
- Request review from maintainers

## Project Structure

```
lib/
├── app/              # App configuration
├── core/             # Core configuration
├── data/             # Data layer
├── domain/           # Domain models
├── features/         # Feature modules
├── services/         # Business logic
└── utils/            # Utilities
```

## Testing

### Writing Tests

- Add unit tests for business logic
- Add widget tests for UI components
- Add integration tests for user flows

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

## Documentation

- Update README.md for user-facing changes
- Add doc comments for public APIs
- Update CONTRIBUTING.md if contributing process changes

## Reporting Bugs

### Before Submitting

1. Check existing issues
2. Test on latest version
3. Gather relevant information

### Bug Report Template

```markdown
**Describe the bug**
A clear description of the issue.

**To Reproduce**
Steps to reproduce the behavior.

**Expected behavior**
What you expected to happen.

**Screenshots**
If applicable.

**Environment:**
- OS: [e.g., macOS 14.0]
- Flutter version: [e.g., 3.7.2]
- App version: [e.g., 1.0.0]

**Additional context**
Any other relevant information.
```

## Suggesting Features

1. Check existing feature requests
2. Open a new issue with "Feature Request" label
3. Describe the feature and use case
4. Discuss implementation approach

## Code Review

### Review Checklist

- [ ] Code follows style guidelines
- [ ] Tests are included and passing
- [ ] Documentation is updated
- [ ] No security issues introduced
- [ ] Performance considerations addressed

## Questions?

- Open an issue for questions
- Check existing documentation
- Ask in discussions

Thank you for contributing! 🎉
