/// Request schema domain models

import 'package:decision_agent/domain/models.dart';

/// Schema column definition
class SchemaColumn {
  final String name;
  final ColumnType type;
  final bool required;

  const SchemaColumn({
    required this.name,
    required this.type,
    required this.required,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'required': required,
      };

  factory SchemaColumn.fromJson(Map<String, dynamic> json) => SchemaColumn(
        name: json['name'] as String,
        type: ColumnType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => ColumnType.stringType,
        ),
        required: json['required'] as bool? ?? false,
      );
}

/// Request schema definition
class RequestSchema {
  final List<SchemaColumn> columns;

  const RequestSchema({required this.columns});

  Map<String, dynamic> toJson() => {
        'columns': columns.map((c) => c.toJson()).toList(),
      };

  factory RequestSchema.fromJson(Map<String, dynamic> json) => RequestSchema(
        columns: (json['columns'] as List<dynamic>?)
                ?.map((c) => SchemaColumn.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
