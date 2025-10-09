// lib/features/offline/offline_demo_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:herbascan/core/widgets/offline_indicator.dart';

class OfflineDemoScreen extends StatefulWidget {
  const OfflineDemoScreen({super.key});

  @override
  State<OfflineDemoScreen> createState() => _OfflineDemoScreenState();
}

class _OfflineDemoScreenState extends State<OfflineDemoScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh offline data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OfflineProvider>(context, listen: false).refreshOfflineData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Processing Demo'),
        actions: [
          OfflineIndicator(),
        ],
      ),
      body: Consumer<OfflineProvider>(
        builder: (context, offlineProvider, child) {
          if (!offlineProvider.isInitialized) {
            return _buildLoadingState(theme);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Overview
                _buildStatusOverview(context, theme, offlineProvider),

                const SizedBox(height: 24),

                // Feature Status
                _buildFeatureStatus(context, theme, offlineProvider),

                const SizedBox(height: 24),

                // Storage Information
                _buildStorageInfo(context, theme, offlineProvider),

                const SizedBox(height: 24),

                // Actions
                _buildActions(context, theme, offlineProvider),

                const SizedBox(height: 24),

                // Statistics
                _buildStatistics(context, theme, offlineProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Initializing offline service...',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverview(
      BuildContext context, ThemeData theme, OfflineProvider offlineProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  offlineProvider.getConnectivityIcon(),
                  color: offlineProvider.getConnectivityColor(context),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Connection Status',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              offlineProvider.getOfflineStatusMessage(),
              style: theme.textTheme.bodyLarge,
            ),
            if (offlineProvider.lastError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        offlineProvider.lastError,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureStatus(
      BuildContext context, ThemeData theme, OfflineProvider offlineProvider) {
    final features = offlineProvider.getOfflineFeatureStatus();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offline Features',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...features.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      entry.value ? Icons.check_circle : Icons.cancel,
                      color: entry.value ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getFeatureDisplayName(entry.key),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: entry.value ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry.value ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildStorageInfo(
      BuildContext context, ThemeData theme, OfflineProvider offlineProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Information',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Total Scans',
                '${offlineProvider.offlineStats['totalScans'] ?? 0}'),
            _buildInfoRow('Total Plants',
                '${offlineProvider.offlineStats['totalPlants'] ?? 0}'),
            _buildInfoRow('DOH Plants',
                '${offlineProvider.offlineStats['dohPlants'] ?? 0}'),
            _buildInfoRow('Pending Sync',
                '${offlineProvider.offlineStats['pendingSync'] ?? 0}'),
            _buildInfoRow(
                'AI Models',
                offlineProvider.offlineStats['aiInitialized'] == true
                    ? 'Loaded'
                    : 'Not Available'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
      BuildContext context, ThemeData theme, OfflineProvider offlineProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              context,
              theme,
              'Refresh Data',
              Icons.refresh,
              () async {
                try {
                  await offlineProvider.refreshOfflineData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Data refreshed successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error refreshing data: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            _buildActionButton(
              context,
              theme,
              'Toggle Offline Mode',
              Icons.offline_bolt,
              () async {
                await offlineProvider.toggleOfflineMode();
              },
            ),
            _buildActionButton(
              context,
              theme,
              'Clear Offline Data',
              Icons.delete_forever,
              () {
                _showClearDataDialog(context, offlineProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    ThemeData theme,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
    );
  }

  Widget _buildStatistics(
      BuildContext context, ThemeData theme, OfflineProvider offlineProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              context,
              theme,
              'Offline Scans',
              '${offlineProvider.offlineStats['totalScans'] ?? 0}',
              Icons.camera_alt,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              theme,
              'Plant Database',
              '${offlineProvider.offlineStats['totalPlants'] ?? 0}',
              Icons.local_florist,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              theme,
              'Pending Sync',
              '${offlineProvider.offlineStats['pendingSync'] ?? 0}',
              Icons.sync,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(
      BuildContext context, OfflineProvider offlineProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Offline Data'),
        content: const Text(
          'This will permanently delete all offline scan history and cached data. '
          'This action cannot be undone. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await offlineProvider.clearOfflineData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Offline data cleared successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error clearing data: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _getFeatureDisplayName(String feature) {
    switch (feature) {
      case 'plant_identification':
        return 'Plant Identification';
      case 'plant_database':
        return 'Plant Database';
      case 'scan_history':
        return 'Scan History';
      case 'doh_plants':
        return 'DOH Approved Plants';
      case 'search':
        return 'Plant Search';
      default:
        return feature;
    }
  }
}
