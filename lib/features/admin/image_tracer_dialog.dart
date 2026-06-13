// lib/features/admin/image_tracer_dialog.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:herbascan/core/services/svg_tracer_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_drawing/path_drawing.dart';

enum _TracerState { idle, picking, resizing, tracing, preview }

/// A full-screen dialog for tracing images into SVG paths.
class ImageTracerDialog extends StatefulWidget {
  const ImageTracerDialog({super.key});

  @override
  State<ImageTracerDialog> createState() => _ImageTracerDialogState();
}

class _ImageTracerDialogState extends State<ImageTracerDialog> {
  // ── State Machine ────────────────────────────────────────────────────────

  _TracerState _state = _TracerState.idle;

  // ── Image Data ───────────────────────────────────────────────────────────
  Uint8List? _originalImageBytes;
  Uint8List? _resizedImageBytes; // 300×300
  String? _imageFilename;

  // ── Tracing Parameters ───────────────────────────────────────────────────
  int _threshold = 128; // 0-255
  int _blur = 2; // 0-15
  double _simplify = 1.5; // 0.5-5.0
  bool _invert = false;
  int _ignoreLessThan = 20; // 0-100
  int _smoothness = 0; // 0-5

  // ── Preview Toggles ──────────────────────────────────────────────────────
  bool _showPath = true;
  bool _showPoints = true;
  bool _fadeImage = false;

  // ── Tracing Results ──────────────────────────────────────────────────────
  String? _tracedSvgPath;
  ui.Image? _previewImage; // For CustomPaint background
  bool _isTracing = false;
  String? _traceError;

  // ── UI Helpers ───────────────────────────────────────────────────────────
  final _picker = ImagePicker();
  bool get _isWeb => kIsWeb;

  @override
  void initState() {
    super.initState();
    _loadPreviewImage();
  }

  Future<void> _loadPreviewImage() async {
    // Create a transparent 300x300 preview image initially
    final pic = await _createPlaceholderImage();
    if (mounted) {
      setState(() => _previewImage = pic);
    }
  }

  Future<ui.Image> _createPlaceholderImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.transparent;
    canvas.drawRect(Rect.fromLTWH(0, 0, 300, 300), paint);
    final picture = recorder.endRecording();
    return await picture.toImage(300, 300);
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    if (_state == _TracerState.tracing) return;

    setState(() {
      _state = _TracerState.picking;
      _traceError = null;
    });

    try {
      final XFile? pickedFile;
      if (_isWeb) {
        // Web: use file_picker via file_picker package
        final result = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 300,
          maxHeight: 300,
        );
        pickedFile = result;
      } else {
        // Mobile: use image_picker
        pickedFile = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
      }

      if (pickedFile == null) {
        if (!mounted) return;
        setState(() => _state = _TracerState.idle);
        return;
      }

      final imageBytes = await pickedFile.readAsBytes();
      final filename = pickedFile.name;

      if (!mounted) return;
      setState(() {
        _originalImageBytes = imageBytes;
        _imageFilename = filename;
        _state = _TracerState.resizing;
      });

      // Resize to 300×300 for processing and preview
      await _resizeImage(imageBytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _TracerState.idle;
        _traceError = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _resizeImage(Uint8List imageBytes) async {
    try {
      final img.Image? decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        if (!mounted) return;
        setState(() {
          _state = _TracerState.idle;
          _traceError = 'Failed to decode image';
        });
        return;
      }

      final img.Image resized =
          img.copyResize(decoded, width: 300, height: 300);
      final resizedBytes = Uint8List.fromList(img.encodePng(resized));

      if (!mounted) return;
      setState(() {
        _resizedImageBytes = resizedBytes;
        _state = _TracerState.tracing;
      });

      // Start tracing
      await _traceImage();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _TracerState.idle;
        _traceError = 'Failed to resize image: $e';
      });
    }
  }

  Future<void> _traceImage() async {
    if (_resizedImageBytes == null) return;

    setState(() => _isTracing = true);

    try {
      final path = await SvgTracerService.traceToSvgPath(
        imageBytes: _resizedImageBytes!,
        threshold: _threshold,
        blur: _blur,
        invert: _invert,
        simplify: _simplify,
        ignoreLessThan: _ignoreLessThan,
        smoothness: _smoothness,
      );

      if (!mounted) return;
      setState(() {
        _tracedSvgPath = path;
        _isTracing = false;
        _state = _TracerState.preview;
        _traceError = null;
      });

      // Update preview image for CustomPaint background
      await _updatePreviewImage();
    } on SvgTracerException catch (e) {
      if (!mounted) return;
      setState(() {
        _isTracing = false;
        _state = _TracerState.preview;
        _traceError = e.message;
        _tracedSvgPath = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTracing = false;
        _state = _TracerState.preview;
        _traceError = 'Unexpected error: $e';
        _tracedSvgPath = null;
      });
    }
  }

  Future<void> _updatePreviewImage() async {
    if (_resizedImageBytes == null) return;
    try {
      final codec = await ui.instantiateImageCodec(
        _resizedImageBytes!,
        targetWidth: 300,
        targetHeight: 300,
      );
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() => _previewImage = frame.image);
      }
    } catch (e) {
      debugPrint('Failed to update preview image: $e');
    }
  }

  void _copyToClipboard() {
    if (_tracedSvgPath == null || !mounted) return;
    Clipboard.setData(ClipboardData(text: _tracedSvgPath!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _useThisPath() {
    if (_tracedSvgPath == null || !mounted) return;
    Navigator.of(context).pop(_tracedSvgPath);
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  // ── Debounced Tracing ────────────────────────────────────────────────────
  Timer? _debounceTimer;

  void _debouncedTrace() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (_state == _TracerState.preview &&
          _resizedImageBytes != null &&
          !_isTracing) {
        _traceImage();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _TracerState.idle:
        return _buildIdleState();
      case _TracerState.picking:
        return _buildPickingState();
      case _TracerState.resizing:
        return _buildResizingState();
      case _TracerState.tracing:
        return _buildTracingState();
      case _TracerState.preview:
        return _buildPreviewState();
    }
  }

  Widget _buildIdleState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image,
            size: 64,
            color: AppTheme.botanicalPrimary,
          ),
          const SizedBox(height: 16),
          Text(
            'Image Tracer',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a plant part image to auto-generate the SVG path',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image),
            label: const Text('Pick Image'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.botanicalPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.botanicalPrimary),
      ),
    );
  }

  Widget _buildResizingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.botanicalPrimary),
      ),
    );
  }

  Widget _buildTracingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.botanicalPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            'Tracing image...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewState() {
    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _buildMainContent(),
          ),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
            onPressed: _cancel,
          ),
          Expanded(
            child: Text(
              'Image Tracer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.botanicalPrimary),
            onPressed: _useThisPath,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: _buildImagePanel(),
        ),
        VerticalDivider(
          width: 1,
          color: Theme.of(context).dividerColor,
        ),
        Expanded(
          flex: 1,
          child: _buildSvgPreviewPanel(),
        ),
      ],
    );
  }

  Widget _buildImagePanel() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _previewImage != null
            ? RawImage(
                image: _previewImage!,
                fit: BoxFit.contain,
              )
            : Container(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                child: Icon(
                  Icons.image,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
      ),
    );
  }

  Widget _buildSvgPreviewPanel() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _tracedSvgPath == null || _tracedSvgPath!.isEmpty
            ? _buildEmptyPreview()
            : _buildSvgPreview(),
      ),
    );
  }

  Widget _buildEmptyPreview() {
    return Container(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
      child: Icon(
        Icons.image_not_supported,
        size: 48,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
      ),
    );
  }

  Widget _buildSvgPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _TracedPathPainter(
            svgPathData: _tracedSvgPath!,
            sourceImage: _previewImage,
            showPath: _showPath,
            showPoints: _showPoints,
            fadeImage: _fadeImage,
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_traceError != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _traceError!,
                style: TextStyle(
                  color: AppTheme.errorColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
          ],
          _buildTracingSettings(),
          const SizedBox(height: 12),
          _buildPathDisplay(),
          const SizedBox(height: 8),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildTracingSettings() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('PREVIEW'),
          _buildCheckbox('Show path', _showPath, (v) => setState(() => _showPath = v)),
          _buildCheckbox('Show points', _showPoints, (v) => setState(() => _showPoints = v)),
          _buildCheckbox('Fade image', _fadeImage, (v) => setState(() => _fadeImage = v)),
          
          Divider(color: Theme.of(context).dividerColor, height: 24),
          _buildSectionHeader('PRE-PROCESSING'),
          _buildCheckbox('Invert image', _invert, (v) {
            setState(() { _invert = v; _debouncedTrace(); });
          }),
          const SizedBox(height: 8),
          _buildSlider(
            label: 'Blur', value: _blur.toDouble(), min: 0, max: 15,
            onChanged: (v) { setState(() { _blur = v.round(); _debouncedTrace(); }); },
            valueFormatter: (v) => v.round().toString(),
          ),
          const SizedBox(height: 4),
          _buildSlider(
            label: 'Threshold', value: _threshold.toDouble(), min: 0, max: 255,
            onChanged: (v) { setState(() { _threshold = v.round(); _debouncedTrace(); }); },
            valueFormatter: (v) => v.round().toString(),
          ),

          Divider(color: Theme.of(context).dividerColor, height: 24),
          _buildSectionHeader('TRACING'),
          _buildSlider(
            label: 'Ignore less than', value: _ignoreLessThan.toDouble(), min: 0, max: 100,
            onChanged: (v) { setState(() { _ignoreLessThan = v.round(); _debouncedTrace(); }); },
            valueFormatter: (v) => v.round().toString(),
          ),
          const SizedBox(height: 4),
          _buildSlider(
            label: 'Smoothness', value: _smoothness.toDouble(), min: 0, max: 5,
            onChanged: (v) { setState(() { _smoothness = v.round(); _debouncedTrace(); }); },
            valueFormatter: (v) => v.round().toString(),
          ),
          const SizedBox(height: 4),
          _buildSlider(
            label: 'Curve optimisation', value: _simplify, min: 0.5, max: 5.0,
            onChanged: (v) { setState(() { _simplify = v; _debouncedTrace(); }); },
            valueFormatter: (v) => v.toStringAsFixed(1),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }

  Widget _buildCheckbox(String title, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppTheme.botanicalPrimary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String Function(double) valueFormatter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ),
            Text(
              valueFormatter(value),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: AppTheme.botanicalPrimary,
            thumbColor: AppTheme.botanicalPrimary,
          ),
        ],
      );
  }

  Widget _buildPathDisplay() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generated path (d="..." value):',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              _tracedSvgPath ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
              maxLines: 3,
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _tracedSvgPath == null ? null : _copyToClipboard,
            icon: const Icon(Icons.content_copy, size: 16),
            label: const Text('Copy to Clipboard'),
            style: TextButton.styleFrom(
              foregroundColor: _tracedSvgPath == null
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
                  : AppTheme.botanicalPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _cancel,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed:
                _isTracing || _tracedSvgPath == null ? null : _useThisPath,
            child: _isTracing
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Text('Use This Path'),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for displaying the traced SVG path overlaid on the image.
class _TracedPathPainter extends CustomPainter {
  final String svgPathData; // the d="..." string
  final ui.Image? sourceImage; // 300×300 decoded image for background
  final bool showPath;
  final bool showPoints;
  final bool fadeImage;

  _TracedPathPainter({
    required this.svgPathData,
    required this.sourceImage,
    required this.showPath,
    required this.showPoints,
    required this.fadeImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw faded source image
    if (sourceImage != null) {
      canvas.saveLayer(
        Rect.largest,
        Paint()..color = Colors.white.withAlpha(fadeImage ? 76 : 255),
      );
      canvas.drawImage(sourceImage!, Offset.zero, Paint());
      canvas.restore();
    }

    // Parse and draw SVG path
    try {
      final path = parseSvgPathData(svgPathData);
      
      if (showPath) {
        canvas.drawPath(path, Paint()
          ..color = AppTheme.botanicalPrimary.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill);
        // Stroke outline
        canvas.drawPath(path, Paint()
          ..color = AppTheme.botanicalPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      }

      if (showPoints) {
        final regex = RegExp(r'[ML]\s+([0-9.]+)\s+([0-9.]+)');
        final matches = regex.allMatches(svgPathData);
        final pointPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;
        
        for (final match in matches) {
          final x = double.tryParse(match.group(1)!) ?? 0;
          final y = double.tryParse(match.group(2)!) ?? 0;
          canvas.drawCircle(Offset(x, y), 2.0, pointPaint);
        }
      }
    } catch (e) {
      // If parsing fails, show error in preview
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Invalid SVG path',
          style: TextStyle(
            color: AppTheme.errorColor,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2,
            (size.height - textPainter.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TracedPathPainter oldDelegate) {
    return oldDelegate.svgPathData != svgPathData ||
        oldDelegate.sourceImage != sourceImage ||
        oldDelegate.showPath != showPath ||
        oldDelegate.showPoints != showPoints ||
        oldDelegate.fadeImage != fadeImage;
  }
}