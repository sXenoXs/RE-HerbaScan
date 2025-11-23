import 'package:flutter/material.dart';
import 'package:herbascan/core/services/performance_monitor.dart';
import 'package:herbascan/core/services/usage_analytics.dart';
import 'package:herbascan/core/services/error_logger.dart';
import 'package:herbascan/core/localization/app_localizations.dart';

class PerformanceDashboardScreen extends StatefulWidget {
  const PerformanceDashboardScreen({super.key});

  @override
  State<PerformanceDashboardScreen> createState() =>
      _PerformanceDashboardScreenState();
}

class _PerformanceDashboardScreenState
    extends State<PerformanceDashboardScreen> {
  final _performanceMonitor = PerformanceMonitor();
  final _usageAnalytics = UsageAnalytics();
  final _errorLogger = ErrorLogger();

  Map<String, dynamic>? _performanceStats;
  Map<String, dynamic>? _usageStats;
  Map<String, dynamic>? _errorStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final perfStats = await _performanceMonitor.getPerformanceStats();
      final usageStats = _usageAnalytics.getStatistics();
      final errorStats = await _errorLogger.getErrorStats();

      setState(() {
        _performanceStats = perfStats;
        _usageStats = usageStats;
        _errorStats = errorStats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading dashboard: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLocalizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.appPerformance),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildDashboardHeader(theme),

                    const SizedBox(height: 24),

                    // Usage Analytics Section
                    _buildSectionHeader(theme, '📊 Usage Analytics'),
                    const SizedBox(height: 12),
                    _buildUsageAnalyticsSection(theme),

                    const SizedBox(height: 24),

                    // Performance Metrics Section
                    _buildSectionHeader(theme, '⚡ Performance Metrics'),
                    const SizedBox(height: 12),
                    _buildPerformanceSection(theme),

                    const SizedBox(height: 24),

                    // Error Logs Section
                    _buildSectionHeader(theme, '🐛 Error Tracking'),
                    const SizedBox(height: 12),
                    _buildErrorSection(theme),

                    const SizedBox(height: 24),

                    // Export Actions
                    _buildExportSection(theme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDashboardHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dashboard,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performance Dashboard',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'App metrics & usage statistics',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildUsageAnalyticsSection(ThemeData theme) {
    if (_usageStats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No usage data available'),
        ),
      );
    }

    final successRate = _usageStats!['success_rate'] as String? ?? '0%';
    final totalScans = _usageStats!['total_scans'] as int? ?? 0;
    final successfulScans = _usageStats!['successful_scans'] as int? ?? 0;
    final failedScans = _usageStats!['failed_scans'] as int? ?? 0;

    return Column(
      children: [
        // Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                'Total Scans',
                totalScans.toString(),
                Icons.qr_code_scanner,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme,
                'Success Rate',
                successRate,
                Icons.check_circle,
                Colors.green,
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
                'Successful',
                successfulScans.toString(),
                Icons.done,
                Colors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme,
                'Failed',
                failedScans.toString(),
                Icons.error_outline,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceSection(ThemeData theme) {
    if (_performanceStats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No performance data available'),
        ),
      );
    }

    final operationsBreakdown =
        _performanceStats!['operations_breakdown'] != null
            ? Map<String, dynamic>.from(
                _performanceStats!['operations_breakdown'] as Map)
            : <String, dynamic>{};

    if (operationsBreakdown.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No operations tracked yet'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...operationsBreakdown.entries.map((entry) {
              final operationName = entry.key;
              final stats = Map<String, dynamic>.from(entry.value as Map);
              final avgMs = stats['avg_ms'] as int? ?? 0;
              final count = stats['count'] as int? ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formatOperationName(operationName),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${avgMs}ms avg',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getPerformanceColor(avgMs),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count executions',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSection(ThemeData theme) {
    if (_errorStats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No error data available'),
        ),
      );
    }

    final totalErrors = _errorStats!['total_errors'] as int? ?? 0;
    final last24h = _errorStats!['last_24h'] as int? ?? 0;
    final errorTypes = _errorStats!['error_types'] != null
        ? Map<String, dynamic>.from(_errorStats!['error_types'] as Map)
        : <String, dynamic>{};

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                'Total Errors',
                totalErrors.toString(),
                Icons.bug_report,
                totalErrors > 0 ? Colors.red : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme,
                'Last 24h',
                last24h.toString(),
                Icons.schedule,
                last24h > 0 ? Colors.orange : Colors.grey,
              ),
            ),
          ],
        ),
        if (errorTypes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error Types',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...errorTypes.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Data',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Export performance data for thesis analysis',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _exportAllData,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export All'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _clearAllData,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatOperationName(String name) {
    return name
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Color _getPerformanceColor(int avgMs) {
    if (avgMs < 1000) return Colors.green;
    if (avgMs < 3000) return Colors.orange;
    return Colors.red;
  }

  Future<void> _exportAllData() async {
    try {
      // In a real app, this would save to file or share
      final perfData = await _performanceMonitor.exportMetricsAsJson();
      final usageData = await _usageAnalytics.exportAnalyticsAsJson();
      final errorData = await _errorLogger.exportErrorsAsJson();

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data exported successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // In production, you would save these to a file or cloud storage
      print('Performance Data: $perfData');
      print('Usage Data: $usageData');
      print('Error Data: $errorData');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will clear all performance metrics, usage analytics, and error logs. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _performanceMonitor.clearAllMetrics();
        await _usageAnalytics.clearAnalytics();
        await _errorLogger.clearAllErrors();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );

        _loadDashboardData();
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
