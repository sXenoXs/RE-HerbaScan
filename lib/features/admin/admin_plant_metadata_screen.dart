import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
          MaterialPageRoute(
              builder: (_) => const AdminNewPlantWizard()),
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
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(label)),
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
      builder: (ctx) => _TrainingImagesSheet(
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
    if (!mounted) return;
    setState(() => _resetting = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${plant.commonName}" removed.')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remove failed. Check connection and try again.')),
      );
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
                      const Text(
                        'Restore the entire Supabase catalog to bundled defaults. '
                        'This will overwrite all 31 plants, safety, habitat, and conditions. '
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
              valueColor:
                  AlwaysStoppedAnimation(AppTheme.botanicalPrimary)),

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
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 68),
              itemBuilder: (context, index) {
                final plant = _filtered[index];
                final cloudEntry = _cloudById[plant.id];
                final status = cloudEntry?.status ?? 'active';
                final trainingCount =
                    cloudEntry?.trainingImageCount ?? 0;
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
                          style: const TextStyle(
                              fontWeight: FontWeight.w500),
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
                                  size: 18,
                                  color: const Color(0xFF6366F1)),
                              const SizedBox(width: 12),
                              Text(
                                'Training Images',
                                style: TextStyle(
                                    color: const Color(0xFF6366F1)),
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
                                  size: 18,
                                  color: Theme.of(ctx).colorScheme.error),
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
// Training Images Upload Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _TrainingImagesSheet extends StatefulWidget {
  const _TrainingImagesSheet({
    required this.plantName,
    required this.plantSlug,
    required this.onUploaded,
  });

  final String plantName;
  final String plantSlug;
  /// Called with the new total image count after a successful upload.
  final void Function(int totalCount) onUploaded;

  @override
  State<_TrainingImagesSheet> createState() => _TrainingImagesSheetState();
}

class _TrainingImagesSheetState extends State<_TrainingImagesSheet> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selected = [];
  bool _uploading = false;
  double _progress = 0.0;
  int _uploadedCount = 0;
  bool _done = false;
  int _existingCount = 0;
  int _approvedScanCount = 0;
  bool _includeApprovedScans = true;
  List<String> _uploadErrors = [];

  @override
  void initState() {
    super.initState();
    _fetchExistingCount();
    _fetchApprovedScanCount();
  }

  Future<void> _fetchExistingCount() async {
    final count =
        await TrainingDatasetService().getImageCount(widget.plantSlug);
    if (mounted) setState(() => _existingCount = count);
  }

  Future<void> _fetchApprovedScanCount() async {
    final scans = await HerbariumService()
        .getTrainingEligibleScans(widget.plantSlug);
    if (mounted) setState(() => _approvedScanCount = scans.length);
  }

  Future<void> _pick() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        _selected = picked;
        _done = false;
        _progress = 0.0;
        _uploadedCount = 0;
        _uploadErrors = [];
      });
    }
  }

  Future<void> _upload() async {
    if (_selected.isEmpty || _uploading) return;
    setState(() {
      _uploading = true;
      _progress = 0.0;
      _uploadedCount = 0;
      _uploadErrors = [];
    });

    final result = await TrainingDatasetService().uploadImages(
      widget.plantSlug,
      _selected,
      onProgress: (p, u, _) {
        if (mounted) setState(() {
          _progress = p;
          _uploadedCount = u;
        });
      },
    );

    if (mounted) {
      final newTotal = _existingCount + result.uploaded;
      setState(() {
        _uploading = false;
        _uploadedCount = result.uploaded;
        _done = result.uploaded > 0;
        _existingCount = newTotal;
        _uploadErrors = result.errors;
      });
      if (result.uploaded > 0) widget.onUploaded(newTotal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const purple = Color(0xFF6366F1);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_photo_alternate_rounded,
                      color: purple, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Training Images',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(
                        widget.plantName,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Current count chip
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$_existingCount images already uploaded',
                  style: const TextStyle(
                      fontSize: 11,
                      color: purple,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── From Approved Scans ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.botanicalPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.botanicalPrimary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.model_training_rounded,
                          size: 16, color: AppTheme.botanicalPrimary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'From Approved Scans',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.botanicalPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.botanicalPrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                '$_approvedScanCount approved scan image${_approvedScanCount == 1 ? '' : 's'} available',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.botanicalPrimary,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Include in next training run',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.75)),
                        ),
                      ),
                      Switch(
                        value: _includeApprovedScans,
                        activeThumbColor: AppTheme.botanicalPrimary,
                        onChanged: (v) =>
                            setState(() => _includeApprovedScans = v),
                      ),
                    ],
                  ),
                  if (!_includeApprovedScans)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Approved scan copies already in training-datasets will still be picked up by the training pipeline.',
                        style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pick button
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pick,
              icon: const Icon(Icons.photo_library_rounded),
              label: Text(_selected.isEmpty
                  ? 'Select Images'
                  : 'Change Selection (${_selected.length} selected)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            // Preview grid
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selected.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => FutureBuilder<Uint8List>(
                    future: _selected[i].readAsBytes(),
                    builder: (_, snap) {
                      if (snap.hasData) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            snap.data!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        );
                      }
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image_outlined),
                      );
                    },
                  ),
                ),
              ),
            ],

            // Upload button
            if (_selected.isNotEmpty && !_done) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(_uploading
                    ? 'Uploading $_uploadedCount / ${_selected.length}…'
                    : 'Upload ${_selected.length} Images'),
                style: FilledButton.styleFrom(
                  backgroundColor: purple,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            // Progress bar
            if (_uploading) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: purple.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(purple),
                borderRadius: BorderRadius.circular(4),
              ),
            ],

            // Success
            if (_done) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.botanicalPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          AppTheme.botanicalPrimary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppTheme.botanicalPrimary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_uploadedCount images uploaded. Total: $_existingCount.',
                        style: const TextStyle(
                            color: AppTheme.botanicalPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Upload errors — shown even on partial success
            if (_uploadErrors.isNotEmpty && !_uploading) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppTheme.errorColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${_uploadErrors.length} upload(s) failed',
                          style: const TextStyle(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Show the first error in full — it usually contains the root cause
                    Text(
                      _uploadErrors.first,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.errorColor),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Common causes:\n'
                      '• The "training-datasets" bucket does not exist in Supabase Storage\n'
                      '• RLS policy does not allow authenticated uploads\n'
                      '• File is too large (Supabase free tier: 50 MB per file)',
                      style: TextStyle(fontSize: 11, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            TriggerTrainingWidget(
              plantSlug: widget.plantSlug,
              newClassName: widget.plantName,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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
          const VerticalDivider(width: 1, thickness: 1, indent: 4, endIndent: 4),
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
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
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
    final color =
        isDraft ? AppTheme.warningAmber : AppTheme.botanicalPrimary;
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
