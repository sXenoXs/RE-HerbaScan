// lib/core/widgets/gradcam_visualization.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';

class GradCAMVisualization extends StatefulWidget {
  final String? gradCAMPath; // Legacy: file path (deprecated)
  final String? summaryGradCAMPath; // Legacy: file path (deprecated)
  final Uint8List? gradcamImageBytes; // New: image bytes
  final String originalImagePath;
  final String plantName;
  final double confidence;
  final String? method; // 'grad-cam' or 'cam'
  final bool? fallbackUsed; // True if offline was fallback
  final VoidCallback? onRefresh;

  const GradCAMVisualization({
    super.key,
    this.gradCAMPath, // Legacy support
    this.summaryGradCAMPath, // Legacy support
    this.gradcamImageBytes, // New format
    required this.originalImagePath,
    required this.plantName,
    required this.confidence,
    this.method,
    this.fallbackUsed,
    this.onRefresh,
  });

  @override
  State<GradCAMVisualization> createState() => _GradCAMVisualizationState();
}

class _GradCAMVisualizationState extends State<GradCAMVisualization>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _showHeatmap = true;
  double _opacity = 0.6;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHeatmap = widget.gradcamImageBytes != null || widget.gradCAMPath != null;
    
    return Card(
      elevation: 4,
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
                    color: theme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explainable AI - ${widget.method == 'grad-cam' ? 'Grad-CAM' : 'CAM'}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
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
                      onPressed: widget.onRefresh,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Regenerate GradCAM',
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Plant info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_florist,
                      color: theme.primaryColor,
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
                            ),
                          ),
                          Text(
                            'Confidence: ${(widget.confidence.clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.primaryColor,
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
                    icon: Icon(Icons.image),
                    text: 'Original',
                  ),
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
                height: hasHeatmap ? 280 : 220, // Reduced further to prevent overflow
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOriginalImage(),
                    _buildHeatmapImage(),
                    _buildSummaryImage(),
                  ],
                ),
              ),
              
              // Only show spacing if controls/legend will be shown
              if (hasHeatmap) const SizedBox(height: 16),
              
              // Controls - only show if heatmap is available
              _buildControls(),
              
              // Only show spacing if legend will be shown
              if (hasHeatmap) const SizedBox(height: 8),
              
              // Legend - only show if heatmap is available
              if (hasHeatmap) _buildLegend(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOriginalImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(widget.originalImagePath),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget('Original image not found');
          },
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
      final methodName = widget.method == 'cam' ? 'CAM' : 'Grad-CAM';
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
          
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.grey.shade100,
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
                          color: Colors.grey.shade700,
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
                              : 'Grad-CAM heatmap generation failed. Please check your internet connection or try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: descFontSize,
                            color: Colors.grey.shade600,
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
                          border: Border.all(color: Colors.grey.shade300),
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
                                  color: Colors.grey.shade400,
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
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
                              final methodName =
                                  widget.method == 'cam' ? 'CAM' : 'Grad-CAM';
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
                              final methodName =
                                  widget.method == 'cam' ? 'CAM' : 'Grad-CAM';
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
    );
  }

  Widget _buildSummaryImage() {
    if (widget.summaryGradCAMPath == null) {
      return _buildErrorWidget('Summary GradCAM not available');
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
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
                  // Summary heatmap overlay
                  Opacity(
                    opacity: _opacity,
                    child: Image.file(
                      File(widget.summaryGradCAMPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildErrorWidget('Summary GradCAM not found');
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
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade600,
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
    final hasHeatmap = widget.gradcamImageBytes != null || widget.gradCAMPath != null;
    
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
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              'Show Heatmap Overlay',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
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
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              'Heatmap Opacity',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const Spacer(),
            Text(
              '${(_opacity * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
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

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Heatmap Legend',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Use Wrap to prevent overflow
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem(Colors.blue, 'Low Attention'),
              _buildLegendItem(Colors.green, 'Medium Attention'),
              _buildLegendItem(Colors.red, 'High Attention'),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'The heatmap shows which parts of the image the AI model focused on when making its prediction. Red areas indicate high attention, while blue areas indicate low attention.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
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
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
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
      badgeText = 'Online (Grad-CAM)';
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
                          'GradCAM not available',
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
