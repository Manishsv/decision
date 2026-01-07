/// Input validation utilities
/// 
/// Provides functions for validating user inputs with user-friendly error messages

/// Email validation regex - RFC 5322 compliant (simplified)
final _emailRegex = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

/// Validation result
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
  });

  const ValidationResult.success()
      : isValid = true,
        errorMessage = null;

  const ValidationResult.failure(this.errorMessage) : isValid = false;
}

/// Validate an email address
/// Returns ValidationResult with user-friendly error message if invalid
ValidationResult validateEmail(String email) {
  if (email.trim().isEmpty) {
    return const ValidationResult.failure('Email address is required');
  }

  final trimmedEmail = email.trim();

  // Check for basic structure
  if (!trimmedEmail.contains('@')) {
    return const ValidationResult.failure(
      'Email address must contain an @ symbol',
    );
  }

  if (!trimmedEmail.contains('.')) {
    return const ValidationResult.failure(
      'Email address must contain a domain (e.g., example.com)',
    );
  }

  // Check for @ at start or end
  if (trimmedEmail.startsWith('@') || trimmedEmail.endsWith('@')) {
    return const ValidationResult.failure(
      'Email address cannot start or end with @',
    );
  }

  // Check for multiple @ symbols
  if (trimmedEmail.split('@').length != 2) {
    return const ValidationResult.failure(
      'Email address can only contain one @ symbol',
    );
  }

  // Check for valid format using regex
  if (!_emailRegex.hasMatch(trimmedEmail)) {
    return const ValidationResult.failure(
      'Please enter a valid email address (e.g., user@example.com)',
    );
  }

  return const ValidationResult.success();
}

/// Validate multiple email addresses
/// Returns list of validation results, one per email
List<ValidationResult> validateEmails(List<String> emails) {
  return emails.map(validateEmail).toList();
}

/// Validate that a string is not empty
ValidationResult validateRequired(String value, [String? fieldName]) {
  if (value.trim().isEmpty) {
    final field = fieldName ?? 'Field';
    return ValidationResult.failure('$field is required');
  }
  return const ValidationResult.success();
}

/// Validate that a string has minimum length
ValidationResult validateMinLength(
  String value,
  int minLength, [
  String? fieldName,
]) {
  if (value.trim().length < minLength) {
    final field = fieldName ?? 'Field';
    return ValidationResult.failure(
      '$field must be at least $minLength characters',
    );
  }
  return const ValidationResult.success();
}

/// Validate OpenAI API key format
/// OpenAI keys start with 'sk-' and are typically 51 characters
ValidationResult validateOpenAiKey(String key) {
  if (key.trim().isEmpty) {
    return const ValidationResult.success(); // Optional field
  }

  final trimmedKey = key.trim();

  if (!trimmedKey.startsWith('sk-')) {
    return const ValidationResult.failure(
      'OpenAI API key must start with "sk-"',
    );
  }

  if (trimmedKey.length < 20) {
    return const ValidationResult.failure(
      'OpenAI API key appears to be too short',
    );
  }

  if (trimmedKey.length > 200) {
    return const ValidationResult.failure(
      'OpenAI API key appears to be too long',
    );
  }

  return const ValidationResult.success();
}
