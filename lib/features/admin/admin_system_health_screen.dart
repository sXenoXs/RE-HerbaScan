import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/services/ai_metrics_service.dart';
import 'package:herbascan/core/services/error_logger.dart';
import 'package:herbascan/core/services/ota_model_service.dart';
import 'package:herbascan/core/services/performance_monitor.dart';
import 'package:herbascan/core/services/usage_analytics.dart';

/// Admin-only System Health: AI metrics, live usage, and error logs.
/// Merges former Performance Metrics and Performance Dashboard.
class AdminSystemHealthScreen extends StatefulWidget {
  const AdminSystemHealthScreen({super.key});

  @override
  State<AdminSystemHealthScreen> createState() => _AdminSystemHealthScreenState();
}

class _AdminSystemHealthScreenState extends State<AdminSystemHealthScreen> {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const _kFilterLabels = ['All', 'Camera', 'AI', 'Database', 'Network'];
  static const _kCollapsedLimit = 5;

  // ── Services ───────────────────────────────────────────────────────────────
  final _performanceMonitor = PerformanceMonitor();
  final _usageAnalytics = UsageAnalytics();
  final _errorLogger = ErrorLogger();
  final _aiMetricsService = AiMetricsService();

  // ── State ──────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _performanceStats;
  Map<String, dynamic>? _usageStats;
  List<ErrorLog> _recentErrors = [];
  AiMetrics _aiMetrics = AiMetricsService.defaults;
  bool _isLoading = true;
  bool _otaActive = false;
  String _otaVersion = '';

  // Error section state
  String _errorFilter = 'All';
  bool _errorsExpanded = false;

  // ── Derived ────────────────────────────────────────────────────────────────
  List<ErrorLog> get _filteredErrors {
    if (_errorFilter == 'All') return _recentErrors;
    return _recentErrors.where((e) {
      final t = e.errorType.toLowerCase();
      switch (_errorFilter) {
        case 'Camera':
          return t.contains('camera');
        case 'AI':
          return t.contains('ai') || t.contains('inference');
        case 'Database':
          return t.contains('database') || t.contains('db');
        case 'Network':
          return t.contains('network');
        default:
          return true;
      }
    }).toList();
  }

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
      final prefs = await SharedPreferences.getInstance();
      final otaVersion = prefs.getString('ota_model_version') ?? '';

      if (!mounted) return;
      setState(() {
        _performanceStats = perfStats;
        _usageStats = usageStats;
        _recentErrors = recentErrors;
        _aiMetrics = aiMetrics;
        _otaActive = OtaModelService.instance.isOtaAvailable;
        _otaVersion = otaVersion;
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

  // ── AI Section (unchanged) ─────────────────────────────────────────────────

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
          'MobileNet V2 · 31 Philippine medicinal plants',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _buildModelSourceCard(theme),
      ],
    );
  }

  Widget _buildModelSourceCard(ThemeData theme) {
    final color = _otaActive ? AppTheme.botanicalPrimary : Colors.orange.shade700;
    final icon = _otaActive ? Icons.cloud_done_rounded : Icons.inventory_2_outlined;
    final label = _otaActive ? 'Live Model (Supabase)' : 'Bundled Asset Model';
    final subtitle = _otaActive
        ? 'Version: $_otaVersion'
        : 'No OTA model downloaded yet';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_otaActive && OtaModelService.instance.tflitePath != null)
                  Text(
                    OtaModelService.instance.tflitePath!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (!_otaActive)
            TextButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Checking for model update…')),
                );
                await OtaModelService.instance.initialize();
                _loadData();
              },
              child: const Text('Check now'),
            ),
        ],
      ),
    );
  }

  // ── Usage Section (unchanged) ──────────────────────────────────────────────

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

  // ── Error Section (refactored) ─────────────────────────────────────────────

  Widget _buildErrorSection(ThemeData theme) {
    final filtered = _filteredErrors;
    final displayList =
        _errorsExpanded ? filtered : filtered.take(_kCollapsedLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Text(
              'Error Logs',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (_recentErrors.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.errorDeep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${_recentErrors.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.errorDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // Filter chip row (only when errors exist)
        if (_recentErrors.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _kFilterLabels.map((label) {
                final isSelected = _errorFilter == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    visualDensity: VisualDensity.compact,
                    selectedColor:
                        AppTheme.errorDeep.withValues(alpha: 0.12),
                    checkmarkColor: AppTheme.errorDeep,
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? AppTheme.errorDeep
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() {
                      _errorFilter = label;
                      _errorsExpanded = false;
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Empty state — no errors at all
        if (_recentErrors.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: AppTheme.safeGreen, size: 20),
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

        // Empty state — filter has no matches
        else if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Center(
              child: Text(
                'No $_errorFilter errors in the last ${_recentErrors.length} log entries.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )

        // Error list
        else ...[
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                for (int i = 0; i < displayList.length; i++) ...[
                  _buildErrorTile(theme, displayList[i]),
                  if (i < displayList.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                ],
              ],
            ),
          ),

          // Expand / collapse toggle
          if (filtered.length > _kCollapsedLimit)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: Icon(
                  _errorsExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                ),
                label: Text(
                  _errorsExpanded
                      ? 'Show less'
                      : 'Show all ${filtered.length} errors',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorDeep,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 4),
                ),
                onPressed: () =>
                    setState(() => _errorsExpanded = !_errorsExpanded),
              ),
            ),
        ],
      ],
    );
  }

  // ── Error Entry Tile ───────────────────────────────────────────────────────

  Widget _buildErrorTile(ThemeData theme, ErrorLog log) {
    final hasStack =
        log.stackTrace != null && log.stackTrace!.trim().isNotEmpty;
    final hasContext = log.context.isNotEmpty;
    final typeColor = _errorTypeColor(log.errorType);

    return ExpansionTile(
      tilePadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      childrenPadding:
          const EdgeInsets.fromLTRB(12, 0, 12, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      leading: Icon(
        Icons.warning_amber_rounded,
        size: 18,
        color: typeColor,
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              log.errorType,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.errorDeep,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTimestamp(log.timestamp),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Text(
          log.message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: _errorsExpanded ? null : 2,
          overflow:
              _errorsExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
        ),
      ),
      children: [
        if (!_errorsExpanded)
          // Full message when expanded individually but list is still collapsed
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              log.message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        if (hasStack)
          _buildDetailBox(
            theme,
            'Stack Trace',
            log.stackTrace!.trim(),
            isCode: true,
          ),
        if (hasContext)
          _buildDetailBox(
            theme,
            'Context',
            _formatContext(log.context),
          ),
        if (!hasStack && !hasContext)
          Text(
            'No additional details.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildDetailBox(
    ThemeData theme,
    String label,
    String content, {
    bool isCode = false,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: isCode ? 'monospace' : null,
              fontSize: isCode ? 10 : 12,
              height: isCode ? 1.4 : null,
            ),
          ),
        ],
      ),
    );
  }

  Color _errorTypeColor(String errorType) {
    final t = errorType.toLowerCase();
    if (t.contains('camera')) return Colors.orange.shade700;
    if (t.contains('ai') || t.contains('inference')) return Colors.purple;
    if (t.contains('database') || t.contains('db')) return Colors.blue;
    if (t.contains('network')) return Colors.teal;
    return AppTheme.warningAmber;
  }

  // ── Export Section (refactored) ────────────────────────────────────────────

  Widget _buildExportSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Export stats and errors for thesis analysis',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    _showExportSheet(errorsOnly: false),
                icon:
                    const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export All'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _showExportSheet(errorsOnly: true),
                icon: const Icon(Icons.bug_report_outlined,
                    size: 18),
                label: const Text('Export Error Logs'),
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
    );
  }

  // ── Export Sheet ───────────────────────────────────────────────────────────

  // Changed: fontSize 12→11, expandedInsets zero→horizontal(4), all segment labels get maxLines:1+ellipsis.
  void _showExportSheet({required bool errorsOnly}) {
    String selectedFormat = 'JSON';
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSheet) {
          final theme = Theme.of(context);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              MediaQuery.of(sheetCtx).viewInsets.bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title + subtitle
                Text(
                  errorsOnly ? 'Export Error Logs' : 'Export All Data',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  errorsOnly
                      ? '${_recentErrors.length} error log entries'
                      : 'Performance · Usage · Error logs',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                // Format picker
                Text(
                  'FORMAT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  expandedInsets: const EdgeInsets.symmetric(horizontal: 4),
                  style: ButtonStyle(
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    backgroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppTheme.botanicalPrimary;
                      }
                      return null;
                    }),
                    foregroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return null;
                    }),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: 'JSON',
                      label: Text('JSON',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      icon: Icon(Icons.code_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: 'MD',
                      label: Text('MD',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      icon: Icon(Icons.text_snippet_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 'CSV',
                      label: Text('CSV',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      icon: Icon(Icons.table_chart_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 'TXT',
                      label: Text('Text',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      icon: Icon(Icons.article_outlined, size: 16),
                    ),
                  ],
                  selected: {selectedFormat},
                  onSelectionChanged: isProcessing
                      ? null
                      : (s) => setSheet(() => selectedFormat = s.first),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy'),
                        onPressed: isProcessing
                            ? null
                            : () async {
                                setSheet(() => isProcessing = true);
                                await _handleExport(
                                  errorsOnly: errorsOnly,
                                  format: selectedFormat,
                                  toClipboard: true,
                                );
                                if (!mounted) return;
                                setSheet(() => isProcessing = false);
                                if (sheetCtx.mounted) {
                                  Navigator.of(sheetCtx).pop();
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download'),
                        onPressed: isProcessing
                            ? null
                            : () async {
                                setSheet(() => isProcessing = true);
                                await _handleExport(
                                  errorsOnly: errorsOnly,
                                  format: selectedFormat,
                                  toClipboard: false,
                                );
                                if (!mounted) return;
                                setSheet(() => isProcessing = false);
                                if (sheetCtx.mounted) {
                                  Navigator.of(sheetCtx).pop();
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Export Handler ─────────────────────────────────────────────────────────

  Future<void> _handleExport({
    required bool errorsOnly,
    required String format,
    required bool toClipboard,
  }) async {
    try {
      String content;
      String filenameBase;
      String ext;

      if (errorsOnly) {
        filenameBase = 'herbascan_errors';
        switch (format) {
          case 'MD':
            content = _toMarkdown(_recentErrors);
            ext = 'md';
          case 'CSV':
            content = _toCsv(_recentErrors);
            ext = 'csv';
          case 'TXT':
            content = _toPlainText(_recentErrors);
            ext = 'txt';
          default: // JSON
            content = await _errorLogger.exportErrorsAsJson();
            ext = 'json';
        }
      } else {
        filenameBase = 'herbascan_all';
        switch (format) {
          case 'MD':
            content = _allToMarkdown(
                _performanceStats, _usageStats, _recentErrors);
            ext = 'md';
          case 'CSV':
            // CSV is tabular — export error log rows; perf/usage as JSON comment header
            content = _toCsv(_recentErrors);
            ext = 'csv';
          case 'TXT':
            content = _allToPlainText(
                _performanceStats, _usageStats, _recentErrors);
            ext = 'txt';
          default: // JSON — bundle all three sources
            final perfData =
                await _performanceMonitor.exportMetricsAsJson();
            final usageData =
                await _usageAnalytics.exportAnalyticsAsJson();
            final errorData =
                await _errorLogger.exportErrorsAsJson();
            content =
                '{"performance":$perfData,"usage":$usageData,"errors":$errorData}';
            ext = 'json';
        }
      }

      if (toClipboard) {
        await Clipboard.setData(ClipboardData(text: content));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            backgroundColor: AppTheme.safeGreen,
          ),
        );
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final stamp = _dateStamp();
        final filename = '${filenameBase}_$stamp.$ext';
        final file = File('${dir.path}/$filename');
        await file.writeAsString(content, flush: true);
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'HerbaScan export — $stamp',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved: $filename'),
            backgroundColor: AppTheme.safeGreen,
          ),
        );
      }
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

  // ── Stat Card (unchanged) ──────────────────────────────────────────────────

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

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatTimestamp(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${ts.month}/${ts.day} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}';
  }

  static String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static String _formatContext(Map<String, dynamic> ctx) =>
      ctx.entries.map((e) => '${e.key}: ${e.value}').join('\n');

  // ── Actions (unchanged) ────────────────────────────────────────────────────

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
      if (value == null || value.trim().isEmpty) return 'Required';
      final parsed = double.tryParse(value.trim());
      if (parsed == null) return 'Enter a valid number';
      if (parsed < 0 || parsed > 100) return 'Use 0 to 100';
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Accuracy (%)'),
                        validator: validator,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: precisionController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Precision (%)'),
                        validator: validator,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: recallController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Recall (%)'),
                        validator: validator,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: f1Controller,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'F1-Score (%)'),
                        validator: validator,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
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
                            accuracy: double.parse(
                                accuracyController.text.trim()),
                            precision: double.parse(
                                precisionController.text.trim()),
                            recall:
                                double.parse(recallController.text.trim()),
                            f1Score:
                                double.parse(f1Controller.text.trim()),
                          );
                          await _aiMetricsService.saveMetrics(metrics);
                          if (!mounted) return;
                          setState(() => _aiMetrics = metrics);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
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

  // ── Static Format Converters ───────────────────────────────────────────────

  static String _toMarkdown(List<ErrorLog> logs) {
    final buf = StringBuffer();
    final now = DateTime.now().toLocal();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    buf.writeln('## HerbaScan Error Log — $dateStr');
    buf.writeln('Total entries: ${logs.length}');
    buf.writeln();
    for (final log in logs) {
      final ts = log.timestamp.toLocal();
      final time =
          '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
      buf.writeln('### [$time] ${log.errorType}');
      buf.writeln(log.message);
      if (log.stackTrace != null && log.stackTrace!.trim().isNotEmpty) {
        buf.writeln();
        buf.writeln('```');
        buf.writeln(log.stackTrace!.trim());
        buf.writeln('```');
      }
      if (log.context.isNotEmpty) {
        buf.writeln();
        buf.writeln('**Context:** ${_formatContext(log.context)}');
      }
      buf.writeln();
    }
    return buf.toString();
  }

  static String _toCsv(List<ErrorLog> logs) {
    final buf = StringBuffer();
    buf.writeln('timestamp,type,message,has_stack_trace,context_keys');
    for (final log in logs) {
      final ts = log.timestamp.toIso8601String();
      final msg = log.message.replaceAll('"', '""');
      final ctxKeys = log.context.keys.join(';');
      final hasStack = log.stackTrace != null &&
          log.stackTrace!.trim().isNotEmpty;
      buf.writeln(
          '"$ts","${log.errorType}","$msg","$hasStack","$ctxKeys"');
    }
    return buf.toString();
  }

  static String _toPlainText(List<ErrorLog> logs) {
    final buf = StringBuffer();
    final now = DateTime.now().toLocal();
    buf.writeln('HerbaScan Error Export — $now');
    buf.writeln('─' * 50);
    buf.writeln('Total entries: ${logs.length}');
    buf.writeln();
    for (final log in logs) {
      buf.writeln('[${log.timestamp.toLocal()}] ${log.errorType}');
      buf.writeln('  ${log.message}');
      if (log.stackTrace != null && log.stackTrace!.trim().isNotEmpty) {
        buf.writeln('  Stack: ${log.stackTrace!.trim()}');
      }
      if (log.context.isNotEmpty) {
        buf.writeln('  Context: ${_formatContext(log.context)}');
      }
      buf.writeln();
    }
    return buf.toString();
  }

  static String _allToMarkdown(
    Map<String, dynamic>? perf,
    Map<String, dynamic>? usage,
    List<ErrorLog> errors,
  ) {
    final buf = StringBuffer();
    final now = DateTime.now().toLocal().toString().split('.')[0];
    buf.writeln('# HerbaScan System Export');
    buf.writeln('Generated: $now');
    buf.writeln();

    buf.writeln('## Usage Statistics');
    if (usage != null && usage.isNotEmpty) {
      for (final e in usage.entries) {
        buf.writeln('- **${e.key}**: ${e.value}');
      }
    } else {
      buf.writeln('No usage data available.');
    }
    buf.writeln();

    buf.writeln('## Error Logs (${errors.length} entries)');
    if (errors.isEmpty) {
      buf.writeln('No errors recorded.');
    } else {
      buf.write(_toMarkdown(errors));
    }
    return buf.toString();
  }

  static String _allToPlainText(
    Map<String, dynamic>? perf,
    Map<String, dynamic>? usage,
    List<ErrorLog> errors,
  ) {
    final buf = StringBuffer();
    final now = DateTime.now().toLocal().toString().split('.')[0];
    buf.writeln('HERBASCAN SYSTEM EXPORT — $now');
    buf.writeln('=' * 50);
    buf.writeln();

    buf.writeln('USAGE STATISTICS');
    buf.writeln('-' * 30);
    if (usage != null && usage.isNotEmpty) {
      for (final e in usage.entries) {
        buf.writeln('${e.key}: ${e.value}');
      }
    } else {
      buf.writeln('No data');
    }
    buf.writeln();

    buf.writeln('ERROR LOGS (${errors.length} entries)');
    buf.writeln('-' * 30);
    if (errors.isEmpty) {
      buf.writeln('No errors recorded.');
    } else {
      buf.write(_toPlainText(errors));
    }
    return buf.toString();
  }
}
