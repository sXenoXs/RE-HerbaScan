import 'package:flutter/material.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/features/scan/scan_screen.dart';
import 'package:herbascan/features/browse/browse_screen.dart';
import 'dart:io';

class PoorImageQualityScreen extends StatelessWidget {
  final String imagePath;

  const PoorImageQualityScreen({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLocalizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.scanResults),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Error Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 60,
                color: theme.colorScheme.error,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              appLocalizations.poorImageQuality,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              appLocalizations.imageQualityTooLow,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Preview Image
            if (imagePath.isNotEmpty)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 32),

            // Tips Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          appLocalizations.improveImageQuality,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTipItem(
                      appLocalizations.useBrightLight, Icons.wb_sunny, theme),
                  _buildTipItem(
                      appLocalizations.holdSteady, Icons.pan_tool, theme),
                  _buildTipItem(appLocalizations.cleanLeaf, Icons.eco, theme),
                  _buildTipItem(appLocalizations.singleLeafFocus,
                      Icons.center_focus_strong, theme),
                  _buildTipItem(appLocalizations.avoidShadowsAndReflections,
                      Icons.wb_twilight, theme),
                  _buildTipItem(
                      appLocalizations.fillFrame, Icons.crop_free, theme),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Go back to scan screen
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => const ScanScreen()),
                        (route) => route.isFirst,
                      );
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: Text(appLocalizations.retake),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to browse screen
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => const BrowseScreen()),
                        (route) => route.isFirst,
                      );
                    },
                    icon: const Icon(Icons.search),
                    label: Text(appLocalizations.browseManually),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildTipItem(String text, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
