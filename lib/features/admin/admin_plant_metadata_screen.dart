import 'package:flutter/material.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_metadata_override.dart';
import 'package:herbascan/core/services/catalog_plant_admin_service.dart';
import 'package:herbascan/core/services/plant_data_service.dart';
import 'package:herbascan/core/services/plant_metadata_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/plant_image.dart';
import 'package:herbascan/features/admin/admin_plant_catalog_editor_screen.dart';

/// Plant Catalog: list of fixed plants with search, edit, factory reset via overflow menu.
class AdminPlantMetadataScreen extends StatefulWidget {
  const AdminPlantMetadataScreen({super.key});

  @override
  State<AdminPlantMetadataScreen> createState() =>
      _AdminPlantMetadataScreenState();
}

class _AdminPlantMetadataScreenState extends State<AdminPlantMetadataScreen> {
  List<Plant> _plants = [];
  List<Plant> _filtered = [];
  Map<String, PlantMetadataOverride> _overrides = {};
  bool _loading = true;
  bool _resetting = false;
  String? _error;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_plants);
      } else {
        _filtered = _plants
            .where((p) =>
                p.commonName.toLowerCase().contains(q) ||
                p.scientificName.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plants = PlantDataService.getAllMedicinalPlantsData();
      final overrides = await PlantMetadataService().getOverrides();
      if (mounted) {
        setState(() {
          _plants = plants;
          _filtered = List.from(plants);
          _overrides = overrides;
          _loading = false;
        });
        _applyFilter();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _openEditor(Plant plant) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => AdminPlantCatalogEditorScreen(
          plant: plant,
          onSaved: () {
            _load();
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  Future<void> _factoryReset() async {
    final theme = Theme.of(context);
    final confirmController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Factory Reset Database?'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Restore the entire Supabase catalog to bundled defaults. '
                        'This will overwrite all 42 plants, safety, habitat, and conditions. '
                        'Uploaded plant images in Storage will be removed.',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Type RESET to confirm:',
                        style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: confirmController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'RESET',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          if (ctx.mounted) setDialogState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: confirmController.text.trim().toUpperCase() == 'RESET'
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error),
                  child: const Text('Factory Reset'),
                ),
              ],
            );
          },
        );
      },
    );

    // Defer disposal by two frames so the dialog route is fully torn down before we dispose.
    // Fixes _dependents.isEmpty when tapping Cancel (TextField still dependent in single-frame defer).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        confirmController.dispose();
      });
    });

    if (confirm != true || !mounted) return;

    setState(() => _resetting = true);
    final ok = await CatalogPlantAdminService()
        .factoryResetCatalog(clearPlantCatalogStorage: true);
    if (mounted) {
      setState(() => _resetting = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Catalog reset to defaults. Sync the app to load new data.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Factory reset failed. Check connection and try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Text(
                'Plant Catalog',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _resetting ? null : _load,
                tooltip: 'Refresh',
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) {
                  if (action == 'factory_reset') _factoryReset();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'factory_reset',
                    child: Row(children: [
                      Icon(Icons.restart_alt, color: theme.colorScheme.error),
                      const SizedBox(width: 12),
                      Text('⚠️ Factory Reset Database',
                          style: TextStyle(color: theme.colorScheme.error)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search ${_plants.length} plants by name',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        if (_resetting)
          const LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppTheme.botanicalPrimary)),
        if (_filtered.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No plants match your search.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
              itemBuilder: (context, index) {
                final plant = _filtered[index];
                final hasOverride = _overrides.containsKey(plant.id);
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: PlantImage(plant: plant, fit: BoxFit.cover),
                    ),
                  ),
                  title: Text(plant.commonName,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(plant.scientificName,
                      style: const TextStyle(
                          fontStyle: FontStyle.italic, fontSize: 12)),
                  trailing: hasOverride
                      ? const Icon(Icons.edit_rounded,
                          color: AppTheme.botanicalPrimary, size: 18)
                      : Icon(Icons.edit_outlined,
                          color: Colors.grey.shade400, size: 18),
                  onTap: () => _openEditor(plant),
                );
              },
            ),
          ),
      ],
    );
  }
}
