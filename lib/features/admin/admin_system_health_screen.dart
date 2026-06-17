import 'package:flutter/material.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/services/performance_monitor.dart';
import 'package:herbascan/core/services/usage_analytics.dart';
import 'package:herbascan/core/services/error_logger.dart';
import 'package:herbascan/core/services/ai_metrics_service.dart';

/// Admin-only System Health: AI metrics, live usage, and error logs.
/// Merges former Performance Metrics and Performance Dashboard.
class AdminSystemHealthScreen extends StatefulWidget {
  const AdminSystemHealthScreen({super.key});

  @override
  State<AdminSystemHealthScreen> createState() => _AdminSystemHealthScreenState();
}

class _AdminSystemHealthScreenState extends State<AdminSystemHealthScreen> {
  final _performanceMonitor = PerformanceMonitor();
  final _usageAnalytics = UsageAnalytics();
  final _errorLogger = ErrorLogger();
  final _aiMetricsService = AiMetricsService();

  Map<String, dynamic>? _performanceStats;
  Map<String, dynamic>? _usageStats;
  List<ErrorLog> _recentErrors = [];
  AiMetrics _aiMetrics = AiMetricsService.defaults;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await _usageAnalytics.initialize();
      final perfStats = await _performanceMonitor.getPerformanceStats();
      final usageStats = _usageAnalytics.getStatistics();
      final allErrors = await _errorLogger.getAllErrors();
      final recentErrors = allErrors.reversed.take(50).toList();
      final aiMetrics = await _aiMetricsService.loadMetrics();

      if (!mounted) return;
      setState(() {
        _performanceStats = perfStats;
        _usageStats = usageStats;
        _recentErrors = recentErrors;
        _aiMetrics = aiMetrics;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: AppTheme.errorDeep,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Text(
                'System Health',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildAISection(theme),
                  const SizedBox(height: 24),
                  _buildUsageSection(theme),
                  const SizedBox(height: 24),
                  _buildErrorSection(theme),
                  const SizedBox(height: 24),
                  _buildExportSection(theme),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAISection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'AI Model Metrics',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Edit model metrics',
              icon: const Icon(Icons.edit),
              onPressed: _showEditMetricsDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                'Accuracy',
                '${_aiMetrics.accuracy.toStringAsFixed(2)}%',
                Icons.check_circle_outline,
                AppTheme.botanicalPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme,
                'Precision',
                '${_aiMetrics.precision.toStringAsFixed(2)}%',
                Icons.track_changes,
                AppTheme.botanicalPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                'Recall',
                '${_aiMetrics.recall.toStringAsFixed(2)}%',
                Icons.search,
                AppTheme.botanicalPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme,
                'F1-Score',
                '${_aiMetrics.f1Score.toStringAsFixed(2)}%',
                Icons.balance,
                AppTheme.botanicalPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'MobileNet V2 · 42 Philippine medicinal plants',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildUsageSection(ThemeData theme) {
    final totalScans = _usageStats?['total_scans'] as int? ?? 0;
    final successfulScans = _usageStats?['successful_scans'] as int? ?? 0;
    final successRate = _usageStats?['success_rate'] as String? ?? '0%';
    final breakdown = _performanceStats?['operations_breakdown'] != null
        ? Map<String, dynamic>.from(
            _performanceStats!['operations_breakdown'] as Map)
        : <String, dynamic>{};
    int avgResponseMs = 0;
    if (breakdown.isNotEmpty) {
      final aiInference = breakdown['ai_inference'];
      if (aiInference != null) {
        avgResponseMs = (aiInference as Map)['avg_ms'] as int? ?? 0;
      }
      if (avgResponseMs == 0 && breakdown['gradcam_generation'] != null) {
        avgResponseMs =
            (breakdown['gradcam_generation'] as Map)['avg_ms'] as int? ?? 0;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Usage',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                'Total Scans',
                totalScans.toString(),
                Icons.qr_code_scanner,
                AppTheme.botanicalPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme,
                'Successful',
                successfulScans.toString(),
                Icons.check_circle_outline,
                AppTheme.safeGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                'Success Rate',
                successRate,
                Icons.percent,
                Colors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme,
                'Avg Response',
                avgResponseMs > 0 ? '${avgResponseMs}ms' : '—',
                Icons.timer_outlined,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Error Logs',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _recentErrors.isEmpty
            ? Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.safeGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'System stable. 0 errors recorded in this timeframe.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  itemCount: _recentErrors.length,
                  itemBuilder: (context, index) {
                    final log = _recentErrors[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: AppTheme.warningAmber,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.errorType,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.errorDeep,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  log.message,
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _formatTimestamp(log.timestamp),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildExportSection(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Export stats and errors for thesis analysis',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _exportAll,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export All'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorDeep,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${ts.month}/${ts.day} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportAll() async {
    try {
      await _performanceMonitor.getPerformanceStats();
      final perfData = await _performanceMonitor.exportMetricsAsJson();
      final usageData = await _usageAnalytics.exportAnalyticsAsJson();
      final errorData = await _errorLogger.exportErrorsAsJson();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data exported (see console for JSON)'),
          backgroundColor: AppTheme.safeGreen,
        ),
      );
      debugPrint('Perf: $perfData');
      debugPrint('Usage: $usageData');
      debugPrint('Errors: $errorData');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppTheme.errorDeep,
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will clear performance metrics, usage analytics, and error logs. Cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorDeep),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _performanceMonitor.clearAllMetrics();
      await _usageAnalytics.clearAnalytics();
      await _errorLogger.clearAllErrors();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data cleared'),
          backgroundColor: AppTheme.safeGreen,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorDeep,
        ),
      );
    }
  }

  Future<void> _showEditMetricsDialog() async {
    final formKey = GlobalKey<FormState>();
    final accuracyController = TextEditingController(
      text: _aiMetrics.accuracy.toStringAsFixed(2),
    );
    final precisionController = TextEditingController(
      text: _aiMetrics.precision.toStringAsFixed(2),
    );
    final recallController = TextEditingController(
      text: _aiMetrics.recall.toStringAsFixed(2),
    );
    final f1Controller = TextEditingController(
      text: _aiMetrics.f1Score.toStringAsFixed(2),
    );
    bool isSaving = false;

    String? validator(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'Required';
      }
      final parsed = double.tryParse(value.trim());
      if (parsed == null) {
        return 'Enter a valid number';
      }
      if (parsed < 0 || parsed > 100) {
        return 'Use 0 to 100';
      }
      return null;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit AI Model Metrics'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: accuracyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Accuracy (%)'),
                        validator: validator,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: precisionController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Precision (%)'),
                        validator: validator,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: recallController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Recall (%)'),
                        validator: validator,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: f1Controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'F1-Score (%)'),
                        validator: validator,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setDialogState(() => isSaving = true);

                          final metrics = AiMetrics(
                            accuracy: double.parse(accuracyController.text.trim()),
                            precision: double.parse(precisionController.text.trim()),
                            recall: double.parse(recallController.text.trim()),
                            f1Score: double.parse(f1Controller.text.trim()),
                          );
                          await _aiMetricsService.saveMetrics(metrics);
                          if (!mounted) return;
                          setState(() {
                            _aiMetrics = metrics;
                          });
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    accuracyController.dispose();
    precisionController.dispose();
    recallController.dispose();
    f1Controller.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI model metrics updated'),
          backgroundColor: AppTheme.safeGreen,
        ),
      );
    }
  }
}
