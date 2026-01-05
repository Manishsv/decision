/// Due date picker widget

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/features/request_builder/request_builder_controller.dart';

class DueDatePicker extends ConsumerStatefulWidget {
  const DueDatePicker({super.key});

  @override
  ConsumerState<DueDatePicker> createState() => _DueDatePickerState();
}

class _DueDatePickerState extends ConsumerState<DueDatePicker> {
  Future<void> _selectDate(BuildContext context) async {
    final state = ref.read(requestBuilderControllerProvider);
    final controller = ref.read(requestBuilderControllerProvider.notifier);

    final initialDate = state.dueDate ?? DateTime.now().add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      controller.updateDueDate(picked);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestBuilderControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Due Date',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'When should recipients respond by?',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    _formatDate(state.dueDate),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(state.dueDate == null ? 'Select Date' : 'Change Date'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
