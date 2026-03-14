// lib/features/scan/plant_result_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/widgets/gradcam_visualization.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/providers/app_provider.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/safety_profile.dart';
import 'package:herbascan/core/models/scan_result.dart';
import 'package:herbascan/core/services/herbarium_service.dart';
import 'package:herbascan/core/services/adaptive_gradcam_service.dart';
import 'package:herbascan/core/services/habitat_service.dart';
import 'package:herbascan/core/services/safety_profile_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/contraindication_engine_widget.dart';
import 'package:herbascan/features/help/help_tutorial_screen.dart';
import 'package:herbascan/features/scan/habitat_map_screen.dart';
import 'package:herbascan/features/scan/plant_detail_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'dart:io';

class PlantResultScreen extends StatefulWidget {
  final String imagePath;
  final List<Map<String, dynamic>> predictions;
  final String? gradCAMPath;
  final String? summaryGradCAMPath;
  final Uint8List? gradcamImageBytes;
  final String? method; // 'grad-cam' or 'cam'
  final bool? fallbackUsed;
  final bool isFromHistory;
  final ScanResult? scanResultFromHistory;

  const PlantResultScreen({
    super.key,
    required this.imagePath,
    required this.predictions,
    this.gradCAMPath,
    this.summaryGradCAMPath,
    this.gradcamImageBytes,
    this.method,
    this.fallbackUsed,
    this.isFromHistory = false,
    this.scanResultFromHistory,
  });

  factory PlantResultScreen.fromScanResult(ScanResult scanResult) {
    final predictions = scanResult.predictions.map((pred) {
      return {
        'label': pred.plantName,
        'plantName': pred.plantName,
        'scientificName': pred.scientificName,
        'confidence': pred.confidence,
        'index': 0,
        'isDOHApproved': false,
      };
    }).toList();

    Uint8List? gradcamImageBytes;
    if (scanResult.gradCAMPath != null) {
      try {
        final file = File(scanResult.gradCAMPath!);
        if (file.existsSync()) {
          gradcamImageBytes = file.readAsBytesSync();
        }
      } catch (e) {
        debugPrint('⚠️ Error loading GradCAM image from path: $e');
      }
    }

    final method = scanResult.metadata['method'] as String?;
    final fallbackUsed = scanResult.metadata['fallbackUsed'] as bool? ?? false;

    return PlantResultScreen(
      imagePath: scanResult.imagePath,
      predictions: predictions,
      gradCAMPath: scanResult.gradCAMPath,
      summaryGradCAMPath: scanResult.metadata['summaryGradCAMPath'] as String?,
      gradcamImageBytes: gradcamImageBytes,
      method: method,
      fallbackUsed: fallbackUsed,
      isFromHistory: true,
      scanResultFromHistory: scanResult,
    );
  }

  @override
  State<PlantResultScreen> createState() => _PlantResultScreenState();
}

class _PlantResultScreenState extends State<PlantResultScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaved = false;
  bool _savedToCloud = false;
  ScanResult? _savedScanResult;

  // Regenerated GradCAM state
  Uint8List? _regeneratedGradcamImageBytes;
  String? _regeneratedMethod;
  bool? _regeneratedFallbackUsed;
  bool _isRegenerating = false;

  // Settings from SharedPreferences
  bool _showConfidence = true;
  bool _showGradcam = true;
  bool _showTop3 = true;

  final AdaptiveGradCAMService _adaptiveGradCAMService =
      AdaptiveGradCAMService();

  @override
  void initState() {
    super.initState();

    if (widget.isFromHistory) {
      _isSaved = true;
      if (widget.scanResultFromHistory != null) {
        _savedScanResult = widget.scanResultFromHistory;
      }
    }

    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final autoSave = context.read<AppProvider>().autoSaveScans;
      if (!widget.isFromHistory && autoSave) {
        _saveResultsAutomatically();
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _showConfidence = prefs.getBool('show_confidence') ?? true;
          _showGradcam = prefs.getBool('show_gradcam') ?? true;
          _showTop3 = prefs.getBool('show_top3') ?? true;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error loading settings: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Resolve matched plant from provider ──────────────────────────────────
  Plant? _resolveMatchedPlant(String plantName) {
    try {
      final plantProvider = Provider.of<PlantProvider>(context, listen: false);
      final normalized = plantName.trim().toLowerCase();
      for (final p in plantProvider.plants) {
        if (p.commonName.trim().toLowerCase() == normalized ||
            p.scientificName.trim().toLowerCase() == normalized) {
          return p;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.predictions.isEmpty) {
      return _buildErrorScreen();
    }

    final topPrediction = widget.predictions.first;
    final plantName = topPrediction['plantName'] ?? 'Unknown Plant';
    final confidence = (topPrediction['confidence'] ?? 0.0).toDouble();
    final scientificName =
        (topPrediction['scientificName'] as String?)?.trim().isNotEmpty == true
            ? topPrediction['scientificName'] as String
            : plantName;

    final hasHeatmap =
        widget.gradcamImageBytes != null || widget.gradCAMPath != null;
    final hasValidMethod = widget.method != null &&
        widget.method != 'classification_only' &&
        widget.method != '';
    final hasFallback = widget.fallbackUsed == true;
    final showAIVision =
        _showGradcam && (hasFallback || hasValidMethod || hasHeatmap);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            // Edge-to-edge hero SliverAppBar
            SliverAppBar(
              expandedHeight: 300,
              floating: false,
              pinned: true,
              snap: false,
              elevation: 0,
              // Solid background when collapsed so tab content doesn't bleed through
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              leading: _buildGlassmorphicButton(
                icon: Icons.arrow_back_ios_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              actions: [
                _buildGlassmorphicButton(
                  icon: Icons.share_rounded,
                  onTap: _shareResults,
                ),
                const SizedBox(width: 8),
                _buildGlassmorphicButton(
                  icon: _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  onTap: () => _showSaveOptions(context),
                ),
                const SizedBox(width: 12),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background:
                    _buildHeroBackground(context, plantName, confidence),
              ),
            ),
            // Pinned TabBar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.botanicalPrimary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.botanicalPrimary,
                  indicatorWeight: 2,
                  tabs: const [
                    Tab(text: 'Insights'),
                    Tab(text: 'AI Vision'),
                  ],
                ),
                Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildInsightsTab(
                context, topPrediction, plantName, scientificName, confidence),
            _buildAIVisionTab(
                context, plantName, scientificName, confidence, showAIVision),
          ],
        ),
      ),
    );
  }

  // ── Hero background (edge-to-edge scan image) ────────────────────────────
  Widget _buildHeroBackground(
      BuildContext context, String plantName, double confidence) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Scan image fills FlexibleSpaceBar edge-to-edge
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    FullScreenImageView(imagePath: widget.imagePath),
              ),
            );
          },
          child: Hero(
            tag: 'scan_image_${widget.imagePath.hashCode}',
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.darkSurface,
                child: const Center(
                  child: Icon(Icons.eco_rounded,
                      size: 64, color: AppTheme.botanicalPrimaryL),
                ),
              ),
            ),
          ),
        ),
        // Bottom gradient overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black54, Colors.transparent],
                stops: [0.0, 0.6],
              ),
            ),
          ),
        ),
        // Glassmorphic confidence badge — bottom-left
        Positioned(
          left: 16,
          bottom: 16,
          child: _buildConfidenceBadge(confidence),
        ),
      ],
    );
  }

  Widget _buildConfidenceBadge(double confidence) {
    final pct = (confidence.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
    final color = _getConfidenceColor(confidence);

    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            if (_showConfidence)
              Text(
                '$pct% Match',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassmorphicButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    // Always use dark semi-transparent pill so it's readable over both the
    // hero image (expanded) and the solid scaffold background (collapsed).
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ── Tab 1: Insights ───────────────────────────────────────────────────────
  Widget _buildInsightsTab(
    BuildContext context,
    Map<String, dynamic> topPrediction,
    String plantName,
    String scientificName,
    double confidence,
  ) {
    final theme = Theme.of(context);
    final resolvedPlant = _resolveMatchedPlant(plantName);
    final isLowConfidence = confidence < kLowConfidenceThreshold;

    final safetyFuture = resolvedPlant != null
        ? SafetyProfileService().getSafetyProfile(resolvedPlant)
        : Future<SafetyProfile?>.value(null);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: FutureBuilder<SafetyProfile?>(
        future: safetyFuture,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final hasActiveContraindications = profile != null &&
              (profile.drugInteractions.isNotEmpty ||
                  profile.strictContraindications.isNotEmpty ||
                  profile.pregnancyWarning);
          // ROADMAP B 3.3: When high-risk, safety first (CE below name, before scientific name)
          final showSafetyFirst = hasActiveContraindications && !isLowConfidence;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plant name row + DOH badge (ROADMAP B 2.2)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      plantName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  _buildDOHBadge(context, resolvedPlant?.isDOHApproved ?? false),
                ],
              ),
              if (showSafetyFirst) ...[
                const SizedBox(height: 16),
                ContraindicationEngineWidget(
                  plant: resolvedPlant,
                  commonName: plantName,
                  confidence: confidence,
                ),
                const SizedBox(height: 16),
                Text(
                  scientificName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  scientificName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ContraindicationEngineWidget(
                  plant: resolvedPlant,
                  commonName: plantName,
                  confidence: confidence,
                ),
              ],
              const SizedBox(height: 16),
              if (isLowConfidence)
                _buildUncertainMatchCard(context)
              else
                _buildActionCards(context, resolvedPlant),
              if (_showTop3 && widget.predictions.length > 1) ...[
                const SizedBox(height: 24),
                _buildAlternativeMatches(theme),
              ],
            ],
          );
        },
      ),
    );
  }

  /// ROADMAP B 1.3: Shown when confidence < threshold; links to Help OOD section.
  Widget _buildUncertainMatchCard(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.search_off_rounded,
                color: theme.colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.plantNotRecognized,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.uncertainMatchBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HelpTutorialScreen(
                    scrollToSection: 'ood_explanation',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: Text(l10n.whyCantAppIdentify),
          ),
        ],
      ),
    );
  }

  /// ROADMAP B 1.2: Open Plant Profile + View Habitat Map; gated when low confidence.
  Widget _buildActionCards(BuildContext context, Plant? resolvedPlant) {
    return Row(
      children: [
        Expanded(
          child: _buildHeroActionCard(
            context,
            icon: Icons.eco_rounded,
            label: 'Open Plant Profile',
            color: AppTheme.botanicalPrimary,
            onTap: resolvedPlant != null
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlantDetailScreen(
                          plant: resolvedPlant,
                        ),
                      ),
                    );
                  }
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FutureBuilder<bool>(
            future: resolvedPlant != null
                ? HabitatService().hasHabitatData(resolvedPlant.id)
                : Future.value(false),
            builder: (context, snapshot) {
              final hasHabitat = snapshot.data == true;
              return _buildHeroActionCard(
                context,
                icon: Icons.map_rounded,
                label: 'View Habitat Map',
                color: Colors.teal,
                onTap: hasHabitat && resolvedPlant != null
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                HabitatMapScreen(plant: resolvedPlant),
                          ),
                        );
                      }
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  /// ROADMAP B 2.2: DOH Verified (green) or Scientifically Documented (amber); tappable → info sheet.
  Widget _buildDOHBadge(BuildContext context, bool isDOHApproved) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDOHApproved
        ? (isDark ? AppTheme.safeGreen.withValues(alpha: 0.25) : AppTheme.safeBgLight)
        : (isDark ? AppTheme.warningAmber.withValues(alpha: 0.2) : AppTheme.warningBgLight);
    final fgColor = isDOHApproved ? AppTheme.safeGreen : AppTheme.warningAmber;
    final label = isDOHApproved ? 'DOH Verified' : 'Scientifically Documented';
    final icon = isDOHApproved ? Icons.verified_rounded : Icons.science_rounded;

    return GestureDetector(
      onTap: () => _showDOHInfoSheet(context, isDOHApproved),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: fgColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fgColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ROADMAP B 2.3: Bottom sheet explaining DOH vs Scientifically Documented.
  void _showDOHInfoSheet(BuildContext context, bool isDOHApproved) {
    final theme = Theme.of(context);
    final title = isDOHApproved ? 'DOH Verified Plant' : 'Scientifically Documented Plant';
    final body = isDOHApproved
        ? 'This plant is officially endorsed by the Philippine Department of Health under Administrative Order No. 12, series of 1997, and is included in the list of clinically validated herbal medicines (Republic Act No. 8423 — TAMA).'
        : 'This plant is not on the DOH approved list but is included in HerbaScan based on peer-reviewed literature and PITAHC (Philippine Institute of Traditional and Alternative Health Care) references.';
    const footer =
        'Source: Dept. of Health Admin. Order No. 12, s. 1997 · Republic Act No. 8423 (TAMA, 1997) · PITAHC';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              isDOHApproved ? Icons.verified_rounded : Icons.science_rounded,
              size: 40,
              color: isDOHApproved ? AppTheme.safeGreen : AppTheme.warningAmber,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              footer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDisabled = onTap == null;

    return Listener(
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDisabled
                ? theme.colorScheme.surfaceContainerHighest
                : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDisabled
                  ? theme.colorScheme.outline.withOpacity(0.1)
                  : color.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDisabled
                      ? theme.colorScheme.onSurface.withOpacity(0.08)
                      : color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDisabled
                      ? theme.colorScheme.onSurface.withOpacity(0.4)
                      : color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDisabled
                      ? theme.colorScheme.onSurface.withOpacity(0.4)
                      : theme.colorScheme.onSurface,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }

  Widget _buildAlternativeMatches(ThemeData theme) {
    final alternatives = widget.predictions.skip(1).toList();
    if (alternatives.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alternative Matches',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'If the top result seems wrong, these are the next possibilities.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...alternatives.take(2).map((pred) {
          final name = pred['plantName'] ?? pred['label'] ?? 'Unknown';
          final conf = (pred['confidence'] ?? 0.0).toDouble();
          return Opacity(
            opacity: 0.85,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.eco_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_showConfidence)
                          Text(
                            '${(conf * 100).toStringAsFixed(1)}% match',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: 60,
                  height: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: conf.clamp(0.0, 1.0),
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getConfidenceColor(conf),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          );
        }),
      ],
    );
  }

  // ── Tab 2: AI Vision ──────────────────────────────────────────────────────
  Widget _buildAIVisionTab(
    BuildContext context,
    String plantName,
    String scientificName,
    double confidence,
    bool showAIVision,
  ) {
    final theme = Theme.of(context);
    final resolvedPlant = _resolveMatchedPlant(plantName);

    if (!showAIVision) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_off_rounded,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'AI Heatmap Disabled',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enable "Show AI Reasoning Heatmap" in Settings to see the AI Vision tab.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: GradCAMVisualization(
        gradCAMPath: widget.gradCAMPath,
        summaryGradCAMPath: widget.summaryGradCAMPath,
        gradcamImageBytes:
            _regeneratedGradcamImageBytes ?? widget.gradcamImageBytes,
        originalImagePath: widget.imagePath,
        plantName: plantName,
        scientificName: scientificName,
        confidence: confidence,
        predictions: widget.predictions,
        plant: resolvedPlant,
        method: _regeneratedMethod ?? widget.method,
        fallbackUsed: _regeneratedFallbackUsed ?? widget.fallbackUsed,
        onRefresh: _regenerateGradCAM,
        onHeatmapTap: (bool showOverlay,
            double opacity,
            Function(bool) onOverlayChanged,
            Function(double) onOpacityChanged) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FullScreenHeatmapRoute(
                originalImagePath: widget.imagePath,
                gradcamImageBytes:
                    _regeneratedGradcamImageBytes ?? widget.gradcamImageBytes,
                gradCAMPath: widget.gradCAMPath,
                initialShowOverlay: showOverlay,
                initialOpacity: opacity,
                onOverlayChanged: onOverlayChanged,
                onOpacityChanged: onOpacityChanged,
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Error screen ──────────────────────────────────────────────────────────
  Widget _buildErrorScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).scanResults),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No predictions available',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to identify the plant in the image',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Save options ──────────────────────────────────────────────────────────
  void _showSaveOptions(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save Scan',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_android_rounded),
                  title: const Text('Save to device'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _saveToDeviceOnly();
                  },
                ),
                if (auth.isLoggedIn)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_upload_rounded),
                    title: const Text('Save to cloud'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _saveToCloudOnly();
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Save to Camera Roll'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _saveToCameraRoll();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return AppTheme.safeGreen;
    if (confidence >= 0.5) return AppTheme.warningAmber;
    return AppTheme.errorColor;
  }

  Future<void> _regenerateGradCAM() async {
    if (_isRegenerating) return;
    setState(() => _isRegenerating = true);

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Regenerating heatmap…',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      final imageFile = File(widget.imagePath);
      if (!await imageFile.exists()) throw Exception('Image file not found');
      final imageBytes = await imageFile.readAsBytes();

      final result = await _adaptiveGradCAMService.identifyPlant(
        imagePath: widget.imagePath,
        imageBytes: imageBytes,
      );

      if (result == null) throw Exception('Failed to regenerate GradCAM');

      if (mounted) {
        setState(() {
          _regeneratedGradcamImageBytes = result['gradcam_image'] as Uint8List?;
          _regeneratedMethod = result['method'] as String?;
          _regeneratedFallbackUsed = result['fallback_used'] as bool? ?? false;
          _isRegenerating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _regeneratedMethod == 'grad-cam'
                  ? 'AI heatmap regenerated!'
                  : 'CAM regenerated!',
            ),
            backgroundColor: AppTheme.safeGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to regenerate: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _shareResults() async {
    final top = widget.predictions.isNotEmpty ? widget.predictions.first : null;
    final plantName = top?['plantName'] ?? top?['label'] ?? 'Unknown Plant';
    final confidence = (top?['confidence'] ?? 0.0) is num
        ? ((top!['confidence'] as num) * 100).toStringAsFixed(1)
        : '0';
    final textPayload =
        'I identified $plantName using HerbaScan! It\'s a $confidence% match. '
        'Identified using AI-powered plant recognition.';
    try {
      if (widget.imagePath.isNotEmpty && File(widget.imagePath).existsSync()) {
        await Share.shareXFiles([XFile(widget.imagePath)], text: textPayload);
      } else {
        await Share.share(textPayload);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  Future<void> _saveToCameraRoll() async {
    try {
      if (widget.imagePath.isNotEmpty && File(widget.imagePath).existsSync()) {
        await Gal.putImage(widget.imagePath);
      } else if (widget.gradcamImageBytes != null &&
          widget.gradcamImageBytes!.isNotEmpty) {
        await Gal.putImageBytes(widget.gradcamImageBytes!);
      } else if (_regeneratedGradcamImageBytes != null &&
          _regeneratedGradcamImageBytes!.isNotEmpty) {
        await Gal.putImageBytes(_regeneratedGradcamImageBytes!);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No image available to save to gallery')),
          );
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to Camera Roll')),
        );
      }
    } on GalException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.type == GalExceptionType.accessDenied
                  ? 'Permission denied to save to gallery'
                  : 'Could not save to gallery: ${e.platformException.message ?? e.toString()}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save to gallery: $e')),
        );
      }
    }
  }

  Future<void> _saveResultsAutomatically() async {
    if (_isSaved) return;

    try {
      final plantProvider = Provider.of<PlantProvider>(context, listen: false);
      final topPrediction = widget.predictions.first;

      final predictions = widget.predictions.map((pred) {
        return Prediction(
          plantId: pred['label'] ?? '',
          plantName: pred['plantName'] ?? pred['label'] ?? 'Unknown',
          scientificName: pred['scientificName'] ?? '',
          confidence: (pred['confidence'] ?? 0.0).toDouble(),
          features: (pred['features'] as Map<String, dynamic>?) ?? {},
        );
      }).toList();

      final predictedPlantName =
          topPrediction['plantName'] ?? topPrediction['label'] ?? '';
      final predictedScientificName = topPrediction['scientificName'] ?? '';
      final normalizedPredictedName = predictedPlantName.trim().toLowerCase();
      final normalizedPredictedScientific =
          predictedScientificName.trim().toLowerCase();

      final plant = plantProvider.plants.where((p) {
        final normalizedCommon = p.commonName.trim().toLowerCase();
        final normalizedScientific = p.scientificName.trim().toLowerCase();
        final normalizedEnglish = p.englishName.trim().toLowerCase();

        if (normalizedPredictedName.isNotEmpty) {
          if (normalizedCommon == normalizedPredictedName ||
              normalizedScientific == normalizedPredictedName ||
              normalizedEnglish == normalizedPredictedName) {
            return true;
          }
        }
        if (normalizedPredictedScientific.isNotEmpty) {
          if (normalizedCommon == normalizedPredictedScientific ||
              normalizedScientific == normalizedPredictedScientific ||
              normalizedEnglish == normalizedPredictedScientific) {
            return true;
          }
        }
        return false;
      }).firstOrNull;

      String? savedGradCAMPath = widget.gradCAMPath;
      if (widget.gradcamImageBytes != null && savedGradCAMPath == null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final gradcamDir = Directory('${appDir.path}/gradcam');
          if (!await gradcamDir.exists()) {
            await gradcamDir.create(recursive: true);
          }
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final gradcamFile = File('${gradcamDir.path}/gradcam_$timestamp.png');
          await gradcamFile.writeAsBytes(widget.gradcamImageBytes!);
          savedGradCAMPath = gradcamFile.path;
        } catch (e) {
          debugPrint('⚠️ Error saving GradCAM image: $e');
        }
      }

      final scanResult = ScanResult(
        id: const Uuid().v4(),
        plant: plant,
        confidenceScore: (topPrediction['confidence'] ?? 0.0).toDouble(),
        predictions: predictions,
        imagePath: widget.imagePath,
        scanDate: DateTime.now(),
        gradCAMPath: savedGradCAMPath,
        metadata: {
          'gradCAMAvailable':
              savedGradCAMPath != null || widget.gradcamImageBytes != null,
          'summaryGradCAMAvailable': widget.summaryGradCAMPath != null,
          'scanTime': DateTime.now().toIso8601String(),
          'method': widget.method ?? 'unknown',
          'fallbackUsed': widget.fallbackUsed ?? false,
        },
        isOfflineScan: widget.method == 'cam' || widget.fallbackUsed == true,
      );

      await plantProvider.addScanResult(scanResult);

      setState(() {
        _isSaved = true;
        _savedScanResult = scanResult;
      });
    } catch (e) {
      debugPrint('❌ Error saving scan result: $e');
    }
  }

  Future<void> _saveToDeviceOnly() async {
    if (!_isSaved) {
      await _saveResultsAutomatically();
      if (!mounted) return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSaved
            ? 'Scan already saved to history'
            : 'Scan saved to device history'),
        backgroundColor: AppTheme.safeGreen,
      ),
    );
  }

  Future<void> _saveToCloudOnly() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to save to cloud'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_isSaved) {
      await _saveResultsAutomatically();
      if (!mounted) return;
    }
    if (_savedScanResult == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Save to device first, then try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    if (_savedToCloud) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Already in Personal Herbarium'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }
    if (widget.imagePath.isEmpty || !await File(widget.imagePath).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image file not found. Cannot upload to cloud.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    try {
      final scanId = await HerbariumService()
          .uploadScan(_savedScanResult!, widget.imagePath);
      if (!mounted) return;
      if (scanId != null) {
        setState(() => _savedToCloud = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to Personal Herbarium'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Could not save to cloud. Check connection or try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud upload failed. Try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}

// ── Sliver delegate for pinned TabBar ─────────────────────────────────────
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

// ── Full-screen image viewer ──────────────────────────────────────────────
class FullScreenImageView extends StatelessWidget {
  final String imagePath;

  const FullScreenImageView({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Hero(
                  tag: 'scan_image_fullscreen',
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: Colors.white),
                            const SizedBox(height: 16),
                            const Text(
                              'Image not found',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    shape: const CircleBorder(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full-screen heatmap viewer ────────────────────────────────────────────
class FullScreenHeatmapRoute extends StatefulWidget {
  final String originalImagePath;
  final Uint8List? gradcamImageBytes;
  final String? gradCAMPath;
  final bool initialShowOverlay;
  final double initialOpacity;
  final Function(bool) onOverlayChanged;
  final Function(double) onOpacityChanged;

  const FullScreenHeatmapRoute({
    super.key,
    required this.originalImagePath,
    this.gradcamImageBytes,
    this.gradCAMPath,
    required this.initialShowOverlay,
    required this.initialOpacity,
    required this.onOverlayChanged,
    required this.onOpacityChanged,
  });

  @override
  State<FullScreenHeatmapRoute> createState() => _FullScreenHeatmapRouteState();
}

class _FullScreenHeatmapRouteState extends State<FullScreenHeatmapRoute> {
  late bool _showOverlay;
  late double _opacity;

  @override
  void initState() {
    super.initState();
    _showOverlay = widget.initialShowOverlay;
    _opacity = widget.initialOpacity;
  }

  @override
  Widget build(BuildContext context) {
    final hasImageBytes = widget.gradcamImageBytes != null;
    final hasFilePath = widget.gradCAMPath != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: _showOverlay
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          alignment: Alignment.center,
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(widget.originalImagePath),
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (_, __, ___) =>
                                  _buildErrorWidget('Original image not found'),
                            ),
                            Positioned.fill(
                              child: Opacity(
                                opacity: _opacity,
                                child: hasImageBytes
                                    ? Image.memory(
                                        widget.gradcamImageBytes!,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.center,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      )
                                    : hasFilePath
                                        ? Image.file(
                                            File(widget.gradCAMPath!),
                                            fit: BoxFit.contain,
                                            alignment: Alignment.center,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox.shrink(),
                                          )
                                        : const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : Image.file(
                      File(widget.originalImagePath),
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) =>
                          _buildErrorWidget('Original image not found'),
                    ),
            ),
          ),
          // Close button
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ),
          // Floating controls card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Show Heatmap Overlay',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: _showOverlay,
                      onChanged: (value) {
                        setState(() => _showOverlay = value);
                        widget.onOverlayChanged(value);
                      },
                      activeThumbColor: AppTheme.botanicalPrimary,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.opacity,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: _opacity,
                            min: 0.0,
                            max: 1.0,
                            divisions: 20,
                            label: '${(_opacity * 100).round()}%',
                            onChanged: (value) {
                              setState(() => _opacity = value);
                              widget.onOpacityChanged(value);
                            },
                            activeColor: AppTheme.botanicalPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(_opacity * 100).round()}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
