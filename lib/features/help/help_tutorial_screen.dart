import 'package:flutter/material.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/services/usage_analytics.dart';

class HelpTutorialScreen extends StatefulWidget {
  const HelpTutorialScreen({super.key});

  @override
  State<HelpTutorialScreen> createState() => _HelpTutorialScreenState();
}

class _HelpTutorialScreenState extends State<HelpTutorialScreen> {
  final UsageAnalytics _analytics = UsageAnalytics();

  @override
  void initState() {
    super.initState();
    // Track help screen view
    _analytics.trackHelpViewed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLocalizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.helpAndTutorial),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    appLocalizations.helpAndTutorial,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Learn how to get the best results from HerbaScan',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Best Practices Section
            _buildSectionTitle(
                appLocalizations.bestPractices, Icons.stars, theme),
            const SizedBox(height: 12),
            _buildPracticeCard(
              '1. ${appLocalizations.useBrightLight}',
              'Natural daylight works best. Avoid direct sunlight which can cause glare and shadows.',
              Icons.wb_sunny,
              theme.colorScheme.primary,
              theme,
            ),
            _buildPracticeCard(
              '2. ${appLocalizations.holdSteady}',
              'Keep your device stable to prevent blurry images. Use both hands or rest on a surface.',
              Icons.pan_tool,
              theme.colorScheme.secondary,
              theme,
            ),
            _buildPracticeCard(
              '3. ${appLocalizations.cleanLeaf}',
              'Choose a healthy, mature leaf without damage or disease for best results.',
              Icons.eco,
              Colors.green,
              theme,
            ),
            _buildPracticeCard(
              '4. ${appLocalizations.singleLeafFocus}',
              'Frame a single leaf in the center. Avoid including multiple leaves or background elements.',
              Icons.center_focus_strong,
              Colors.orange,
              theme,
            ),
            _buildPracticeCard(
              '5. ${appLocalizations.fillFrame}',
              'Fill most of the frame with the leaf for better AI recognition.',
              Icons.crop_free,
              Colors.purple,
              theme,
            ),
            _buildPracticeCard(
              '6. ${appLocalizations.plainBackground}',
              'Use a plain, contrasting background (white paper or cloth works well).',
              Icons.image,
              Colors.teal,
              theme,
            ),

            const SizedBox(height: 24),

            // Common Issues Section
            _buildSectionTitle(
                'Common Issues', Icons.report_problem_outlined, theme),
            const SizedBox(height: 12),
            _buildIssueCard(
              'Poor Image Quality',
              'If you see a "Poor Image Quality" message, retake the photo with better lighting and a steady hand.',
              Icons.image_not_supported,
              theme.colorScheme.error,
              theme,
            ),
            _buildIssueCard(
              'No Match Found',
              'If no match is found, try a different leaf or manually browse the plant database.',
              Icons.search_off,
              Colors.orange,
              theme,
            ),
            _buildIssueCard(
              'Low Confidence Score',
              'Scores below 80% may be less reliable. Compare with plant details to verify.',
              Icons.trending_down,
              Colors.amber,
              theme,
            ),

            const SizedBox(height: 24),

            // Features Section
            _buildSectionTitle('App Features', Icons.featured_play_list, theme),
            const SizedBox(height: 12),
            _buildFeatureCard(
              'Browse Plants',
              'Explore our database of 13 medicinal plants with detailed information.',
              Icons.search,
              theme,
            ),
            _buildFeatureCard(
              'DOH Approved',
              'View the 9 Philippine Department of Health approved medicinal plants.',
              Icons.verified,
              theme,
            ),
            _buildFeatureCard(
              'Condition Search',
              'Search plants by medical condition to find natural remedies.',
              Icons.medical_services,
              theme,
            ),
            _buildFeatureCard(
              'Scan History',
              'Access your past scans with confidence scores and timestamps.',
              Icons.history,
              theme,
            ),
            _buildFeatureCard(
              'GradCAM Visualization',
              'See which parts of the leaf the AI focused on for identification.',
              Icons.visibility,
              theme,
            ),

            const SizedBox(height: 24),

            // Safety Disclaimer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.error,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medical Disclaimer',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          appLocalizations.medicalDisclaimer,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeCard(String title, String description, IconData icon,
      Color color, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueCard(String title, String description, IconData icon,
      Color color, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
      String title, String description, IconData icon, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Icon(icon, color: Colors.white, size: 24),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          description,
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
