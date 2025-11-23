import 'package:flutter/material.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/features/scan/scan_screen.dart';
import 'package:herbascan/features/browse/browse_screen.dart';
import 'package:herbascan/features/browse/condition_search_screen.dart';
import 'dart:io';

class NoMatchFoundScreen extends StatelessWidget {
  final String imagePath;
  final double? lowConfidence;

  const NoMatchFoundScreen({
    super.key,
    required this.imagePath,
    this.lowConfidence,
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
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 60,
                color: Colors.orange,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              appLocalizations.noMatchFound,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              appLocalizations.noMatchDescription,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),

            if (lowConfidence != null) ...[
              const SizedBox(height: 8),
              Text(
                'Confidence: ${(lowConfidence! * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Preview Image
            if (imagePath.isNotEmpty)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
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

            // Possible Reasons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blue.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Possible reasons:',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildReasonItem(
                      'Plant not in our database', Icons.storage, theme),
                  _buildReasonItem('Image quality too low',
                      Icons.image_not_supported, theme),
                  _buildReasonItem('Unusual leaf angle or position',
                      Icons.rotate_90_degrees_ccw, theme),
                  _buildReasonItem('Young or damaged leaf', Icons.eco, theme),
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      // Navigate to condition search
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ConditionSearchScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.medical_services),
                    label: Text(appLocalizations.byCondition),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildReasonItem(String text, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.blue.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
