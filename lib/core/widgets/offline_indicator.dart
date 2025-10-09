// lib/core/widgets/offline_indicator.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/offline_provider.dart';

class OfflineIndicator extends StatelessWidget {
  final bool showDetails;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const OfflineIndicator({
    super.key,
    this.showDetails = false,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        if (!offlineProvider.isInitialized) {
          return _buildLoadingIndicator(context);
        }

        if (offlineProvider.isFullyOffline) {
          return _buildOfflineIndicator(context, offlineProvider);
        }

        if (offlineProvider.hasPendingSync) {
          return _buildPendingSyncIndicator(context, offlineProvider);
        }

        return _buildOnlineIndicator(context, offlineProvider);
      },
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return Container(
      margin: margin,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Initializing...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineIndicator(
      BuildContext context, OfflineProvider offlineProvider) {
    return Container(
      margin: margin,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            offlineProvider.getConnectivityIcon(),
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Text(
            'Offline Mode',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(width: 8),
            Text(
              '- All features available',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onError.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingSyncIndicator(
      BuildContext context, OfflineProvider offlineProvider) {
    return Container(
      margin: margin,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            offlineProvider.getConnectivityIcon(),
            size: 16,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Text(
            '${offlineProvider.pendingSyncResults.length} Pending',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(width: 8),
            Text(
              'sync',
              style: TextStyle(
                fontSize: 11,
                color:
                    Theme.of(context).colorScheme.onTertiary.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOnlineIndicator(
      BuildContext context, OfflineProvider offlineProvider) {
    return Container(
      margin: margin,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            offlineProvider.getConnectivityIcon(),
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Online',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(width: 8),
            Text(
              '- All features available',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OfflineStatusCard extends StatelessWidget {
  const OfflineStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
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
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Connection Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  offlineProvider.getOfflineStatusMessage(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (offlineProvider.hasPendingSync) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: 0.7, // Placeholder for sync progress
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ],
                if (offlineProvider.lastError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            offlineProvider.lastError,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
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
      },
    );
  }
}

class OfflineFeatureStatus extends StatelessWidget {
  const OfflineFeatureStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        final features = offlineProvider.getOfflineFeatureStatus();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Features',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                ...features.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          entry.value ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: entry.value
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getFeatureDisplayName(entry.key),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        Text(
                          entry.value ? 'Available' : 'Unavailable',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: entry.value
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w500,
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
      },
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
