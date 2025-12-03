import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

import 'package:herbascan/core/providers/camera_provider.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/features/scan/plant_result_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  double _baseZoomLevel = 1.0;
  Timer? _zoomUpdateTimer;
  double? _pendingZoomLevel;
  bool _isCameraReady = false; // Local flag to prevent red screen

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCameraAndModels();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);

    // App entered background: Dispose camera to release resources
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      setState(() {
        _isCameraReady = false; // Stop rendering CameraPreview immediately
      });
      // We don't manually call dispose() here because the Provider might hold onto the instance.
      // Instead, we rely on the re-initialization when resumed.
    }
    // App came to foreground: Re-initialize
    else if (state == AppLifecycleState.resumed) {
      _initializeCameraAndModels();
    }
  }

  Future<void> _initializeCameraAndModels() async {
    if (!mounted) return;
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);

    // Initialize
    try {
      await cameraProvider.initializeClassifier();
      // Wait a moment to ensure controller is actually created in the provider
      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      print('Failed to initialize AI models: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zoomUpdateTimer?.cancel();
    super.dispose();
  }

  // --- LOGIC: Zoom Throttling ---
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

  // --- LOGIC: Capture Image ---
  Future<void> _captureImage() async {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);

    try {
      final XFile? image = await cameraProvider.captureImage();

      if (image != null && mounted) {
        // Pause preview safely
        if (cameraProvider.cameraController != null &&
            cameraProvider.cameraController!.value.isInitialized) {
          await cameraProvider.cameraController?.pausePreview();
        }

        final File imageFile = File(image.path);
        final Uint8List imageBytes = await imageFile.readAsBytes();

        // Process with TFLite
        final predictions = await cameraProvider.processImageForAI(imageBytes);

        if (!mounted) return;

        if (predictions.isNotEmpty) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlantResultScreen(
                predictions: predictions,
                imagePath: image.path,
                gradcamImageBytes: null,
                method: 'tflite_offline',
                fallbackUsed: true,
                gradCAMPath: null,
                summaryGradCAMPath: null,
              ),
            ),
          );
          // Resume safely
          if (mounted && cameraProvider.cameraController != null) {
            await cameraProvider.cameraController?.resumePreview();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No plant detected.')),
          );
          if (mounted && cameraProvider.cameraController != null) {
            await cameraProvider.cameraController?.resumePreview();
          }
        }
      }
    } catch (e) {
      print("Capture Error: $e");
      if (mounted) {
        // Try to resume if something failed
        if (cameraProvider.cameraController != null) {
          await cameraProvider.cameraController?.resumePreview();
        }
      }
    }
  }

  // --- LOGIC: Gallery Picker ---
  Future<void> _pickFromGallery() async {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);

    try {
      final XFile? image = await cameraProvider.pickImageFromGallery();

      if (image != null && mounted) {
        final File imageFile = File(image.path);
        final Uint8List imageBytes = await imageFile.readAsBytes();

        final predictions = await cameraProvider.processImageForAI(imageBytes);

        if (!mounted) return;

        if (predictions.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlantResultScreen(
                predictions: predictions,
                imagePath: image.path,
                gradcamImageBytes: null,
                method: 'tflite_offline',
                fallbackUsed: true,
                gradCAMPath: null,
                summaryGradCAMPath: null,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to identify plant.')),
          );
        }
      }
    } catch (e) {
      print("Gallery Error: $e");
    }
  }

  void _toggleFlash(CameraProvider cameraProvider) {
    if (cameraProvider.cameraController == null || !cameraProvider.isInitialized) return;
    final newMode = cameraProvider.currentFlashMode == FlashMode.off ? FlashMode.always : FlashMode.off;
    cameraProvider.setFlashMode(newMode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).scanPlant),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Consumer<CameraProvider>(
        builder: (context, cameraProvider, child) {
          if (cameraProvider.hasError) {
            return _buildErrorState(context, theme, cameraProvider);
          }

          // CRITICAL FIX: The "Red Screen" check.
          // We check our local flag _isCameraReady AND the controller state
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

  Widget _buildLoadingState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Initializing camera...',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ThemeData theme, CameraProvider cameraProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Camera Error', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            Text(cameraProvider.errorMessage ?? 'Unknown error', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                cameraProvider.clearError();
                _initializeCameraAndModels();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView(BuildContext context, ThemeData theme, CameraProvider cameraProvider) {
    return Stack(
      children: [
        // 1. Camera Preview
        Positioned.fill(
          child: CameraPreview(cameraProvider.cameraController!),
        ),

        // 2. Gesture Overlay
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
            onScaleStart: (ScaleStartDetails details) {
              _zoomUpdateTimer?.cancel();
              _zoomUpdateTimer = null;
              _pendingZoomLevel = null;
              _baseZoomLevel = cameraProvider.currentZoomLevel;
            },
            onScaleUpdate: (ScaleUpdateDetails details) {
              final newZoom = _baseZoomLevel * details.scale;
              final clampedZoom = newZoom.clamp(
                cameraProvider.minZoomLevel,
                cameraProvider.maxZoomLevel,
              );
              cameraProvider.setZoomLevel(clampedZoom);
            },
            onScaleEnd: (ScaleEndDetails details) {
              _baseZoomLevel = cameraProvider.currentZoomLevel;
            },
            child: Container(
              color: Colors.transparent,
              child: Column(
                children: [
                  // Top Controls
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black26,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => _toggleFlash(cameraProvider),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              cameraProvider.currentFlashMode == FlashMode.off
                                  ? Icons.flash_off
                                  : Icons.flash_on,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _showScanningTips,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.lightbulb_outline, color: Colors.white, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Tips',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _pickFromGallery,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.photo_library, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Center Area
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(125),
                        ),
                        child: Stack(
                          children: [
                            if (cameraProvider.isCapturing || cameraProvider.isClassifying)
                              const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Controls
                  Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.black45,
                    child: Column(
                      children: [
                        if (cameraProvider.maxZoomLevel > 1.0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              children: [
                                const Icon(Icons.remove, color: Colors.white, size: 20),
                                Expanded(
                                  child: Slider(
                                    value: cameraProvider.currentZoomLevel,
                                    min: cameraProvider.minZoomLevel,
                                    max: cameraProvider.maxZoomLevel,
                                    onChanged: (value) {
                                      _updateZoomLevel(cameraProvider, value);
                                    },
                                    activeColor: Colors.white,
                                    inactiveColor: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                const Icon(Icons.add, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        if (cameraProvider.maxZoomLevel > 1.0)
                          const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cameraProvider.isClassifying
                                ? 'Analyzing plant...'
                                : AppLocalizations.of(context).positionPlant,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 24),

                        GestureDetector(
                          onTap: (cameraProvider.isCapturing || cameraProvider.isClassifying)
                              ? null
                              : _captureImage,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: (cameraProvider.isCapturing || cameraProvider.isClassifying)
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
                                : const Icon(Icons.camera_alt, color: Colors.black, size: 32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Keeping your existing Tips UI
  void _showScanningTips() {
    final theme = Theme.of(context);
    final appLocalizations = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.lightbulb, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appLocalizations.scanningTipsTitle,
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Get the best scanning results',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        _buildTipCard(appLocalizations.useBrightLight, 'Natural daylight works best.', Icons.wb_sunny, theme.colorScheme.primary, theme),
                        _buildTipCard(appLocalizations.holdSteady, 'Keep your device stable.', Icons.pan_tool, theme.colorScheme.secondary, theme),
                        _buildTipCard(appLocalizations.cleanLeaf, 'Choose a healthy leaf.', Icons.eco, Colors.green, theme),
                        _buildTipCard(appLocalizations.singleLeafFocus, 'Frame a single leaf.', Icons.center_focus_strong, Colors.orange, theme),
                        _buildTipCard(appLocalizations.plainBackground, 'Use a plain background.', Icons.image, Colors.teal, theme),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Got it!'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTipCard(String title, String description, IconData icon, Color color, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}