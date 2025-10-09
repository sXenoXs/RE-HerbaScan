// lib/core/widgets/gradcam_visualization.dart
import 'package:flutter/material.dart';
import 'dart:io';

class GradCAMVisualization extends StatefulWidget {
  final String? gradCAMPath;
  final String? summaryGradCAMPath;
  final String originalImagePath;
  final String plantName;
  final double confidence;
  final VoidCallback? onRefresh;

  const GradCAMVisualization({
    super.key,
    this.gradCAMPath,
    this.summaryGradCAMPath,
    required this.originalImagePath,
    required this.plantName,
    required this.confidence,
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
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  'Explainable AI - GradCAM',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
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
                          'Confidence: ${(widget.confidence * 100).toStringAsFixed(1)}%',
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
            
            // Tab content
            SizedBox(
              height: 300,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOriginalImage(),
                  _buildHeatmapImage(),
                  _buildSummaryImage(),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Controls
            _buildControls(),
            
            const SizedBox(height: 16),
            
            // Legend
            _buildLegend(),
          ],
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
    if (widget.gradCAMPath == null) {
      return _buildErrorWidget('GradCAM heatmap not available');
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
                  child: Image.file(
                    File(widget.gradCAMPath!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildErrorWidget('GradCAM heatmap not found');
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
    return Column(
      children: [
        // Show heatmap toggle
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
