import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_anatomy_part.dart';
import 'package:herbascan/core/services/habitat_service.dart';
import 'package:herbascan/core/models/plant_habitat.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/anatomy_interactive_view.dart';
import 'package:herbascan/core/widgets/contraindication_engine_widget.dart';
import 'package:herbascan/features/scan/habitat_map_screen.dart';
import 'package:herbascan/features/scan/preparation_instructions_screen.dart';
import 'package:herbascan/features/scan/anatomy_full_screen_screen.dart';

class PlantDetailScreen extends StatefulWidget {
  final Plant plant;

  /// If set, the tab at this index (0–3) is selected when the screen opens.
  final int? initialTabIndex;

  const PlantDetailScreen({
    super.key,
    required this.plant,
    this.initialTabIndex,
  });

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  // Collapsed AppBar height (kToolbarHeight = 56)
  static const double _expandedHeight = 320;
  static const double _collapsedHeight = kToolbarHeight;

  /// 0.0 = fully expanded, 1.0 = fully collapsed
  double _collapseRatio = 0.0;

  @override
  void initState() {
    super.initState();
    final index = widget.initialTabIndex;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: (index != null && index >= 0 && index < 4) ? index : 0,
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final maxScroll = _expandedHeight - _collapsedHeight;
    final ratio = (offset / maxScroll).clamp(0.0, 1.0);
    if ((ratio - _collapseRatio).abs() > 0.01) {
      setState(() => _collapseRatio = ratio);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Header image helper
  // ---------------------------------------------------------------------------

  Widget _buildPlantHeaderImage() {
    final plant = widget.plant;
    if (plant.imageUrl != null && plant.imageUrl!.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: plant.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _fallbackGradient(),
        errorWidget: (_, __, ___) => _fallbackGradient(),
      );
    }
    if (plant.imagePath.isNotEmpty) {
      return Image.asset(
        plant.imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackGradient(),
      );
    }
    return _fallbackGradient();
  }

  Widget _fallbackGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.botanicalPrimary, AppTheme.botanicalPrimaryL],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark 
          ? Colors.black 
          : theme.colorScheme.surfaceContainerHighest,
      body: Container(
        color: theme.colorScheme.surface,
        child: NestedScrollView(
          controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // ── Immersive SliverAppBar (320 px expanded) ──────────────────
            SliverAppBar(
              expandedHeight: _expandedHeight,
              pinned: true,
              forceElevated: innerBoxIsScrolled,
              backgroundColor: theme.colorScheme.surface,
              // Title fades in only as the image collapses away
              title: Opacity(
                opacity: _collapseRatio,
                child: Text(
                  widget.plant.commonName,
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
                    // Plant image fills full expanded area
                    _buildPlantHeaderImage(),

                    // Bottom gradient overlay for legibility
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

                    // Common name — bottom-left of expanded image
                    Positioned(
                      left: 16,
                      right: widget.plant.isDOHApproved ? 120 : 16,
                      bottom: 20,
                      child: Text(
                        widget.plant.commonName,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 28,
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

                    // DOH badge — glassmorphic pill top-right
                    if (widget.plant.isDOHApproved)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'DOH Approved',
                                    style: TextStyle(
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

            // ── Quick Facts Card ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Card(
                  elevation: 0,
                  color: theme.cardTheme.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.plant.scientificName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.plant.englishName.isNotEmpty &&
                              widget.plant.englishName !=
                                  widget.plant.commonName) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.plant.englishName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Pinned Tab Bar ───────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  labelStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.science_rounded, size: 20), text: 'Taxonomy'),
                    Tab(icon: Icon(Icons.nature_rounded, size: 20), text: 'Ecology'),
                    Tab(icon: Icon(Icons.medical_services_rounded, size: 20), text: 'Medicinal'),
                    Tab(icon: Icon(Icons.shield_rounded, size: 20), text: 'Safety'),
                  ],
                ),
                theme.colorScheme.surface,
              ),
            ),
          ];
        },

        // Tab content
        body: TabBarView(
          controller: _tabController,
          physics: const ClampingScrollPhysics(),
          children: [
            _buildTaxonomyTab(theme),
            _buildEcologyTab(theme),
            _buildMedicinalTab(theme),
            _buildSafetyTab(theme),
          ],
        ),
      ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Taxonomy Tab — 2x2 micro-card grid + clean morphology text
  // ---------------------------------------------------------------------------

  Widget _buildTaxonomyTab(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _sectionHeader('Scientific Classification', theme),
              const SizedBox(height: 12),
              _buildTaxonomyGrid(theme),
              const SizedBox(height: 24),
              _sectionHeader('Morphology', theme),
              const SizedBox(height: 8),
              _buildTextOrPlaceholder(
                widget.plant.morphology,
                theme,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.65,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildTaxonomyGrid(ThemeData theme) {
    final items = [
      _TaxonomyItem('Kingdom', 'Plantae', Icons.hub_rounded),
      _TaxonomyItem('Family', widget.plant.family, Icons.account_tree_rounded),
      _TaxonomyItem('Genus', widget.plant.genus, Icons.eco_rounded),
      _TaxonomyItem('Species', widget.plant.species, Icons.grass_rounded),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 100,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.botanicalPrimary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: AppTheme.botanicalPrimary, size: 18),
              const SizedBox(height: 6),
              Text(
                item.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.value.isEmpty ? '—' : item.value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontStyle: item.label == 'Genus' || item.label == 'Species'
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Ecology Tab — static mini-map preview + climate/habitat text
  // ---------------------------------------------------------------------------

  Widget _buildEcologyTab(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Habitat mini-map (non-interactive)
              FutureBuilder<bool>(
                future: HabitatService().hasHabitatData(widget.plant.id),
                builder: (context, snapshot) {
                  if (snapshot.data != true) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildMiniMap(theme, l10n),
                  );
                },
              ),

              _sectionHeader('Ecology', theme),
              const SizedBox(height: 8),
              _buildTextOrPlaceholder(
                widget.plant.ecology,
                theme,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
              ),
              const SizedBox(height: 20),

              _sectionHeader('Habitat', theme),
              const SizedBox(height: 8),
              _buildTextOrPlaceholder(
                widget.plant.habitat,
                theme,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMap(ThemeData theme, AppLocalizations l10n) {
    return FutureBuilder<PlantHabitat?>(
      future: HabitatService().getHabitatByPlantId(widget.plant.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final habitat = snapshot.data!;
        final List<LatLng> markers = habitat.knownCoordinates
            .map((c) => LatLng(c.lat, c.lng))
            .toList();

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                child: AbsorbPointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: markers.isNotEmpty
                          ? markers.first
                          : const LatLng(12.8797, 121.7740),
                      initialZoom: 6,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.herbascan',
                      ),
                      MarkerLayer(
                        markers: markers
                            .map(
                              (latlng) => Marker(
                                point: latlng,
                                width: 28,
                                height: 28,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.botanicalPrimary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.eco_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HabitatMapScreen(plant: widget.plant),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: Text(l10n.viewHabitatMap),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Medicinal Tab — static Cards (no accordions), Preparation cards
  // ---------------------------------------------------------------------------

  Widget _buildMedicinalTab(ThemeData theme) {
    final plantProvider = context.read<PlantProvider>();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Interactive anatomy silhouette (single or multi-part carousel)
              FutureBuilder<List<PlantAnatomyPart>>(
                future: plantProvider.getPlantAnatomy(widget.plant.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final parts = snapshot.data!;
                  final l10n = AppLocalizations.of(context);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader(l10n.explorePlantParts, theme),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: parts.length == 1 ? 400 : 464,
                            color: theme.colorScheme.surfaceContainerLow,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: parts.length == 1
                                      ? AnatomyInteractiveView(
                                          parts: parts,
                                          height: 400,
                                          onPartTapped: (part) =>
                                              _showAnatomyPartBottomSheet(
                                                  context, part, theme),
                                        )
                                      : _AnatomyPartCarousel(
                                          parts: parts,
                                          height: 400,
                                          onPartTapped: (part) =>
                                              _showAnatomyPartBottomSheet(
                                                  context, part, theme),
                                          l10n: l10n,
                                        ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.open_in_full_rounded),
                                    color: AppTheme.botanicalPrimary,
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => AnatomyFullScreenScreen(
                                            plant: widget.plant,
                                            parts: parts,
                                            isCarousel: parts.length > 1,
                                          ),
                                        ),
                                      );
                                    },
                                    tooltip: 'Expand to full screen',
                                    style: IconButton.styleFrom(
                                      backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
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
                },
              ),

              // Medicinal Uses — static cards, no accordion
              if (widget.plant.medicinalUses.isNotEmpty) ...[
                _sectionHeader('Medicinal Uses', theme),
                const SizedBox(height: 12),
                ...widget.plant.medicinalUses
                    .map((use) => _buildMedicinalUseCard(theme, use)),
                const SizedBox(height: 20),
              ],

              // Preparation Methods
              if (widget.plant.preparationMethods.isNotEmpty) ...[
                _sectionHeader('Preparation Methods', theme),
                const SizedBox(height: 12),
                ...widget.plant.preparationMethods
                    .map((method) => _buildPreparationMethodCard(theme, method)),
              ],
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicinalUseCard(ThemeData theme, MedicinalUse use) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Condition chip + effectiveness
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.safeBgLight,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  use.condition,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.botanicalPrimary,
                  ),
                ),
              ),
              Text(
                use.effectiveness,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            use.description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
          if (use.activeCompounds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: use.activeCompounds
                  .map(
                    (c) => Chip(
                      label: Text(c),
                      backgroundColor:
                          AppTheme.botanicalPrimary.withOpacity(0.08),
                      labelStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppTheme.botanicalPrimaryD,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (use.dosage.isNotEmpty || use.duration.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (use.dosage.isNotEmpty)
              _infoRow(Icons.medication_rounded, 'Dosage', use.dosage, theme),
            if (use.duration.isNotEmpty)
              _infoRow(Icons.schedule_rounded, 'Duration', use.duration, theme),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(
      IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreparationMethodCard(
      ThemeData theme, PreparationMethod method) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.botanicalPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    method.preparationType.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.botanicalPrimaryD,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              method.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'For ${method.condition}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PreparationInstructionsScreen(
                      plant: widget.plant,
                      preparationMethod: method,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Start Guide'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Safety Tab — disclaimer top, then ContraindicationEngineWidget
  // ---------------------------------------------------------------------------

  Widget _buildSafetyTab(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              ContraindicationEngineWidget(plant: widget.plant),
              const SizedBox(height: 24),
              // ROADMAP B 4.2: Data Sources section
              ExpansionTile(
                leading: const Icon(Icons.menu_book_rounded,
                    color: AppTheme.botanicalPrimary),
                title: Text(
                  'Data Sources',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text('Where this information comes from'),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.plant.isDOHApproved) ...[
                          _DataSourceTile(
                            icon: Icons.verified_rounded,
                            title: 'Department of Health',
                            subtitle:
                                'Administrative Order No. 12, s. 1997 · Republic Act No. 8423 (TAMA, 1997)',
                          ),
                          const SizedBox(height: 12),
                        ],
                        _DataSourceTile(
                          icon: Icons.science_rounded,
                          title: 'PITAHC',
                          subtitle:
                              'Philippine Herbal Pharmacopeia 2022 (PITAHC)',
                        ),
                        const SizedBox(height: 12),
                        _DataSourceTile(
                          icon: Icons.psychology_rounded,
                          title: 'AI Training Dataset',
                          subtitle:
                              'PhilMedic Dataset (Santos et al., 2024) · Roboflow Medicinal Plant Collections',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Anatomy bottom sheet
  // ---------------------------------------------------------------------------

  void _showAnatomyPartBottomSheet(
    BuildContext context,
    PlantAnatomyPart part,
    ThemeData theme,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (ctx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant
                          .withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding:
                          const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Text(
                          part.title.isNotEmpty ? part.title : part.partName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (part.conditions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: part.conditions
                                .map(
                                  (c) => Chip(
                                    label: Text(c),
                                    backgroundColor:
                                        theme.colorScheme.primaryContainer,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (part.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            part.description,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Renders [text] if non-empty; otherwise shows a subtle placeholder so the
  /// UI stays intact while the catalog field is being edited by the admin or
  /// arrives via a Realtime sync event.
  Widget _buildTextOrPlaceholder(
    String text,
    ThemeData theme, {
    TextStyle? style,
  }) {
    if (text.isNotEmpty) {
      return Text(text, style: style);
    }
    return Text(
      'Information not yet available.',
      style: (style ?? theme.textTheme.bodyMedium)?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.38),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _sectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data class for taxonomy grid
// ---------------------------------------------------------------------------

class _TaxonomyItem {
  final String label;
  final String value;
  final IconData icon;
  const _TaxonomyItem(this.label, this.value, this.icon);
}

// ---------------------------------------------------------------------------
// Sliver TabBar delegate
// ---------------------------------------------------------------------------

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

/// ROADMAP B 4.2: One row in the Data Sources expansion (icon + title + subtitle).
class _DataSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DataSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.botanicalPrimary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Multi-part anatomy carousel: one silhouette per part with Next/Previous.
class _AnatomyPartCarousel extends StatefulWidget {
  const _AnatomyPartCarousel({
    required this.parts,
    required this.height,
    required this.onPartTapped,
    required this.l10n,
  });

  final List<PlantAnatomyPart> parts;
  final double height;
  final ValueChanged<PlantAnatomyPart> onPartTapped;
  final AppLocalizations l10n;

  @override
  State<_AnatomyPartCarousel> createState() => _AnatomyPartCarouselState();
}

class _AnatomyPartCarouselState extends State<_AnatomyPartCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final part = widget.parts[_currentPage.clamp(0, widget.parts.length - 1)];
    final label = part.title.isNotEmpty ? part.title : part.partName;
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: widget.parts.length,
            itemBuilder: (context, index) {
              final p = widget.parts[index];
              return AnatomyInteractiveView(
                parts: [p],
                height: widget.height,
                onPartTapped: widget.onPartTapped,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentPage > 0
                  ? () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              tooltip: widget.l10n.previousPart,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentPage < widget.parts.length - 1
                  ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              tooltip: widget.l10n.nextPart,
            ),
          ],
        ),
      ],
    );
  }
}
