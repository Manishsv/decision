/// Request builder page - multi-step form for creating data requests

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:decision_agent/features/request_builder/request_builder_controller.dart';
import 'package:decision_agent/features/request_builder/schema_editor.dart';
import 'package:decision_agent/features/request_builder/recipients_editor.dart';
import 'package:decision_agent/features/request_builder/due_date_picker.dart';
import 'package:decision_agent/features/request_builder/sheet_section.dart';
import 'package:decision_agent/features/request_builder/send_section.dart';

class RequestBuilderPage extends ConsumerStatefulWidget {
  const RequestBuilderPage({super.key});

  @override
  ConsumerState<RequestBuilderPage> createState() => _RequestBuilderPageState();
}

class _RequestBuilderPageState extends ConsumerState<RequestBuilderPage> {
  final _pageController = PageController();
  int _currentStep = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleCancel(BuildContext context, RequestBuilderState state) async {
    // Check if user has entered any data
    final hasData = state.title.isNotEmpty ||
        state.schema.columns.isNotEmpty ||
        state.recipients.isNotEmpty ||
        state.requestId != null;

    if (hasData) {
      // Show confirmation dialog if data has been entered
      final shouldCancel = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel Request?'),
          content: const Text(
            'You have unsaved changes. Are you sure you want to cancel?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continue Editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Cancel Request'),
            ),
          ],
        ),
      );

      if (shouldCancel != true) {
        return; // User chose to continue editing
      }
    }

    // Navigate back to home
    if (context.mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(requestBuilderControllerProvider.notifier);
    final state = ref.watch(requestBuilderControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Data Request'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _handleCancel(context, state),
          tooltip: 'Cancel',
        ),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() {
                  _currentStep--;
                });
              },
              child: const Text('Back'),
            ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe
        onPageChanged: (index) {
          setState(() {
            _currentStep = index;
          });
        },
        children: [
          // Step 1: Basic Info
          _BasicInfoStep(
            onNext: () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              setState(() {
                _currentStep++;
              });
            },
          ),
          // Step 2: Schema Editor
          const SchemaEditor(),
          // Step 3: Recipients
          const RecipientsEditor(),
          // Step 4: Due Date
          const DueDatePicker(),
          // Step 5: Sheet Creation
          const SheetSection(),
          // Step 6: Send/Preview
          const SendSection(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step ${_currentStep + 1} of 6',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_currentStep < 5)
              ElevatedButton(
                onPressed: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                  setState(() {
                    _currentStep++;
                  });
                },
                child: const Text('Next'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Step 1: Basic Info (Title and Instructions)
class _BasicInfoStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const _BasicInfoStep({required this.onNext});

  @override
  ConsumerState<_BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends ConsumerState<_BasicInfoStep> {
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(requestBuilderControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Basic Information',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Request Title *',
              hintText: 'e.g., Q4 Sales Data',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              controller.updateTitle(value);
            },
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _instructionsController,
            decoration: const InputDecoration(
              labelText: 'Instructions (Optional)',
              hintText: 'Additional instructions for recipients...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            onChanged: (value) {
              controller.updateInstructions(value);
            },
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _titleController.text.trim().isEmpty
                  ? null
                  : () {
                      widget.onNext();
                    },
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }
}
