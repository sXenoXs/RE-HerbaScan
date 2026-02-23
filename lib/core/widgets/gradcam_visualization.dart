// lib/core/widgets/gradcam_visualization.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:herbascan/core/services/xai_explanation_service.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:herbascan/core/widgets/summary_fullscreen_view.dart';

class GradCAMVisualization extends StatefulWidget {
  final String? gradCAMPath; // Legacy: file path (deprecated)
  final String? summaryGradCAMPath; // Legacy: file path (deprecated)
  final Uint8List? gradcamImageBytes; // New: image bytes
  final String originalImagePath;
  final String plantName;
  final String? scientificName; // Scientific name for explanation lookup
  final double confidence;
  final List<Map<String, dynamic>>?
      predictions; // Top predictions for explanation
  final String? method; // 'grad-cam' or 'cam'
  final bool? fallbackUsed; // True if offline was fallback
  final VoidCallback? onRefresh;
  final Function(bool showOverlay, double opacity,
          Function(bool) onOverlayChanged, Function(double) onOpacityChanged)?
      onHeatmapTap; // Callback for full-screen heatmap

  const GradCAMVisualization({
    super.key,
    this.gradCAMPath, // Legacy support
    this.summaryGradCAMPath, // Legacy support
    this.gradcamImageBytes, // New format
    required this.originalImagePath,
    required this.plantName,
    this.scientificName,
    required this.confidence,
    this.predictions,
    this.method,
    this.fallbackUsed,
    this.onRefresh,
    this.onHeatmapTap, // Callback for full-screen heatmap
  });

  @override
  State<GradCAMVisualization> createState() => _GradCAMVisualizationState();
}

class _GradCAMVisualizationState extends State<GradCAMVisualization>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _showHeatmap = true;
  double _opacity = 0.6;
  int _currentTabIndex = 0; // Track current tab index

  // Explanation state
  final XAIExplanationService _explanationService = XAIExplanationService();
  String? _explanationText;
  bool _isLoadingExplanation = false;
  String? _explanationError;
  String?
      _explanationSource; // Track source: "gemini", "cache", "offline", "fallback"
  bool _shouldForceOnline = false; // Track if we should force online mode

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Listen to tab changes to track current tab index
    // CRITICAL: This listener ensures setState() is called when tab changes
    // Without this, the visibility condition won't re-evaluate when user swipes between tabs
    _tabController.addListener(() {
      if (mounted && _tabController.index != _currentTabIndex) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
    // Only load explanation on initial build, not on rebuilds
    // Rebuilds will be handled by didUpdateWidget or explicit refresh calls
    // Load cached explanation first (don't auto-trigger online calls)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadExplanation(forceOnline: false); // Load from cache only
      }
    });
  }

  @override
  void didUpdateWidget(GradCAMVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload explanation if key data changed OR if heatmap was regenerated
    final heatmapChanged =
        oldWidget.gradcamImageBytes != widget.gradcamImageBytes ||
            oldWidget.gradCAMPath != widget.gradCAMPath;

    if (oldWidget.scientificName != widget.scientificName ||
        oldWidget.plantName != widget.plantName ||
        oldWidget.confidence != widget.confidence ||
        heatmapChanged) {
      // If heatmap changed, reload explanation to use new heatmap
      // Use forceOnline if it was set by refresh button (user explicitly requested)
      if (heatmapChanged && _shouldForceOnline) {
        _loadExplanation(forceOnline: true);
        _shouldForceOnline = false; // Reset after use
      } else {
        // Otherwise, just reload from cache (don't auto-trigger online calls)
        _loadExplanation(forceOnline: false);
      }
    }
  }

  /// Load explanation (offline or online)
  Future<void> _loadExplanation({bool forceOnline = false}) async {
    if (widget.scientificName == null) {
      setState(() {
        _explanationError = 'Scientific name not available';
      });
      return;
    }

    setState(() {
      _isLoadingExplanation = true;
      _explanationError = null;
      _explanationSource = null;
    });

    try {
      final offlineProvider =
          Provider.of<OfflineProvider>(context, listen: false);
      final isOnline = offlineProvider.isOnline;

      // Load images as bytes
      Uint8List? originalImageBytes;
      Uint8List? heatmapImageBytes;

      try {
        final originalFile = File(widget.originalImagePath);
        if (await originalFile.exists()) {
          originalImageBytes = await originalFile.readAsBytes();
        }
      } catch (e) {
        print('⚠️ Error loading original image: $e');
      }

      // Get heatmap bytes (prefer bytes over file path)
      heatmapImageBytes = widget.gradcamImageBytes;
      if (heatmapImageBytes == null && widget.gradCAMPath != null) {
        try {
          final heatmapFile = File(widget.gradCAMPath!);
          if (await heatmapFile.exists()) {
            heatmapImageBytes = await heatmapFile.readAsBytes();
          }
        } catch (e) {
          print('⚠️ Error loading heatmap image: $e');
        }
      }

      // CRITICAL FIX: If using online GradCAM (method == 'grad-cam' and not fallback),
      // we should try to get online explanation if available, not just use cache
      // This ensures the source badge shows "Online" when using online GradCAM
      final shouldTryOnline = forceOnline ||
          (widget.method == 'grad-cam' &&
              !(widget.fallbackUsed == true) &&
              isOnline);

      // Only pass isOnline if we should try online (forceOnline OR using online GradCAM)
      // Otherwise, let the service check cache first without triggering online calls
      final explanation = await _explanationService.generateExplanation(
        plantName: widget.plantName,
        scientificName: widget.scientificName!,
        confidence: widget.confidence,
        predictions: widget.predictions ?? [],
        imagePath: widget.originalImagePath,
        originalImageBytes: originalImageBytes,
        heatmapImagePath: widget.gradCAMPath,
        heatmapImageBytes: heatmapImageBytes,
        isOnline: shouldTryOnline ? isOnline : false,
        forceOnline:
            shouldTryOnline, // Try online if using GradCAM or user requested refresh
      );

      if (mounted) {
        setState(() {
          _explanationText = explanation;
          // CRITICAL FIX: If method is 'grad-cam' (online), show "Online" regardless of cache source
          // This ensures that when using online GradCAM, the badge shows "Online" even if explanation came from cache
          final serviceSource = _explanationService.getLastExplanationSource();
          if (widget.method == 'grad-cam' && !(widget.fallbackUsed == true)) {
            // Using online GradCAM - show "Online" (gemini) even if it came from cache
            _explanationSource = 'gemini';
          } else {
            // Use the actual source from service (offline, cache, fallback)
            _explanationSource = serviceSource;
          }
          _isLoadingExplanation = false;
          if (explanation == null) {
            _explanationError = 'Unable to generate explanation';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingExplanation = false;
          _explanationError = 'Error loading explanation: $e';
          _explanationSource = null;
        });
      }
    }
  }

  /// Handle refresh button - regenerate both heatmap and explanation
  Future<void> _handleRefresh() async {
    // Show loading state
    setState(() {
      _isLoadingExplanation = true;
      _explanationError = null;
      _explanationText = null;
      _shouldForceOnline = true; // Mark that we want to force online mode
    });

    // First, regenerate the heatmap (if callback provided)
    // This will trigger _regenerateGradCAM in parent, which updates the widget
    // with new gradcamImageBytes, causing didUpdateWidget to be called
    if (widget.onRefresh != null) {
      widget.onRefresh!(); // This will trigger _regenerateGradCAM in parent
    }

    // Also immediately reload explanation with force online
    // This ensures explanation is regenerated even if heatmap doesn't change
    await _loadExplanation(forceOnline: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHeatmap =
        widget.gradcamImageBytes != null || widget.gradCAMPath != null;

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
        // CRITICAL FIX: Use SingleChildScrollView to prevent overflow
        // Especially important when heatmap is missing and error widget is shown
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Use min to prevent overflow
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.visibility,
                    color: theme.colorScheme.onSurface,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explainable AI - ${widget.method == 'grad-cam' ? 'Score-CAM' : 'CAM'}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (widget.method != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _buildMethodBadge(theme),
                          ),
                      ],
                    ),
                  ),
                  if (widget.onRefresh != null)
                    IconButton(
                      onPressed: _isLoadingExplanation ? null : _handleRefresh,
                      icon: _isLoadingExplanation
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.onSurface,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.refresh,
                              color: theme.colorScheme.onSurface,
                            ),
                      tooltip: _isLoadingExplanation
                          ? 'Regenerating...'
                          : 'Regenerate explanation and heatmap',
                      color: theme.colorScheme.onSurface,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Plant info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_florist,
                      color: theme.colorScheme.onSurface,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.plantName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Confidence: ${(widget.confidence.clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tab bar
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.thermostat),
                    text: 'Heatmap',
                  ),
                  Tab(
                    icon: Icon(Icons.analytics),
                    text: 'Summary',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tab content - use SizedBox with explicit height
              // CRITICAL: TabBarView requires explicit height, use smaller when heatmap missing
              SizedBox(
                height: hasHeatmap
                    ? 280
                    : 220, // Reduced further to prevent overflow
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHeatmapImage(),
                    _buildSummaryImage(),
                  ],
                ),
              ),

              // Only show spacing if controls/legend will be shown
              // Show controls and legend only when Heatmap tab (index 0) is active
              if (hasHeatmap && _currentTabIndex == 0)
                const SizedBox(height: 16),

              // Controls - only show if heatmap is available AND Heatmap tab is active
              if (hasHeatmap && _currentTabIndex == 0) _buildControls(),

              // Legend removed - now integrated into "About GradCAM/CAM" card in plant_result_screen.dart
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeatmapImage() {
    // Check if we have image bytes (new format)
    final hasImageBytes = widget.gradcamImageBytes != null;
    // Check if we have file path (legacy format)
    final hasFilePath = widget.gradCAMPath != null;

    // Debug logging
    print('🔍 [GradCAMVisualization] _buildHeatmapImage:');
    print('   method: ${widget.method}');
    print('   hasImageBytes: $hasImageBytes');
    print('   hasFilePath: $hasFilePath');
    if (hasImageBytes) {
      print('   imageBytes size: ${widget.gradcamImageBytes!.length} bytes');
    }

    if (!hasImageBytes && !hasFilePath) {
      final methodName = widget.method == 'cam' ? 'CAM' : 'Score-CAM';
      print('   ⚠️ WARNING: No heatmap available for $methodName');
      // CRITICAL FIX: Use LayoutBuilder to respect parent constraints
      // TabBarView provides fixed constraints (220px), we must fit exactly
      return LayoutBuilder(
        builder: (context, constraints) {
          final padding = 8.0; // Minimal padding

          // Fixed sizes that fit within 220px: icon(28) + spacing(4) + title(32) + spacing(4) + desc(40) + spacing(4) + image(70) + padding(16) = ~198px
          final iconSize = 28.0;
          final titleFontSize = 11.0;
          final descFontSize = 9.0;
          final spacing = 4.0;
          final imageMaxHeight = 70.0; // Fixed size to prevent overflow

          final theme = Theme.of(context);
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            // CRITICAL: Use SizedBox.expand to fill TabBarView constraints exactly
            // Then use Center to center the content
            child: SizedBox.expand(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Critical: use min
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon - fixed size
                    SizedBox(
                      height: iconSize,
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: iconSize,
                        color: Colors.orange.shade300,
                      ),
                    ),
                    SizedBox(height: spacing),
                    // Title - fixed height
                    SizedBox(
                      height: 32, // Enough for 2 lines
                      child: Text(
                        '$methodName Heatmap Not Available',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: spacing),
                    // Description - fixed height
                    SizedBox(
                      height: 40, // Enough for 3 lines of 9px font
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          widget.method == 'cam'
                              ? 'Offline CAM heatmap generation failed. This may be due to model initialization issues or image processing errors.'
                              : 'Score-CAM heatmap generation failed. Please check your internet connection or try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: descFontSize,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.87),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing),
                    // Image - fixed size
                    SizedBox(
                      height: imageMaxHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(widget.originalImagePath),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 24,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return GestureDetector(
      onTap: () {
        // Only open full-screen if heatmap is available and callback is provided
        if ((hasImageBytes || hasFilePath) && widget.onHeatmapTap != null) {
          widget.onHeatmapTap!(
            _showHeatmap,
            _opacity,
            (bool val) {
              setState(() {
                _showHeatmap = val;
              });
            },
            (double val) {
              setState(() {
                _opacity = val;
              });
            },
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _showHeatmap
              ? Stack(
                  children: [
                    // Original image
                    Image.file(
                      File(widget.originalImagePath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildErrorWidget('Original image not found');
                      },
                    ),
                    // Heatmap overlay
                    Opacity(
                      opacity: _opacity,
                      child: hasImageBytes
                          ? Image.memory(
                              widget.gradcamImageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                final methodName = widget.method == 'cam'
                                    ? 'CAM'
                                    : 'Score-CAM';
                                return _buildErrorWidget(
                                    'Failed to decode $methodName heatmap image');
                              },
                            )
                          : Image.file(
                              File(widget.gradCAMPath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                final methodName = widget.method == 'cam'
                                    ? 'CAM'
                                    : 'Score-CAM';
                                return _buildErrorWidget(
                                    '$methodName heatmap not found');
                              },
                            ),
                    ),
                  ],
                )
              : Image.file(
                  File(widget.originalImagePath),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildErrorWidget('Original image not found');
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryImage() {
    // Show text explanation instead of image
    return _buildSummaryExplanation();
  }

  Widget _buildSummaryExplanation() {
    final theme = Theme.of(context);

    if (_isLoadingExplanation) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Generating explanation...',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_explanationError != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  _explanationError!,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _loadExplanation(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_explanationText == null || _explanationText!.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 48,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Explanation not available',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show explanation text
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Header Row - AI Explanation title, Status Badge, and Fullscreen Icon
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: theme.colorScheme.onSurface,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Explanation',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Source badge (Online/Fallback/Offline/Cached) and Fullscreen Icon
                if (_explanationSource != null)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _explanationSource == 'gemini'
                                ? Colors.green.withOpacity(0.1)
                                : _explanationSource == 'cache'
                                    ? Colors.orange.withOpacity(0.1)
                                    : _explanationSource == 'fallback'
                                        ? Colors.orange.withOpacity(0.1)
                                        : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _explanationSource == 'gemini'
                                  ? Colors.green.withOpacity(0.3)
                                  : _explanationSource == 'cache'
                                      ? Colors.orange.withOpacity(0.3)
                                      : _explanationSource == 'fallback'
                                          ? Colors.orange.withOpacity(0.3)
                                          : Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _explanationSource == 'gemini'
                                    ? Icons.auto_awesome
                                    : _explanationSource == 'cache'
                                        ? Icons.cached
                                        : _explanationSource == 'fallback'
                                            ? Icons.info_outline
                                            : Icons.storage,
                                size: 12,
                                color: _explanationSource == 'gemini'
                                    ? Colors.green
                                    : _explanationSource == 'cache'
                                        ? Colors.orange
                                        : _explanationSource == 'fallback'
                                            ? Colors.orange
                                            : Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _explanationSource == 'gemini'
                                      ? 'Online'
                                      : _explanationSource == 'cache'
                                          ? 'Cached'
                                          : _explanationSource == 'fallback'
                                              ? 'Fallback'
                                              : 'Offline',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _explanationSource == 'gemini'
                                        ? Colors.green
                                        : _explanationSource == 'cache'
                                            ? Colors.orange
                                            : _explanationSource == 'fallback'
                                                ? Colors.orange
                                                : Colors.blue,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Fullscreen Icon
                        if (_explanationText != null &&
                            _explanationText!.isNotEmpty)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => SummaryFullScreenView(
                                      explanationText: _explanationText!,
                                      onRegenerate: _handleRefresh,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.fullscreen,
                                  size: 18,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Content area (no longer needs Stack since icon is in header)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MarkdownBody(
                    data: _explanationText!,
                    styleSheet: MarkdownStyleSheet(
                      // Headings with reduced spacing
                      h1: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        fontSize: 22,
                        height: 1.3,
                      ),
                      h1Padding: const EdgeInsets.only(bottom: 4, top: 8),
                      h2: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        fontSize: 20,
                        height: 1.3,
                      ),
                      h2Padding: const EdgeInsets.only(bottom: 4, top: 8),
                      h3: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                        height: 1.3,
                      ),
                      h3Padding: const EdgeInsets.only(bottom: 4, top: 8),
                      // Body text with reduced spacing
                      p: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.7,
                        color: theme.colorScheme.onSurface.withOpacity(0.87),
                        fontSize: 14,
                      ),
                      pPadding: const EdgeInsets.only(bottom: 8, top: 2),
                      // Bold text (for section headers like **Plant Identification Summary**)
                      strong: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        height: 1.4,
                      ),
                      // Italic text
                      em: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      // Lists
                      listBullet: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.primaryColor,
                        fontSize: 16,
                      ),
                      // List items
                      listIndent: 24.0,
                      listBulletPadding: const EdgeInsets.only(right: 8),
                      // Block quotes
                      blockquote: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                        backgroundColor: theme
                            .colorScheme.surfaceContainerHighest
                            .withOpacity(0.3),
                      ),
                      blockquotePadding: const EdgeInsets.all(12),
                      blockquoteDecoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                        border: Border(
                          left: BorderSide(
                            color: theme.primaryColor,
                            width: 4,
                          ),
                        ),
                      ),
                      // Code blocks
                      code: theme.textTheme.bodySmall?.copyWith(
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurface,
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      codeblockDecoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      // Horizontal rule
                      horizontalRuleDecoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: theme.dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                      // Links
                      a: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                      // Table
                      tableHead: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        backgroundColor: theme
                            .colorScheme.surfaceContainerHighest
                            .withOpacity(0.5),
                      ),
                      tableBody: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.87),
                      ),
                      tableBorder: TableBorder.all(
                        color: theme.dividerColor,
                        width: 1,
                      ),
                      tableHeadAlign: TextAlign.center,
                      tableCellsPadding: const EdgeInsets.all(8),
                      // Spacing between blocks (reduced)
                      blockSpacing: 12.0,
                      textScaleFactor: 1.0,
                    ),
                  ),
                  // "Ask AI Assistant" button when online - at the bottom of content
                  const SizedBox(height: 16),
                  Consumer<OfflineProvider>(
                    builder: (context, offlineProvider, _) {
                      if (offlineProvider.isOnline) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _loadExplanation(forceOnline: true),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Ask AI Assistant (Regenerate)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.87),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    // CRITICAL FIX: Only show controls if heatmap is available
    // Don't show toggle when heatmap is missing (causes confusion)
    final hasHeatmap =
        widget.gradcamImageBytes != null || widget.gradCAMPath != null;

    if (!hasHeatmap) {
      // Don't show controls when heatmap is not available
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Show heatmap toggle - only when heatmap is available
        Row(
          children: [
            Icon(
              Icons.visibility,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              'Show Heatmap Overlay',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Switch(
              value: _showHeatmap,
              onChanged: (value) {
                setState(() {
                  _showHeatmap = value;
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Opacity slider
        Row(
          children: [
            Icon(
              Icons.opacity,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              'Heatmap Opacity',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '${(_opacity * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),

        Slider(
          value: _opacity,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          onChanged: (value) {
            setState(() {
              _opacity = value;
            });
          },
        ),
      ],
    );
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
      badgeText = 'Online (Score-CAM)';
    } else if (isFallback) {
      badgeColor = Colors.orange;
      badgeIcon = Icons.sync_problem;
      badgeText = 'Offline (Fallback)';
    } else {
      badgeColor = Colors.blue;
      badgeIcon = Icons.offline_bolt;
      badgeText = 'Offline (CAM)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple GradCAM preview widget for quick display
class GradCAMPreview extends StatelessWidget {
  final String? gradCAMPath;
  final String plantName;
  final double confidence;
  final VoidCallback? onTap;

  const GradCAMPreview({
    super.key,
    this.gradCAMPath,
    required this.plantName,
    required this.confidence,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.visibility,
                    color: theme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI Explanation',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (gradCAMPath != null)
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    )
                  else
                    Icon(
                      Icons.error_outline,
                      color: Colors.orange,
                      size: 16,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (gradCAMPath != null) ...[
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(gradCAMPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade100,
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to view detailed explanation',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ] else ...[
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.visibility_off,
                          color: Colors.grey.shade400,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Score-CAM not available',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
