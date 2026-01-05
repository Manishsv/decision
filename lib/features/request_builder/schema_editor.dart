/// Schema editor widget

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decision_agent/features/request_builder/request_builder_controller.dart';
import 'package:decision_agent/domain/request_schema.dart';
import 'package:decision_agent/domain/models.dart';

class SchemaEditor extends ConsumerStatefulWidget {
  const SchemaEditor({super.key});

  @override
  ConsumerState<SchemaEditor> createState() => _SchemaEditorState();
}

class _SchemaEditorState extends ConsumerState<SchemaEditor> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestBuilderControllerProvider);
    final controller = ref.watch(requestBuilderControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Define Data Schema',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add columns that recipients should fill in their responses',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: state.schema.columns.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_chart, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No columns yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Click "Add Column" to get started',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: state.schema.columns.length,
                    itemBuilder: (context, index) {
                      final column = state.schema.columns[index];
                      return _ColumnCard(
                        column: column,
                        index: index,
                        onUpdate: (updated) {
                          final newColumns = List<SchemaColumn>.from(state.schema.columns);
                          newColumns[index] = updated;
                          controller.updateSchema(RequestSchema(columns: newColumns));
                        },
                        onDelete: () {
                          final newColumns = List<SchemaColumn>.from(state.schema.columns);
                          newColumns.removeAt(index);
                          controller.updateSchema(RequestSchema(columns: newColumns));
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final newColumns = List<SchemaColumn>.from(state.schema.columns);
              newColumns.add(SchemaColumn(
                name: 'Column ${newColumns.length + 1}',
                type: ColumnType.stringType,
                required: false,
              ));
              controller.updateSchema(RequestSchema(columns: newColumns));
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Column'),
          ),
        ],
      ),
    );
  }
}

class _ColumnCard extends StatefulWidget {
  final SchemaColumn column;
  final int index;
  final ValueChanged<SchemaColumn> onUpdate;
  final VoidCallback onDelete;

  const _ColumnCard({
    required this.column,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_ColumnCard> createState() => _ColumnCardState();
}

class _ColumnCardState extends State<_ColumnCard> {
  late TextEditingController _nameController;
  late ColumnType _type;
  late bool _required;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.column.name);
    _type = widget.column.type;
    _required = widget.column.required;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _updateColumn() {
    widget.onUpdate(SchemaColumn(
      name: _nameController.text,
      type: _type,
      required: _required,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Column Name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _updateColumn(),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<ColumnType>(
                  value: _type,
                  items: ColumnType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_typeLabel(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _type = value;
                      });
                      _updateColumn();
                    }
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Required'),
              value: _required,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setState(() {
                  _required = value ?? false;
                });
                _updateColumn();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(ColumnType type) {
    switch (type) {
      case ColumnType.stringType:
        return 'Text';
      case ColumnType.numberType:
        return 'Number';
      case ColumnType.dateType:
        return 'Date';
    }
  }
}
