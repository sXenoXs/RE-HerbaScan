import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_habitat.dart';
import 'package:herbascan/core/services/error_logger.dart';
import 'package:herbascan/core/services/habitat_service.dart';
import 'package:herbascan/core/localization/app_localizations.dart';

/// Static Habitat Heatmap screen: shows known regions/coordinates where the plant thrives.
/// Data from assets/data/plant_habitats.json; no third-party location API.
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

  /// Uniform border color so BoxDecoration allows borderRadius.
  static Color _borderColor(ThemeData theme) =>
      theme.colorScheme.outline.withValues(alpha: 0.2);

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
              '[HabitatMapScreen] Loaded: habitat=${habitat != null}, hasCoordinates=${habitat?.hasCoordinates ?? false}, regionNames=${habitat?.regionNames.length ?? 0}, climateNotes=${habitat?.climateNotes.isEmpty ?? true ? "empty" : "set"}');
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.viewHabitatMap),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildNoDataView(context, l10n, theme)
              : _buildMapView(context, theme),
      bottomSheet: _habitat != null && _habitat!.hasCoordinates
          ? _buildInfoCard(context, theme, l10n)
          : null,
    );
  }

  Widget _buildNoDataView(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return Center(
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
              _error == 'loadError' ? l10n.habitatLoadError : l10n.noHabitatData,
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
    );
  }

  Widget _buildMapView(BuildContext context, ThemeData theme) {
    if (_habitat == null || !_habitat!.hasCoordinates) return const SizedBox.shrink();

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
        width: 40,
        height: 40,
        child: Tooltip(
          message: label,
          child: Icon(
            Icons.eco,
            color: theme.colorScheme.primary,
            size: 32,
          ),
        ),
      );
    }).toList();

    return FlutterMap(
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
    );
  }

  Widget? _buildInfoCard(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    if (_habitat == null) {
      if (kDebugMode) debugPrint('[HabitatMapScreen] _buildInfoCard: _habitat is null, returning null');
      return null;
    }
    if (kDebugMode) {
      debugPrint(
          '[HabitatMapScreen] _buildInfoCard: regionNames=${_habitat!.regionNames.length}, climateNotes.isEmpty=${_habitat!.climateNotes.isEmpty}');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: _borderColor(theme),
            width: 1,
          ),
          left: BorderSide(
            color: _borderColor(theme),
            width: 1,
          ),
          right: BorderSide(
            color: _borderColor(theme),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_habitat!.regionNames.isNotEmpty) ...[
              Text(
                l10n.knownHabitatRegions,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _habitat!.regionNames
                    .map((name) => Chip(
                          label: Text(name),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ))
                    .toList(),
              ),
              if (_habitat!.climateNotes.isNotEmpty) const SizedBox(height: 16),
            ],
            if (_habitat!.climateNotes.isNotEmpty) ...[
              Text(
                l10n.climateNotes,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  _habitat!.climateNotes,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (_habitat!.regionNames.isEmpty && _habitat!.climateNotes.isEmpty)
              Text(
                l10n.whereItGrows,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
