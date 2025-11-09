import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'package:herbascan/core/providers/camera_provider.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/features/scan/plant_result_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize camera and AI models
    _initializeCameraAndModels();
    // Resume camera preview if it was paused
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeCamera();
    });
  }

  void _resumeCamera() {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
    if (cameraProvider.cameraController != null &&
        cameraProvider.cameraController!.value.isInitialized) {
      cameraProvider.cameraController!.resumePreview();
    }
  }

  Future<void> _initializeCameraAndModels() async {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);

    // Initialize the classifier first
    try {
      await cameraProvider.initializeClassifier();
    } catch (e) {
      print('Failed to initialize AI models: $e');
    }
  }

  @override
  void dispose() {
    // Pause camera when leaving scan screen to prevent buffer warnings
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
    if (cameraProvider.cameraController != null &&
        cameraProvider.cameraController!.value.isInitialized) {
      cameraProvider.cameraController!.pausePreview();
    }
    super.dispose();
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

          if (!cameraProvider.isInitialized) {
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

  Widget _buildErrorState(
      BuildContext context, ThemeData theme, CameraProvider cameraProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Camera Error',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              cameraProvider.errorMessage ?? 'Unknown error occurred',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                cameraProvider.clearError();
                // Camera will reinitialize automatically
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView(
      BuildContext context, ThemeData theme, CameraProvider cameraProvider) {
    return Stack(
      children: [
        // Camera Preview with tap-to-focus
        Positioned.fill(
          child: GestureDetector(
            onTapUp: (TapUpDetails details) {
              final offset = Offset(
                details.localPosition.dx / context.size!.width,
                details.localPosition.dy / context.size!.height,
              );
              cameraProvider.setFocusPoint(offset);
            },
            child: CameraPreview(cameraProvider.cameraController!),
          ),
        ),

        // Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
            ),
            child: Column(
              children: [
                // Top Controls
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Flash Toggle
                      GestureDetector(
                        onTap: () => _toggleFlash(cameraProvider),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
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

                      // Scanning Tips Button
                      GestureDetector(
                        onTap: _showScanningTips,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Colors.white,
                                size: 20,
                              ),
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

                      // Gallery Button
                      GestureDetector(
                        onTap: _pickFromGallery,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.photo_library,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Center - Scanning Area
                Expanded(
                  child: Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(125),
                      ),
                      child: Stack(
                        children: [
                          // Scanning Animation
                          if (cameraProvider.isCapturing ||
                              cameraProvider.isClassifying)
                            const Center(
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
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
                  child: Column(
                    children: [
                      // Zoom slider
                      if (cameraProvider.maxZoomLevel > 1.0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Row(
                            children: [
                              const Icon(Icons.remove,
                                  color: Colors.white, size: 20),
                              Expanded(
                                child: Slider(
                                  value: cameraProvider.currentZoomLevel,
                                  min: cameraProvider.minZoomLevel,
                                  max: cameraProvider.maxZoomLevel,
                                  onChanged: (value) {
                                    cameraProvider.setZoomLevel(value);
                                  },
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              const Icon(Icons.add,
                                  color: Colors.white, size: 20),
                            ],
                          ),
                        ),
                      if (cameraProvider.maxZoomLevel > 1.0)
                        const SizedBox(height: 16),

                      // Instructions
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cameraProvider.isClassifying
                              ? 'Analyzing plant...'
                              : AppLocalizations.of(context).positionPlant,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Capture Button
                      GestureDetector(
                        onTap: (cameraProvider.isCapturing ||
                                cameraProvider.isClassifying)
                            ? null
                            : _captureImage,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                          ),
                          child: (cameraProvider.isCapturing ||
                                  cameraProvider.isClassifying)
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: Colors.black,
                                  size: 32,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Flash toggle functionality
  void _toggleFlash(CameraProvider cameraProvider) {
    final currentMode = cameraProvider.currentFlashMode;
    FlashMode newMode;

    switch (currentMode) {
      case FlashMode.off:
        newMode = FlashMode.always;
        break;
      case FlashMode.always:
        newMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        newMode = FlashMode.off;
        break;
      default:
        newMode = FlashMode.off;
    }

    cameraProvider.setFlashMode(newMode);
  }

  // Gallery image selection with GradCAM
  Future<void> _pickFromGallery() async {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
    final offlineProvider =
        Provider.of<OfflineProvider>(context, listen: false);
    final image = await cameraProvider.pickImageFromGallery();

    if (image != null) {
      try {
        // Process image with AI and GradCAM
        final result =
            await cameraProvider.processPlantIdentificationWithGradCAM(
          cameraProvider.lastCapturedImageData!,
          offlineProvider: offlineProvider,
        );

        if (!mounted) return;

        // Safely convert List<dynamic> to List<Map<String, dynamic>>
        List<Map<String, dynamic>> predictions = [];
        if (result['predictions'] != null) {
          final rawPredictions = result['predictions'];
          if (rawPredictions is List) {
            predictions = rawPredictions
                .map((item) => item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item))
                .toList()
                .cast<Map<String, dynamic>>();
          }
        }
        final gradcamImageBytes = result['gradcam_image'] as Uint8List?;
        final method = result['method'] as String?;
        final fallbackUsed = result['fallback_used'] as bool?;
        // Legacy support
        final gradCAMPath = result['gradCAMPath'] as String?;
        final summaryGradCAMPath = result['summaryGradCAMPath'] as String?;
        
        // Enhanced logging for debugging
        print('🔍 [ScanScreen] Navigating to PlantResultScreen:');
        print('   ════════════════════════════════════════════════════════');
        print('   Method: "$method"');
        print('   Fallback used: $fallbackUsed');
        print('   Heatmap bytes present: ${gradcamImageBytes != null}');
        if (gradcamImageBytes != null) {
          print('   Heatmap size: ${gradcamImageBytes.length} bytes');
        } else {
          print('   ⚠️ WARNING: No heatmap bytes passed to PlantResultScreen!');
        }
        print('   Predictions count: ${predictions.length}');
        if (predictions.isNotEmpty) {
          print('   Top prediction: ${predictions.first['plantName']}');
        }
        print('   ════════════════════════════════════════════════════════');
        print('   ✅ Will show tabs if: fallback=$fallbackUsed OR method="$method"');
        print('   ✅ Expected: ${(fallbackUsed == true || (method != null && method != 'classification_only')) ? "SHOW TABS" : "NO TABS"}');

        if (predictions.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlantResultScreen(
                predictions: predictions,
                imagePath: image.path,
                gradcamImageBytes: gradcamImageBytes, // New format
                method: method, // Should be 'cam' when offline
                fallbackUsed: fallbackUsed, // Should be true when offline
                gradCAMPath: gradCAMPath, // Legacy support
                summaryGradCAMPath: summaryGradCAMPath, // Legacy support
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to identify plant. Please try again.'),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Updated method with AI classification and GradCAM
  Future<void> _captureImage() async {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
    final offlineProvider =
        Provider.of<OfflineProvider>(context, listen: false);
    final image = await cameraProvider.captureImage();

    if (image != null) {
      try {
        // Process image with AI and GradCAM
        final result =
            await cameraProvider.processPlantIdentificationWithGradCAM(
          cameraProvider.lastCapturedImageData!,
          offlineProvider: offlineProvider,
        );

        if (!mounted) return;

        // Safely convert List<dynamic> to List<Map<String, dynamic>>
        List<Map<String, dynamic>> predictions = [];
        if (result['predictions'] != null) {
          final rawPredictions = result['predictions'];
          if (rawPredictions is List) {
            predictions = rawPredictions
                .map((item) => item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item))
                .toList()
                .cast<Map<String, dynamic>>();
          }
        }
        final gradcamImageBytes = result['gradcam_image'] as Uint8List?;
        final method = result['method'] as String?;
        final fallbackUsed = result['fallback_used'] as bool?;
        // Legacy support
        final gradCAMPath = result['gradCAMPath'] as String?;
        final summaryGradCAMPath = result['summaryGradCAMPath'] as String?;

        if (predictions.isNotEmpty) {
          // Navigate to results screen with predictions and GradCAM
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlantResultScreen(
                predictions: predictions,
                imagePath: image.path,
                gradcamImageBytes: gradcamImageBytes, // New format
                method: method,
                fallbackUsed: fallbackUsed,
                gradCAMPath: gradCAMPath, // Legacy support
                summaryGradCAMPath: summaryGradCAMPath, // Legacy support
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to identify plant. Please try again.'),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.lightbulb,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appLocalizations.scanningTipsTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Get the best scanning results',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
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

                  // Tips List
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        _buildTipCard(
                          appLocalizations.useBrightLight,
                          'Natural daylight works best. Avoid direct sunlight which can cause glare.',
                          Icons.wb_sunny,
                          theme.colorScheme.primary,
                          theme,
                        ),
                        _buildTipCard(
                          appLocalizations.holdSteady,
                          'Keep your device stable to prevent blurry images. Use both hands.',
                          Icons.pan_tool,
                          theme.colorScheme.secondary,
                          theme,
                        ),
                        _buildTipCard(
                          appLocalizations.cleanLeaf,
                          'Choose a healthy, mature leaf without damage or disease.',
                          Icons.eco,
                          Colors.green,
                          theme,
                        ),
                        _buildTipCard(
                          appLocalizations.singleLeafFocus,
                          'Frame a single leaf in the center. Avoid multiple leaves.',
                          Icons.center_focus_strong,
                          Colors.orange,
                          theme,
                        ),
                        _buildTipCard(
                          appLocalizations.fillFrame,
                          'Fill most of the frame with the leaf for better AI recognition.',
                          Icons.crop_free,
                          Colors.purple,
                          theme,
                        ),
                        _buildTipCard(
                          appLocalizations.plainBackground,
                          'Use a plain, contrasting background (white paper works well).',
                          Icons.image,
                          Colors.teal,
                          theme,
                        ),

                        const SizedBox(height: 16),

                        // Got it button
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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

  Widget _buildTipCard(String title, String description, IconData icon,
      Color color, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
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
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
