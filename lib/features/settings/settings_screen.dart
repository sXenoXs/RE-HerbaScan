import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/app_provider.dart';
import 'package:herbascan/core/providers/language_provider.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:herbascan/core/widgets/offline_indicator.dart';
import 'package:herbascan/features/offline/offline_demo_screen.dart';
import 'package:herbascan/features/help/help_tutorial_screen.dart';
import 'package:herbascan/features/metrics/performance_metrics_screen.dart';
import 'package:herbascan/features/feedback/feedback_screen.dart';
import 'package:herbascan/features/dashboard/performance_dashboard_screen.dart';
import 'package:herbascan/features/testing/gradcam_testing_screen.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/providers/plant_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // General Settings
          _buildSectionHeader(context, theme, 'General'),
          _buildThemeSetting(context, theme),
          _buildLanguageSetting(context, theme),
          _buildOfflineModeSetting(context, theme),
          _buildAutoSaveSetting(context, theme),

          const SizedBox(height: 16),

          // Offline Management
          _buildOfflineManagementSection(context, theme),

          const SizedBox(height: 24),

          // AI Settings
          _buildSectionHeader(context, theme, 'AI Settings'),
          _buildConfidenceScoresSetting(context, theme),
          _buildGradCAMSetting(context, theme),
          _buildTop3ResultsSetting(context, theme),

          const SizedBox(height: 24),

          // Help & Support
          _buildSectionHeader(context, theme, 'Help & Support'),
          _buildHelpTutorialLink(context, theme),
          _buildPerformanceMetricsLink(context, theme),
          _buildFeedbackLink(context, theme),
          _buildAppPerformanceLink(context, theme),
          _buildGradCAMTestingLink(context, theme),

          const SizedBox(height: 24),

          // Database Management
          _buildSectionHeader(context, theme, 'Database'),
          _buildDatabaseResetOption(context, theme),

          const SizedBox(height: 24),

          // About
          _buildSectionHeader(context, theme, 'About'),
          _buildAppVersionInfo(context, theme),
          _buildModelVersionInfo(context, theme),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildThemeSetting(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);

    return Card(
      child: SwitchListTile(
        secondary: Icon(
          appProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
        ),
        title: Text(appProvider.isDarkMode ? 'Dark Mode' : 'Light Mode'),
        subtitle: const Text('Toggle between dark and light themes'),
        value: appProvider.isDarkMode,
        onChanged: (value) {
          appProvider.toggleDarkMode();
        },
      ),
    );
  }

  Widget _buildLanguageSetting(BuildContext context, ThemeData theme) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.language),
        title: Text(AppLocalizations.of(context).language),
        subtitle: Text(languageProvider.isEnglish ? 'English' : 'Filipino'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          languageProvider.toggleLanguage();
        },
      ),
    );
  }

  Widget _buildOfflineModeSetting(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);
    final offlineProvider = Provider.of<OfflineProvider>(context);

    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.offline_bolt),
        title: Text(AppLocalizations.of(context).offlineMode),
        subtitle: const Text('Enable offline processing'),
        value: appProvider.isOfflineMode,
        onChanged: (value) async {
          await appProvider.toggleOfflineMode();
          await offlineProvider.toggleOfflineMode();
        },
      ),
    );
  }

  Widget _buildAutoSaveSetting(BuildContext context, ThemeData theme) {
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.save),
        title: const Text('Auto-save Scans'),
        subtitle: const Text('Automatically save scan results'),
        value: true,
        onChanged: (value) {
          // TODO: Implement auto-save setting
        },
      ),
    );
  }

  Widget _buildConfidenceScoresSetting(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);

    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.analytics),
        title: Text(AppLocalizations.of(context).showConfidenceScores),
        subtitle: const Text('Display confidence percentages'),
        value: appProvider.showConfidenceScores,
        onChanged: (value) {
          appProvider.toggleConfidenceScores();
        },
      ),
    );
  }

  Widget _buildGradCAMSetting(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);

    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.visibility),
        title: Text(AppLocalizations.of(context).showGradCAM),
        subtitle: const Text('Show AI focus areas'),
        value: appProvider.showGradCAM,
        onChanged: (value) {
          appProvider.toggleGradCAM();
        },
      ),
    );
  }

  Widget _buildTop3ResultsSetting(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);

    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.list),
        title: Text(AppLocalizations.of(context).showTop3Results),
        subtitle: const Text('Show top 3 predictions'),
        value: appProvider.showTop3Results,
        onChanged: (value) {
          appProvider.toggleTop3Results();
        },
      ),
    );
  }

  Widget _buildAppVersionInfo(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.info),
        title: const Text('App Version'),
        subtitle: Text(appProvider.appVersion),
      ),
    );
  }

  Widget _buildModelVersionInfo(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.psychology),
        title: const Text('Model Version'),
        subtitle: Text(appProvider.modelVersion),
      ),
    );
  }

  Widget _buildHelpTutorialLink(BuildContext context, ThemeData theme) {
    final appLocalizations = AppLocalizations.of(context);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.help_outline),
        title: Text(appLocalizations.helpAndTutorial),
        subtitle: const Text('Learn how to get the best scanning results'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const HelpTutorialScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPerformanceMetricsLink(BuildContext context, ThemeData theme) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.analytics),
        title: const Text('AI Performance Metrics'),
        subtitle: const Text('View model accuracy and performance stats'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PerformanceMetricsScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedbackLink(BuildContext context, ThemeData theme) {
    final appLocalizations = AppLocalizations.of(context);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.feedback_outlined),
        title: Text(appLocalizations.sendFeedback),
        subtitle: const Text('Help us improve HerbaScan'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const FeedbackScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppPerformanceLink(BuildContext context, ThemeData theme) {
    final appLocalizations = AppLocalizations.of(context);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.speed),
        title: Text(appLocalizations.appPerformance),
        subtitle: Text(appLocalizations.viewPerformanceData),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PerformanceDashboardScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradCAMTestingLink(BuildContext context, ThemeData theme) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.science),
        title: const Text('Phase 5: GradCAM Testing'),
        subtitle: const Text('Test online/offline modes and measure performance'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const GradCAMTestingScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOfflineManagementSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, theme, 'Offline Management'),

        // Offline Status Card
        OfflineStatusCard(),

        const SizedBox(height: 16),

        // Offline Features Status
        OfflineFeatureStatus(),

        const SizedBox(height: 16),

        // Offline Actions
        _buildOfflineActions(context, theme),
      ],
    );
  }

  Widget _buildOfflineActions(BuildContext context, ThemeData theme) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        return Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh Offline Data'),
                subtitle: const Text('Update offline database and sync status'),
                onTap: () async {
                  try {
                    await offlineProvider.refreshOfflineData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Offline data refreshed successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
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
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Offline Storage Info'),
                subtitle: Text(
                  'Scans: ${offlineProvider.offlineStats['totalScans'] ?? 0}\n'
                  'Plants: ${offlineProvider.offlineStats['totalPlants'] ?? 0}\n'
                  'Pending Sync: ${offlineProvider.offlineStats['pendingSync'] ?? 0}',
                ),
                onTap: () {
                  _showOfflineStorageDialog(context, offlineProvider);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('Clear Offline Data'),
                subtitle:
                    const Text('Remove all offline scans and cached data'),
                onTap: () {
                  _showClearDataDialog(context, offlineProvider);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.offline_bolt),
                title: const Text('Offline Demo'),
                subtitle: const Text('Test offline processing capabilities'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const OfflineDemoScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOfflineStorageDialog(
      BuildContext context, OfflineProvider offlineProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Storage Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStorageInfoRow('Total Scans',
                '${offlineProvider.offlineStats['totalScans'] ?? 0}'),
            _buildStorageInfoRow('Total Plants',
                '${offlineProvider.offlineStats['totalPlants'] ?? 0}'),
            _buildStorageInfoRow('DOH Plants',
                '${offlineProvider.offlineStats['dohPlants'] ?? 0}'),
            _buildStorageInfoRow('Pending Sync',
                '${offlineProvider.offlineStats['pendingSync'] ?? 0}'),
            _buildStorageInfoRow('Offline Mode',
                offlineProvider.isOfflineMode ? 'Enabled' : 'Disabled'),
            _buildStorageInfoRow('Internet',
                offlineProvider.isOnline ? 'Connected' : 'Disconnected'),
            _buildStorageInfoRow(
                'AI Models',
                offlineProvider.offlineStats['aiInitialized'] == true
                    ? 'Loaded'
                    : 'Not Available'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageInfoRow(String label, String value) {
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
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Offline data cleared successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
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

  Widget _buildDatabaseResetOption(BuildContext context, ThemeData theme) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.refresh, color: Colors.orange),
        title: const Text('Reset Plant Database'),
        subtitle: const Text('Clear and reload all plant data (fixes missing plants)'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _showDatabaseResetDialog(context);
        },
      ),
    );
  }

  void _showDatabaseResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Plant Database'),
        content: const Text(
          'This will clear the plant database and reload all 16 plants (10 DOH + 6 additional). '
          'This will fix missing plants. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final plantProvider = Provider.of<PlantProvider>(context, listen: false);
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                await plantProvider.forceReinitializeDatabase();
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Database reset successfully! All 16 plants loaded.'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error resetting database: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}
