import 'package:flutter/material.dart';
import 'package:herbascan/core/theme/app_theme.dart';

/// Shared botanical header used across auth screens.
/// Shows a leaf icon in a circular container, a bold title, and a subtitle.
class BotanicalAuthHeader extends StatelessWidget {
  const BotanicalAuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.eco_rounded,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.botanicalPrimary.withOpacity(0.10),
          ),
          child: Icon(icon, size: 40, color: AppTheme.botanicalPrimary),
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
