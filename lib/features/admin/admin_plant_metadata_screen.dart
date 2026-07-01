import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:herbascan/core/models/cloud_scan.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_metadata_override.dart';
import 'package:herbascan/core/services/catalog_plant_admin_service.dart';
import 'package:herbascan/core/services/database_service.dart';
import 'package:herbascan/core/services/plant_data_service.dart';
import 'package:herbascan/core/services/plant_metadata_service.dart';
import 'package:herbascan/core/services/herbarium_service.dart';
import 'package:herbascan/core/services/training_dataset_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/plant_image.dart';
import 'package:herbascan/features/admin/admin_new_plant_wizard.dart';
import 'package:herbascan/features/admin/admin_plant_catalog_editor_screen.dart';
import 'package:herbascan/features/admin/widgets/training_images_sheet.dart';
import 'package:herbascan/features/admin/widgets/trigger_training_widget.dart';

/// Plant Catalog: searchable, filterable list of all plants with status badges.
///
/// Status badge rules:
///   Active — plant is visible to end-users
///   Draft  — admin-only, not yet published
///
/// Filter chips: All | Active | Draft | Needs Images (training_image_count == 0)
class AdminPlantMetadataScreen extends StatefulWidget {
  const AdminPlantMetadataScreen({super.key});

  @override
  State<AdminPlantMetadataScreen> createState() =>
      _AdminPlantMetadataScreenState();
}

class _AdminPlantMetadataScreenState extends State<AdminPlantMetadataScreen> {
  // Local (bundled) plants — always available
  List<Plant> _localPlants = [];
  // Cloud summary rows — has status / training_image_count
  List<CatalogPlantEntry> _cloudEntries = [];
  // Map cloud entries by plant id for quick look-up
  Map<String, CatalogPlantEntry> _cloudById = {};
  // Metadata overrides (description, safety_warnings, preparation_steps_json)
  Map<String, PlantMetadataOverride> _overrides = {};
  // Combined list: local plants + wizard-created (cloud-only) plant stubs
  List<Plant> _allPlants = [];

  bool _loading = true;
  bool _resetting = false;
  String? _error;

  final TextEditingController _searchController = TextEditingController();

  // Filter state
  String _statusFilter = 'all'; // 'all' | 'active' | 'draft'
  bool _needsImagesFilter = false;

  List<Plant> _filtered = [];

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

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plants = PlantDataService.getAllMedicinalPlantsData();
      final overrides = await PlantMetadataService().getOverrides();
      // Fetch cloud summaries (may fail gracefully if Supabase unavailable)
      final cloudEntries =
          await CatalogPlantAdminService().listCatalogPlantsWithStatus();

      if (mounted) {
        // Build stubs for plants created via wizard that are only in Supabase.
        final localIds = {for (final p in plants) p.id};
        final cloudOnlyStubs = cloudEntries
            .where((e) => !localIds.contains(e.id))
            .map(_plantStubFromEntry)
            .toList();

        setState(() {
          _localPlants = plants;
          _overrides = overrides;
          _cloudEntries = cloudEntries;
          _cloudById = {for (final e in cloudEntries) e.id: e};
          _allPlants = [...plants, ...cloudOnlyStubs];
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

  /// Converts a cloud-only [CatalogPlantEntry] into a minimal [Plant] stub so
  /// it can be displayed and edited in the catalog exactly like a local plant.
  Plant _plantStubFromEntry(CatalogPlantEntry e) {
    return Plant(
      id: e.id,
      commonName: e.commonName,
      scientificName: e.scientificName,
      localName: '',
      englishName: '',
      family: '',
      genus: '',
      species: '',
      isDOHApproved: false,
      morphology: '',
      ecology: '',
      habitat: '',
      medicinalUses: const [],
      preparationMethods: const [],
      safetyWarnings: const [],
      references: const [],
      imagePath: '',
      imageUrl: e.imageUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _allPlants.where((p) {
        // Search
        final matchSearch = q.isEmpty ||
            p.commonName.toLowerCase().contains(q) ||
            p.scientificName.toLowerCase().contains(q);

        // Status filter
        final entry = _cloudById[p.id];
        final status = entry?.status ?? 'active';
        final matchStatus = _statusFilter == 'all' || status == _statusFilter;

        // Needs images filter
        final trainingCount = entry?.trainingImageCount ?? 0;
        final matchImages = !_needsImagesFilter || trainingCount == 0;

        return matchSearch && matchStatus && matchImages;
      }).toList();
    });
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

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

  void _openNewPlantWizard() {
    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(builder: (_) => const AdminNewPlantWizard()),
    )
        .then((created) {
      if (created == true) _load();
    });
  }

  Future<void> _toggleStatus(Plant plant) async {
    final entry = _cloudById[plant.id];
    final current = entry?.status ?? 'active';
    final next = current == 'active' ? 'draft' : 'active';
    final label = next == 'active' ? 'Publish' : 'Unpublish';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label "${plant.commonName}"?'),
        content: Text(next == 'active'
            ? 'This plant will become visible to all users.'
            : 'This plant will be hidden from users and saved as a Draft.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(label)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final ok =
        await CatalogPlantAdminService().updatePlantStatus(plant.id, next);
    if (mounted) {
      if (ok) {
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status update failed.')),
        );
      }
    }
  }

  Future<void> _openTrainingImages(Plant plant) async {
    final slug = _cloudById[plant.id]?.plantSlug ?? plant.id;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TrainingImagesSheet(
        plantName: plant.commonName,
        plantSlug: slug,
        onUploaded: (count) {
          // Update the training_image_count in Supabase after upload
          CatalogPlantAdminService().updateTrainingImageCount(plant.id, count);
          _load();
        },
      ),
    );
  }

  Future<void> _deletePlant(Plant plant) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Plant?'),
        content: Text(
          'This will permanently delete "${plant.commonName}" from Supabase and your local database. '
          'Connected users will see the plant disappear immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _resetting = true);
    final ok = await CatalogPlantAdminService().deletePlant(plant.id);
    if (ok) {
      try {
        await DatabaseService().deletePlantFromLocal(plant.id);
      } catch (e) {
        debugPrint('[AdminPlantMetadata] Local delete failed: $e');
      }
    }
    if (mounted) {
      setState(() => _resetting = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${plant.commonName}" removed.')),
        );
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not remove plant. Check your connection and try again.')),
        );
      }
    }
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
                      Text(
                        'Restore the entire Supabase catalog to bundled defaults. '
                        'This will overwrite all ${PlantDataService.getAllMedicinalPlantsData().length} plants, safety, habitat, and conditions. '
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
                  onPressed:
                      confirmController.text.trim().toUpperCase() == 'RESET'
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
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Factory reset failed. Check connection and try again.')),
        );
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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
        // ── Toolbar ─────────────────────────────────────────────────────
        Container(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
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
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: AppTheme.botanicalPrimary,
                tooltip: 'Add New Plant',
                onPressed: _resetting ? null : _openNewPlantWizard,
              ),
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

        // ── Search bar ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search ${_allPlants.length} plants by name',
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

        // ── Filter chips ─────────────────────────────────────────────────
        _FilterBar(
          statusFilter: _statusFilter,
          needsImagesFilter: _needsImagesFilter,
          onStatusChanged: (v) {
            setState(() => _statusFilter = v);
            _applyFilter();
          },
          onNeedsImagesChanged: (v) {
            setState(() => _needsImagesFilter = v);
            _applyFilter();
          },
        ),

        if (_resetting)
          const LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppTheme.botanicalPrimary)),

        // ── List ─────────────────────────────────────────────────────────
        if (_filtered.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No plants match the current filters.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
              itemBuilder: (context, index) {
                final plant = _filtered[index];
                final cloudEntry = _cloudById[plant.id];
                final status = cloudEntry?.status ?? 'active';
                final trainingCount = cloudEntry?.trainingImageCount ?? 0;
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
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          plant.commonName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _StatusBadge(status: status),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.scientificName,
                        style: const TextStyle(
                            fontStyle: FontStyle.italic, fontSize: 12),
                      ),
                      if (trainingCount > 0)
                        Text(
                          '$trainingCount training images',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.botanicalPrimary
                                  .withValues(alpha: 0.8)),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded,
                        color: Colors.grey.shade400),
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          _openEditor(plant);
                        case 'training_images':
                          _openTrainingImages(plant);
                        case 'toggle_status':
                          _toggleStatus(plant);
                        case 'delete':
                          _deletePlant(plant);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_rounded, size: 18),
                          SizedBox(width: 12),
                          Text('Edit Catalog Data'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'training_images',
                        child: Row(children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              size: 18, color: const Color(0xFF6366F1)),
                          const SizedBox(width: 12),
                          Text(
                            'Training Images',
                            style: TextStyle(color: const Color(0xFF6366F1)),
                          ),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'toggle_status',
                        child: Row(children: [
                          Icon(
                            status == 'active'
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: status == 'active'
                                ? AppTheme.warningAmber
                                : AppTheme.botanicalPrimary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            status == 'active'
                                ? 'Unpublish (→ Draft)'
                                : 'Publish (→ Active)',
                            style: TextStyle(
                              color: status == 'active'
                                  ? AppTheme.warningAmber
                                  : AppTheme.botanicalPrimary,
                            ),
                          ),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_forever_rounded,
                              size: 18, color: Theme.of(ctx).colorScheme.error),
                          const SizedBox(width: 12),
                          Text(
                            'Remove Plant',
                            style: TextStyle(
                                color: Theme.of(ctx).colorScheme.error),
                          ),
                        ]),
                      ),
                    ],
                  ),
                  onTap: () => _openEditor(plant),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.statusFilter,
    required this.needsImagesFilter,
    required this.onStatusChanged,
    required this.onNeedsImagesChanged,
  });

  final String statusFilter;
  final bool needsImagesFilter;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool> onNeedsImagesChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Status filters
          _FilterChip(
            label: 'All',
            selected: statusFilter == 'all',
            onTap: () => onStatusChanged('all'),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Active',
            selected: statusFilter == 'active',
            selectedColor: AppTheme.botanicalPrimary,
            onTap: () => onStatusChanged('active'),
            icon: Icons.visibility_rounded,
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Draft',
            selected: statusFilter == 'draft',
            selectedColor: AppTheme.warningAmber,
            onTap: () => onStatusChanged('draft'),
            icon: Icons.pending_actions_rounded,
          ),
          const SizedBox(width: 12),
          const VerticalDivider(
              width: 1, thickness: 1, indent: 4, endIndent: 4),
          const SizedBox(width: 12),
          // Image count filter
          _FilterChip(
            label: 'Needs Images',
            selected: needsImagesFilter,
            selectedColor: const Color(0xFF6366F1),
            onTap: () => onNeedsImagesChanged(!needsImagesFilter),
            icon: Icons.add_photo_alternate_rounded,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = AppTheme.botanicalPrimary,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? selectedColor.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected
                      ? selectedColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? selectedColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isDraft = status == 'draft';
    final color = isDraft ? AppTheme.warningAmber : AppTheme.botanicalPrimary;
    final label = isDraft ? 'Draft' : 'Active';
    final icon =
        isDraft ? Icons.pending_actions_rounded : Icons.visibility_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
