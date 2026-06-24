import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

import 'package:herbascan/core/widgets/responsive_layout.dart';
import 'package:herbascan/core/constants/toxic_plant_blacklist.dart';
import 'package:herbascan/core/providers/camera_provider.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/contraindication_engine_widget.dart';
import 'package:herbascan/features/scan/no_match_found_screen.dart';
import 'package:herbascan/features/scan/plant_result_screen.dart';
import 'package:herbascan/features/scan/poor_image_quality_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  double _baseZoomLevel = 1.0;
  Timer? _zoomUpdateTimer;
  double? _pendingZoomLevel;
  bool _isCameraReady = false;
  CameraProvider? _cameraProvider;

  // Reticle pulse animation
  late AnimationController _reticleController;
  late Animation<Color?> _reticleColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraProvider = Provider.of<CameraProvider>(context, listen: false);

    _reticleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _reticleColor = ColorTween(
      begin: Colors.white,
      end: AppTheme.botanicalPrimary,
    ).animate(CurvedAnimation(
      parent: _reticleController,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCameraAndModels();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      setState(() => _isCameraReady = false);
      // Release flashlight when app goes to background so quick-settings torch works (e.g. Samsung).
      if (_cameraProvider != null &&
          _cameraProvider!.cameraController != null &&
          _cameraProvider!.cameraController!.value.isInitialized) {
        _cameraProvider!.setFlashMode(FlashMode.off);
      }
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraAndModels();
    }
  }

  Future<void> _initializeCameraAndModels() async {
    if (!mounted) return;
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
    try {
      await cameraProvider.initializeClassifier();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Failed to initialize AI models: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zoomUpdateTimer?.cancel();
    _reticleController.dispose();
    // Release flashlight so system no longer shows "light is being used by HerbaScan" (e.g. Samsung).
    if (_cameraProvider != null &&
        _cameraProvider!.cameraController != null &&
        _cameraProvider!.cameraController!.value.isInitialized) {
      _cameraProvider!.setFlashMode(FlashMode.off);
    }
    super.dispose();
  }

  void _updateZoomLevel(CameraProvider cameraProvider, double zoomLevel) {
    _pendingZoomLevel = zoomLevel;
    _zoomUpdateTimer?.cancel();
    cameraProvider.setZoomLevel(zoomLevel);
    _zoomUpdateTimer = Timer(const Duration(milliseconds: 30), () {
      if (_pendingZoomLevel != null &&
          (_pendingZoomLevel! - cameraProvider.currentZoomLevel).abs() > 0.01) {
        cameraProvider.setZoomLevel(_pendingZoomLevel!);
      }
      _pendingZoomLevel = null;
      _zoomUpdateTimer = null;
    });
  }

  bool _isNoMatchOrUnknown(List<Map<String, dynamic>> predictions) {
    if (predictions.isEmpty) return true;
    final top = predictions.first;
    final confidence = (top['confidence'] as num?)?.toDouble() ?? 0.0;
    return _isUnknownLabel(top) || confidence < kLowConfidenceThreshold;
  }

  /// True when the top prediction's label itself signals "not a known plant"
  /// (UnknownPlant / Not_Plant / empty), independent of confidence.
  /// Used to distinguish "Low Confidence Match" (real guess, low score) from
  /// "No Plant Match Found" (model explicitly said unknown).
  bool _isUnknownLabel(Map<String, dynamic> top) {
    final label = (top['plantName'] as String? ?? top['label'] as String? ?? '')
        .toLowerCase()
        .trim();
    final normalized = label.replaceAll(RegExp(r'[_\s]'), '');
    return normalized.isEmpty ||
        normalized == 'unknown' ||
        normalized == 'unknownplant' ||
        normalized == 'notplant';
  }

  Future<void> _captureImage() async {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
    try {
      final XFile? image = await cameraProvider.captureImage();
      if (image != null && mounted) {
        if (cameraProvider.cameraController != null &&
            cameraProvider.cameraController!.value.isInitialized) {
          await cameraProvider.cameraController?.pausePreview();
        }
        final File imageFile = File(image.path);
        final Uint8List imageBytes = await imageFile.readAsBytes();
        final result =
            await cameraProvider.processPlantIdentificationWithGradCAM(imageBytes);
        if (!mounted) return;

        // Stage 1 (blur/dark) → PoorImageQualityScreen
        // Stage 2 (OOD)       → NoMatchFoundScreen
        if (result['validation_failed'] == true) {
          final stage = result['stage'] as int? ?? 2;
          if (stage == 1) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PoorImageQualityScreen(
                  imagePath: image.path,
                  reason: result['failure_reason'] as String?,
                ),
              ),
            );
          } else {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NoMatchFoundScreen(imagePath: image.path),
              ),
            );
          }
          if (mounted && cameraProvider.cameraController != null) {
            await cameraProvider.cameraController?.resumePreview();
          }
          return;
        }

        final predictions =
            result['predictions'] as List<Map<String, dynamic>>? ?? [];
        if (predictions.isNotEmpty) {
          if (isTopPredictionBlacklisted(predictions)) {
            if (!mounted) return;
            final topLabel = predictions.first['plantName'] as String? ??
                predictions.first['label'] as String?;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NoMatchFoundScreen(
                  imagePath: image.path,
                  isToxicPlant: true,
                  detectedToxicPlantName: toxicPlantDisplayName(topLabel),
                ),
              ),
            );
          } else if (_isNoMatchOrUnknown(predictions)) {
            if (!mounted) return;
            final unknownLabel =
                predictions.isEmpty ? true : _isUnknownLabel(predictions.first);
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NoMatchFoundScreen(
                  imagePath: image.path,
                  lookalikePredictions: predictions,
                  isLowConfidence: !unknownLabel,
                ),
              ),
            );
          } else {
            if (!mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PlantResultScreen(
                  predictions: predictions,
                  imagePath: image.path,
                  gradcamImageBytes: result['gradcam_image'] as Uint8List?,
                  method: result['method'] as String? ?? 'cam',
                  fallbackUsed: result['fallback_used'] as bool? ?? true,
                  gradCAMPath: result['gradCAMPath'] as String?,
                  summaryGradCAMPath: result['summaryGradCAMPath'] as String?,
                ),
              ),
            );
          }
          if (mounted && cameraProvider.cameraController != null) {
            await cameraProvider.cameraController?.resumePreview();
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No plant detected.')),
          );
          if (mounted && cameraProvider.cameraController != null) {
            await cameraProvider.cameraController?.resumePreview();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [ScanScreen] Capture Error: $e');
      if (mounted) {
        final cameraProvider =
            Provider.of<CameraProvider>(context, listen: false);
        if (cameraProvider.cameraController != null) {
          await cameraProvider.cameraController?.resumePreview();
        }
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
    try {
      final XFile? image = await cameraProvider.pickImageFromGallery();
      if (image != null && mounted) {
        final File imageFile = File(image.path);
        final Uint8List imageBytes = await imageFile.readAsBytes();
        final result =
            await cameraProvider.processPlantIdentificationWithGradCAM(imageBytes);
        if (!mounted) return;

        // Stage 1 (blur/dark) → PoorImageQualityScreen
        // Stage 2 (OOD)       → NoMatchFoundScreen
        if (result['validation_failed'] == true) {
          final stage = result['stage'] as int? ?? 2;
          if (stage == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PoorImageQualityScreen(
                  imagePath: image.path,
                  reason: result['failure_reason'] as String?,
                ),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NoMatchFoundScreen(imagePath: image.path),
              ),
            );
          }
          return;
        }

        final predictions =
            result['predictions'] as List<Map<String, dynamic>>? ?? [];
        if (predictions.isNotEmpty) {
          if (isTopPredictionBlacklisted(predictions)) {
            if (!mounted) return;
            final topLabel = predictions.first['plantName'] as String? ??
                predictions.first['label'] as String?;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NoMatchFoundScreen(
                  imagePath: image.path,
                  isToxicPlant: true,
                  detectedToxicPlantName: toxicPlantDisplayName(topLabel),
                ),
              ),
            );
          } else if (_isNoMatchOrUnknown(predictions)) {
            if (!mounted) return;
            final unknownLabel =
                predictions.isEmpty ? true : _isUnknownLabel(predictions.first);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NoMatchFoundScreen(
                  imagePath: image.path,
                  lookalikePredictions: predictions,
                  isLowConfidence: !unknownLabel,
                ),
              ),
            );
          } else {
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PlantResultScreen(
                  predictions: predictions,
                  imagePath: image.path,
                  gradcamImageBytes: result['gradcam_image'] as Uint8List?,
                  method: result['method'] as String? ?? 'cam',
                  fallbackUsed: result['fallback_used'] as bool? ?? true,
                  gradCAMPath: result['gradCAMPath'] as String?,
                  summaryGradCAMPath: result['summaryGradCAMPath'] as String?,
                ),
              ),
            );
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to identify plant.')),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [ScanScreen] Gallery Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _toggleFlash(CameraProvider cameraProvider) {
    if (cameraProvider.cameraController == null ||
        !cameraProvider.isInitialized) {
      return;
    }
    final newMode = cameraProvider.currentFlashMode == FlashMode.off
        ? FlashMode.always
        : FlashMode.off;
    cameraProvider.setFlashMode(newMode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Consumer<CameraProvider>(
        builder: (context, cameraProvider, child) {
          if (cameraProvider.isWindowsDesktop) {
            return _buildDesktopView(context, theme, cameraProvider);
          }
          if (cameraProvider.hasError) {
            return _buildErrorState(context, theme, cameraProvider);
          }
          final controller = cameraProvider.cameraController;
          if (!_isCameraReady ||
              !cameraProvider.isInitialized ||
              controller == null ||
              !controller.value.isInitialized) {
            return _buildLoadingState(context, theme);
          }
          return _buildCameraView(context, theme, cameraProvider);
        },
      ),
    );
  }

  Widget _buildDesktopView(
      BuildContext context, ThemeData theme, CameraProvider cameraProvider) {
    final padding = MediaQuery.of(context).padding;
    final isProcessing =
        cameraProvider.isCapturing || cameraProvider.isClassifying;
    final hasImage = cameraProvider.lastCapturedImageData != null;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Background image preview
          if (hasImage)
            Positioned.fill(
              child: Image.memory(
                cameraProvider.lastCapturedImageData!,
                fit: BoxFit.contain,
              ),
            ),

          // Dimming overlay
          if (!hasImage)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: AppTheme.botanicalPrimary,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Select a plant image to identify',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Camera is not available on Windows desktop',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),

          // Processing overlay
          if (isProcessing)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.botanicalPrimary),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Analyzing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top bar: close button
          Positioned(
            top: padding.top + 12,
            left: 16,
            child: _GlassPill(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),

          // Bottom bar: browse button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: padding.bottom + 20,
                top: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.75),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: FilledButton.icon(
                      onPressed: isProcessing ? null : _pickFromGallery,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: Text(
                          hasImage ? 'Choose Different Image' : 'Browse Image'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.botanicalPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, ThemeData theme) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.botanicalPrimary),
            ),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, ThemeData theme, CameraProvider cameraProvider) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text(
                'Camera Error',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                cameraProvider.errorMessage ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  cameraProvider.clearError();
                  _initializeCameraAndModels();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraView(
      BuildContext context, ThemeData theme, CameraProvider cameraProvider) {
    final padding = MediaQuery.of(context).padding;

    final cameraStack = Stack(
      fit: StackFit.expand,
      children: [
        // 1. Full-screen camera preview
        CameraPreview(cameraProvider.cameraController!),

        // 2. Gesture layer for focus/zoom
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (TapUpDetails details) {
              final RenderBox? box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final offset = Offset(
                  details.localPosition.dx / box.size.width,
                  details.localPosition.dy / box.size.height,
                );
                cameraProvider.setFocusPoint(offset);
              }
            },
            onScaleStart: (details) {
              _zoomUpdateTimer?.cancel();
              _baseZoomLevel = cameraProvider.currentZoomLevel;
            },
            onScaleUpdate: (details) {
              final newZoom = _baseZoomLevel * details.scale;
              final clamped = newZoom.clamp(
                cameraProvider.minZoomLevel,
                cameraProvider.maxZoomLevel,
              );
              cameraProvider.setZoomLevel(clamped);
            },
            onScaleEnd: (_) {
              _baseZoomLevel = cameraProvider.currentZoomLevel;
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        // 3. Corner bracket reticle (center of screen)
        Center(
          child: AnimatedBuilder(
            animation: _reticleColor,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(220, 220),
                painter: _CornerBracketPainter(
                  color: (cameraProvider.isCapturing ||
                          cameraProvider.isClassifying)
                      ? _reticleColor.value ?? Colors.white
                      : Colors.white,
                  bracketLength: 32,
                  strokeWidth: 3,
                ),
              );
            },
          ),
        ),

        // 4. Processing indicator overlay
        if (cameraProvider.isCapturing || cameraProvider.isClassifying)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.botanicalPrimary),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Analyzing...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 5. Top controls: close (left) + flash (right)
        Positioned(
          top: padding.top + 12,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close button (glassmorphic pill)
              _GlassPill(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),

              // Flash toggle (glassmorphic pill)
              _GlassPill(
                onTap: () => _toggleFlash(cameraProvider),
                child: Icon(
                  cameraProvider.currentFlashMode == FlashMode.off
                      ? Icons.flash_off_rounded
                      : Icons.flash_on_rounded,
                  color: cameraProvider.currentFlashMode == FlashMode.off
                      ? Colors.white
                      : AppTheme.warningAmber,
                  size: 20,
                ),
              ),
            ],
          ),
        ),

        // 6. Bottom control deck (thumb-zone)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: padding.bottom + 20,
              top: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.75),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom quick-tap pills — only show levels the hardware supports
                if (cameraProvider.maxZoomLevel > 1.0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 0.5× only shown when device supports sub-1× zoom
                        if (cameraProvider.minZoomLevel < 0.9) ...[
                          _ZoomPill(
                            label: '0.5×',
                            active: cameraProvider.currentZoomLevel < 0.8,
                            onTap: () => _updateZoomLevel(
                                cameraProvider, cameraProvider.minZoomLevel),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _ZoomPill(
                          label: '1×',
                          active: cameraProvider.currentZoomLevel >= 0.8 &&
                              cameraProvider.currentZoomLevel < 1.6,
                          onTap: () => _updateZoomLevel(cameraProvider, 1.0),
                        ),
                        const SizedBox(width: 8),
                        _ZoomPill(
                          label: '2×',
                          active: cameraProvider.currentZoomLevel >= 1.6,
                          onTap: () => _updateZoomLevel(
                            cameraProvider,
                            2.0.clamp(cameraProvider.minZoomLevel,
                                cameraProvider.maxZoomLevel),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main control row: Gallery | Capture | Tips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Gallery picker
                    _GlassPill(
                      onTap: (cameraProvider.isCapturing ||
                              cameraProvider.isClassifying)
                          ? null
                          : _pickFromGallery,
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.photo_library_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),

                    // Capture button
                    GestureDetector(
                      onTap: (cameraProvider.isCapturing ||
                              cameraProvider.isClassifying)
                          ? null
                          : _captureImage,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer white ring
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                            ),
                          ),
                          // Inner green filled circle
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.botanicalPrimary,
                            ),
                            child: (cameraProvider.isCapturing ||
                                    cameraProvider.isClassifying)
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                          ),
                        ],
                      ),
                    ),

                    // Tips button
                    _GlassPill(
                      onTap: _showScanningTips,
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.tips_and_updates_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return cameraStack;
  }

  void _showScanningTips() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ScanTipsSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Corner Bracket Reticle Painter
// ---------------------------------------------------------------------------
class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final double bracketLength;
  final double strokeWidth;

  const _CornerBracketPainter({
    required this.color,
    required this.bracketLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;
    final double b = bracketLength;

    // Top-left
    canvas.drawPath(
        Path()
          ..moveTo(0, b)
          ..lineTo(0, 0)
          ..lineTo(b, 0),
        paint);
    // Top-right
    canvas.drawPath(
        Path()
          ..moveTo(w - b, 0)
          ..lineTo(w, 0)
          ..lineTo(w, b),
        paint);
    // Bottom-left
    canvas.drawPath(
        Path()
          ..moveTo(0, h - b)
          ..lineTo(0, h)
          ..lineTo(b, h),
        paint);
    // Bottom-right
    canvas.drawPath(
        Path()
          ..moveTo(w - b, h)
          ..lineTo(w, h)
          ..lineTo(w, h - b),
        paint);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bracketLength != bracketLength ||
      oldDelegate.strokeWidth != strokeWidth;
}

// ---------------------------------------------------------------------------
// Glassmorphic pill button
// ---------------------------------------------------------------------------
class _GlassPill extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassPill({
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(10),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(100),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zoom quick-tap pill
// ---------------------------------------------------------------------------
class _ZoomPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ZoomPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.botanicalPrimary
              : Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active ? AppTheme.botanicalPrimary : Colors.white30,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tips bottom sheet — horizontal carousel of 3 tip cards
// ---------------------------------------------------------------------------
class _ScanTipsSheet extends StatelessWidget {
  const _ScanTipsSheet();

  static const _tips = [
    (
      icon: Icons.wb_sunny_rounded,
      title: 'Good Lighting',
      body: 'Use natural daylight. Avoid harsh shadows.',
    ),
    (
      icon: Icons.filter_center_focus_rounded,
      title: 'Single Leaf',
      body: 'Frame one healthy leaf clearly in the reticle.',
    ),
    (
      icon: Icons.eco_rounded,
      title: 'Clean Subject',
      body: 'Choose an undamaged leaf on a plain background.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          color: theme.colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grab handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.botanicalPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tips_and_updates_rounded,
                          color: AppTheme.botanicalPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Scanning Tips',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Horizontal tip cards carousel
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemCount: _tips.length,
                    itemBuilder: (context, index) {
                      final tip = _tips[index];
                      return _TipCard(
                        icon: tip.icon,
                        title: tip.title,
                        body: tip.body,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Got it button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it!'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _TipCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.safeBgLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.botanicalPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.botanicalPrimary, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.botanicalPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
