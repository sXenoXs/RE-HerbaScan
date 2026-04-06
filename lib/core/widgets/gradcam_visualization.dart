// lib/core/widgets/gradcam_visualization.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/services/xai_explanation_service.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:herbascan/core/theme/app_theme.dart';

class GradCAMVisualization extends StatefulWidget {
  final String? gradCAMPath; // Legacy: file path (deprecated)
  final String? summaryGradCAMPath; // Legacy: file path (deprecated)
  final Uint8List? gradcamImageBytes; // New: image bytes
  final String originalImagePath;
  final String plantName;
  final String? scientificName;
  final double confidence;
  final List<Map<String, dynamic>>? predictions;
  final String? method; // 'grad-cam' or 'cam'
  final bool? fallbackUsed;
  final VoidCallback? onRefresh;
  final Function(bool showOverlay, double opacity,
          Function(bool) onOverlayChanged, Function(double) onOpacityChanged)?
      onHeatmapTap;
  final Plant? plant;

  const GradCAMVisualization({
    super.key,
    this.gradCAMPath,
    this.summaryGradCAMPath,
    this.gradcamImageBytes,
    required this.originalImagePath,
    required this.plantName,
    this.scientificName,
    required this.confidence,
    this.predictions,
    this.method,
    this.fallbackUsed,
    this.onRefresh,
    this.onHeatmapTap,
    this.plant,
  });

  @override
  State<GradCAMVisualization> createState() => _GradCAMVisualizationState();
}

class _GradCAMVisualizationState extends State<GradCAMVisualization>
    with TickerProviderStateMixin {
  bool _showHeatmap = true;
  double _opacity = 0.6;

  // Explanation state
  final XAIExplanationService _explanationService = XAIExplanationService();
  String? _explanationText;
  bool _isLoadingExplanation = false;
  String? _explanationError;
  String? _explanationSource;
  bool _shouldForceOnline = false;
  bool _isReadMoreExpanded = false;

  static const int _collapsedMaxLines = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadExplanation(forceOnline: false);
      }
    });
  }

  @override
  void didUpdateWidget(GradCAMVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    final heatmapChanged =
        oldWidget.gradcamImageBytes != widget.gradcamImageBytes ||
            oldWidget.gradCAMPath != widget.gradCAMPath;

    if (oldWidget.scientificName != widget.scientificName ||
        oldWidget.plantName != widget.plantName ||
        oldWidget.confidence != widget.confidence ||
        heatmapChanged) {
      if (heatmapChanged && _shouldForceOnline) {
        _loadExplanation(forceOnline: true);
        _shouldForceOnline = false;
      } else {
        _loadExplanation(forceOnline: false);
      }
    }
  }

  Future<void> _loadExplanation({bool forceOnline = false}) async {
    final effectiveScientificName =
        widget.scientificName?.trim().isEmpty == true
            ? null
            : (widget.scientificName ?? widget.plantName);
    if (effectiveScientificName == null || effectiveScientificName.isEmpty) {
      setState(() {
        _explanationError = 'Plant name not available';
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

      Uint8List? originalImageBytes;
      Uint8List? heatmapImageBytes;

      try {
        final originalFile = File(widget.originalImagePath);
        if (await originalFile.exists()) {
          originalImageBytes = await originalFile.readAsBytes();
        }
      } catch (e) {
        debugPrint('⚠️ Error loading original image: $e');
      }

      heatmapImageBytes = widget.gradcamImageBytes;
      if (heatmapImageBytes == null && widget.gradCAMPath != null) {
        try {
          final heatmapFile = File(widget.gradCAMPath!);
          if (await heatmapFile.exists()) {
            heatmapImageBytes = await heatmapFile.readAsBytes();
          }
        } catch (e) {
          debugPrint('⚠️ Error loading heatmap image: $e');
        }
      }

      final shouldTryOnline = forceOnline ||
          (widget.method == 'grad-cam' &&
              !(widget.fallbackUsed == true) &&
              isOnline);

      final explanation = await _explanationService.generateExplanation(
        plantName: widget.plantName,
        scientificName: effectiveScientificName,
        confidence: widget.confidence,
        predictions: widget.predictions ?? [],
        imagePath: widget.originalImagePath,
        originalImageBytes: originalImageBytes,
        heatmapImagePath: widget.gradCAMPath,
        heatmapImageBytes: heatmapImageBytes,
        isOnline: shouldTryOnline ? isOnline : false,
        forceOnline: shouldTryOnline,
      );

      if (mounted) {
        setState(() {
          _explanationText = explanation;
          final serviceSource = _explanationService.getLastExplanationSource();
          if (widget.method == 'grad-cam' && !(widget.fallbackUsed == true)) {
            _explanationSource = 'online';
          } else {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHeatmap =
        widget.gradcamImageBytes != null || widget.gradCAMPath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Method banner
        _buildMethodBanner(theme),
        const SizedBox(height: 12),
        // ROADMAP B 3.2: Plain-language label above heatmap
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'The highlighted areas show what the AI examined to identify this plant. Brighter areas were most important to the decision.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
        // Heatmap image
        _buildHeatmapContainer(theme, hasHeatmap),
        const SizedBox(height: 16),

        // Opacity slider only (slider 0 = off, replaces separate toggle)
        if (hasHeatmap) ...[
          _buildOpacitySlider(theme),
          const SizedBox(height: 16),

          // Color legend: horizontal gradient bar
          _buildColorLegend(theme),
          const SizedBox(height: 16),
        ],

        // AI explanation with inline Read More / Show Less
        _buildExplanationSection(theme),
      ],
    );
  }

  Widget _buildMethodBanner(ThemeData theme) {
    if (widget.method == null) return const SizedBox.shrink();

    final isOnline = widget.method == 'grad-cam' && widget.fallbackUsed != true;
    final isFallback = widget.fallbackUsed == true;

    final Color bannerColor;
    final String bannerText;
    final IconData bannerIcon;

    if (isOnline) {
      bannerColor = AppTheme.safeGreen;
      bannerText = 'Cloud AI Reasoning Heatmap';
      bannerIcon = Icons.cloud_done_rounded;
    } else if (isFallback) {
      bannerColor = AppTheme.warningAmber;
      bannerText = 'Offline CAM (Fallback)';
      bannerIcon = Icons.sync_problem_rounded;
    } else {
      bannerColor = AppTheme.warningAmber;
      bannerText = 'Offline CAM';
      bannerIcon = Icons.offline_bolt_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bannerColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(bannerIcon, size: 16, color: bannerColor),
          const SizedBox(width: 8),
          Text(
            bannerText,
            style: theme.textTheme.labelMedium?.copyWith(
              color: bannerColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapContainer(ThemeData theme, bool hasHeatmap) {
    final height = hasHeatmap ? 280.0 : 180.0;

    return GestureDetector(
      onTap: hasHeatmap && widget.onHeatmapTap != null
          ? () {
              widget.onHeatmapTap!(
                _showHeatmap,
                _opacity,
                (bool val) => setState(() => _showHeatmap = val),
                (double val) => setState(() => _opacity = val),
              );
            }
          : null,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: hasHeatmap
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(widget.originalImagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildImageErrorPlaceholder(theme),
                    ),
                    if (_showHeatmap && _opacity > 0)
                      Opacity(
                        opacity: _opacity,
                        child: widget.gradcamImageBytes != null
                            ? Image.memory(
                                widget.gradcamImageBytes!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              )
                            : Image.file(
                                File(widget.gradCAMPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                      ),
                    // Tap to expand hint
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fullscreen_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Expand',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : _buildNoHeatmapPlaceholder(theme),
        ),
      ),
    );
  }

  Widget _buildNoHeatmapPlaceholder(ThemeData theme) {
    final methodName = widget.method == 'cam' ? 'CAM' : 'AI Reasoning Heatmap';
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 40,
              color: AppTheme.warningAmber,
            ),
            const SizedBox(height: 8),
            Text(
              '$methodName Not Available',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.method == 'cam'
                    ? 'Offline CAM heatmap generation failed.'
                    : 'AI heatmap generation failed. Check your connection.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageErrorPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildOpacitySlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.layers_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Heatmap Opacity',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              '${(_opacity * 100).round()}%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppTheme.botanicalPrimary,
            inactiveTrackColor:
                AppTheme.botanicalPrimary.withOpacity(0.2),
            thumbColor: AppTheme.botanicalPrimary,
            overlayColor: AppTheme.botanicalPrimary.withOpacity(0.12),
          ),
          child: Slider(
            value: _opacity,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: (value) {
              setState(() {
                _opacity = value;
                _showHeatmap = value > 0;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorLegend(ThemeData theme) {
    return Row(
      children: [
        Text(
          'Low',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.green, Colors.red],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'High',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildExplanationSection(ThemeData theme) {
    if (_isLoadingExplanation) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.botanicalPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Generating explanation…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_explanationError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              _explanationError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _loadExplanation(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_explanationText == null || _explanationText!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Explanation not available.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with source badge
        Row(
          children: [
            Icon(
              Icons.psychology_rounded,
              size: 18,
              color: AppTheme.botanicalPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              'AI Explanation',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (_explanationSource != null)
              _buildSourceBadge(theme, _explanationSource!),
          ],
        ),
        const SizedBox(height: 12),

        // Inline Read More / Show Less with AnimatedSize
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: _isReadMoreExpanded
              ? MarkdownBody(
                  data: _explanationText!,
                  styleSheet: _buildMarkdownStyle(theme),
                )
              : _buildCollapsedText(theme),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _isReadMoreExpanded = !_isReadMoreExpanded;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isReadMoreExpanded ? 'Show Less' : 'Read More',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.botanicalPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _isReadMoreExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16,
                color: AppTheme.botanicalPrimary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedText(ThemeData theme) {
    // Strip markdown for the collapsed preview using replaceAllMapped so the
    // captured group content is preserved (replaceAll with r'$1' is a literal
    // string in Dart, not a backreference, which caused "$1" to appear).
    final plainText = _explanationText!
        .replaceAll(RegExp(r'#{1,6}\s'), '')
        .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1) ?? '');

    return Text(
      plainText,
      maxLines: _collapsedMaxLines,
      overflow: TextOverflow.fade,
      style: theme.textTheme.bodyMedium?.copyWith(
        height: 1.6,
        color: theme.colorScheme.onSurface.withOpacity(0.87),
      ),
    );
  }

  Widget _buildSourceBadge(ThemeData theme, String source) {
    final Color badgeColor;
    final IconData badgeIcon;
    final String badgeLabel;

    switch (source) {
      case 'online':
        badgeColor = AppTheme.safeGreen;
        badgeIcon = Icons.auto_awesome_rounded;
        badgeLabel = 'Online';
      case 'cache':
        badgeColor = AppTheme.warningAmber;
        badgeIcon = Icons.cached_rounded;
        badgeLabel = 'Cached';
      case 'fallback':
        badgeColor = AppTheme.warningAmber;
        badgeIcon = Icons.info_outline_rounded;
        badgeLabel = 'Fallback';
      default:
        badgeColor = Colors.blue;
        badgeIcon = Icons.storage_rounded;
        badgeLabel = 'Offline';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 11, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            badgeLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyle(ThemeData theme) {
    return MarkdownStyleSheet(
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
      p: theme.textTheme.bodyMedium?.copyWith(
        height: 1.7,
        color: theme.colorScheme.onSurface.withOpacity(0.87),
        fontSize: 14,
      ),
      pPadding: const EdgeInsets.only(bottom: 8, top: 2),
      strong: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
        fontSize: 16,
        height: 1.4,
      ),
      em: theme.textTheme.bodyMedium?.copyWith(
        fontStyle: FontStyle.italic,
        color: theme.colorScheme.onSurface.withOpacity(0.7),
      ),
      listBullet: theme.textTheme.bodyMedium?.copyWith(
        color: AppTheme.botanicalPrimary,
        fontSize: 16,
      ),
      listIndent: 24.0,
      listBulletPadding: const EdgeInsets.only(right: 8),
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.7),
        fontStyle: FontStyle.italic,
        backgroundColor:
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      blockquotePadding: const EdgeInsets.all(12),
      blockquoteDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: AppTheme.botanicalPrimary, width: 4),
        ),
      ),
      code: theme.textTheme.bodySmall?.copyWith(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        fontFamily: 'monospace',
        color: theme.colorScheme.onSurface,
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      a: theme.textTheme.bodyMedium?.copyWith(
        color: AppTheme.botanicalPrimary,
        decoration: TextDecoration.underline,
      ),
      tableHead: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
        backgroundColor:
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      tableBody: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.87),
      ),
      tableBorder: TableBorder.all(color: theme.dividerColor, width: 1),
      tableHeadAlign: TextAlign.center,
      tableCellsPadding: const EdgeInsets.all(8),
      blockSpacing: 12.0,
      textScaleFactor: 1.0,
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
                    const Icon(Icons.check_circle, color: Colors.green, size: 16)
                  else
                    const Icon(Icons.error_outline,
                        color: Colors.orange, size: 16),
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
                          'AI Reasoning Heatmap not available',
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
