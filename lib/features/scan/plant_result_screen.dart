// lib/features/scan/plant_result_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/widgets/gradcam_visualization.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/models/scan_result.dart';
import 'package:herbascan/core/services/adaptive_gradcam_service.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

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

  // Regenerated GradCAM state
  Uint8List? _regeneratedGradcamImageBytes;
  String? _regeneratedMethod;
  bool? _regeneratedFallbackUsed;
  bool _isRegenerating = false;

  final AdaptiveGradCAMService _adaptiveGradCAMService =
      AdaptiveGradCAMService();

  @override
  void initState() {
    super.initState();

    // If opened from history, mark as already saved (don't auto-save)
    if (widget.isFromHistory) {
      _isSaved = true;
    }

    // CRITICAL FIX: Always show AI Explanation tabs if:
    // 1. Fallback was used (HIGHEST PRIORITY - indicates CAM/GradCAM was attempted), OR
    // 2. Method is set (grad-cam or cam), OR
    // 3. Heatmap is available
    // This ensures tabs show even when heatmap generation fails
    final hasHeatmap =
        widget.gradcamImageBytes != null || widget.gradCAMPath != null;
    final hasValidMethod = widget.method != null &&
        widget.method != 'classification_only' &&
        widget.method != '';
    final hasFallback = widget.fallbackUsed == true;

    // PRIORITY LOGIC:
    // 1. If fallback is used, ALWAYS show tabs (offline CAM was attempted)
    // 2. Otherwise, show if method is valid or heatmap exists
    // This is the most permissive approach - if fallback is used, we attempted CAM/GradCAM
    final showAIExplanation = hasFallback || hasValidMethod || hasHeatmap;

    // Debug logging BEFORE TabController initialization
    print('🔍 [PlantResultScreen] initState - TabController Setup:');
    print('   ════════════════════════════════════════════════════════');
    print('   method: "${widget.method}"');
    print('   fallbackUsed: ${widget.fallbackUsed}');
    print('   hasHeatmap: $hasHeatmap');
    print('   hasValidMethod: $hasValidMethod');
    print('   hasFallback: $hasFallback (PRIORITY)');
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
    print('🔍 [PlantResultScreen] initState - TabController Created:');
    print('   TabController.length: ${_tabController.length}');
    print('   TabController.index: ${_tabController.index}');
    print(
        '   Result: ${_tabController.length == 2 ? "✅ 2 tabs (Details + AI Explanation)" : "❌ 1 tab (Details only)"}');
    if (_tabController.length == 1 && hasFallback) {
      print('   ⚠️ ERROR: Fallback is true but TabController length is 1!');
      print('   ⚠️ This should not happen - tabs should be showing!');
      print(
          '   ⚠️ Check if fallbackUsed is being passed correctly to PlantResultScreen');
    }

    // Automatically save scan result when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only auto-save if not from history
      if (!widget.isFromHistory) {
        _saveResultsAutomatically();
      }
    });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).scanResults),
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
      body: Builder(
        builder: (context) {
          // CRITICAL: Use TabController length to determine if tabs should show
          // TabController was initialized in initState based on method/heatmap/fallback
          // We MUST use the same length here to avoid TabController mismatch errors
          final tabCount = _tabController.length;
          final shouldShowTabs = tabCount == 2;

          // Re-check conditions for debugging (should match initState logic)
          final hasHeatmap =
              widget.gradcamImageBytes != null || widget.gradCAMPath != null;
          final hasValidMethod = widget.method != null &&
              widget.method != 'classification_only' &&
              widget.method != '';
          final hasFallback = widget.fallbackUsed == true;
          // CRITICAL: Same priority logic as initState - fallback has highest priority
          final expectedShowTabs = hasFallback || hasValidMethod || hasHeatmap;

          // Debug logging
          print('🔍 [PlantResultScreen] build() - Rendering UI:');
          print('   method: "${widget.method}"');
          print('   fallbackUsed: ${widget.fallbackUsed}');
          print('   hasHeatmap: $hasHeatmap');
          print('   hasValidMethod: $hasValidMethod');
          print('   hasFallback: $hasFallback');
          print('   expectedShowTabs: $expectedShowTabs');
          print('   TabController.length: $tabCount');
          print('   shouldShowTabs: $shouldShowTabs');
          print(
              '   gradcamImageBytes: ${widget.gradcamImageBytes != null ? "${widget.gradcamImageBytes!.length} bytes" : "null"}');
          print('   gradCAMPath: ${widget.gradCAMPath}');

          // WARNING if mismatch
          if (expectedShowTabs != shouldShowTabs) {
            print('⚠️ [PlantResultScreen] MISMATCH DETECTED:');
            print('   Expected to show tabs: $expectedShowTabs');
            print('   TabController says: $shouldShowTabs');
            print('   This means TabController was initialized incorrectly!');
          }

          return Column(
            children: [
              // Plant identification result
              _buildPlantResultCard(theme, plantName, confidence),

              // Tab bar - ONLY show if TabController length is 2
              // This is critical - TabBar requires TabController.length == 2
              if (tabCount == 2)
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

              // Tab content - MUST match TabController length
              Expanded(
                child: tabCount == 2
                    ? TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDetailsTab(theme, topPrediction),
                          _buildGradCAMTab(theme, plantName, confidence),
                        ],
                      )
                    : _buildDetailsTab(theme, topPrediction),
              ),
            ],
          );
        },
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

  Widget _buildPlantResultCard(
      ThemeData theme, String plantName, double confidence) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.1),
            theme.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Plant image
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade100,
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

          const SizedBox(height: 16),

          // Plant name
          Text(
            plantName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Confidence score and method badge
          // Use Wrap to prevent overflow issues - Wrap automatically handles overflow
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Confidence badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getConfidenceColor(confidence).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getConfidenceColor(confidence).withOpacity(0.3),
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
                    Text(
                      '${(confidence.clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getConfidenceColor(confidence),
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
    // Get scientific name and predictions from top prediction
    final topPrediction = widget.predictions.isNotEmpty
        ? widget.predictions.first
        : <String, dynamic>{};
    final scientificName = topPrediction['scientificName'] as String?;

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
            // Use regenerated method if available, otherwise use original
            method: _regeneratedMethod ?? widget.method,
            fallbackUsed: _regeneratedFallbackUsed ?? widget.fallbackUsed,
            onRefresh: _regenerateGradCAM,
          ),

          const SizedBox(height: 16),

          // GradCAM info
          _buildGradCAMInfoCard(theme),
        ],
      ),
    );
  }

  Widget _buildPredictionsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Top Predictions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...widget.predictions.asMap().entries.map((entry) {
              final index = entry.key;
              final prediction = entry.value;
              final confidence = (prediction['confidence'] ?? 0.0).toDouble();
              final plantName = prediction['plantName'] ?? 'Unknown';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
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
                          Text(
                            '${(confidence * 100).toStringAsFixed(1)}% confidence',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
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
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantInfoCard(ThemeData theme, Map<String, dynamic> prediction) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Plant Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                'Scientific Name', prediction['scientificName'] ?? 'Unknown'),
            _buildInfoRow(
                'Confidence Level',
                _getConfidenceLevel(
                    (prediction['confidence'] ?? 0.0).toDouble())),
            _buildInfoRow(
                'Prediction Index', '${prediction['index'] ?? 'N/A'}'),
            _buildInfoRow('Features',
                '${(prediction['features'] as Map?)?.length ?? 0} features detected'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Scan Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Scan Time', DateTime.now().toString().split('.')[0]),
            _buildInfoRow('Image Path', widget.imagePath.split('/').last),
            _buildInfoRow(
                // Show "CAM Available" for offline CAM, "GradCAM Available" for online GradCAM
                widget.method == 'cam' ? 'CAM Available' : 'GradCAM Available',
                (widget.gradcamImageBytes != null || widget.gradCAMPath != null)
                    ? 'Yes'
                    : 'No'),
            if (widget.method != null)
              _buildInfoRow(
                  'Method',
                  widget.method == 'grad-cam'
                      ? 'Online (Grad-CAM)'
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
    final methodName = isCAM ? 'CAM' : 'GradCAM';

    // Description text based on method
    final description = isCAM
        ? 'CAM (Class Activation Mapping) shows which parts of the image the AI model focused on when making its prediction. This offline method uses feature maps to highlight important regions without requiring gradient computation.'
        : 'GradCAM (Gradient-weighted Class Activation Mapping) shows which parts of the image the AI model focused on when making its prediction. This helps explain why the model made its decision.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'About $methodName',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$description',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '• Red areas: High attention (important features)\n'
              '• Green areas: Medium attention\n'
              '• Blue areas: Low attention',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
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

  String _getConfidenceLevel(double confidence) {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.5) return 'Medium';
    return 'Low';
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
      // Show loading indicator
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Regenerating GradCAM and explanation...',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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
                  ? 'GradCAM regenerated successfully!'
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

      // Save to database
      await plantProvider.addScanResult(scanResult);

      setState(() {
        _isSaved = true;
      });

      print('✅ Scan result saved successfully');
    } catch (e) {
      print('❌ Error saving scan result: $e');
    }
  }

  void _saveResults() {
    if (_isSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan already saved to history'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Manually save when button is pressed
      _saveResultsAutomatically();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan saved to history successfully'),
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
