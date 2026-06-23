// lib/features/scan/plant_result_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/constants/toxic_plant_blacklist.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/providers/app_provider.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/safety_profile.dart';
import 'package:herbascan/core/models/scan_result.dart';
import 'package:herbascan/core/services/herbarium_service.dart';
import 'package:herbascan/core/services/habitat_service.dart';
import 'package:herbascan/core/services/safety_profile_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/contraindication_engine_widget.dart';
import 'package:herbascan/core/services/feedback_service.dart';
import 'package:herbascan/features/feedback/feedback_bottom_sheet.dart';
import 'package:herbascan/features/feedback/feedback_screen.dart';
import 'package:herbascan/features/help/help_tutorial_screen.dart';
import 'package:herbascan/features/scan/habitat_map_screen.dart';
import 'package:herbascan/features/scan/plant_detail_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

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

class _PlantResultScreenState extends State<PlantResultScreen> {
  bool _isSaved = false;
  bool _savedToCloud = false;
  ScanResult? _savedScanResult;

  // Settings from SharedPreferences
  bool _showConfidence = true;
  bool _showTop3 = true;

  @override
  void initState() {
    super.initState();

    if (widget.isFromHistory) {
      _isSaved = true;
      if (widget.scanResultFromHistory != null) {
        _savedScanResult = widget.scanResultFromHistory;
      }
    }

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
          _showTop3 = prefs.getBool('show_top3') ?? true;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error loading settings: $e');
    }
  }

  // ── OOD detection ────────────────────────────────────────────────────────
  bool get _isOODResult {
    if (widget.predictions.isEmpty) return false;
    final name = (widget.predictions.first['plantName'] as String? ?? '')
        .trim()
        .toLowerCase();
    return name == 'not_plant' || name == 'unknownplant';
  }

  // Converts class-label strings to human-readable display names.
  String _toDisplayName(String plantName) {
    final key = plantName.trim().toLowerCase();
    if (key == 'not_plant') return 'Not Plant';
    if (key == 'unknownplant') return 'Unknown Plant';
    return plantName;
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
    final plantName =
        _toDisplayName(topPrediction['plantName'] ?? 'Unknown Plant');
    final confidence = (topPrediction['confidence'] ?? 0.0).toDouble();
    final scientificName =
        (topPrediction['scientificName'] as String?)?.trim().isNotEmpty == true
            ? topPrediction['scientificName'] as String
            : plantName;

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
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              leading: _buildGlassmorphicButton(
                icon: Icons.arrow_back_ios_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              actions: [
                _buildGlassmorphicButton(
                  icon: Icons.share_rounded,
                  onTap: () => _showShareSheet(context),
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
          ];
        },
        body: _buildInsightsTab(
            context, topPrediction, plantName, scientificName, confidence),
      ),
    );
  }

  // ── Hero background (edge-to-edge scan image) ────────────────────────────
  Widget _buildHeroBackground(
      BuildContext context, String plantName, double confidence) {
    // Cloud scans thread their Supabase URL through metadata['imageUrl'];
    // local scans have no such key, so imagePath is a filesystem path.
    final imageUrlFromMeta =
        widget.scanResultFromHistory?.metadata['imageUrl'] as String?;
    final hasNetworkImage =
        imageUrlFromMeta != null && imageUrlFromMeta.startsWith('http');

    final imageWidget = hasNetworkImage
        ? Image.network(
            imageUrlFromMeta,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => Container(
              color: AppTheme.darkSurface,
              child: const Center(
                child: Icon(Icons.eco_rounded,
                    size: 64, color: AppTheme.botanicalPrimaryL),
              ),
            ),
          )
        : Image.file(
            File(widget.imagePath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppTheme.darkSurface,
              child: const Center(
                child: Icon(Icons.eco_rounded,
                    size: 64, color: AppTheme.botanicalPrimaryL),
              ),
            ),
          );

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
            child: imageWidget,
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
    final color =
        _isOODResult ? AppTheme.errorColor : _getConfidenceColor(confidence);

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
            if (_isOODResult)
              const Text(
                'Not identified',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              )
            else if (_showConfidence)
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
          final showSafetyFirst =
              hasActiveContraindications && !isLowConfidence;

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
                  _buildDOHBadge(
                      context, resolvedPlant?.isDOHApproved ?? false),
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
              const SizedBox(height: 24),
              _buildFeedbackCTA(context),
            ],
          );
        },
      ),
    );
  }

  /// "Did we get this right? Help our research." — opens feedback bottom sheet with scan context.
  Widget _buildFeedbackCTA(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scanId = _savedScanResult?.id ?? widget.scanResultFromHistory?.id;
    final plantName = widget.predictions.isNotEmpty
        ? (widget.predictions[0]['plantName'] ?? widget.predictions[0]['label'])
            as String?
        : null;
    final confidence = widget.predictions.isNotEmpty
        ? (widget.predictions[0]['confidence'] as num?)?.toDouble()
        : null;
    return Center(
      child: TextButton.icon(
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (ctx) => FeedbackBottomSheetContent(
              scanId: scanId,
              plantName: plantName,
              confidence: confidence,
              onClosed: () {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.thankYou),
                      backgroundColor: AppTheme.safeGreen,
                    ),
                  );
                }
              },
            ),
          );
        },
        icon: const Icon(Icons.feedback_outlined, size: 20),
        label: Text(l10n.didWeGetThisRight),
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
        ? (isDark
            ? AppTheme.safeGreen.withValues(alpha: 0.25)
            : AppTheme.safeBgLight)
        : (isDark
            ? AppTheme.warningAmber.withValues(alpha: 0.2)
            : AppTheme.warningBgLight);
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
    final title = isDOHApproved
        ? 'DOH Verified Plant'
        : 'Scientifically Documented Plant';
    final body = isDOHApproved
        ? 'This plant is officially endorsed by the Philippine Department of Health under Administrative Order No. 12, series of 1997, and is included in the list of clinically validated herbal medicines (Republic Act No. 8423 — TAMA).'
        : 'This plant is not on the DOH approved list but is included in HerbaScan based on peer-reviewed literature and Philippine Herbal Pharmacopeia (PITAHC) references.';
    const footer =
        'Source: Dept. of Health Admin. Order No. 12, s. 1997 · Republic Act No. 8423 (TAMA, 1997) · Philippine Herbal Pharmacopeia (PITAHC)';

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
    // Exclude blacklisted toxic plants from alternative matches
    final alternatives = widget.predictions.skip(1).where((pred) {
      final label = pred['plantName'] as String? ?? pred['label'] as String?;
      final canonical = normalizeToCanonicalKey(label);
      return canonical == null || !toxicPlantBlacklist.contains(canonical);
    }).toList();
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
                        if (_showConfidence && !_isOODResult)
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

  // ── Share sheet + options ─────────────────────────────────────────────────

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_rounded),
                title: const Text('Share as Info Card'),
                subtitle: const Text('Branded card with plant details'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareAsCard();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.text_fields_rounded),
                title: const Text('Share as Text'),
                subtitle: const Text('Plain text for WhatsApp, SMS, etc.'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareAsText();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareAsCard() async {
    final top = widget.predictions.isNotEmpty ? widget.predictions.first : null;
    if (top == null) return;

    final plantName =
        (top['plantName'] ?? top['label'] ?? 'Unknown Plant') as String;
    final scientificName =
        ((top['scientificName'] as String?)?.trim().isNotEmpty == true
            ? top['scientificName'] as String
            : plantName);
    final confidence = ((top['confidence'] ?? 0.0) as num).toDouble();
    final confidencePct = (confidence * 100).toStringAsFixed(1);

    final resolvedPlant = _resolveMatchedPlant(plantName);
    final isDOH = resolvedPlant?.isDOHApproved ?? false;
    final uses = resolvedPlant?.medicinalUses
            .take(3)
            .map((u) => u.condition)
            .join(', ') ??
        '';

    final bytes = await _renderCardToImage(
      _buildShareCard(
        plantName: plantName,
        scientificName: scientificName,
        confidencePct: confidencePct,
        isDOH: isDOH,
        uses: uses,
      ),
    );

    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate share card')),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/herbascan_share_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);

    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🌿 $plantName – scanned with HerbaScan',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  void _shareAsText() {
    final top = widget.predictions.isNotEmpty ? widget.predictions.first : null;
    if (top == null) return;

    final plantName =
        (top['plantName'] ?? top['label'] ?? 'Unknown Plant') as String;
    final scientificName =
        ((top['scientificName'] as String?)?.trim().isNotEmpty == true
            ? top['scientificName'] as String
            : plantName);
    final confidence = ((top['confidence'] ?? 0.0) as num).toDouble();
    final confidencePct = (confidence * 100).toStringAsFixed(1);

    final resolvedPlant = _resolveMatchedPlant(plantName);
    final isDOH = resolvedPlant?.isDOHApproved ?? false;
    final uses = resolvedPlant?.medicinalUses
            .take(3)
            .map((u) => u.condition)
            .join(', ') ??
        '';

    final text = '🌿 I just identified a Philippine medicinal plant using HerbaScan!\n\n'
        'Plant: $plantName ($scientificName)\n'
        'Confidence: $confidencePct% Match\n'
        'DOH Approved: ${isDOH ? '✅ Yes' : 'Not listed'}\n'
        '${uses.isNotEmpty ? 'Uses: $uses\n' : ''}'
        '\n⚠️ Always consult a healthcare professional before use.\n\n'
        'Scanned with HerbaScan – Discover Philippine Medicinal Plants';

    Share.share(text);
  }

  // ── Share card widget (rendered off-screen) ───────────────────────────────

  Widget _buildShareCard({
    required String plantName,
    required String scientificName,
    required String confidencePct,
    required bool isDOH,
    required String uses,
  }) {
    final scanImageExists =
        widget.imagePath.isNotEmpty && File(widget.imagePath).existsSync();

    return SizedBox(
      width: 380,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scan image thumbnail
            if (scanImageExists)
              SizedBox(
                height: 180,
                child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
              )
            else
              Container(
                height: 180,
                color: AppTheme.botanicalPrimary.withValues(alpha: 0.10),
                child: const Center(
                  child: Icon(Icons.eco_rounded,
                      size: 64, color: AppTheme.botanicalPrimary),
                ),
              ),

            // Botanical green accent stripe
            Container(height: 4, color: AppTheme.botanicalPrimary),

            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plantName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scientificName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCardRow(
                    icon: Icons.analytics_outlined,
                    label: 'Match Confidence',
                    value: '$confidencePct%',
                  ),
                  const SizedBox(height: 8),
                  _buildCardRow(
                    icon: isDOH
                        ? Icons.verified_rounded
                        : Icons.info_outline_rounded,
                    label: 'DOH Approved',
                    value: isDOH ? '✅ Yes' : 'Not listed',
                    valueColor: isDOH
                        ? AppTheme.botanicalPrimary
                        : const Color(0xFF6B7280),
                  ),
                  if (uses.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildCardRow(
                      icon: Icons.local_hospital_outlined,
                      label: 'Medicinal Uses',
                      value: uses,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 12),

                  // Footer branding
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.botanicalPrimary
                              .withValues(alpha: 0.10),
                        ),
                        child: const Icon(Icons.eco_rounded,
                            size: 18, color: AppTheme.botanicalPrimary),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scanned with HerbaScan 🌱',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.botanicalPrimary,
                            ),
                          ),
                          Text(
                            'Discover Philippine medicinal plants',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  // Inserts the card widget into the Overlay off-screen, waits two frames for
  // painting, then captures it via RenderRepaintBoundary.toImage().
  Future<Uint8List?> _renderCardToImage(Widget cardWidget) async {
    if (!mounted) return null;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final overlayState = Overlay.of(context, rootOverlay: true);
    final key = GlobalKey();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -99999,
        top: -99999,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            key: key,
            child: cardWidget,
          ),
        ),
      ),
    );

    overlayState.insert(entry);
    // Two frames: first mounts the widget, second paints it.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    Uint8List? bytes;
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final data =
            await image.toByteData(format: ui.ImageByteFormat.png);
        bytes = data?.buffer.asUint8List();
      }
    } finally {
      entry.remove();
    }
    return bytes;
  }

  Future<void> _saveToCameraRoll() async {
    try {
      if (widget.imagePath.isNotEmpty && File(widget.imagePath).existsSync()) {
        await Gal.putImage(widget.imagePath);
      } else if (widget.gradcamImageBytes != null &&
          widget.gradcamImageBytes!.isNotEmpty) {
        await Gal.putImageBytes(widget.gradcamImageBytes!);
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

      // Milestone feedback prompt (3rd or 5th save)
      final count = plantProvider.scanHistory.length;
      final feedbackService = FeedbackService();
      final shouldShow = await feedbackService.shouldShowMilestonePrompt(count);
      if (!mounted) return;
      if (shouldShow) {
        await feedbackService.recordMilestonePromptShown();
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showMilestoneFeedbackDialog(context);
        });
      }
    } catch (e) {
      debugPrint('❌ Error saving scan result: $e');
    }
  }

  void _showMilestoneFeedbackDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.milestoneFeedbackTitle),
        content: Text(l10n.milestoneFeedbackBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.maybeLater),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FeedbackScreen(),
                ),
              );
            },
            child: Text(l10n.rateExperience),
          ),
        ],
      ),
    );
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

