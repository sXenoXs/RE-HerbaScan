import 'package:flutter/material.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/services/usage_analytics.dart';
import 'package:herbascan/core/theme/app_theme.dart';

class HelpTutorialScreen extends StatefulWidget {
  /// When set to 'ood_explanation', scrolls to and expands the OOD FAQ tile (ROADMAP B 1.3).
  final String? scrollToSection;

  const HelpTutorialScreen({super.key, this.scrollToSection});

  @override
  State<HelpTutorialScreen> createState() => _HelpTutorialScreenState();
}

class _HelpTutorialScreenState extends State<HelpTutorialScreen> {
  final UsageAnalytics _analytics = UsageAnalytics();
  final GlobalKey _oodSectionKey = GlobalKey();

  static const List<_TipData> _tips = [
    _TipData(
      icon: Icons.wb_sunny_rounded,
      title: 'Bright\nLighting',
      subtitle: 'Natural daylight works best. Avoid direct sunlight.',
    ),
    _TipData(
      icon: Icons.filter_center_focus_rounded,
      title: 'Steady\nHands',
      subtitle: 'Hold device stable. Use both hands or rest on a surface.',
    ),
    _TipData(
      icon: Icons.eco_rounded,
      title: 'Clean\nLeaf',
      subtitle: 'Choose a healthy, mature leaf without damage.',
    ),
    _TipData(
      icon: Icons.center_focus_strong_rounded,
      title: 'Single\nLeaf',
      subtitle: 'Frame one leaf in the center without overlap.',
    ),
    _TipData(
      icon: Icons.crop_free_rounded,
      title: 'Fill\nFrame',
      subtitle: 'Fill most of the frame with the leaf for better AI results.',
    ),
    _TipData(
      icon: Icons.image_rounded,
      title: 'Plain\nBackground',
      subtitle: 'Use white paper or plain cloth as background.',
    ),
  ];

  static const List<_IssueData> _issues = [
    _IssueData(
      title: 'Poor Image Quality',
      content:
          'If you see a "Poor Image Quality" message, retake the photo with better lighting and a steady hand. Make sure the lens is clean.',
    ),
    _IssueData(
      title: 'No Match Found',
      content:
          'If no match is found, try photographing a different leaf or manually browse the plant database. Ensure the leaf is clearly visible.',
    ),
    _IssueData(
      title: 'Low Confidence Score',
      content:
          'Scores below 85% may be less reliable. Compare with plant details in the catalog to verify the identification before use.',
    ),
  ];

  static const List<_FeatureData> _features = [
    _FeatureData(
      icon: Icons.search_rounded,
      title: 'Browse Plants',
      subtitle:
          'Explore our database of medicinal plants with detailed information.',
    ),
    _FeatureData(
      icon: Icons.verified_rounded,
      title: 'DOH Approved',
      subtitle:
          'View Philippine Department of Health approved medicinal plants.',
    ),
    _FeatureData(
      icon: Icons.medical_services_rounded,
      title: 'Condition Search',
      subtitle: 'Search plants by medical condition to find natural remedies.',
    ),
    _FeatureData(
      icon: Icons.history_rounded,
      title: 'Scan History',
      subtitle: 'Access your past scans with confidence scores and timestamps.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _analytics.trackHelpViewed();
    if (widget.scrollToSection == 'ood_explanation') {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToOODSection());
    }
  }

  void _scrollToOODSection() {
    if (!mounted) return;
    final context = _oodSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.helpAndTutorial),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MedicalDisclaimerBanner(disclaimerText: loc.medicalDisclaimer),

            const SizedBox(height: 28),

            // Best Practices — horizontal carousel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                loc.bestPractices,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _tips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _TipCard(tip: _tips[index], theme: theme),
              ),
            ),

            const SizedBox(height: 32),

            // Common Issues — FAQ accordion
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Common Issues',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._issues.map(
              (issue) => _IssueExpansionTile(issue: issue, theme: theme),
            ),
            // ROADMAP B 1.3: OOD explanation — why app said it cannot identify
            _OODExplanationTile(
              key: _oodSectionKey,
              theme: theme,
              initiallyExpanded: widget.scrollToSection == 'ood_explanation',
            ),

            const SizedBox(height: 32),

            // App Features — borderless ListTile
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'App Features',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const SizedBox(height: 8),
            ..._features.map(
              (feature) => _FeatureListTile(feature: feature, theme: theme),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Data classes ────────────────────────────────────────────────────────────

class _TipData {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TipData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _IssueData {
  final String title;
  final String content;

  const _IssueData({required this.title, required this.content});
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _MedicalDisclaimerBanner extends StatelessWidget {
  final String disclaimerText;

  const _MedicalDisclaimerBanner({required this.disclaimerText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.warningBgLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.medical_services_rounded,
            color: AppTheme.warningAmber,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Medical Disclaimer',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warningAmber,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  disclaimerText,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final _TipData tip;
  final ThemeData theme;

  const _TipCard({required this.tip, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.botanicalPrimary.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              tip.icon,
              color: AppTheme.botanicalPrimary,
              size: 26,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tip.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueExpansionTile extends StatelessWidget {
  final _IssueData issue;
  final ThemeData theme;

  const _IssueExpansionTile({required this.issue, required this.theme});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding:
          const EdgeInsets.only(left: 16, right: 16, bottom: 14, top: 0),
      title: Text(
        issue.title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            issue.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// ROADMAP B 1.3: Why the app said it cannot identify the plant (low confidence / OOD).
class _OODExplanationTile extends StatelessWidget {
  final ThemeData theme;
  final bool initiallyExpanded;

  const _OODExplanationTile({
    super.key,
    required this.theme,
    this.initiallyExpanded = false,
  });

  static const String _title =
      'Why did the app say it cannot identify my plant?';
  static const String _body =
      'HerbaScan identifies only the 31 Philippine medicinal plants in its database. '
      'When the identification confidence is too low (below 85%), the app does not show '
      'safety information or preparation guides for your safety—using the wrong plant can be harmful.\n\n'
      'Tips: use a clear, single leaf; avoid shadows and blur; ensure the plant is one of the '
      '31 supported species. You can browse the plant list in the app to see which plants are supported.';

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: const Key('ood_explanation'),
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding:
          const EdgeInsets.only(left: 16, right: 16, bottom: 14, top: 0),
      title: Text(
        _title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureListTile extends StatelessWidget {
  final _FeatureData feature;
  final ThemeData theme;

  const _FeatureListTile({required this.feature, required this.theme});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(
        feature.icon,
        color: AppTheme.botanicalPrimary,
        size: 26,
      ),
      title: Text(
        feature.title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      subtitle: Text(
        feature.subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
