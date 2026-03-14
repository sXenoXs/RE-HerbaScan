import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/app_provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/providers/language_provider.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/features/auth/login_screen.dart';
import 'package:herbascan/features/auth/change_password_screen.dart';
import 'package:herbascan/features/auth/change_email_screen.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Account / Personal Herbarium
          _buildSectionLabel(context, theme, 'Account'),
          const SizedBox(height: 8),
          _buildAccountBlock(context, theme),

          const SizedBox(height: 24),

          // 2. App Preferences
          _buildSectionLabel(context, theme, 'App Preferences'),
          const SizedBox(height: 8),
          _buildGroupedCard(
            theme,
            children: [
              _buildThemeTile(context, theme),
              _buildSoftDivider(theme),
              _buildLanguageTile(context, theme),
              _buildSoftDivider(theme),
              _buildAutoSaveTile(context, theme),
            ],
          ),

          const SizedBox(height: 24),

          // 3. Scanning & AI
          _buildSectionLabel(context, theme, 'Scanning & AI'),
          const SizedBox(height: 8),
          _buildGroupedCard(
            theme,
            children: [
              _buildConfidenceScoresTile(context, theme),
              _buildSoftDivider(theme),
              _buildGradCAMTile(context, theme),
              _buildSoftDivider(theme),
              _buildTop3ResultsTile(context, theme),
            ],
          ),

          const SizedBox(height: 24),

          // 4. Support & About
          _buildSectionLabel(context, theme, 'Support & About'),
          const SizedBox(height: 8),
          _buildGroupedCard(
            theme,
            children: [
              _buildHelpTutorialTile(context, theme),
              _buildSoftDivider(theme),
              _buildAppVersionTile(context, theme),
              _buildSoftDivider(theme),
              _buildModelVersionTile(context, theme),
            ],
          ),

          const SizedBox(height: 32),

          // 5. Developer Options (visually separated)
          _buildDeveloperOptionsBlock(context, theme),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(
      BuildContext context, ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildGroupedCard(ThemeData theme,
      {required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  // ── Account block ──────────────────────────────────────────────────────────

  Widget _buildAccountBlock(BuildContext context, ThemeData theme) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isLoggedIn) {
          return _buildGroupedCard(
            theme,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Personal Herbarium'),
                subtitle:
                    const Text('Sign in to back up your scans to the cloud'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
              ),
            ],
          );
        }

        final email = auth.user?.email ?? '';
        final initials = email.isNotEmpty ? email[0].toUpperCase() : '?';
        final isAdmin = auth.isAdmin;

        return _buildGroupedCard(
          theme,
          children: [
            // User avatar + email header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        AppTheme.botanicalPrimary.withOpacity(0.15),
                    child: Text(
                      initials,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.botanicalPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isAdmin ? 'Administrator' : 'Standard User',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isAdmin
                                ? AppTheme.botanicalPrimary
                                : theme.colorScheme.onSurface.withOpacity(0.45),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildSoftDivider(theme),
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: const Text('Change Password'),
              subtitle: const Text('Update your account password'),
              trailing:
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),
            _buildSoftDivider(theme),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email Address'),
              subtitle: const Text('Update your account email'),
              trailing:
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const ChangeEmailScreen(),
                  ),
                );
              },
            ),
            if (isAdmin) ...[
              _buildSoftDivider(theme),
              ListTile(
                leading: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppTheme.botanicalPrimary,
                ),
                title: const Text('Admin Console'),
                subtitle: const Text('Approve or delete user submissions'),
                trailing:
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => context.push('/admin'),
              ),
            ],
            _buildSoftDivider(theme),
            // Sign Out as a plain list tile — restores visual rhythm
            ListTile(
              leading: Icon(Icons.logout_rounded,
                  color: theme.colorScheme.error),
              title: Text(
                'Sign Out',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () async {
                await auth.signOut();
              },
            ),
            _buildSoftDivider(theme),
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Delete Account',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Permanently delete your account and cloud data',
              ),
              trailing:
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => _showDeleteAccountDialog(context, auth),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSoftDivider(ThemeData theme) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: theme.colorScheme.onSurface.withOpacity(0.07),
    );
  }


  // ── App Preferences tiles ──────────────────────────────────────────────────

  Widget _buildThemeTile(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);
    return SwitchListTile(
      secondary: Icon(
        appProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
      ),
      title: Text(appProvider.isDarkMode ? 'Dark Mode' : 'Light Mode'),
      subtitle: const Text('Toggle between dark and light themes'),
      value: appProvider.isDarkMode,
      onChanged: (_) => appProvider.toggleDarkMode(),
    );
  }

  Widget _buildLanguageTile(BuildContext context, ThemeData theme) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    return ListTile(
      leading: const Icon(Icons.language_rounded),
      title: Text(AppLocalizations.of(context).language),
      subtitle:
          Text(languageProvider.isEnglish ? 'English' : 'Filipino'),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: () => languageProvider.toggleLanguage(),
    );
  }

  Widget _buildAutoSaveTile(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);
    return SwitchListTile(
      secondary: const Icon(Icons.save_outlined),
      title: const Text('Auto-save Scans'),
      subtitle: const Text('Automatically save scan results'),
      value: appProvider.autoSaveScans,
      onChanged: (value) async {
        appProvider.toggleAutoSaveScans();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auto_save_scans', value);
      },
    );
  }

  // ── Scanning & AI tiles (de-jargonified) ──────────────────────────────────

  Widget _buildConfidenceScoresTile(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);
    return SwitchListTile(
      secondary: const Icon(Icons.analytics_outlined),
      title: const Text('Show Prediction Confidence'),
      value: appProvider.showConfidenceScores,
      onChanged: (value) async {
        appProvider.toggleConfidenceScores();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('show_confidence', value);
      },
    );
  }

  Widget _buildGradCAMTile(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);
    return SwitchListTile(
      secondary: const Icon(Icons.visibility_outlined),
      title: const Text('Show AI Reasoning Heatmap'),
      subtitle: const Text('Highlights the leaf areas the AI examined'),
      value: appProvider.showGradCAM,
      onChanged: (value) async {
        appProvider.toggleGradCAM();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('show_gradcam', value);
      },
    );
  }

  Widget _buildTop3ResultsTile(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);
    return SwitchListTile(
      secondary: const Icon(Icons.format_list_numbered_rounded),
      title: const Text('Show Alternative Matches'),
      value: appProvider.showTop3Results,
      onChanged: (value) async {
        appProvider.toggleTop3Results();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('show_top3', value);
      },
    );
  }

  // ── Support & About tiles ──────────────────────────────────────────────────

  Widget _buildHelpTutorialTile(BuildContext context, ThemeData theme) {
    return ListTile(
      leading: const Icon(Icons.help_outline_rounded),
      title: Text(AppLocalizations.of(context).helpAndTutorial),
      subtitle: const Text('Learn how to get the best scanning results'),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const HelpTutorialScreen(),
          ),
        );
      },
    );
  }

  Widget _buildAppVersionTile(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);
    return ListTile(
      leading: const Icon(Icons.info_outline_rounded),
      title: const Text('App Version'),
      subtitle: Text(appProvider.appVersion),
    );
  }

  Widget _buildModelVersionTile(BuildContext context, ThemeData theme) {
    final appProvider = Provider.of<AppProvider>(context);
    return ListTile(
      leading: const Icon(Icons.psychology_outlined),
      title: const Text('Model Version'),
      subtitle: Text(appProvider.modelVersion),
    );
  }

  // ── Developer Options block ────────────────────────────────────────────────

  Widget _buildDeveloperOptionsBlock(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Developer Options',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withOpacity(0.45),
              letterSpacing: 0.4,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Consumer<OfflineProvider>(
            builder: (context, offlineProvider, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOfflineModeTile(context, theme, offlineProvider),
                  _buildSoftDivider(theme),
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('Refresh Offline Data'),
                    subtitle: const Text(
                        'Reload stats from local database and sync status'),
                    onTap: () async {
                      try {
                        await offlineProvider.refreshOfflineData();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Offline data refreshed successfully'),
                              backgroundColor: AppTheme.botanicalPrimary,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error refreshing data: $e'),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _buildSoftDivider(theme),
                  ListTile(
                    leading: const Icon(Icons.storage_rounded),
                    title: const Text('Offline Storage Info'),
                    subtitle: Text(
                      'Scans: ${offlineProvider.offlineStats['totalScans'] ?? 0} · '
                      'Plants: ${offlineProvider.offlineStats['totalPlants'] ?? 0} · '
                      'Pending: ${offlineProvider.offlineStats['pendingSync'] ?? 0}',
                    ),
                    onTap: () async {
                      await offlineProvider.refreshOfflineData();
                      if (context.mounted) {
                        _showOfflineStorageDialog(context, offlineProvider);
                      }
                    },
                  ),
                  _buildSoftDivider(theme),
                  ListTile(
                    leading: Icon(
                      Icons.delete_sweep_outlined,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      'Clear Offline Data',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    subtitle: const Text(
                        'Remove all scan history and pending sync from this device'),
                    onTap: () =>
                        _showClearDataDialog(context, offlineProvider),
                  ),
                  _buildSoftDivider(theme),
                  ListTile(
                    leading: const Icon(Icons.monitor_heart_outlined),
                    title: const Text('System Diagnostics'),
                    subtitle: const Text(
                        'View models, database, and connection status'),
                    trailing:
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const OfflineDemoScreen(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineModeTile(
      BuildContext context, ThemeData theme, OfflineProvider offlineProvider) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    return SwitchListTile(
      secondary: const Icon(Icons.offline_bolt_outlined),
      title: Text(AppLocalizations.of(context).offlineMode),
      subtitle: const Text(
          'Force offline: use AI and local database only, no cloud sync'),
      value: offlineProvider.isOfflineMode,
      onChanged: (value) async {
        await offlineProvider.toggleOfflineMode();
        await appProvider.syncOfflineModeFromPrefs();
      },
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

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
            _buildStorageInfoRow(
                'Total Scans',
                '${offlineProvider.offlineStats['totalScans'] ?? 0}'),
            _buildStorageInfoRow(
                'Total Plants',
                '${offlineProvider.offlineStats['totalPlants'] ?? 0}'),
            _buildStorageInfoRow(
                'DOH Plants',
                '${offlineProvider.offlineStats['dohPlants'] ?? 0}'),
            _buildStorageInfoRow(
                'Pending Sync',
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthProvider auth) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            color: theme.colorScheme.error, size: 48),
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your Personal Herbarium account and all cloud data. '
          'Your device scan history will not be affected. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await auth.deleteAccount();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(
      BuildContext context, OfflineProvider offlineProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Offline Data'),
        content: const Text(
          'This will permanently delete all scan history and pending sync on this device. '
          'This action cannot be undone. Are you sure?',
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
                if (context.mounted) {
                  await context.read<PlantProvider>().loadScanHistory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Offline data cleared successfully'),
                      backgroundColor: AppTheme.botanicalPrimary,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error clearing data: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Clear',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}
