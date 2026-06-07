import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/models/app_version.dart';
import 'package:herbascan/core/theme/app_theme.dart';

/// OtaAppUpdateService — checks for newer APK versions via Supabase and
/// orchestrates in-app download + Android install intent.
///
/// Integration point: call [checkAndPrompt] from SplashScreen._navigateToNextScreen()
/// before routing so the update dialog appears immediately after the splash delay.
///
/// Flow:
///   1. [checkForUpdate] queries app_versions for the latest active android version.
///   2. If version_code > current build number → [showUpdateDialog] is shown.
///   3. User taps "Update Now" → [downloadAndInstall] streams APK to temp dir.
///   4. OpenFile.open() triggers Android install intent — installs over old APK.
class OtaAppUpdateService {
  OtaAppUpdateService._();
  static final OtaAppUpdateService _instance = OtaAppUpdateService._();
  factory OtaAppUpdateService() => _instance;

  final _supabase = Supabase.instance.client;

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Checks for an update and shows the dialog if one is available.
  /// Returns true if an update dialog was shown, false otherwise.
  /// Safe to call on non-Android platforms (silently returns false).
  Future<bool> checkAndPrompt(BuildContext context) async {
    if (!Platform.isAndroid) return false;

    try {
      final update = await checkForUpdate();
      if (update == null) return false;
      if (!context.mounted) return false;
      await showUpdateDialog(context, update);
      return true;
    } catch (e) {
      // OTA check must never crash the app — log silently.
      debugPrint('[OtaAppUpdateService] checkAndPrompt error: $e');
      return false;
    }
  }

  /// Queries app_versions for the latest active android release.
  /// Returns [AppVersion] if a newer version is available, null otherwise.
  Future<AppVersion?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final response = await _supabase
          .from('app_versions')
          .select()
          .eq('platform', 'android')
          .eq('is_active', true)
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final latest = AppVersion.fromJson(response);
      if (latest.versionCode <= currentBuildNumber) return null;

      return latest;
    } catch (e) {
      debugPrint('[OtaAppUpdateService] checkForUpdate error: $e');
      return null;
    }
  }

  /// Downloads the APK to the device temp directory and triggers the install intent.
  /// [onProgress] receives values 0.0–1.0 as the download progresses.
  Future<void> downloadAndInstall(
    String url,
    String versionName, {
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final savePath = '${tempDir.path}/herbascan-v$versionName.apk';

    final dio = Dio();
    await dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    final result = await OpenFile.open(savePath, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      throw Exception('Failed to open installer: ${result.message}');
    }
  }

  // -------------------------------------------------------------------------
  // Update dialog
  // -------------------------------------------------------------------------

  /// Shows a Material dialog for the available [update].
  /// - If [AppVersion.isMandatory] is true: dialog cannot be dismissed, blocks navigation.
  /// - Otherwise: user can tap "Later" to proceed without updating.
  Future<void> showUpdateDialog(BuildContext context, AppVersion update) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !update.isMandatory,
      builder: (ctx) => _UpdateDialog(update: update, service: this),
    );
  }
}

// ---------------------------------------------------------------------------
// Update dialog widget (private)
// ---------------------------------------------------------------------------
class _UpdateDialog extends StatefulWidget {
  final AppVersion update;
  final OtaAppUpdateService service;

  const _UpdateDialog({required this.update, required this.service});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _errorMessage;

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    try {
      await widget.service.downloadAndInstall(
        widget.update.downloadUrl,
        widget.update.versionName,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      // After OpenFile.open() the OS takes over — dialog can close.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Download failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMandatory = widget.update.isMandatory;

    return PopScope(
      // Prevent back-button dismissal on mandatory updates
      canPop: !isMandatory && !_isDownloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: AppTheme.botanicalPrimary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Update Available',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.safeBgLight,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: AppTheme.botanicalPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'v${widget.update.versionName}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.botanicalPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Mandatory badge
            if (isMandatory) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 4),
                    Text(
                      'Required update',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Release notes
            if (widget.update.releaseNotes.isNotEmpty) ...[
              Text(
                widget.update.releaseNotes,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],

            // Download progress
            if (_isDownloading) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: AppTheme.botanicalPrimary.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.botanicalPrimary),
                borderRadius: BorderRadius.circular(100),
              ),
              const SizedBox(height: 6),
              Text(
                _progress > 0
                    ? 'Downloading… ${(_progress * 100).toStringAsFixed(0)}%'
                    : 'Preparing download…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          // "Later" only shown for optional updates and when not downloading
          if (!isMandatory && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),

          // "Update Now" / downloading state
          FilledButton.icon(
            onPressed: _isDownloading ? null : _startDownload,
            icon: _isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(_isDownloading ? 'Downloading…' : 'Update Now'),
          ),
        ],
      ),
    );
  }
}
