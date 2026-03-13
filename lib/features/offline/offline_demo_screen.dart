// lib/features/offline/offline_demo_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:herbascan/core/theme/app_theme.dart';

class OfflineDemoScreen extends StatefulWidget {
  const OfflineDemoScreen({super.key});

  @override
  State<OfflineDemoScreen> createState() => _OfflineDemoScreenState();
}

class _OfflineDemoScreenState extends State<OfflineDemoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OfflineProvider>(context, listen: false).refreshOfflineData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Diagnostics'),
      ),
      body: Consumer<OfflineProvider>(
        builder: (context, offlineProvider, child) {
          if (!offlineProvider.isInitialized) {
            return _buildLoadingState(context);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusBanner(context, offlineProvider),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStatsGrid(context, offlineProvider),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildActionButtons(context, offlineProvider),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
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

  Widget _buildStatusBanner(
      BuildContext context, OfflineProvider offlineProvider) {
    final isOffline = offlineProvider.isFullyOffline;
    final bgColor = isOffline ? AppTheme.warningBgLight : AppTheme.safeBgLight;
    final iconColor =
        isOffline ? AppTheme.warningAmber : AppTheme.botanicalPrimary;
    final icon = isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded;
    final message = isOffline
        ? 'System Offline • Operating via Local SQLite'
        : 'System Online • Connected to Supabase Cloud';

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
      BuildContext context, OfflineProvider offlineProvider) {
    final totalPlants = offlineProvider.offlineStats['totalPlants'] ?? 0;
    final totalScans = offlineProvider.offlineStats['totalScans'] ?? 0;
    final pendingSync = offlineProvider.offlineStats['pendingSync'] ?? 0;
    final aiReady = offlineProvider.offlineStats['aiInitialized'] == true;

    final pendingColor =
        pendingSync == 0 ? AppTheme.textSecondary : AppTheme.warningAmber;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          context,
          value: '$totalPlants / 42 Plants',
          subtitle: 'Secured in local cache',
          icon: Icons.local_florist_rounded,
          iconColor: AppTheme.botanicalPrimary,
          bgColor: AppTheme.safeBgLight,
        ),
        _buildStatCard(
          context,
          value: aiReady ? 'AI model' : 'Not Loaded',
          subtitle: aiReady ? 'Offline AI ready' : 'AI model unavailable',
          icon: Icons.memory_rounded,
          iconColor: aiReady ? AppTheme.botanicalPrimary : AppTheme.errorDeep,
          bgColor: aiReady ? AppTheme.safeBgLight : AppTheme.errorBgLight,
        ),
        _buildStatCard(
          context,
          value: '$totalScans Scans',
          subtitle: 'Saved to device',
          icon: Icons.camera_alt_rounded,
          iconColor: AppTheme.botanicalPrimary,
          bgColor: AppTheme.safeBgLight,
        ),
        _buildStatCard(
          context,
          value: '$pendingSync Pending',
          subtitle: 'Waiting to backup to cloud',
          icon: Icons.cloud_upload_rounded,
          iconColor: pendingColor,
          bgColor:
              pendingSync == 0 ? AppTheme.safeBgLight : AppTheme.warningBgLight,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: iconColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, OfflineProvider offlineProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.sync_rounded),
          label: const Text('Force Cloud Sync'),
          onPressed: () => _handleForceSync(context, offlineProvider),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_sweep_rounded),
          label: const Text('Wipe Local Cache'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            side: const BorderSide(color: AppTheme.errorColor, width: 2),
          ),
          onPressed: () => _showWipeCacheDialog(context, offlineProvider),
        ),
        const SizedBox(height: 16),
        Consumer<OfflineProvider>(
          builder: (context, provider, _) {
            return SwitchListTile(
              title: const Text(
                'Simulate Offline Mode',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text(
                'Forces the app to operate without network',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              value: provider.isOfflineMode,
              activeThumbColor: AppTheme.botanicalPrimary,
              onChanged: (_) async {
                await provider.toggleOfflineMode();
              },
              contentPadding: EdgeInsets.zero,
            );
          },
        ),
      ],
    );
  }

  Future<void> _handleForceSync(
      BuildContext context, OfflineProvider offlineProvider) async {
    try {
      await offlineProvider.refreshOfflineData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync complete'),
            backgroundColor: AppTheme.botanicalPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showWipeCacheDialog(
      BuildContext context, OfflineProvider offlineProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Wipe Local Cache'),
        content: const Text(
          'This will permanently delete all offline scan history and cached '
          'data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await offlineProvider.clearOfflineData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Local cache wiped'),
                      backgroundColor: AppTheme.botanicalPrimary,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error wiping cache: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Wipe',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}
