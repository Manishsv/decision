import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:decision_agent/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // .env file not found, but that's okay - we'll use defaults
    debugPrint('Warning: .env file not found, using default values: $e');
  }
  
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
