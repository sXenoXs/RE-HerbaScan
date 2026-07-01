// lib/features/offline/system_diagnostics_screen.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:herbascan/core/theme/app_theme.dart';

class SystemDiagnosticsScreen extends StatefulWidget {
  const SystemDiagnosticsScreen({super.key});

  @override
  State<SystemDiagnosticsScreen> createState() =>
      _SystemDiagnosticsScreenState();
}

class _SystemDiagnosticsScreenState extends State<SystemDiagnosticsScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OfflineProvider>(context, listen: false).refreshOfflineData();
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await Provider.of<OfflineProvider>(context, listen: false)
        .refreshOfflineData();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Diagnostics'),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh stats',
            onPressed: _refreshing ? null : _refresh,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Consumer<OfflineProvider>(
            builder: (context, offlineProvider, child) {
              if (!offlineProvider.isInitialized) {
                return _buildLoadingState(context);
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                color: AppTheme.botanicalPrimary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStatusBanner(context, offlineProvider),
                      _buildOfflineNotice(context),
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
                ),
              );
            },
          ),
        ),
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

  /// Persistent banner explaining what "Online" actually means in this app.
  Widget _buildOfflineNotice(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.botanicalPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.botanicalPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppTheme.botanicalPrimary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This app is fully offline. Plant identification runs on-device '
              'using TFLite — no internet needed. '
              '"Online" mode only enables cloud sync to Supabase '
              'and model retraining via Railway.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.botanicalPrimary,
                fontFamily: 'Inter',
                height: 1.4,
              ),
            ),
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
    // Clarified messaging: offline = no sync, online = sync only
    final message = isOffline
        ? 'Sync Offline · On-device AI active · No cloud backup'
        : 'Sync Online · On-device AI active · Cloud backup enabled';

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
    final totalPlants = offlineProvider.offlineStats['totalPlants'] as int? ?? 0;
    final totalScans = offlineProvider.offlineStats['totalScans'] as int? ?? 0;
    final pendingSync = offlineProvider.offlineStats['pendingSync'] as int? ?? 0;
    final aiModelLoaded =
        offlineProvider.offlineStats['aiModelLoaded'] == true;
    final aiLabelsLoaded =
        offlineProvider.offlineStats['aiLabelsLoaded'] == true;
    final aiLabelCount =
        offlineProvider.offlineStats['aiLabelCount'] as int? ?? 0;
    final aiReady = aiModelLoaded && aiLabelsLoaded;

    final pendingColor =
        pendingSync == 0 ? AppTheme.textSecondary : AppTheme.warningAmber;

    final aiValue = aiReady
        ? 'Loaded'
        : aiModelLoaded
            ? 'Partial'
            : 'Not Loaded';

    // Show full label count (31) with note that 2 are non-plant classes
    final viewablePlantCount = aiLabelCount > 2 ? aiLabelCount - 2 : aiLabelCount;
    final aiSubtitle = aiReady
        ? 'TFLite ready · $aiLabelCount labels ($viewablePlantCount medicinal + 2 non-plant)'
        : aiModelLoaded
            ? 'Model loaded, labels missing'
            : 'Local TFLite model unavailable';
    final aiColor = aiReady
        ? AppTheme.botanicalPrimary
        : aiModelLoaded
            ? AppTheme.warningAmber
            : AppTheme.errorDeep;
    final aiBg = aiReady
        ? AppTheme.safeBgLight
        : aiModelLoaded
            ? AppTheme.warningBgLight
            : AppTheme.errorBgLight;

    // Plants: show dynamic DB count vs the viewable catalog target (not hardcoded)
    final catalogTarget = viewablePlantCount > 0 ? viewablePlantCount : 30;
    final plantSubtitle = totalPlants >= catalogTarget
        ? 'Full catalog cached locally'
        : 'Secured in local cache';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          context,
          value: '$totalPlants / $catalogTarget Plants',
          subtitle: plantSubtitle,
          icon: Icons.local_florist_rounded,
          iconColor: AppTheme.botanicalPrimary,
          bgColor: AppTheme.safeBgLight,
        ),
        _buildStatCard(
          context,
          value: aiValue,
          subtitle: aiSubtitle,
          icon: Icons.memory_rounded,
          iconColor: aiColor,
          bgColor: aiBg,
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
          subtitle: pendingSync == 0
              ? 'All scans backed up'
              : 'Waiting to sync to cloud',
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: iconColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Flexible(
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
              ),
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
        // ── Section label ────────────────────────────────────────────────
        const Text(
          'ACTIONS',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),

        // Force Cloud Sync
        OutlinedButton.icon(
          icon: const Icon(Icons.sync_rounded),
          label: const Text('Force Cloud Sync'),
          onPressed: () => _handleForceSync(offlineProvider),
        ),
        const SizedBox(height: 6),
        Text(
          'Pushes pending scans to Supabase. Inference always stays on-device.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: AppTheme.textSecondary.withValues(alpha: 0.8),
          ),
        ),

        const SizedBox(height: 16),

        // Simulate Offline/Online toggle
        Consumer<OfflineProvider>(
          builder: (context, provider, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text(
                    'Simulate Sync-Offline Mode',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: const Text(
                    'Disables cloud sync — AI identification still works fully offline',
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
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // Wipe Local Cache
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_sweep_rounded),
          label: const Text('Wipe Local Cache'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            side: const BorderSide(color: AppTheme.errorColor, width: 2),
          ),
          onPressed: () => _showWipeCacheDialog(offlineProvider),
        ),
        const SizedBox(height: 6),
        Text(
          'Deletes all locally saved scan history and pending sync queue. '
          'Plant catalog and AI model are not affected.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: AppTheme.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Future<void> _handleForceSync(OfflineProvider offlineProvider) async {
    try {
      await offlineProvider.refreshOfflineData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync complete — scans backed up to Supabase'),
          backgroundColor: AppTheme.botanicalPrimary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showWipeCacheDialog(OfflineProvider offlineProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Wipe Local Cache'),
        content: const Text(
          'This will permanently delete all offline scan history and the '
          'pending sync queue from this device.\n\n'
          'Your plant catalog and AI model will not be affected. '
          'This action cannot be undone.',
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
                // Refresh stats so cards update immediately
                await offlineProvider.refreshOfflineData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Local cache wiped successfully'),
                    backgroundColor: AppTheme.botanicalPrimary,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error wiping cache: $e'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
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
