import 'package:flutter/material.dart';
import 'package:herbascan/core/theme/app_theme.dart';

/// Shared botanical header used across auth screens.
/// Shows a leaf icon or optional image in a circular container, a bold title,
/// and a subtitle.
class BotanicalAuthHeader extends StatelessWidget {
  const BotanicalAuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.eco_rounded,
    this.imageAsset,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          child: imageAsset != null
              ? Image.asset(
                  imageAsset!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(icon, size: 40, color: AppTheme.botanicalPrimary),
                )
              : Icon(icon, size: 40, color: AppTheme.botanicalPrimary),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
      ],
    );
  }
}
