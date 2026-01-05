/// ID generation utilities

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generate a new UUID
String generateId() => _uuid.v4();

/// Generate a request ID (UUID format)
String generateRequestId() => _uuid.v4();
