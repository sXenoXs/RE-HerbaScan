import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/models/scan_result.dart';
import 'package:herbascan/features/scan/plant_result_screen.dart';
import 'package:herbascan/features/scan/scan_screen.dart';
import 'package:herbascan/core/services/usage_analytics.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final UsageAnalytics _analytics = UsageAnalytics();
  String _sortBy = 'recent'; // recent, oldest, confidence

  @override
  void initState() {
    super.initState();
    // Track history screen view
    _analytics.trackHistoryViewed();
  }

  List<ScanResult> _sortScans(List<ScanResult> scans) {
    List<ScanResult> sorted = List.from(scans);

    switch (_sortBy) {
      case 'recent':
        sorted.sort((a, b) => b.scanDate.compareTo(a.scanDate));
        break;
      case 'oldest':
        sorted.sort((a, b) => a.scanDate.compareTo(b.scanDate));
        break;
      case 'confidence':
        sorted.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
        break;
    }

    return sorted;
  }

  void _showDeleteConfirmation(BuildContext context, ScanResult scan) {
    final appLocalizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(appLocalizations.confirmDelete),
          content: Text(appLocalizations.deleteConfirmation),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(appLocalizations.cancel),
            ),
            TextButton(
              onPressed: () {
                final plantProvider =
                    Provider.of<PlantProvider>(context, listen: false);
                plantProvider.deleteScanResult(scan.id);
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Scan deleted'),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              },
              child: Text(
                appLocalizations.delete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAllConfirmation(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(appLocalizations.confirmDelete),
          content:
              const Text('Are you sure you want to delete all scan history?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(appLocalizations.cancel),
            ),
            TextButton(
              onPressed: () {
                final plantProvider =
                    Provider.of<PlantProvider>(context, listen: false);
                plantProvider.clearScanHistory();
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('All scans deleted'),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              },
              child: Text(
                appLocalizations.deleteAll,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLocalizations = AppLocalizations.of(context);
    final plantProvider = Provider.of<PlantProvider>(context);
    final sortedScans = _sortScans(plantProvider.scanHistory);

    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.scanHistory),
        actions: [
          if (sortedScans.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              onSelected: (value) {
                setState(() {
                  _sortBy = value;
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'recent',
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: _sortBy == 'recent'
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Most Recent',
                        style: TextStyle(
                          fontWeight:
                              _sortBy == 'recent' ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'oldest',
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: _sortBy == 'oldest'
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Oldest First',
                        style: TextStyle(
                          fontWeight:
                              _sortBy == 'oldest' ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'confidence',
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: _sortBy == 'confidence'
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Highest Confidence',
                        style: TextStyle(
                          fontWeight:
                              _sortBy == 'confidence' ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          if (sortedScans.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _showDeleteAllConfirmation(context),
              tooltip: appLocalizations.deleteAll,
            ),
        ],
      ),
      body: plantProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : sortedScans.isEmpty
              ? _buildEmptyState(context, theme, appLocalizations)
              : Column(
                  children: [
                    // Stats Header
                    _buildStatsHeader(context, theme, sortedScans),

                    // Scan List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sortedScans.length,
                        itemBuilder: (context, index) {
                          final scan = sortedScans[index];
                          return _buildScanCard(context, theme, scan);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme,
      AppLocalizations appLocalizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            appLocalizations.noScansYet,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            appLocalizations.startScanning,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to scan screen
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ScanScreen(),
                ),
              );
            },
            icon: const Icon(Icons.camera_alt),
            label: Text(appLocalizations.scanPlant),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(
      BuildContext context, ThemeData theme, List<ScanResult> scans) {
    final avgConfidence = scans.isEmpty
        ? 0.0
        : scans.map((s) => s.confidenceScore).reduce((a, b) => a + b) /
            scans.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            theme,
            '${scans.length}',
            'Total Scans',
            Icons.eco,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.3),
          ),
          _buildStatItem(
            theme,
            '${(avgConfidence * 100).toStringAsFixed(1)}%',
            'Avg Confidence',
            Icons.analytics,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      ThemeData theme, String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildScanCard(
      BuildContext context, ThemeData theme, ScanResult scan) {
    final appLocalizations = AppLocalizations.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to PlantResultScreen to view full scan results
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlantResultScreen.fromScanResult(scan),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Plant Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: scan.imagePath.isNotEmpty
                    ? Image.file(
                        File(scan.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage(theme);
                        },
                      )
                    : _buildPlaceholderImage(theme),
              ),
              const SizedBox(width: 16),
              // Scan Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          flex: 1,
                          child: Text(
                            scan.plant?.commonName ??
                                scan.topPrediction?.plantName ??
                                'Unknown Plant',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        if (_getMethodLabel(scan) != null) ...[
                          const SizedBox(width: 8),
                          _buildMethodLabel(theme, _getMethodLabel(scan)!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scan.plant?.scientificName ??
                          scan.topPrediction?.scientificName ??
                          '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(scan.scanDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildConfidenceBadge(
                        theme, appLocalizations, scan.confidenceScore),
                  ],
                ),
              ),
              // Delete Button
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                onPressed: () => _showDeleteConfirmation(context, scan),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(
      ThemeData theme, AppLocalizations appLocalizations, double confidence) {
    final percentage = (confidence * 100).toStringAsFixed(1);
    final Color badgeColor;

    if (confidence >= 0.8) {
      badgeColor = const Color(0xFF48BB78); // Green
    } else if (confidence >= 0.6) {
      badgeColor = Colors.orange;
    } else {
      badgeColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: badgeColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            '$percentage% ${appLocalizations.confidence}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.local_florist,
        size: 40,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
      ),
    );
  }

  /// Get method label from scan result metadata
  /// Returns: "CAM", "GradCAM", "Fallback", or "Online"
  String? _getMethodLabel(ScanResult scan) {
    final method = scan.metadata['method'] as String?;
    final fallbackUsed = scan.metadata['fallbackUsed'] as bool? ?? false;

    // If fallback was used, show "Fallback"
    if (fallbackUsed == true) {
      return 'Fallback';
    }

    // Otherwise, show based on method
    if (method == 'cam') {
      return 'CAM';
    } else if (method == 'grad-cam') {
      return 'GradCAM';
    }

    // Fallback: use isOfflineScan to determine
    if (scan.isOfflineScan) {
      return 'CAM';
    }

    // If no method info, return null (don't show label)
    return null;
  }

  /// Build method label widget
  Widget _buildMethodLabel(ThemeData theme, String label) {
    // Determine color based on label
    Color labelColor;
    if (label == 'CAM' || label == 'Fallback') {
      labelColor = Colors.orange; // Orange for offline/fallback
    } else {
      labelColor = Colors.green; // Green for online/GradCAM
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: labelColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: labelColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        '($label)',
        style: theme.textTheme.bodySmall?.copyWith(
          color: labelColor,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
