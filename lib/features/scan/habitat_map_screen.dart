import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_habitat.dart';
import 'package:herbascan/core/services/error_logger.dart';
import 'package:herbascan/core/services/habitat_service.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/theme/app_theme.dart';

/// Static Habitat Heatmap screen: shows known regions/coordinates where the plant thrives.
/// Data from assets/data/plant_habitats.json; no third-party location API.
/// Redesigned: edge-to-edge map, floating controls, DraggableScrollableSheet, custom green markers.
class HabitatMapScreen extends StatefulWidget {
  final Plant plant;

  const HabitatMapScreen({
    super.key,
    required this.plant,
  });

  @override
  State<HabitatMapScreen> createState() => _HabitatMapScreenState();
}

class _HabitatMapScreenState extends State<HabitatMapScreen> {
  final HabitatService _habitatService = HabitatService();
  final MapController _mapController = MapController();
  static const LatLng _philippinesCenter = LatLng(12.8797, 121.7740);

  PlantHabitat? _habitat;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHabitat();
  }

  Future<void> _loadHabitat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final plantId = widget.plant.id;
    if (kDebugMode) {
      debugPrint('[HabitatMapScreen] Loading habitat for plantId="$plantId"');
    }
    try {
      final habitat = await _habitatService.getHabitatByPlantId(plantId);
      if (mounted) {
        setState(() {
          _habitat = habitat;
          _loading = false;
          if (habitat == null || !habitat.hasCoordinates) {
            _error = 'noHabitatData';
          }
        });
        if (kDebugMode) {
          debugPrint(
            '[HabitatMapScreen] Loaded: habitat=${habitat != null}, '
            'hasCoordinates=${habitat?.hasCoordinates ?? false}, '
            'regionNames=${habitat?.regionNames.length ?? 0}, '
            'climateNotes=${habitat?.climateNotes.isEmpty ?? true ? "empty" : "set"}',
          );
        }
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[HabitatMapScreen] Load error: $e\n$stack');
      }
      await ErrorLogger().logError(
        ErrorType.unknownError,
        'HabitatMapScreen: failed to load habitat for plant "$plantId"',
        stackTrace: stack.toString(),
        context: {'plantId': plantId, 'error': e.toString()},
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'loadError';
        });
      }
    }
  }

  void _zoomIn() {
    final current = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, current + 1);
  }

  void _zoomOut() {
    final current = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, current - 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: _loading
          ? _buildLoadingView()
          : _error != null && (_habitat == null || !_habitat!.hasCoordinates)
              ? _buildNoDataView(context, l10n)
              : _buildEdgeToEdgeMapView(context, l10n),
    );
  }

  Widget _buildLoadingView() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildNoDataView(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  _error == 'loadError'
                      ? l10n.habitatLoadError
                      : l10n.noHabitatData,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (_error != 'loadError') ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.noHabitatDataSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Floating back button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _GlassmorphicPill(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEdgeToEdgeMapView(BuildContext context, AppLocalizations l10n) {
    if (_habitat == null || !_habitat!.hasCoordinates) {
      return const SizedBox.shrink();
    }

    final points = _habitat!.knownCoordinates;
    final latLngs = points.map((p) => LatLng(p.lat, p.lng)).toList();

    final markers = latLngs.asMap().entries.map((entry) {
      final i = entry.key;
      final ll = entry.value;
      final label = _habitat!.regionNames.length > i
          ? _habitat!.regionNames[i]
          : '${ll.latitude.toStringAsFixed(2)}, ${ll.longitude.toStringAsFixed(2)}';
      return Marker(
        point: ll,
        width: 44,
        height: 44,
        child: Tooltip(
          message: label,
          child: _GreenPlantMarker(),
        ),
      );
    }).toList();

    final hasInfo = _habitat!.regionNames.isNotEmpty ||
        _habitat!.climateNotes.isNotEmpty;

    return Stack(
      children: [
        // Edge-to-edge map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _philippinesCenter,
            initialZoom: 5.5,
            minZoom: 4,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.herbascan',
            ),
            MarkerLayer(markers: markers),
          ],
        ),

        // Floating back button — top-left
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _GlassmorphicPill(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),

        // Floating zoom controls — right mid-screen
        Positioned(
          right: 12,
          top: 0,
          bottom: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GlassmorphicPill(
                  onTap: _zoomIn,
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                _GlassmorphicPill(
                  onTap: _zoomOut,
                  child: const Icon(
                    Icons.remove_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),

        // DraggableScrollableSheet — plant habitat info panel
        if (hasInfo)
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.15,
            maxChildSize: 0.7,
            builder: (context, scrollController) {
              return _HabitatInfoSheet(
                plant: widget.plant,
                habitat: _habitat!,
                l10n: l10n,
                scrollController: scrollController,
              );
            },
          ),
      ],
    );
  }
}

/// Custom green plant marker with eco icon and shadow.
class _GreenPlantMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.botanicalPrimary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.botanicalPrimary.withOpacity(0.45),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.eco_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

/// Glassmorphic floating pill button.
class _GlassmorphicPill extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _GlassmorphicPill({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The draggable bottom sheet showing habitat info.
class _HabitatInfoSheet extends StatelessWidget {
  final Plant plant;
  final PlantHabitat habitat;
  final AppLocalizations l10n;
  final ScrollController scrollController;

  const _HabitatInfoSheet({
    required this.plant,
    required this.habitat,
    required this.l10n,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          // Grabber pill
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Where to find ${plant.commonName}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Climate description (icon prefix)
          if (habitat.climateNotes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.wb_sunny_outlined,
                    size: 18,
                    color: AppTheme.warningAmber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      habitat.climateNotes,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Regions horizontal scroll chips
          if (habitat.regionNames.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppTheme.botanicalPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.knownHabitatRegions,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.botanicalPrimary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: habitat.regionNames.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return Chip(
                    label: Text(
                      habitat.regionNames[index],
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: AppTheme.safeBgLight,
                    side: BorderSide(
                      color: AppTheme.botanicalPrimary.withOpacity(0.25),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Bottom safe area padding
          SafeArea(top: false, child: const SizedBox(height: 8)),
        ],
      ),
    );
  }
}
