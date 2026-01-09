/// Visualization Service
/// Executes Python scripts to generate data visualizations

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:decision_agent/services/python_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of visualization generation
class VisualizationResult {
  final bool success;
  final Uint8List? imageData; // PNG image bytes
  final String? error;
  final String? pythonCode;
  final String? description;

  VisualizationResult({
    required this.success,
    this.imageData,
    this.error,
    this.pythonCode,
    this.description,
  });
}

/// Service for generating data visualizations using Python
class VisualizationService {
  final PythonService _pythonService;

  VisualizationService(this._pythonService);

  /// Generate visualization from Python code
  Future<VisualizationResult> generateVisualization({
    required String pythonCode,
    required List<List<String>> sheetData,
    required List<String> headers,
    String? description,
  }) async {
    try {
      // Check Python installation
      final pythonCheck = await _pythonService.checkPythonInstallation();
      if (!pythonCheck.isReady) {
        return VisualizationResult(
          success: false,
          error:
              'Python is not installed or packages are missing. '
              'Please check Settings > Python Environment.',
          pythonCode: pythonCode,
          description: description,
        );
      }

      final pythonExec = await _pythonService.getPythonExecutable();
      if (pythonExec == null) {
        return VisualizationResult(
          success: false,
          error: 'Could not find Python executable',
          pythonCode: pythonCode,
          description: description,
        );
      }

      // Create temporary directory for script and data
      final tempDir = await getTemporaryDirectory();
      final scriptPath = p.join(
        tempDir.path,
        'visualization_${DateTime.now().millisecondsSinceEpoch}.py',
      );
      final dataPath = p.join(
        tempDir.path,
        'data_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      final outputPath = p.join(
        tempDir.path,
        'output_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      try {
        // Convert sheet data to JSON format
        final jsonData = _convertSheetDataToJson(sheetData, headers);
        await File(dataPath).writeAsString(jsonEncode(jsonData));

        // Create Python script wrapper
        final wrappedScript = _wrapPythonScript(
          pythonCode,
          dataPath,
          outputPath,
        );

        // Write script to file
        await File(scriptPath).writeAsString(wrappedScript);

        // Execute Python script
        final result = await Process.run(
          pythonExec,
          [scriptPath],
          runInShell: true,
          workingDirectory: tempDir.path,
        );

        if (result.exitCode != 0) {
          debugPrint('Python script error: ${result.stderr}');
          return VisualizationResult(
            success: false,
            error: 'Python script failed:\n${result.stderr}',
            pythonCode: pythonCode,
            description: description,
          );
        }

        // Read generated image
        final imageFile = File(outputPath);
        if (!await imageFile.exists()) {
          return VisualizationResult(
            success: false,
            error: 'Visualization image was not generated',
            pythonCode: pythonCode,
            description: description,
          );
        }

        final imageData = await imageFile.readAsBytes();

        // Clean up temporary files
        try {
          await File(scriptPath).delete();
          await File(dataPath).delete();
          await imageFile.delete();
        } catch (e) {
          debugPrint('Warning: Could not clean up temp files: $e');
        }

        return VisualizationResult(
          success: true,
          imageData: imageData,
          pythonCode: pythonCode,
          description: description,
        );
      } finally {
        // Ensure cleanup even on error
        try {
          final scriptFile = File(scriptPath);
          final dataFile = File(dataPath);
          final outputFile = File(outputPath);

          if (await scriptFile.exists()) await scriptFile.delete();
          if (await dataFile.exists()) await dataFile.delete();
          if (await outputFile.exists()) await outputFile.delete();
        } catch (e) {
          debugPrint('Warning: Cleanup error: $e');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Visualization error: $e');
      debugPrint('Stack trace: $stackTrace');
      return VisualizationResult(
        success: false,
        error: 'Error generating visualization: $e',
        pythonCode: pythonCode,
        description: description,
      );
    }
  }

  /// Convert sheet data to JSON format for Python
  Map<String, dynamic> _convertSheetDataToJson(
    List<List<String>> sheetData,
    List<String> headers,
  ) {
    if (sheetData.isEmpty || headers.isEmpty) {
      return {'headers': [], 'rows': []};
    }

    // Filter out metadata columns (starting with __)
    final dataHeaders = headers.where((h) => !h.startsWith('__')).toList();
    final dataHeaderIndices =
        dataHeaders.map((h) => headers.indexOf(h)).toList();

    // Convert rows to objects
    final rows = <Map<String, dynamic>>[];
    for (int i = 1; i < sheetData.length; i++) {
      final row = sheetData[i];
      if (row.isEmpty) continue;

      final rowData = <String, dynamic>{};
      for (int j = 0; j < dataHeaderIndices.length; j++) {
        final headerIndex = dataHeaderIndices[j];
        if (headerIndex < row.length) {
          rowData[dataHeaders[j]] = row[headerIndex];
        }
      }
      rows.add(rowData);
    }

    return {'headers': dataHeaders, 'rows': rows};
  }

  /// Wrap user's Python code with data loading and image saving
  String _wrapPythonScript(
    String userCode,
    String dataPath,
    String outputPath,
  ) {
    // Normalize paths for cross-platform compatibility
    final normalizedDataPath = dataPath.replaceAll('\\', '/');
    final normalizedOutputPath = outputPath.replaceAll('\\', '/');

    // Indent user code to match try block indentation (4 spaces)
    final indentedUserCode = userCode
        .split('\n')
        .map((line) => line.isEmpty ? line : '    $line')
        .join('\n');

    return '''
import json
import sys
import os
import pandas as pd
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
import seaborn as sns

# Set style
plt.style.use('seaborn-v0_8-darkgrid')
sns.set_palette("husl")

# Load data
try:
    with open(r'$normalizedDataPath', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    headers = data.get('headers', [])
    rows = data.get('rows', [])
    
    if not rows:
        print("Error: No data rows found", file=sys.stderr)
        sys.exit(1)
    
    # Convert to DataFrame
    df = pd.DataFrame(rows)
    
    # Convert numeric columns
    for col in df.columns:
        try:
            df[col] = pd.to_numeric(df[col], errors='ignore')
        except:
            pass
    
    # User's code here
$indentedUserCode
    
    # Save figure with larger size and better quality
    plt.tight_layout(pad=2.0)
    plt.savefig(r'$normalizedOutputPath', dpi=200, bbox_inches='tight', facecolor='white', pad_inches=0.2)
    plt.close()
    
except Exception as e:
    print(f"Error: {str(e)}", file=sys.stderr)
    import traceback
    traceback.print_exc(file=sys.stderr)
    sys.exit(1)
''';
  }

  /// Generate Python code for a specific analysis type
  Future<String> generatePythonCode({
    required String analysisType,
    required List<String> headers,
    Map<String, dynamic>? parameters,
  }) async {
    // This will be enhanced with LLM code generation
    // For now, return template code based on analysis type

    switch (analysisType.toLowerCase()) {
      case 'trend':
      case 'trends':
        return _generateTrendCode(headers, parameters);
      case 'distribution':
      case 'dist':
        return _generateDistributionCode(headers, parameters);
      case 'correlation':
      case 'corr':
        return _generateCorrelationCode(headers, parameters);
      case 'summary':
      case 'stats':
        return _generateSummaryCode(headers, parameters);
      default:
        return _generateGeneralCode(headers, parameters);
    }
  }

  String _generateTrendCode(
    List<String> headers,
    Map<String, dynamic>? params,
  ) {
    // Support x_axis and y_axis parameters from user
    final xAxis =
        params?['x_axis'] as String? ??
        params?['date_column'] as String? ??
        headers.firstWhere(
          (h) =>
              h.toLowerCase().contains('date') ||
              h.toLowerCase().contains('time') ||
              h.toLowerCase().contains('month'),
          orElse: () => headers[0],
        );

    // Support multiple y-axis values (for multiple lines)
    final yAxisParam = params?['y_axis'] as dynamic;
    List<String> yAxisCols = [];

    if (yAxisParam is List) {
      yAxisCols = yAxisParam.cast<String>();
    } else if (yAxisParam is String) {
      yAxisCols = [yAxisParam];
    } else if (params?['value_columns'] is List) {
      yAxisCols = (params!['value_columns'] as List).cast<String>();
    } else if (params?['lines'] is List) {
      yAxisCols = (params!['lines'] as List).cast<String>();
    } else {
      // Auto-detect Expense and Revenue columns
      final expenseCols =
          headers.where((h) => h.toLowerCase().contains('expense')).toList();
      final revenueCols =
          headers.where((h) => h.toLowerCase().contains('revenue')).toList();
      final expenseCol = expenseCols.isNotEmpty ? expenseCols.first : null;
      final revenueCol = revenueCols.isNotEmpty ? revenueCols.first : null;
      if (expenseCol != null && revenueCol != null) {
        yAxisCols = [expenseCol, revenueCol];
      } else {
        // Fallback to single value column
        final singleValueCol =
            params?['value_column'] as String? ??
            headers.firstWhere(
              (h) =>
                  h.toLowerCase().contains('amount') ||
                  h.toLowerCase().contains('value') ||
                  h.toLowerCase().contains('total'),
              orElse: () => headers.length > 1 ? headers[1] : headers[0],
            );
        yAxisCols = [singleValueCol];
      }
    }

    final title = params?['title'] as String? ?? 'Trend Analysis';
    final yAxisLabel = params?['y_axis_label'] as String? ?? 'Amount';

    // Check if user wants to group by category (e.g., Program Name)
    // Default: aggregate across all programs (aggregateByProgram = true)
    final groupByCategory = params?['group_by'] as String?;
    final aggregateByProgram =
        params?['aggregate_by_program'] as bool? ??
        true; // Default to true (aggregate)

    // Detect category columns (e.g., Program Name) for grouping
    String? categoryCol;
    bool shouldGroupByCategory = false;

    // Only group by category if explicitly requested (group_by specified and aggregate_by_program is false)
    if (groupByCategory != null) {
      categoryCol = groupByCategory;
      shouldGroupByCategory = !aggregateByProgram;
    } else if (params?['aggregate_by_program'] == false) {
      // If user explicitly set aggregate_by_program to false, auto-detect category column
      final categoryCols =
          headers
              .where(
                (h) =>
                    h.toLowerCase().contains('program') ||
                    h.toLowerCase().contains('name') ||
                    h.toLowerCase().contains('category') ||
                    h.toLowerCase().contains('project'),
              )
              .toList();
      if (categoryCols.isNotEmpty) {
        categoryCol = categoryCols.first;
        shouldGroupByCategory = true;
      }
    }
    // Otherwise, default to aggregating across all programs (shouldGroupByCategory = false)

    // Build aggregation code - default to aggregating all programs, unless group_by is specified
    final aggregationCode =
        shouldGroupByCategory && categoryCol != null
            ? '''
# Group by category and time period, then aggregate
if '$categoryCol' in df.columns:
    # Aggregate by category and time
    aggDict = {}
    for col in yAxisColumns:
        if col in df.columns:
            aggDict[col] = 'sum'
    
    df_agg = df.groupby(['$categoryCol', '_time_period'], as_index=False).agg(aggDict)
    df_agg['_time_period_str'] = df_agg['_time_period'].astype(str)
    df_agg = df_agg.sort_values('_time_period')
    
    # Plot separate lines for each category
    categories = sorted(df_agg['$categoryCol'].unique())
    colors = ['#2E86AB', '#A23B72', '#F18F01', '#C73E1D', '#6A994E', '#6C757D', '#28A745', '#DC3545']
    
    for catIdx, category in enumerate(categories):
        catData = df_agg[df_agg['$categoryCol'] == category].copy()
        catData = catData.sort_values('_time_period')
        for colIdx, col in enumerate(yAxisColumns):
            if col in catData.columns:
                label = f"{category} - {col}" if len(yAxisColumns) > 1 else f"{category}"
                ax.plot(catData['_time_period_str'], catData[col], 
                        marker='o', linewidth=2.5, markersize=7, 
                        label=label, color=colors[catIdx % len(colors)],
                        linestyle='-' if colIdx == 0 else '--')
else:
    # No category column, aggregate all data by time period
    aggDict = {}
    for col in yAxisColumns:
        if col in df.columns:
            aggDict[col] = 'sum'
    
    df_agg = df.groupby('_time_period', as_index=False).agg(aggDict)
    df_agg['_time_period_str'] = df_agg['_time_period'].astype(str)
    df_agg = df_agg.sort_values('_time_period')
    
    colors = ['#2E86AB', '#A23B72', '#F18F01', '#C73E1D', '#6A994E']
    for colIdx, col in enumerate(yAxisColumns):
        if col in df_agg.columns:
            ax.plot(df_agg['_time_period_str'], df_agg[col], 
                    marker='o', linewidth=2.5, markersize=7, 
                    label=col, color=colors[colIdx % len(colors)])
'''
            : '''
# Aggregate all data by time period (sum across all categories/programs)
aggDict = {}
for col in yAxisColumns:
    if col in df.columns:
        aggDict[col] = 'sum'

df_agg = df.groupby('_time_period', as_index=False).agg(aggDict)
df_agg['_time_period_str'] = df_agg['_time_period'].astype(str)
df_agg = df_agg.sort_values('_time_period')

# Plot aggregated lines (one line per Y-axis column)
colors = ['#2E86AB', '#A23B72', '#F18F01', '#C73E1D', '#6A994E']
for colIdx, col in enumerate(yAxisColumns):
    if col in df_agg.columns:
        ax.plot(df_agg['_time_period_str'], df_agg[col], 
                marker='o', linewidth=2.5, markersize=7, 
                label=col, color=colors[colIdx % len(colors)])
''';

    // Use larger figure size to fill more of the image
    return '''
# Trend Analysis - Aggregated by Time Period
fig, ax = plt.subplots(figsize=(16, 10))

# Convert x-axis column (time/date) and prepare for aggregation
xLabel = '$xAxis'
if '$xAxis' in df.columns:
    # Try to convert to datetime if it looks like dates
    try:
        df['$xAxis'] = pd.to_datetime(df['$xAxis'], errors='coerce')
        # Create time period column for aggregation (monthly by default)
        # Use the month/year as the time period key
        df['_time_period'] = df['$xAxis'].dt.to_period('M')
        # Convert to string for consistent sorting and display
        df['_time_period_str'] = df['_time_period'].astype(str)
        df = df.sort_values('$xAxis')
        ax.set_xlabel('$xAxis', fontsize=14, fontweight='bold')
        plt.xticks(rotation=45, ha='right')
    except Exception as e:
        # If datetime conversion fails, use the column as-is
        df['_time_period'] = df['$xAxis']
        df['_time_period_str'] = df['$xAxis'].astype(str)
        ax.set_xlabel('$xAxis', fontsize=14, fontweight='bold')
        plt.xticks(rotation=45, ha='right')
else:
    df['_time_period'] = df.index
    df['_time_period_str'] = df.index.astype(str)
    ax.set_xlabel('Index', fontsize=14, fontweight='bold')

# Aggregate data by time period
yAxisColumns = [${yAxisCols.map((c) => "'$c'").join(', ')}]
$aggregationCode

ax.set_ylabel('$yAxisLabel', fontsize=14, fontweight='bold')
ax.set_title('$title', fontsize=16, fontweight='bold', pad=20)
ax.legend(loc='best', fontsize=11, framealpha=0.9, ncol=1 if len(yAxisColumns) <= 3 else 2)
ax.grid(True, alpha=0.3, linestyle='--')
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
''';
  }

  String _generateDistributionCode(
    List<String> headers,
    Map<String, dynamic>? params,
  ) {
    final valueCol =
        params?['column'] as String? ??
        headers.firstWhere(
          (h) =>
              h.toLowerCase().contains('amount') ||
              h.toLowerCase().contains('value') ||
              h.toLowerCase().contains('total'),
          orElse: () => headers[0],
        );

    return '''
# Distribution Analysis
fig, axes = plt.subplots(1, 2, figsize=(14, 6))

# Histogram
axes[0].hist(df['$valueCol'].dropna(), bins=20, edgecolor='black', alpha=0.7)
axes[0].set_xlabel('$valueCol', fontsize=12)
axes[0].set_ylabel('Frequency', fontsize=12)
axes[0].set_title('Distribution of $valueCol', fontsize=14, fontweight='bold')
axes[0].grid(True, alpha=0.3)

# Box plot
axes[1].boxplot(df['$valueCol'].dropna(), vert=True)
axes[1].set_ylabel('$valueCol', fontsize=12)
axes[1].set_title('Box Plot: $valueCol', fontsize=14, fontweight='bold')
axes[1].grid(True, alpha=0.3)
''';
  }

  String _generateCorrelationCode(
    List<String> headers,
    Map<String, dynamic>? params,
  ) {
    // Find numeric columns
    final numericCols =
        headers
            .where(
              (h) =>
                  h.toLowerCase().contains('amount') ||
                  h.toLowerCase().contains('value') ||
                  h.toLowerCase().contains('total') ||
                  h.toLowerCase().contains('number') ||
                  h.toLowerCase().contains('count'),
            )
            .take(5)
            .toList();

    if (numericCols.isEmpty) {
      numericCols.addAll(headers.take(3));
    }

    return '''
# Correlation Analysis
numeric_df = df[${numericCols.map((c) => "'$c'").join(', ')}].select_dtypes(include=['number'])

if len(numeric_df.columns) > 1:
    fig, ax = plt.subplots(figsize=(10, 8))
    corr = numeric_df.corr()
    sns.heatmap(corr, annot=True, fmt='.2f', cmap='coolwarm', center=0, 
                square=True, linewidths=1, cbar_kws={"shrink": 0.8}, ax=ax)
    ax.set_title('Correlation Matrix', fontsize=14, fontweight='bold')
else:
    fig, ax = plt.subplots(figsize=(8, 6))
    ax.text(0.5, 0.5, 'Not enough numeric columns\\nfor correlation analysis', 
            ha='center', va='center', fontsize=14)
    ax.set_title('Correlation Analysis', fontsize=14, fontweight='bold')
''';
  }

  String _generateSummaryCode(
    List<String> headers,
    Map<String, dynamic>? params,
  ) {
    final numericCols =
        headers
            .where(
              (h) =>
                  h.toLowerCase().contains('amount') ||
                  h.toLowerCase().contains('value') ||
                  h.toLowerCase().contains('total'),
            )
            .take(3)
            .toList();

    if (numericCols.isEmpty) {
      numericCols.addAll(headers.take(2));
    }

    final numericColsList = numericCols.map((c) => "'$c'").join(', ');
    final numCols = numericCols.length;

    return '''
# Summary Statistics
numeric_cols_list = [$numericColsList]
fig, axes = plt.subplots($numCols, 1, figsize=(12, 4 * $numCols))

if $numCols == 1:
    axes = [axes]

for i, col in enumerate(numeric_cols_list):
    if col in df.columns:
        numeric_data = pd.to_numeric(df[col], errors='coerce').dropna()
        if len(numeric_data) > 0:
            axes[i].bar(['Mean', 'Median', 'Min', 'Max'], 
                       [numeric_data.mean(), numeric_data.median(), 
                        numeric_data.min(), numeric_data.max()],
                       color=['#3498db', '#2ecc71', '#e74c3c', '#f39c12'])
            axes[i].set_ylabel(col, fontsize=12)
            axes[i].set_title(f'Summary Statistics: {col}', fontsize=14, fontweight='bold')
            axes[i].grid(True, alpha=0.3, axis='y')
''';
  }

  String _generateGeneralCode(
    List<String> headers,
    Map<String, dynamic>? params,
  ) {
    return '''
# General Data Analysis
fig, axes = plt.subplots(2, 2, figsize=(14, 10))

# Basic info
axes[0, 0].text(0.1, 0.5, f'Total Rows: {len(df)}\\nTotal Columns: {len(df.columns)}', 
                fontsize=12, va='center')
axes[0, 0].set_title('Dataset Overview', fontsize=14, fontweight='bold')
axes[0, 0].axis('off')

# First numeric column distribution
numeric_cols = df.select_dtypes(include=['number']).columns
if len(numeric_cols) > 0:
    axes[0, 1].hist(df[numeric_cols[0]].dropna(), bins=20, edgecolor='black', alpha=0.7)
    axes[0, 1].set_title(f'Distribution: {numeric_cols[0]}', fontsize=12, fontweight='bold')
    axes[0, 1].grid(True, alpha=0.3)
else:
    axes[0, 1].text(0.5, 0.5, 'No numeric columns', ha='center', va='center')
    axes[0, 1].axis('off')

# Data types
axes[1, 0].text(0.1, 0.5, '\\n'.join([f'{col}: {str(dtype)}' 
                                     for col, dtype in list(df.dtypes.items())[:5]]), 
                fontsize=10, va='center', family='monospace')
axes[1, 0].set_title('Column Types', fontsize=12, fontweight='bold')
axes[1, 0].axis('off')

# Missing values
if df.isnull().sum().sum() > 0:
    missing = df.isnull().sum()
    axes[1, 1].barh(range(len(missing[missing > 0])), missing[missing > 0].values)
    axes[1, 1].set_yticks(range(len(missing[missing > 0])))
    axes[1, 1].set_yticklabels(missing[missing > 0].index)
    axes[1, 1].set_xlabel('Missing Count', fontsize=10)
    axes[1, 1].set_title('Missing Values', fontsize=12, fontweight='bold')
    axes[1, 1].grid(True, alpha=0.3, axis='x')
else:
    axes[1, 1].text(0.5, 0.5, 'No missing values', ha='center', va='center')
    axes[1, 1].axis('off')
''';
  }
}

/// Provider for VisualizationService
final visualizationServiceProvider = Provider<VisualizationService>((ref) {
  final pythonService = ref.read(pythonServiceProvider);
  return VisualizationService(pythonService);
});
