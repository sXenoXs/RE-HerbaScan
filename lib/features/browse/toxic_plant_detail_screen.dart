import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:herbascan/core/models/toxic_plant_entry.dart';
import 'package:herbascan/core/theme/app_theme.dart';

class ToxicPlantDetailScreen extends StatefulWidget {
  final ToxicPlantEntry plant;
  final Widget Function(ToxicPlantEntry, Color) imageBuilder;

  const ToxicPlantDetailScreen({
    super.key,
    required this.plant,
    required this.imageBuilder,
  });

  @override
  State<ToxicPlantDetailScreen> createState() =>
      _ToxicPlantDetailScreenState();
}

class _ToxicPlantDetailScreenState extends State<ToxicPlantDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  static const double _expandedHeight = 300;
  static const double _collapsedHeight = kToolbarHeight;
  double _collapseRatio = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final maxScroll = _expandedHeight - _collapsedHeight;
    final ratio = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
    if ((ratio - _collapseRatio).abs() > 0.01) {
      setState(() => _collapseRatio = ratio);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Color get _harmColor {
    final h = widget.plant.harm.toLowerCase();
    if (h.contains('heavy') || h.contains('poison') || h.contains('toxic')) {
      return Colors.red.shade700;
    }
    if (h.contains('mild') || h.contains('irritant') || h.contains('blister') || h.contains('allerg')) {
      return Colors.orange.shade700;
    }
    return Colors.orange.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plant = widget.plant;
    final accent = _harmColor;

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: _expandedHeight,
              pinned: true,
              forceElevated: innerBoxIsScrolled,
              backgroundColor: theme.colorScheme.surface,
              title: Opacity(
                opacity: _collapseRatio,
                child: Text(
                  plant.commonName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.imageBuilder(plant, accent),

                    // Bottom gradient for legibility
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: [0.0, 0.55],
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                    ),

                    // Plant name — bottom-left
                    Positioned(
                      left: 16,
                      right: 120,
                      bottom: 20,
                      child: Text(
                        plant.commonName,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 6,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Harm badge — glassmorphic pill bottom-right
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  plant.harm,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            // Scientific name + local name
            Text(
              plant.scientificName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppTheme.textSecondary,
              ),
            ),
            if (plant.localName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Local name: ${plant.localName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: 20),

            _InfoSection(
              icon: Icons.visibility_outlined,
              color: accent,
              title: 'Appearance',
              body: plant.appearance,
              theme: theme,
            ),
            const SizedBox(height: 16),

            _InfoSection(
              icon: Icons.terrain_rounded,
              color: accent,
              title: 'Habitat',
              body: plant.habitat,
              theme: theme,
            ),
            const SizedBox(height: 16),

            _InfoSection(
              icon: Icons.science_rounded,
              color: accent,
              title: 'Toxin',
              body: plant.toxin,
              theme: theme,
            ),
            const SizedBox(height: 16),

            _InfoSection(
              icon: Icons.sick_rounded,
              color: accent,
              title: 'Symptoms',
              body: plant.symptoms,
              theme: theme,
            ),
            const SizedBox(height: 24),

            // Safety notice
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.25), width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.health_and_safety_rounded,
                      color: accent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'If ingestion or contact is suspected, seek medical attention immediately.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final ThemeData theme;

  const _InfoSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
