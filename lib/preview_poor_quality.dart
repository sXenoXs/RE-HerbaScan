import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/features/scan/poor_image_quality_screen.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const PreviewApp(),
    ),
  );
}

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // The following 3 lines are required for DevicePreview
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const PoorImageQualityScreen(
        imagePath: '', // Leaving this empty triggers the fallback background
        reason: 'This is a preview reason: The image is too blurry.',
      ),
    );
  }
}
