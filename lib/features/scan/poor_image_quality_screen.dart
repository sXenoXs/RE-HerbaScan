import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/features/browse/browse_screen.dart';

class PoorImageQualityScreen extends StatelessWidget {
  final String imagePath;
  final String? reason;

  const PoorImageQualityScreen({
    super.key,
    required this.imagePath,
    this.reason,
  });

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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Blurred background image
          if (imagePath.isNotEmpty)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: AppTheme.darkScaffold),
              ),
            )
          else
            Container(color: AppTheme.darkScaffold),

          // 2. Dark scrim
          Container(color: Colors.black.withOpacity(0.45)),

          // 3. Glassmorphic center card
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon with warning style
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.warningAmber.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            size: 40,
                            color: AppTheme.warningAmber,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Title
                        Text(
                          'Image Too Unclear',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 10),

                        // Description
                        Text(
                          reason ?? "Couldn't get a clear look. Try better lighting or wipe your lens.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.80),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 28),

                        // Retake button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: const Text('Retake Photo'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.botanicalPrimary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Browse catalog button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const BrowseScreen(),
                                ),
                                (route) => route.isFirst,
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Browse Catalog'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
