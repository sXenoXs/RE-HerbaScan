import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/app_provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/providers/language_provider.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:herbascan/features/auth/login_screen.dart';
import 'package:herbascan/features/auth/change_password_screen.dart';
import 'package:herbascan/features/auth/change_email_screen.dart';
import 'package:herbascan/features/admin/admin_dashboard_screen.dart';
import 'package:herbascan/core/widgets/offline_indicator.dart';
import 'package:herbascan/features/offline/offline_demo_screen.dart';
import 'package:herbascan/features/help/help_tutorial_screen.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          _buildHelpTutorialLink(context, theme),

          const SizedBox(height: 16),

          // Account / Personal Herbarium
          _buildSectionHeader(context, theme, 'Account'),
          _buildAccountSection(context, theme),

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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
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
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: SwitchListTile(
        secondary: const Icon(Icons.analytics),
        title: Text(AppLocalizations.of(context).showConfidenceScores),
        subtitle: const Text('Display confidence percentages'),
        value: appProvider.showConfidenceScores,
        onChanged: (value) async {
          appProvider.toggleConfidenceScores();
          // Save to SharedPreferences with key 'show_confidence'
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('show_confidence', value);
        },
      ),
    );
  }

  Widget _buildGradCAMSetting(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: SwitchListTile(
        secondary: const Icon(Icons.visibility),
        title: Text(AppLocalizations.of(context).showGradCAM),
        subtitle: const Text('Show AI focus areas'),
        value: appProvider.showGradCAM,
        onChanged: (value) async {
          appProvider.toggleGradCAM();
          // Save to SharedPreferences with key 'show_gradcam'
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('show_gradcam', value);
        },
      ),
    );
  }

  Widget _buildTop3ResultsSetting(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: SwitchListTile(
        secondary: const Icon(Icons.list),
        title: Text(AppLocalizations.of(context).showTop3Results),
        subtitle: const Text('Show top 3 predictions'),
        value: appProvider.showTop3Results,
        onChanged: (value) async {
          appProvider.toggleTop3Results();
          // Save to SharedPreferences with key 'show_top3'
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('show_top3', value);
        },
      ),
    );
  }

  Widget _buildAppVersionInfo(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        leading: const Icon(Icons.info),
        title: const Text('App Version'),
        subtitle: Text(appProvider.appVersion),
      ),
    );
  }

  Widget _buildModelVersionInfo(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        leading: const Icon(Icons.psychology),
        title: const Text('Model Version'),
        subtitle: Text(appProvider.modelVersion),
      ),
    );
  }

  Widget _buildHelpTutorialLink(BuildContext context, ThemeData theme) {
    final appLocalizations = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
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

  Widget _buildAccountSection(BuildContext context, ThemeData theme) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              auth.isLoggedIn
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.cloud_done_outlined),
                          title: const Text('Personal Herbarium'),
                          subtitle: Text(auth.user?.email ?? ''),
                          trailing: TextButton(
                            onPressed: () async {
                              await auth.signOut();
                            },
                            child: const Text('Sign out'),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: const Text('Change password'),
                          subtitle: const Text('Update your account password'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    const ChangePasswordScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.email_outlined),
                          title: const Text('Change email'),
                          subtitle: const Text('Update your account email'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    const ChangeEmailScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.cloud_upload_outlined),
                      title: const Text('Personal Herbarium'),
                      subtitle: const Text(
                        'Sign in to back up your scans to the cloud',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<bool>(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                    ),
              if (auth.isAdmin) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Review submissions'),
                  subtitle: const Text('Admin – approve or delete user scans'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const AdminDashboardScreen(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
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

        // Offline Actions
        _buildOfflineActions(context, theme),
      ],
    );
  }

  Widget _buildOfflineActions(BuildContext context, ThemeData theme) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
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
}
