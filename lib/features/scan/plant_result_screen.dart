// lib/features/scan/plant_result_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/widgets/gradcam_visualization.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/scan_result.dart';
import 'package:herbascan/core/services/herbarium_service.dart';
import 'package:herbascan/core/services/adaptive_gradcam_service.dart';
import 'package:herbascan/core/services/habitat_service.dart';
import 'package:herbascan/features/scan/habitat_map_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

class PlantResultScreen extends StatefulWidget {
  final String imagePath;
  final List<Map<String, dynamic>> predictions;
  final String? gradCAMPath; // Legacy: file path (deprecated)
  final String? summaryGradCAMPath; // Legacy: file path (deprecated)
  final Uint8List? gradcamImageBytes; // New: image bytes
  final String? method; // 'grad-cam' or 'cam'
  final bool? fallbackUsed; // True if offline was fallback
  final bool isFromHistory; // True if opened from history (don't auto-save)

  const PlantResultScreen({
    super.key,
    required this.imagePath,
    required this.predictions,
    this.gradCAMPath, // Legacy support
    this.summaryGradCAMPath, // Legacy support
    this.gradcamImageBytes, // New format
    this.method,
    this.fallbackUsed,
    this.isFromHistory = false, // Default to false for new scans
  });

  /// Factory constructor to create PlantResultScreen from ScanResult
  /// Used when viewing scan results from history
  factory PlantResultScreen.fromScanResult(ScanResult scanResult) {
    // Convert Prediction objects to Map format
    final predictions = scanResult.predictions.map((pred) {
      return {
        'label': pred.plantName,
        'plantName': pred.plantName,
        'scientificName': pred.scientificName,
        'confidence': pred.confidence,
        'index': 0, // Not stored in Prediction, use 0
        'isDOHApproved': false, // Will be determined from plant if available
      };
    }).toList();

    // Try to load GradCAM image from file path if it exists
    Uint8List? gradcamImageBytes;
    if (scanResult.gradCAMPath != null) {
      try {
        final file = File(scanResult.gradCAMPath!);
        if (file.existsSync()) {
          gradcamImageBytes = file.readAsBytesSync();
        }
      } catch (e) {
        print('⚠️ Error loading GradCAM image from path: $e');
      }
    }

    // Get method and fallback info from metadata
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
      isFromHistory: true, // Mark as from history to disable auto-save
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

  // Settings from SharedPreferences (default all true)
  bool _showConfidence = true;
  bool _showGradcam = true;
  bool _showTop3 = true;

  final AdaptiveGradCAMService _adaptiveGradCAMService =
      AdaptiveGradCAMService();

  @override
  void initState() {
    super.initState();

    // If opened from history, mark as already saved (don't auto-save)
    if (widget.isFromHistory) {
      _isSaved = true;
    }

    // Initialize TabController with defaults first (will be updated after settings load)
    _initializeTabController();

    // Load settings from SharedPreferences and update TabController if needed
    _loadSettings();

    // Automatically save scan result when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only auto-save if not from history
      if (!widget.isFromHistory) {
        _saveResultsAutomatically();
      }
    });
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final showConfidence = prefs.getBool('show_confidence') ?? true;
      final showGradcam = prefs.getBool('show_gradcam') ?? true;
      final showTop3 = prefs.getBool('show_top3') ?? true;

      // Check if GradCAM setting changed (before updating state)
      final gradcamChanged = _showGradcam != showGradcam;

      // Only update if values changed
      if (mounted &&
          (_showConfidence != showConfidence ||
              _showGradcam != showGradcam ||
              _showTop3 != showTop3)) {
        setState(() {
          _showConfidence = showConfidence;
          _showGradcam = showGradcam;
          _showTop3 = showTop3;
        });

        // Reinitialize TabController if GradCAM setting changed
        if (gradcamChanged) {
          _tabController.dispose();
          _initializeTabController();
        }
      }
    } catch (e) {
      print('⚠️ Error loading settings: $e');
    }
  }

  /// Initialize TabController based on settings and heatmap availability
  void _initializeTabController() {
    // CRITICAL FIX: Always show AI Explanation tabs if:
    // 1. _showGradcam is true (user wants to see GradCAM), AND
    // 2. (Fallback was used OR Method is set OR Heatmap is available)
    // This ensures tabs show even when heatmap generation fails
    final hasHeatmap =
        widget.gradcamImageBytes != null || widget.gradCAMPath != null;
    final hasValidMethod = widget.method != null &&
        widget.method != 'classification_only' &&
        widget.method != '';
    final hasFallback = widget.fallbackUsed == true;

    // PRIORITY LOGIC:
    // 1. If _showGradcam is false, NEVER show tabs (user disabled GradCAM)
    // 2. If _showGradcam is true, show tabs if fallback was used OR method is valid OR heatmap exists
    final showAIExplanation =
        _showGradcam && (hasFallback || hasValidMethod || hasHeatmap);

    // Debug logging BEFORE TabController initialization
    print('🔍 [PlantResultScreen] _initializeTabController:');
    print('   ════════════════════════════════════════════════════════');
    print('   _showGradcam: $_showGradcam');
    print('   method: "${widget.method}"');
    print('   fallbackUsed: ${widget.fallbackUsed}');
    print('   hasHeatmap: $hasHeatmap');
    print('   hasValidMethod: $hasValidMethod');
    print('   hasFallback: $hasFallback');
    print('   ────────────────────────────────────────────────────────');
    print('   showAIExplanation: $showAIExplanation');
    print('   TabController length will be: ${showAIExplanation ? 2 : 1}');
    print('   ════════════════════════════════════════════════════════');

    // CRITICAL: Initialize TabController with correct length
    // If showAIExplanation is true, length must be 2 (Details + AI Explanation)
    // If false, length is 1 (Details only)
    _tabController = TabController(
      length: showAIExplanation ? 2 : 1,
      vsync: this,
    );

    // Debug logging AFTER TabController initialization
    print('🔍 [PlantResultScreen] TabController Created:');
    print('   TabController.length: ${_tabController.length}');
    print('   TabController.index: ${_tabController.index}');
    print(
        '   Result: ${_tabController.length == 2 ? "✅ 2 tabs (Details + AI Explanation)" : "❌ 1 tab (Details only)"}');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.predictions.isEmpty) {
      return _buildErrorScreen();
    }

    final topPrediction = widget.predictions.first;
    final plantName = topPrediction['plantName'] ?? 'Unknown Plant';
    final confidence = (topPrediction['confidence'] ?? 0.0).toDouble();

    // CRITICAL: Use TabController length and _showGradcam setting to determine if tabs should show
    final tabCount = _tabController.length;
    final shouldShowTabs = tabCount == 2 && _showGradcam;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            // SliverAppBar with collapsible header
            SliverAppBar(
              expandedHeight: 420.0, // Increased to prevent overflow
              floating: false,
              pinned: true, // Always visible at top
              snap: false,
              elevation: 0,
              backgroundColor: theme.scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                // Do NOT use title property - plant name is in the card
                background: _buildExpandedHeader(theme, plantName, confidence),
              ),
              // Title always shows "Scan Results"
              centerTitle: true,
              title: Text(
                AppLocalizations.of(context).scanResults,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: _shareResults,
                  icon: const Icon(Icons.share),
                  tooltip: 'Share Results',
                ),
                IconButton(
                  onPressed: _saveResults,
                  icon: const Icon(Icons.save),
                  tooltip: 'Save Results',
                ),
              ],
            ),
            // Pinned TabBar - only show if _showGradcam is true
            if (shouldShowTabs && _showGradcam)
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.info),
                        text: 'Details',
                      ),
                      Tab(
                        icon: Icon(Icons.visibility),
                        text: 'AI Explanation',
                      ),
                    ],
                  ),
                  theme.scaffoldBackgroundColor,
                ),
              ),
          ];
        },
        body: (shouldShowTabs && _showGradcam)
            ? TabBarView(
                controller: _tabController,
                children: [
                  _buildDetailsTab(theme, topPrediction),
                  _buildGradCAMTab(theme, plantName, confidence),
                ],
              )
            : _buildDetailsTab(theme, topPrediction),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).scanResults),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
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

  Widget _buildExpandedHeader(
      ThemeData theme, String plantName, double confidence) {
    // Main container acting as canvas
    return Container(
      color: theme.scaffoldBackgroundColor, // Use theme background color
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Main card with plant details - centered
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface, // Use theme surface color
                borderRadius:
                    BorderRadius.circular(20), // Changed from 16 to 20
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: theme.colorScheme.outline
                      .withOpacity(0.2), // Use theme outline color
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Plant image - will fade out as user scrolls
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageView(
                            imagePath: widget.imagePath,
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: 'plant_image_hero',
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: theme.primaryColor.withOpacity(0.3)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.local_florist,
                                  size: 48,
                                  color: theme.primaryColor,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Plant name
                  Text(
                    plantName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Confidence score and method badge - will fade out as user scrolls
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Confidence badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              _getConfidenceColor(confidence).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getConfidenceColor(confidence)
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.analytics,
                              size: 14,
                              color: _getConfidenceColor(confidence),
                            ),
                            const SizedBox(width: 6),
                            Visibility(
                              visible: _showConfidence,
                              child: Text(
                                '${(confidence.clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getConfidenceColor(confidence),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Method badge - only show if method is set
                      if (widget.method != null) _buildMethodBadge(theme),
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

  Widget _buildDetailsTab(ThemeData theme, Map<String, dynamic> topPrediction) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top predictions
          _buildPredictionsCard(theme),

          const SizedBox(height: 16),

          // Plant information
          _buildPlantInfoCard(theme, topPrediction),

          const SizedBox(height: 16),

          // Scan metadata
          _buildMetadataCard(theme),
        ],
      ),
    );
  }

  Widget _buildGradCAMTab(
      ThemeData theme, String plantName, double confidence) {
    // Get scientific name and predictions from top prediction.
    // Fallback to plantName so Summary tab can load explanation when backend omits scientificName.
    final topPrediction = widget.predictions.isNotEmpty
        ? widget.predictions.first
        : <String, dynamic>{};
    final scientificName =
        (topPrediction['scientificName'] as String?)?.trim().isNotEmpty == true
            ? (topPrediction['scientificName'] as String)
            : plantName;

    // Resolve plant for Contraindication Engine (safety cards)
    Plant? resolvedPlant;
    try {
      final plantProvider = Provider.of<PlantProvider>(context, listen: false);
      final normalized = plantName.trim().toLowerCase();
      for (final p in plantProvider.plants) {
        if (p.commonName.trim().toLowerCase() == normalized ||
            p.scientificName.trim().toLowerCase() == normalized) {
          resolvedPlant = p;
          break;
        }
      }
    } catch (_) {}

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // GradCAM visualization
          GradCAMVisualization(
            gradCAMPath: widget.gradCAMPath, // Legacy support
            summaryGradCAMPath: widget.summaryGradCAMPath, // Legacy support
            // Use regenerated data if available, otherwise use original
            gradcamImageBytes:
                _regeneratedGradcamImageBytes ?? widget.gradcamImageBytes,
            originalImagePath: widget.imagePath,
            plantName: plantName,
            scientificName: scientificName,
            confidence: confidence,
            predictions: widget.predictions,
            plant: resolvedPlant,
            // Use regenerated method if available, otherwise use original
            method: _regeneratedMethod ?? widget.method,
            fallbackUsed: _regeneratedFallbackUsed ?? widget.fallbackUsed,
            onRefresh: _regenerateGradCAM,
            onHeatmapTap: (bool showOverlay,
                double opacity,
                Function(bool) onOverlayChanged,
                Function(double) onOpacityChanged) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => FullScreenHeatmapRoute(
                    originalImagePath: widget.imagePath,
                    gradcamImageBytes: _regeneratedGradcamImageBytes ??
                        widget.gradcamImageBytes,
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

          const SizedBox(height: 16),

          // Optional: Where it grows (Static Habitat Heatmap) – above GradCAM info for visibility
          if (resolvedPlant != null) ...[
            _WhereItGrowsTile(
              plant: resolvedPlant,
              theme: theme,
            ),
            const SizedBox(height: 16),
          ],

          // GradCAM info
          _buildGradCAMInfoCard(theme),
        ],
      ),
    );
  }

  Widget _buildPredictionsCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.analytics,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Predictions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Higher % = more likely this plant matches your photo.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message:
                      'This percentage shows how sure the app is that the photo matches this plant. Higher is better.',
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.help_outline,
                      size: 20,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Logic C: Top-3 Results - use displayCount based on _showTop3 setting
            Builder(
              builder: (context) {
                // Create displayCount variable
                final displayCount = _showTop3 ? widget.predictions.length : 1;

                return Column(
                  children: widget.predictions
                      .asMap()
                      .entries
                      .take(displayCount)
                      .map((entry) {
                    final index = entry.key;
                    final prediction = entry.value;
                    final confidence =
                        (prediction['confidence'] ?? 0.0).toDouble();
                    final plantName = prediction['plantName'] ?? 'Unknown';

                    final isDark = theme.brightness == Brightness.dark;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? theme.colorScheme.surfaceContainerHighest
                                  : theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? theme.colorScheme.onSurface
                                      : theme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plantName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Visibility(
                                  visible: _showConfidence,
                                  child: Text(
                                    '${(confidence * 100).toStringAsFixed(1)}% match',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 60,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: confidence.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _getConfidenceColor(confidence),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantInfoCard(ThemeData theme, Map<String, dynamic> prediction) {
    final plantName =
        prediction['plantName'] ?? prediction['label'] ?? 'Unknown';
    final confidence = (prediction['confidence'] ?? 0.0).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  'Plant Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<String>(
              future: _resolveScientificName(plantName),
              builder: (context, snapshot) {
                final scientificName = snapshot.data ?? plantName;
                return _buildInfoRow('Scientific Name', scientificName);
              },
            ),
            _buildInfoRow('Match', '${(confidence * 100).toStringAsFixed(1)}%'),
            _buildInfoRow(
                'Prediction Index', '${prediction['index'] ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }

  /// Resolves scientific name from plant_explanations.json based on common name
  /// Falls back to common name if not found
  Future<String> _resolveScientificName(String commonName) async {
    try {
      // First, check if scientific name is already provided in prediction
      final topPrediction = widget.predictions.isNotEmpty
          ? widget.predictions.first
          : <String, dynamic>{};
      final existingScientificName = topPrediction['scientificName'] as String?;

      if (existingScientificName != null &&
          existingScientificName.isNotEmpty &&
          existingScientificName != 'Unknown') {
        return existingScientificName;
      }

      // Load plant_explanations.json
      final jsonString =
          await rootBundle.loadString('assets/data/plant_explanations.json');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Normalize common name for lookup (case-insensitive, trim)
      final normalizedCommonName = commonName.trim();

      // Try exact match first
      var plantData = jsonData[normalizedCommonName];

      // Try case-insensitive match if exact match fails
      if (plantData == null) {
        final matchingKey = jsonData.keys.firstWhere(
          (key) =>
              key.trim().toLowerCase() == normalizedCommonName.toLowerCase(),
          orElse: () => '',
        );
        if (matchingKey.isNotEmpty) {
          plantData = jsonData[matchingKey];
        }
      }

      // Extract scientific name from identification text
      if (plantData != null) {
        final plantMap = plantData as Map<String, dynamic>;
        final identification = plantMap['identification'] as String?;

        if (identification != null && identification.isNotEmpty) {
          // Pattern: "The model identified this as [Common Name] ([Scientific Name])"
          // Extract text in parentheses after the common name
          final regex = RegExp(r'\(([^)]+)\)');
          final match = regex.firstMatch(identification);

          if (match != null && match.groupCount >= 1) {
            final scientificName = match.group(1)?.trim();
            if (scientificName != null && scientificName.isNotEmpty) {
              return scientificName;
            }
          }
        }
      }

      // Fallback: return common name if scientific name cannot be found
      return commonName;
    } catch (e) {
      print('⚠️ Error resolving scientific name for "$commonName": $e');
      // Fallback: return common name on error
      return commonName;
    }
  }

  Widget _buildMetadataCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  'Scan Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Scan Time', DateTime.now().toString().split('.')[0]),
            _buildInfoRow('Image Path', widget.imagePath.split('/').last),
            _buildInfoRow(
                // Show "CAM Available" for offline CAM, "Score-CAM Available" for online Score-CAM
                widget.method == 'cam'
                    ? 'CAM Available'
                    : 'Score-CAM Available',
                (widget.gradcamImageBytes != null || widget.gradCAMPath != null)
                    ? 'Yes'
                    : 'No'),
            if (widget.method != null)
              _buildInfoRow(
                  'Method',
                  widget.method == 'grad-cam'
                      ? 'Online (Score-CAM)'
                      : 'Offline (CAM)'),
            if (widget.fallbackUsed == true)
              _buildInfoRow('Fallback Used', 'Yes'),
          ],
        ),
      ),
    );
  }

  Widget _buildGradCAMInfoCard(ThemeData theme) {
    // Determine if using CAM (offline) or GradCAM (online)
    final isCAM = widget.method == 'cam';
    final title = isCAM ? 'About Offline CAM' : 'About Score-CAM';

    // Description text based on method
    final description = isCAM
        ? 'CAM (Class Activation Mapping) shows which parts of the image the AI model focused on when making its prediction. This offline method uses feature maps to highlight important regions without requiring gradient computation.'
        : 'Score-CAM (Score-weighted Class Activation Mapping) shows which parts of the image the AI model focused on when making its prediction. This helps explain why the model made its decision.';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.87),
              ),
            ),
            const SizedBox(height: 16),
            // Visual legend with colored squares
            Row(
              children: [
                _buildColorLegendItem(Colors.red, 'High'),
                const SizedBox(width: 16),
                _buildColorLegendItem(Colors.green, 'Medium'),
                const SizedBox(width: 16),
                _buildColorLegendItem(Colors.blue, 'Low'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorLegendItem(Color color, String label) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.87),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withOpacity(0.9),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.5) return Colors.orange;
    return Colors.red;
  }

  Future<void> _regenerateGradCAM() async {
    if (_isRegenerating) {
      // Already regenerating, ignore
      return;
    }

    setState(() {
      _isRegenerating = true;
    });

    try {
      // Show loading indicator (spinner and text must contrast with SnackBar: dark mode SnackBar often has light bg)
      if (!mounted) return;
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final contentColor = isDark ? Colors.black87 : Colors.white;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(contentColor),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Regenerating heatmap & explanation',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(color: contentColor),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Read image bytes
      final imageFile = File(widget.imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found');
      }
      final imageBytes = await imageFile.readAsBytes();

      // Regenerate using AdaptiveGradCAMService
      final result = await _adaptiveGradCAMService.identifyPlant(
        imagePath: widget.imagePath,
        imageBytes: imageBytes,
      );

      if (result == null) {
        throw Exception('Failed to regenerate GradCAM');
      }

      // Update state with regenerated data
      if (mounted) {
        setState(() {
          _regeneratedGradcamImageBytes = result['gradcam_image'] as Uint8List?;
          _regeneratedMethod = result['method'] as String?;
          _regeneratedFallbackUsed = result['fallback_used'] as bool? ?? false;
          _isRegenerating = false;
          // Widget will rebuild automatically when state changes
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _regeneratedMethod == 'grad-cam'
                  ? 'Score-CAM regenerated successfully!'
                  : 'CAM regenerated successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRegenerating = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to regenerate: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _shareResults() {
    // TODO: Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality not implemented yet'),
      ),
    );
  }

  Future<void> _saveResultsAutomatically() async {
    if (_isSaved) return;

    try {
      final plantProvider = Provider.of<PlantProvider>(context, listen: false);
      final topPrediction = widget.predictions.first;

      // Convert predictions to Prediction objects
      final predictions = widget.predictions.map((pred) {
        return Prediction(
          plantId: pred['label'] ?? '',
          plantName: pred['plantName'] ?? pred['label'] ?? 'Unknown',
          scientificName: pred['scientificName'] ?? '',
          confidence: (pred['confidence'] ?? 0.0).toDouble(),
          features: (pred['features'] as Map<String, dynamic>?) ?? {},
        );
      }).toList();

      // Get plant data from provider based on the predicted plant name
      // CRITICAL FIX: Use plantName and scientificName from prediction for better matching
      final predictedPlantName =
          topPrediction['plantName'] ?? topPrediction['label'] ?? '';
      final predictedScientificName = topPrediction['scientificName'] ?? '';

      // Normalize strings for comparison (trim, lowercase)
      final normalizedPredictedName = predictedPlantName.trim().toLowerCase();
      final normalizedPredictedScientific =
          predictedScientificName.trim().toLowerCase();

      // Try to find matching plant in database
      // Check against commonName, scientificName, and englishName
      final plant = plantProvider.plants.where((p) {
        final normalizedCommon = p.commonName.trim().toLowerCase();
        final normalizedScientific = p.scientificName.trim().toLowerCase();
        final normalizedEnglish = p.englishName.trim().toLowerCase();

        // Match against predicted plant name
        if (normalizedPredictedName.isNotEmpty) {
          if (normalizedCommon == normalizedPredictedName ||
              normalizedScientific == normalizedPredictedName ||
              normalizedEnglish == normalizedPredictedName) {
            return true;
          }
        }

        // Match against predicted scientific name
        if (normalizedPredictedScientific.isNotEmpty) {
          if (normalizedCommon == normalizedPredictedScientific ||
              normalizedScientific == normalizedPredictedScientific ||
              normalizedEnglish == normalizedPredictedScientific) {
            return true;
          }
        }

        return false;
      }).firstOrNull;

      // Debug logging
      if (plant == null) {
        print('⚠️ [PlantResultScreen] Plant not found in database:');
        print('   Predicted plant name: "$predictedPlantName"');
        print('   Predicted scientific name: "$predictedScientificName"');
        print(
            '   Available plants: ${plantProvider.plants.map((p) => p.commonName).join(", ")}');
      } else {
        print(
            '✅ [PlantResultScreen] Plant matched: ${plant.commonName} (${plant.scientificName})');
      }

      // Save GradCAM image bytes to file if we have bytes but no path
      // This is needed for online GradCAM which returns bytes directly
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

          print('💾 Saved GradCAM image to: $savedGradCAMPath');
        } catch (e) {
          print('⚠️ Error saving GradCAM image: $e');
        }
      }

      // Create scan result
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

      // Save to database (device only; Cloud is opt-in via Save button when logged in)
      await plantProvider.addScanResult(scanResult);

      setState(() {
        _isSaved = true;
        _savedScanResult = scanResult;
      });

      print('✅ Scan result saved to device');
    } catch (e) {
      print('❌ Error saving scan result: $e');
    }
  }

  Future<void> _saveResults() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!_isSaved) {
      await _saveResultsAutomatically();
      if (!mounted) return;
      if (auth.isLoggedIn && _savedScanResult != null) {
        try {
          await HerbariumService()
              .uploadScan(_savedScanResult!, widget.imagePath);
          if (mounted) setState(() => _savedToCloud = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved to device and Personal Herbarium'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved to device. Cloud upload failed.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan saved to device history'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }
    if (auth.isLoggedIn && !_savedToCloud && _savedScanResult != null) {
      try {
        await HerbariumService()
            .uploadScan(_savedScanResult!, widget.imagePath);
        if (mounted) setState(() => _savedToCloud = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to Personal Herbarium'),
              backgroundColor: Colors.green,
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan already saved to history'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildMethodBadge(ThemeData theme) {
    if (widget.method == null) return const SizedBox.shrink();

    final isOnline = widget.method == 'grad-cam';
    final isFallback = widget.fallbackUsed == true;

    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    if (isOnline && !isFallback) {
      badgeColor = Colors.green;
      badgeIcon = Icons.cloud;
      badgeText = 'Online';
    } else if (isFallback) {
      badgeColor = Colors.orange;
      badgeIcon = Icons.sync_problem;
      badgeText = 'Fallback'; // Short text to prevent overflow
    } else {
      badgeColor = Colors.blue;
      badgeIcon = Icons.offline_bolt;
      badgeText = 'Offline';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badgeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: 16,
            color: badgeColor,
          ),
          const SizedBox(width: 6),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom delegate for pinned TabBar
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

// Full-screen image viewer with zoom and pan capabilities
class FullScreenImageView extends StatelessWidget {
  final String imagePath;

  const FullScreenImageView({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Full-screen image with zoom and pan
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Hero(
                  tag: 'plant_image_hero',
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Image not found',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Close button in top-right corner
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 32,
                  ),
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

// Full-screen heatmap viewer with zoom, pan, and live controls
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
          // Layer 1: The Zoomable Image (Bottom of Stack)
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: _showOverlay
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        // Use a single image widget to ensure both images are constrained to same size
                        return Stack(
                          alignment: Alignment.center,
                          fit: StackFit.expand,
                          children: [
                            // Original image - base layer
                            Image.file(
                              File(widget.originalImagePath),
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildErrorWidget(
                                    'Original image not found');
                              },
                            ),
                            // Heatmap overlay - constrained to match original image exactly
                            Positioned.fill(
                              child: Opacity(
                                opacity: _opacity,
                                child: hasImageBytes
                                    ? Image.memory(
                                        widget.gradcamImageBytes!,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.center,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return _buildErrorWidget(
                                              'Failed to decode heatmap image');
                                        },
                                      )
                                    : hasFilePath
                                        ? Image.file(
                                            File(widget.gradCAMPath!),
                                            fit: BoxFit.contain,
                                            alignment: Alignment.center,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return _buildErrorWidget(
                                                  'Heatmap not found');
                                            },
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
                      errorBuilder: (context, error, stackTrace) {
                        return _buildErrorWidget('Original image not found');
                      },
                    ),
            ),
          ),

          // Layer 2: The UI Overlays (Top of Stack)
          // Close Button
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 32,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ),

          // Floating Controls Card
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
                    // Show Heatmap Overlay Switch
                    SwitchListTile(
                      title: const Text(
                        'Show Heatmap Overlay',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: _showOverlay,
                      onChanged: (value) {
                        setState(() {
                          _showOverlay = value;
                        });
                        // Update parent state
                        widget.onOverlayChanged(value);
                      },
                      activeThumbColor: Theme.of(context).primaryColor,
                    ),

                    const SizedBox(height: 8),

                    // Heatmap Opacity Slider
                    Row(
                      children: [
                        const Icon(
                          Icons.opacity,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: _opacity,
                            min: 0.0,
                            max: 1.0,
                            divisions: 20,
                            label: '${(_opacity * 100).round()}%',
                            onChanged: (value) {
                              setState(() {
                                _opacity = value;
                              });
                              // Update parent state
                              widget.onOpacityChanged(value);
                            },
                            activeColor: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(_opacity * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
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
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Optional "Where it grows" tile for the scan result screen (Static Habitat Heatmap).
/// Only visible when the resolved plant has habitat data in assets.
class _WhereItGrowsTile extends StatelessWidget {
  const _WhereItGrowsTile({
    required this.plant,
    required this.theme,
  });

  final Plant plant;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: HabitatService().hasHabitatData(plant.id),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => HabitatMapScreen(plant: plant),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.map_outlined,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.whereItGrows,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.viewHabitatMap,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
