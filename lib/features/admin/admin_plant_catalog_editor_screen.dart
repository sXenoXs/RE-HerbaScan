import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_habitat.dart';
import 'package:herbascan/core/models/safety_profile.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/plant_image.dart';
import 'package:herbascan/core/services/catalog_plant_admin_service.dart';
import 'package:herbascan/core/services/catalog_sync_service.dart';
import 'package:herbascan/core/services/database_service.dart';
import 'package:herbascan/core/services/default_anatomy_service.dart';
import 'package:herbascan/core/services/habitat_service.dart';
import 'package:herbascan/core/services/safety_profile_service.dart';
import 'package:herbascan/core/services/plant_data_service.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/features/scan/habitat_map_screen.dart';
import 'package:herbascan/features/admin/image_tracer_dialog.dart';

/// Tabbed admin editor for one plant: Identity & Taxonomy, Ecology, Medicinal, Preparations, Safety.
/// Saves to Supabase catalog_* tables; image upload to Storage.
class AdminPlantCatalogEditorScreen extends StatefulWidget {
  const AdminPlantCatalogEditorScreen({
    super.key,
    required this.plant,
    required this.onSaved,
  });

  final Plant plant;
  final VoidCallback onSaved;

  @override
  State<AdminPlantCatalogEditorScreen> createState() =>
      _AdminPlantCatalogEditorScreenState();
}

class _AdminPlantCatalogEditorScreenState
    extends State<AdminPlantCatalogEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Plant _plant;
  String? _climateNotes;
  bool _saving = false;
  bool _loading = true;

  // Editable safety (catalog_safety)
  bool _isGenerallySafe = true;
  bool _pregnancyWarning = false;
  bool _needsStrictContraindications = false;
  List<String> _knownSideEffects = [];
  List<String> _drugInteractions = [];
  List<String> _strictContraindications = [];

  // Editable habitat (catalog_habitat)
  List<HabitatPoint> _habitatCoordinates = [];
  List<String> _habitatRegionNames = [];
  String _habitatClimateNotes = '';

  // Anatomy (catalog_plant_anatomy) — 6th tab
  List<Map<String, dynamic>> _anatomyList = [];
  Map<String, bool> _anatomyDefaultFlags = {}; // id -> isDefault
  bool _anatomyLoading = true;

  final CatalogPlantAdminService _adminService = CatalogPlantAdminService();
  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _plant = widget.plant;
    _tabController = TabController(length: 6, vsync: this);
    _loadCatalog();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() => _loading = true);
    try {
      final fromCatalog = await _adminService.getCatalogPlant(
        widget.plant.id,
        defaultImagePath: widget.plant.imagePath,
      );
      var safety = await _adminService.getCatalogSafety(widget.plant.id);
      safety ??= await SafetyProfileService().getSafetyProfile(widget.plant);
      var habitat = await _adminService.getCatalogHabitat(widget.plant.id);
      habitat ??= await HabitatService().getHabitat(widget.plant);
      if (mounted) {
        setState(() {
          if (fromCatalog != null) _plant = fromCatalog;
          if (safety != null) {
            _isGenerallySafe = safety.isGenerallySafe;
            _pregnancyWarning = safety.pregnancyWarning;
            _needsStrictContraindications = safety.needsStrictContraindications;
            _knownSideEffects = List.from(safety.knownSideEffects);
            _drugInteractions = List.from(safety.drugInteractions);
            _strictContraindications = List.from(safety.strictContraindications);
          }
          if (habitat != null) {
            _habitatCoordinates = List.from(habitat.knownCoordinates);
            _habitatRegionNames = List.from(habitat.regionNames);
            _habitatClimateNotes = habitat.climateNotes;
          }
        });
      }
    } catch (e) {
      debugPrint('[AdminEditor] _loadCatalog error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    _loadAnatomy();
  }

  Future<void> _loadAnatomy() async {
    setState(() => _anatomyLoading = true);
    final list = await _adminService.getCatalogAnatomyForPlant(_plant.id);
    final flags = <String, bool>{};
    for (var row in list) {
      final id = row['id']?.toString() ?? '';
      final partName = row['part_name'] as String? ?? '';
      flags[id] = await DefaultAnatomyService.isDefault(_plant.id, partName);
    }
    if (mounted) {
      setState(() {
        _anatomyList = list;
        _anatomyDefaultFlags = flags;
        _anatomyLoading = false;
      });
    }
  }

  /// After anatomy Supabase mutation: re-fetch and sync to local SQLite.
  Future<void> _syncAnatomyToLocal() async {
    final rows = await _adminService.getCatalogAnatomyForPlant(_plant.id);
    try {
      final localRows = rows.map((row) {
        final conditionsRaw = row['conditions'];
        String conditionsStr = '[]';
        if (conditionsRaw is List) {
          conditionsStr = jsonEncode(conditionsRaw);
        } else if (conditionsRaw is String && conditionsRaw.isNotEmpty && conditionsRaw != '[]') {
          conditionsStr = conditionsRaw;
        }
        return {
          'id': row['id']?.toString() ?? '',
          'plant_id': row['plant_id'] as String? ?? _plant.id,
          'part_name': row['part_name'] as String? ?? '',
          'svg_path': row['svg_path'] as String? ?? '',
          'color_hex': row['color_hex'] as String? ?? '4CAF50',
          'z_index': row['z_index'] is int ? row['z_index'] as int : int.tryParse(row['z_index'].toString()) ?? 0,
          'is_interactive': (row['is_interactive'] as bool?) ?? true,
          'title': row['title'] as String? ?? '',
          'description': row['description'] as String? ?? '',
          'conditions': conditionsStr,
        };
      }).toList();
      await _db.replaceAnatomyForPlantFromSync(_plant.id, localRows);
    } catch (e) {
      debugPrint('[AdminEditor] Anatomy local sync failed: $e');
    }
    if (mounted) await _loadAnatomy();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    // Build objects once — reused for both Supabase and local SQLite writes
    final safetyProfile = SafetyProfile(
      plantId: _plant.id,
      name: _plant.commonName,
      isGenerallySafe: _isGenerallySafe,
      pregnancyWarning: _pregnancyWarning,
      needsStrictContraindications: _needsStrictContraindications,
      knownSideEffects: _knownSideEffects,
      drugInteractions: _drugInteractions,
      strictContraindications: _strictContraindications,
    );
    final habitat = PlantHabitat(
      plantId: _plant.id,
      knownCoordinates: _habitatCoordinates,
      regionNames: _habitatRegionNames,
      climateNotes: _habitatClimateNotes,
    );

    // 1. Write to Supabase
    var ok = await _adminService.saveCatalogPlant(_plant,
        climateNotes: _climateNotes);
    if (ok) {
      ok = await _adminService.saveCatalogSafety(_plant.id, safetyProfile);
    }
    if (ok) ok = await _adminService.saveCatalogHabitat(_plant.id, habitat);

    // 2. Write to local SQLite immediately — no app restart needed
    if (ok) {
      try {
        await _db.replacePlantFromSync(_plant);
        await _db.replaceSafetyFromSync(safetyProfile);
        await _db.replaceHabitatFromSync(habitat);
        if (mounted) {
          await context.read<PlantProvider>().loadPlants();
        }
      } catch (e) {
        // Non-fatal: Supabase write succeeded; local will sync on next launch
        debugPrint('[AdminEditor] Local sync after save failed: $e');
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved to catalog')));
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Save failed')));
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null || !mounted) return;
    final file = File(xfile.path);
    final url = await _adminService.uploadPlantImage(_plant.id, file);
    if (mounted && url != null) {
      setState(() {
        _plant = Plant(
          id: _plant.id,
          commonName: _plant.commonName,
          scientificName: _plant.scientificName,
          localName: _plant.localName,
          englishName: _plant.englishName,
          family: _plant.family,
          genus: _plant.genus,
          species: _plant.species,
          isDOHApproved: _plant.isDOHApproved,
          morphology: _plant.morphology,
          ecology: _plant.ecology,
          habitat: _plant.habitat,
          medicinalUses: _plant.medicinalUses,
          preparationMethods: _plant.preparationMethods,
          safetyWarnings: _plant.safetyWarnings,
          references: _plant.references,
          imagePath: _plant.imagePath,
          imageUrl: url,
          createdAt: _plant.createdAt,
          updatedAt: DateTime.now(),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Image uploaded. Tap Save to update catalog.')));
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Upload failed')));
    }
  }

  Future<void> _seedFromDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seed catalog from defaults?'),
        content: Text(
          'This will upsert all ${PlantDataService.getAllMedicinalPlantsData().length} plants and default safety, habitat, conditions, and anatomy into Supabase. '
          'Existing catalog data will be overwritten. Anatomy is additive (missing parts only).',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Seed')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    final ok = await _adminService.seedCatalogFromDefaults();
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      await CatalogSyncService().syncFromSupabase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catalog seeded from defaults')));
      await _loadCatalog();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Seed failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.plant.commonName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_plant.commonName),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Identity'),
            Tab(text: 'Ecology'),
            Tab(text: 'Medicinal'),
            Tab(text: 'Preparations'),
            Tab(text: 'Safety'),
            Tab(text: 'Anatomy'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) {
              if (action == 'seed') _seedFromDefaults();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'seed',
                child: Row(children: [
                  Icon(Icons.restore, color: Theme.of(ctx).colorScheme.error),
                  const SizedBox(width: 12),
                  Text('Seed Defaults',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
      // Persistent bottom save button
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                8),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.botanicalPrimary,
            minimumSize: const Size(double.infinity, 48),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save All Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIdentityTab(),
          _buildEcologyTab(),
          _buildMedicinalTab(),
          _buildPreparationsTab(),
          _buildSafetyTab(),
          _buildAnatomyTab(),
        ],
      ),
    );
  }

  // ─── Identity Tab ────────────────────────────────────────────────────────────

  Widget _buildIdentityTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // DOH toggle at top (elevated card) — theme-aware so text is visible in dark mode
          Card(
            elevation: 0,
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHighest
                : (_plant.isDOHApproved
                    ? AppTheme.safeBgLight
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              title: Text(
                'DOH Approved',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Shows verified shield badge and appears in DOH Spotlight',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              value: _plant.isDOHApproved,
              activeThumbColor: AppTheme.botanicalPrimary,
              onChanged: (v) =>
                  setState(() => _plant = _copyWith(isDOHApproved: v)),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PlantImage(plant: _plant, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _pickAndUploadImage,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload image'),
          ),
          const SizedBox(height: 24),
          // Name fields
          _EditableTextField(
            label: 'Common name',
            value: _plant.commonName,
            onChanged: (v) => setState(() => _plant = _copyWith(commonName: v)),
          ),
          _EditableTextField(
            label: 'Scientific name',
            value: _plant.scientificName,
            onChanged: (v) =>
                setState(() => _plant = _copyWith(scientificName: v)),
          ),
          // Grouped row: Family + Genus
          Row(
            children: [
              Expanded(
                child: _EditableTextField(
                  label: 'Family',
                  value: _plant.family,
                  onChanged: (v) =>
                      setState(() => _plant = _copyWith(family: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EditableTextField(
                  label: 'Genus',
                  value: _plant.genus,
                  onChanged: (v) =>
                      setState(() => _plant = _copyWith(genus: v)),
                ),
              ),
            ],
          ),
          // Grouped row: Species + Local Name
          Row(
            children: [
              Expanded(
                child: _EditableTextField(
                  label: 'Species',
                  value: _plant.species,
                  onChanged: (v) =>
                      setState(() => _plant = _copyWith(species: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EditableTextField(
                  label: 'Local name',
                  value: _plant.localName,
                  onChanged: (v) =>
                      setState(() => _plant = _copyWith(localName: v)),
                ),
              ),
            ],
          ),
          _EditableTextField(
            label: 'English name',
            value: _plant.englishName,
            onChanged: (v) =>
                setState(() => _plant = _copyWith(englishName: v)),
          ),
          _EditableTextField(
            label: 'Morphology',
            value: _plant.morphology,
            onChanged: (v) =>
                setState(() => _plant = _copyWith(morphology: v)),
            maxLines: 6,
            minLines: 2,
          ),
          const SizedBox(height: 20),
          Text('References (APA 7th Edition)',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...List.generate(_plant.references.length, (i) {
            return Dismissible(
              key: Key('ref_$i'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete_outline,
                    color: AppTheme.errorColor),
              ),
              onDismissed: (_) {
                setState(() {
                  final list = List<String>.from(_plant.references)..removeAt(i);
                  _plant = _copyWith(references: list);
                });
              },
              child: _RegionNameRowWidget(
                value: _plant.references[i],
                onChanged: (v) {
                  final list = List<String>.from(_plant.references);
                  list[i] = v;
                  setState(() => _plant = _copyWith(references: list));
                },
                onRemove: () {
                  setState(() {
                    final list = List<String>.from(_plant.references)..removeAt(i);
                    _plant = _copyWith(references: list);
                  });
                },
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() {
              final list = List<String>.from(_plant.references)..add('');
              _plant = _copyWith(references: list);
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add reference'),
          ),
        ],
      ),
    );
  }

  Plant _copyWith({
    String? commonName,
    String? scientificName,
    String? localName,
    String? englishName,
    String? family,
    String? genus,
    String? species,
    bool? isDOHApproved,
    String? morphology,
    String? ecology,
    String? habitat,
    List<MedicinalUse>? medicinalUses,
    List<PreparationMethod>? preparationMethods,
    List<String>? references,
  }) {
    return Plant(
      id: _plant.id,
      commonName: commonName ?? _plant.commonName,
      scientificName: scientificName ?? _plant.scientificName,
      localName: localName ?? _plant.localName,
      englishName: englishName ?? _plant.englishName,
      family: family ?? _plant.family,
      genus: genus ?? _plant.genus,
      species: species ?? _plant.species,
      isDOHApproved: isDOHApproved ?? _plant.isDOHApproved,
      morphology: morphology ?? _plant.morphology,
      ecology: ecology ?? _plant.ecology,
      habitat: habitat ?? _plant.habitat,
      medicinalUses: medicinalUses ?? _plant.medicinalUses,
      preparationMethods: preparationMethods ?? _plant.preparationMethods,
      safetyWarnings: _plant.safetyWarnings,
      references: references ?? _plant.references,
      imagePath: _plant.imagePath,
      imageUrl: _plant.imageUrl,
      createdAt: _plant.createdAt,
      updatedAt: _plant.updatedAt,
    );
  }

  // ─── Ecology Tab ─────────────────────────────────────────────────────────────

  Widget _buildEcologyTab() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasHabitatData = _habitatCoordinates.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EditableTextField(
            label: 'Ecology',
            value: _plant.ecology,
            onChanged: (v) =>
                setState(() => _plant = _copyWith(ecology: v)),
            maxLines: 6,
            minLines: 2,
          ),
          _EditableTextField(
            label: 'Habitat',
            value: _plant.habitat,
            onChanged: (v) =>
                setState(() => _plant = _copyWith(habitat: v)),
            maxLines: 6,
            minLines: 2,
          ),
          _EditableTextField(
            label: 'Climate notes (plant)',
            value: _climateNotes ?? '',
            onChanged: (v) => setState(() => _climateNotes = v),
            maxLines: 4,
            minLines: 2,
          ),
          const SizedBox(height: 20),
          Text('Known habitat regions',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Coordinates (lat, lng)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ...List.generate(_habitatCoordinates.length, (i) {
            final pt = _habitatCoordinates[i];
            return Dismissible(
              key: Key('coord_$i'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete_outline,
                    color: AppTheme.errorColor),
              ),
              onDismissed: (_) {
                setState(() {
                  _habitatCoordinates =
                      List<HabitatPoint>.from(_habitatCoordinates)..removeAt(i);
                });
              },
              child: _CoordRowWidget(
                point: pt,
                onChanged: (lat, lng) {
                  final list = List<HabitatPoint>.from(_habitatCoordinates);
                  list[i] = HabitatPoint(lat: lat, lng: lng);
                  setState(() => _habitatCoordinates = list);
                },
                onRemove: () {
                  setState(() {
                    _habitatCoordinates =
                        List<HabitatPoint>.from(_habitatCoordinates)
                          ..removeAt(i);
                  });
                },
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _habitatCoordinates =
                List<HabitatPoint>.from(_habitatCoordinates)
                  ..add(const HabitatPoint(lat: 14.6, lng: 121.0))),
            icon: const Icon(Icons.add),
            label: const Text('Add coordinate'),
          ),
          const SizedBox(height: 12),
          Text('Region names',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ...List.generate(_habitatRegionNames.length, (i) {
            return Dismissible(
              key: Key('region_$i'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete_outline,
                    color: AppTheme.errorColor),
              ),
              onDismissed: (_) {
                setState(() => _habitatRegionNames =
                    List<String>.from(_habitatRegionNames)..removeAt(i));
              },
              child: _RegionNameRowWidget(
                value: _habitatRegionNames[i],
                onChanged: (v) {
                  final list = List<String>.from(_habitatRegionNames);
                  list[i] = v;
                  setState(() => _habitatRegionNames = list);
                },
                onRemove: () {
                  setState(() => _habitatRegionNames =
                      List<String>.from(_habitatRegionNames)..removeAt(i));
                },
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _habitatRegionNames =
                List<String>.from(_habitatRegionNames)..add('')),
            icon: const Icon(Icons.add),
            label: const Text('Add region'),
          ),
          const SizedBox(height: 12),
          _EditableTextField(
            label: 'Habitat climate notes',
            value: _habitatClimateNotes,
            onChanged: (v) => setState(() => _habitatClimateNotes = v),
            maxLines: 4,
            minLines: 2,
          ),
          if (hasHabitatData) ...[
            const SizedBox(height: 16),
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => HabitatMapScreen(plant: _plant),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.whereItGrows,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Medicinal Tab ───────────────────────────────────────────────────────────

  Widget _buildMedicinalTab() {
    final theme = Theme.of(context);
    final uses = _plant.medicinalUses;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Medicinal uses (${uses.length})',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  final added = await _openMedicinalUseEditor(null);
                  if (added != null && mounted) {
                    setState(() {
                      _plant = _copyWith(
                          medicinalUses: List<MedicinalUse>.from(uses)
                            ..add(added));
                    });
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add use'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(uses.length, (i) {
            final use = uses[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                    use.condition.isEmpty ? '(No condition)' : use.condition,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: use.effectiveness.isNotEmpty
                    ? Text(use.effectiveness,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant))
                    : null,
                trailing: TextButton(
                  onPressed: () async {
                    final updated = await _openMedicinalUseEditor(use);
                    if (updated != null && mounted) {
                      setState(() {
                        final list = List<MedicinalUse>.from(uses)
                          ..[i] = updated;
                        _plant = _copyWith(medicinalUses: list);
                      });
                    }
                  },
                  child: const Text('Edit'),
                ),
                onLongPress: () {
                  setState(() {
                    final list = List<MedicinalUse>.from(uses)..removeAt(i);
                    _plant = _copyWith(medicinalUses: list);
                  });
                },
              ),
            );
          }),
          if (uses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No medicinal uses added yet.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            ),
        ],
      ),
    );
  }

  Future<MedicinalUse?> _openMedicinalUseEditor(MedicinalUse? initial) async {
    return Navigator.of(context).push<MedicinalUse>(
      MaterialPageRoute(
        builder: (ctx) => _EditMedicinalUseScreen(initial: initial),
        fullscreenDialog: true,
      ),
    );
  }

  // ─── Preparations Tab ────────────────────────────────────────────────────────

  Widget _buildPreparationsTab() {
    final theme = Theme.of(context);
    final methods = _plant.preparationMethods;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Preparation methods (${methods.length})',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  final added = await _openPreparationEditor(null);
                  if (added != null && mounted) {
                    setState(() {
                      _plant = _copyWith(
                          preparationMethods:
                              List<PreparationMethod>.from(methods)
                                ..add(added));
                    });
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add method'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(methods.length, (i) {
            final method = methods[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(method.title.isEmpty ? '(No title)' : method.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: method.condition.isNotEmpty
                    ? Text('For: ${method.condition}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant))
                    : null,
                trailing: TextButton(
                  onPressed: () async {
                    final updated = await _openPreparationEditor(method);
                    if (updated != null && mounted) {
                      setState(() {
                        final list = List<PreparationMethod>.from(methods)
                          ..[i] = updated;
                        _plant = _copyWith(preparationMethods: list);
                      });
                    }
                  },
                  child: const Text('Edit'),
                ),
                onLongPress: () {
                  setState(() {
                    final list = List<PreparationMethod>.from(methods)
                      ..removeAt(i);
                    _plant = _copyWith(preparationMethods: list);
                  });
                },
              ),
            );
          }),
          if (methods.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No preparation methods added yet.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            ),
        ],
      ),
    );
  }

  Future<PreparationMethod?> _openPreparationEditor(
      PreparationMethod? initial) async {
    return Navigator.of(context).push<PreparationMethod>(
      MaterialPageRoute(
        builder: (ctx) => _EditPreparationMethodScreen(
          initial: initial,
          plantId: _plant.id,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  // ─── Safety Tab ──────────────────────────────────────────────────────────────

  Widget _buildSafetyTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            title: const Text('Generally safe for consumption'),
            value: _isGenerallySafe,
            onChanged: (v) => setState(() => _isGenerallySafe = v),
            activeThumbColor: AppTheme.botanicalPrimary,
          ),
          SwitchListTile(
            title: const Text('Pregnancy warning'),
            value: _pregnancyWarning,
            onChanged: (v) => setState(() => _pregnancyWarning = v),
            activeThumbColor: AppTheme.errorColor,
          ),
          SwitchListTile(
            title: const Text('Use with strict caution (prominent warning)'),
            subtitle: const Text('Show "Use with strict caution" card at top of safety (e.g. Kamias, Kamoteng Kahoy, Kakawate)'),
            value: _needsStrictContraindications,
            onChanged: (v) => setState(() => _needsStrictContraindications = v),
            activeThumbColor: Colors.orange,
          ),
          const SizedBox(height: 16),
          _buildListSection(
            theme,
            'Known side effects',
            _knownSideEffects,
            (list) => setState(() => _knownSideEffects = list),
            borderColor: AppTheme.warningAmber,
          ),
          _buildListSection(
            theme,
            'Drug interactions',
            _drugInteractions,
            (list) => setState(() => _drugInteractions = list),
            borderColor: Colors.orange,
          ),
          _buildListSection(
            theme,
            'Strict contraindications',
            _strictContraindications,
            (list) => setState(() => _strictContraindications = list),
            borderColor: AppTheme.errorColor,
          ),
        ],
      ),
    );
  }

  // ─── Anatomy Tab (Explore Plant Parts) ────────────────────────────────────────

  Widget _buildAnatomyTab() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (_anatomyLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_anatomyList.isEmpty)
            SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  l10n.adminAnatomyEmpty,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...List.generate(_anatomyList.length, (index) {
              final row = _anatomyList[index];
              final id = row['id']?.toString() ?? '';
              final partName = row['part_name'] as String? ?? '';
              final title = row['title'] as String? ?? partName;
              final isDefault = _anatomyDefaultFlags[id] ?? false;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    title.isNotEmpty ? title : partName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(partName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDefault)
                        IconButton(
                          icon: const Icon(Icons.restore),
                          tooltip: l10n.restoreToDefault,
                          onPressed: () => _restoreAnatomyPart(row),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: l10n.edit,
                        onPressed: () => _openEditAnatomyPart(row),
                      ),
                      if (!isDefault)
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: theme.colorScheme.error),
                          tooltip: l10n.delete,
                          onPressed: () => _deleteAnatomyPart(row),
                        ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _openAddAnatomyPart,
            icon: const Icon(Icons.add),
            label: Text(l10n.adminAnatomyAddPart),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.botanicalPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddAnatomyPart() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _EditAnatomyPartScreen(
          plantId: _plant.id,
          initial: null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final id = await _adminService.insertCatalogAnatomy(result);
    if (id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saveFailed)),
        );
      }
      return;
    }
    await _syncAnatomyToLocal();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).savedToCatalog)),
      );
    }
  }

  Future<void> _openEditAnatomyPart(Map<String, dynamic> row) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _EditAnatomyPartScreen(
          plantId: _plant.id,
          initial: row,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final ok = await _adminService.updateCatalogAnatomy(
      id,
      partName: result['part_name'] as String?,
      svgPath: result['svg_path'] as String?,
      title: result['title'] as String?,
      description: result['description'] as String?,
      conditions: result['conditions'],
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveFailed)),
      );
      return;
    }
    await _syncAnatomyToLocal();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).savedToCatalog)),
    );
  }

  Future<void> _deleteAnatomyPart(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).delete),
        content: Text(
          '${AppLocalizations.of(context).adminAnatomyDeleteConfirm} "${row['title'] ?? row['part_name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final ok = await _adminService.deleteCatalogAnatomy(id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveFailed)),
      );
      return;
    }
    await _syncAnatomyToLocal();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).deleted)),
    );
  }

  Future<void> _restoreAnatomyPart(Map<String, dynamic> row) async {
    final partName = row['part_name'] as String? ?? '';
    final defaultData = await DefaultAnatomyService.getDefaultData(_plant.id, partName);
    if (defaultData == null || !mounted) return;
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final ok = await _adminService.updateCatalogAnatomy(
      id,
      svgPath: defaultData['svg_path'] as String?,
      description: defaultData['description'] as String?,
      conditions: defaultData['conditions'] is List
          ? (defaultData['conditions'] as List).cast<String>()
          : null,
      title: defaultData['title'] as String?,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveFailed)),
      );
      return;
    }
    await _syncAnatomyToLocal();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).restoredToDefault)),
      );
    }
  }

  Widget _buildListSection(ThemeData theme, String title, List<String> items,
      void Function(List<String>) onChanged,
      {Color? borderColor, int listItemMaxLines = 3}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (borderColor != null)
                Container(
                  width: 4,
                  height: 18,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  final list = List<String>.from(items)..add('');
                  onChanged(list);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(items.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _EditableListRow(
                      value: items[i],
                      hintText: 'Item',
                      maxLines: listItemMaxLines,
                      onChanged: (v) {
                        final list = List<String>.from(items);
                        list[i] = v;
                        onChanged(list);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      final list = List<String>.from(items)..removeAt(i);
                      onChanged(list);
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Editable text field (owns controller; for Identity/Ecology long-form fields)
// ═══════════════════════════════════════════════════════════════════════════════

class _EditableTextField extends StatefulWidget {
  const _EditableTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    this.minLines,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final int? minLines;

  @override
  State<_EditableTextField> createState() => _EditableTextFieldState();
}

class _EditableTextFieldState extends State<_EditableTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.selection =
        TextSelection.collapsed(offset: widget.value.length);
  }

  @override
  void didUpdateWidget(_EditableTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection =
          TextSelection.collapsed(offset: widget.value.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(labelText: widget.label),
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        onChanged: widget.onChanged,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Ecology coord / region row widgets (own controllers; no controller in build)
// ═══════════════════════════════════════════════════════════════════════════════

class _CoordRowWidget extends StatefulWidget {
  const _CoordRowWidget({
    required this.point,
    required this.onChanged,
    required this.onRemove,
  });

  final HabitatPoint point;
  final void Function(double lat, double lng) onChanged;
  final VoidCallback onRemove;

  @override
  State<_CoordRowWidget> createState() => _CoordRowWidgetState();
}

class _CoordRowWidgetState extends State<_CoordRowWidget> {
  late TextEditingController _latController;
  late TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(text: widget.point.lat.toString());
    _lngController = TextEditingController(text: widget.point.lng.toString());
    _latController.selection =
        TextSelection.collapsed(offset: widget.point.lat.toString().length);
    _lngController.selection =
        TextSelection.collapsed(offset: widget.point.lng.toString().length);
  }

  @override
  void didUpdateWidget(_CoordRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point.lat != widget.point.lat &&
        _latController.text != widget.point.lat.toString()) {
      _latController.text = widget.point.lat.toString();
      _latController.selection =
          TextSelection.collapsed(offset: _latController.text.length);
    }
    if (oldWidget.point.lng != widget.point.lng &&
        _lngController.text != widget.point.lng.toString()) {
      _lngController.text = widget.point.lng.toString();
      _lngController.selection =
          TextSelection.collapsed(offset: _lngController.text.length);
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _latController,
              decoration: const InputDecoration(
                  isDense: true, labelText: 'Lat'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                final n = double.tryParse(v);
                if (n != null) {
                  widget.onChanged(n, widget.point.lng);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _lngController,
              decoration: const InputDecoration(
                  isDense: true, labelText: 'Lng'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                final n = double.tryParse(v);
                if (n != null) {
                  widget.onChanged(widget.point.lat, n);
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}

class _RegionNameRowWidget extends StatefulWidget {
  const _RegionNameRowWidget({
    required this.value,
    required this.onChanged,
    required this.onRemove,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  @override
  State<_RegionNameRowWidget> createState() => _RegionNameRowWidgetState();
}

class _RegionNameRowWidgetState extends State<_RegionNameRowWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.selection =
        TextSelection.collapsed(offset: widget.value.length);
  }

  @override
  void didUpdateWidget(_RegionNameRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection =
          TextSelection.collapsed(offset: widget.value.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                  isDense: true, hintText: 'Region name'),
              onChanged: widget.onChanged,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Full-screen Medicinal Use Editor
// ═══════════════════════════════════════════════════════════════════════════════

class _EditMedicinalUseScreen extends StatefulWidget {
  const _EditMedicinalUseScreen({this.initial});

  final MedicinalUse? initial;

  @override
  State<_EditMedicinalUseScreen> createState() =>
      _EditMedicinalUseScreenState();
}

class _EditMedicinalUseScreenState extends State<_EditMedicinalUseScreen> {
  late TextEditingController _conditionController;
  late TextEditingController _effectivenessController;
  late TextEditingController _descriptionController;
  late TextEditingController _dosageController;
  late TextEditingController _durationController;
  late List<String> _activeCompounds;

  @override
  void initState() {
    super.initState();
    final u = widget.initial;
    _conditionController = TextEditingController(text: u?.condition ?? '');
    _effectivenessController =
        TextEditingController(text: u?.effectiveness ?? '');
    _descriptionController = TextEditingController(text: u?.description ?? '');
    _dosageController = TextEditingController(text: u?.dosage ?? '');
    _durationController = TextEditingController(text: u?.duration ?? '');
    _activeCompounds = u != null ? List.from(u.activeCompounds) : [];
  }

  @override
  void dispose() {
    _conditionController.dispose();
    _effectivenessController.dispose();
    _descriptionController.dispose();
    _dosageController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _done() {
    final use = MedicinalUse(
      condition: _conditionController.text.trim(),
      effectiveness: _effectivenessController.text.trim(),
      description: _descriptionController.text.trim(),
      activeCompounds:
          _activeCompounds.where((s) => s.trim().isNotEmpty).toList(),
      dosage: _dosageController.text.trim(),
      duration: _durationController.text.trim(),
    );
    Navigator.of(context).pop(use);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null
            ? 'Add Medicinal Use'
            : 'Edit Medicinal Use'),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                8),
        child: FilledButton(
          onPressed: _done,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.botanicalPrimary,
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text('Done',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _conditionController,
              decoration: const InputDecoration(labelText: 'Condition (title)'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _effectivenessController,
              decoration: const InputDecoration(
                  labelText: 'Effectiveness (e.g. High – DOH approved)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 6,
              minLines: 2,
            ),
            const SizedBox(height: 12),
            _buildStringListSection(theme, 'Active compounds', _activeCompounds,
                (list) => setState(() => _activeCompounds = list)),
            const SizedBox(height: 12),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(labelText: 'Dosage'),
              maxLines: 4,
              minLines: 1,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration'),
              maxLines: 4,
              minLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStringListSection(ThemeData theme, String title,
      List<String> items, void Function(List<String>) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => onChanged(List<String>.from(items)..add('')),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(items.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: _EditableListRow(
                    value: items[i],
                    hintText: 'Compound',
                    maxLines: 3,
                    onChanged: (v) {
                      final list = List<String>.from(items)..[i] = v;
                      onChanged(list);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () =>
                      onChanged(List<String>.from(items)..removeAt(i)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// One row in the editable list; owns its controller to avoid creating one per build (reduces lag).
class _EditableListRow extends StatefulWidget {
  const _EditableListRow({
    required this.value,
    required this.hintText,
    required this.maxLines,
    required this.onChanged,
  });
  final String value;
  final String hintText;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  State<_EditableListRow> createState() => _EditableListRowState();
}

class _EditableListRowState extends State<_EditableListRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.selection =
        TextSelection.collapsed(offset: widget.value.length);
  }

  @override
  void didUpdateWidget(_EditableListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection =
          TextSelection.collapsed(offset: widget.value.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(isDense: true, hintText: widget.hintText),
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Full-screen Preparation Method Editor
// ═══════════════════════════════════════════════════════════════════════════════

class _EditPreparationMethodScreen extends StatefulWidget {
  const _EditPreparationMethodScreen({this.initial, required this.plantId});

  final PreparationMethod? initial;
  final String plantId;

  @override
  State<_EditPreparationMethodScreen> createState() =>
      _EditPreparationMethodScreenState();
}

class _EditPreparationMethodScreenState
    extends State<_EditPreparationMethodScreen> {
  late TextEditingController _idController;
  late TextEditingController _conditionController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _preparationTypeController;
  late TextEditingController _dosageController;
  late TextEditingController _frequencyController;
  late TextEditingController _durationController;
  late List<String> _steps;
  late List<String> _warnings;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    final id = m?.id ??
        '${widget.plantId}-prep-${DateTime.now().millisecondsSinceEpoch}';
    _idController = TextEditingController(text: id);
    _conditionController = TextEditingController(text: m?.condition ?? '');
    _titleController = TextEditingController(text: m?.title ?? '');
    _descriptionController = TextEditingController(text: m?.description ?? '');
    _preparationTypeController =
        TextEditingController(text: m?.preparationType ?? '');
    _dosageController = TextEditingController(text: m?.dosage ?? '');
    _frequencyController = TextEditingController(text: m?.frequency ?? '');
    _durationController = TextEditingController(text: m?.duration ?? '');
    _steps = m != null ? List.from(m.steps) : [];
    _warnings = m != null ? List.from(m.warnings) : [];
  }

  @override
  void dispose() {
    _idController.dispose();
    _conditionController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _preparationTypeController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _done() {
    final method = PreparationMethod(
      id: _idController.text.trim().isEmpty
          ? '${widget.plantId}-prep-${DateTime.now().millisecondsSinceEpoch}'
          : _idController.text.trim(),
      condition: _conditionController.text.trim(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      steps: _steps.where((s) => s.trim().isNotEmpty).toList(),
      dosage: _dosageController.text.trim(),
      frequency: _frequencyController.text.trim(),
      duration: _durationController.text.trim(),
      warnings: _warnings.where((s) => s.trim().isNotEmpty).toList(),
      preparationType: _preparationTypeController.text.trim(),
      stepDetails: null,
      schedule: null,
    );
    Navigator.of(context).pop(method);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null
            ? 'Add Preparation Method'
            : 'Edit Preparation Method'),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                8),
        child: FilledButton(
          onPressed: _done,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.botanicalPrimary,
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text('Done',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _conditionController,
              decoration:
                  const InputDecoration(labelText: 'Condition (e.g. Cough)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _preparationTypeController,
              decoration: const InputDecoration(
                  labelText: 'Preparation type (e.g. decoction, tea)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 6,
              minLines: 2,
            ),
            const SizedBox(height: 12),
            _buildStringListSection(theme, 'Steps', _steps,
                (list) => setState(() => _steps = list)),
            const SizedBox(height: 12),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(labelText: 'Dosage'),
              maxLines: 4,
              minLines: 1,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _frequencyController,
              decoration: const InputDecoration(labelText: 'Frequency'),
              maxLines: 4,
              minLines: 1,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration'),
              maxLines: 4,
              minLines: 1,
            ),
            const SizedBox(height: 12),
            _buildStringListSection(theme, 'Warnings', _warnings,
                (list) => setState(() => _warnings = list), listItemMaxLines: 3),
            const SizedBox(height: 12),
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                  labelText: 'ID (unique)',
                  helperText: 'Auto-generated if empty',
                  helperStyle:
                      TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStringListSection(ThemeData theme, String title,
      List<String> items, void Function(List<String>) onChanged,
      {int? listItemMaxLines}) {
    final hintText = title == 'Steps' ? 'Step instruction' : 'Item';
    final maxLines = listItemMaxLines ??
        (title == 'Steps' ? 2 : (title == 'Warnings' ? 3 : 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => onChanged(List<String>.from(items)..add('')),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(items.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _EditableListRow(
                    value: items[i],
                    hintText: hintText,
                    maxLines: maxLines,
                    onChanged: (v) {
                      final list = List<String>.from(items)..[i] = v;
                      onChanged(list);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () =>
                      onChanged(List<String>.from(items)..removeAt(i)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Anatomy part add/edit screen (owns controllers; lifecycle-safe)
// ═══════════════════════════════════════════════════════════════════════════════

class _EditAnatomyPartScreen extends StatefulWidget {
  const _EditAnatomyPartScreen({
    required this.plantId,
    this.initial,
  });

  final String plantId;
  final Map<String, dynamic>? initial;

  @override
  State<_EditAnatomyPartScreen> createState() => _EditAnatomyPartScreenState();
}

class _EditAnatomyPartScreenState extends State<_EditAnatomyPartScreen> {
  late TextEditingController _partNameController;
  late TextEditingController _svgPathController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _colorHexController;
  late List<String> _conditions;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    _partNameController =
        TextEditingController(text: m?['part_name'] as String? ?? '');
    _svgPathController =
        TextEditingController(text: m?['svg_path'] as String? ?? '');
    _titleController =
        TextEditingController(text: m?['title'] as String? ?? '');
    _descriptionController =
        TextEditingController(text: m?['description'] as String? ?? '');
    _colorHexController =
        TextEditingController(text: m?['color_hex'] as String? ?? '4CAF50');
    if (m?['conditions'] is List) {
      _conditions =
          (m!['conditions'] as List).map((e) => e.toString()).toList();
    } else {
      _conditions = [];
    }
  }

  @override
  void dispose() {
    _partNameController.dispose();
    _svgPathController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _colorHexController.dispose();
    super.dispose();
  }

  Future<void> _openImageTracer() async {
    final hex = _colorHexController.text.trim().replaceAll('#', '');
    Color fillCol = const Color(0xFF4CAF50);
    if (hex.isNotEmpty) {
      try {
        fillCol = Color(int.parse(hex, radix: 16) | 0xFF000000);
      } catch (_) {}
    }

    final result = await showDialog<String>(
      context: context,
      builder: (_) => ImageTracerDialog(fillColor: fillCol),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _svgPathController.text = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SVG path applied from Image Tracer ✓'),
          backgroundColor: AppTheme.botanicalPrimary,
        ),
      );
    }
  }

  void _done() {
    final partName = _partNameController.text.trim();
    if (partName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Part name is required')),
      );
      return;
    }
    final conditionsList =
        _conditions.where((s) => s.trim().isNotEmpty).toList();
    Navigator.of(context).pop({
      'plant_id': widget.plantId,
      'part_name': partName,
      'svg_path': _svgPathController.text.trim(),
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'conditions': conditionsList,
      'color_hex': _colorHexController.text.replaceAll('#', '').toUpperCase(),
      'z_index': widget.initial?['z_index'] is int
          ? widget.initial!['z_index'] as int
          : int.tryParse(widget.initial?['z_index'].toString() ?? '0') ?? 0,
      'is_interactive': widget.initial?['is_interactive'] ?? true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null
            ? l10n.adminAnatomyAddPart
            : l10n.edit),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                8),
        child: FilledButton(
          onPressed: _done,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.botanicalPrimary,
            minimumSize: const Size(double.infinity, 48),
          ),
          child: Text(l10n.save,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _partNameController,
              decoration: const InputDecoration(
                labelText: 'Part name (e.g. leaves, bulb, seeds)',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                  labelText: 'Title (display name)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _svgPathController,
              decoration: const InputDecoration(
                labelText: 'SVG path (d="..." value)',
                hintText: 'e.g. M 20 20 L 180 20 L 180 160 L 20 160 Z',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Trace from Image'),
                onPressed: _openImageTracer,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.botanicalPrimary,
                  side: BorderSide(color: AppTheme.botanicalPrimary.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload a plant part image (will be resized to 300×300) to auto-generate the SVG path.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 6,
              minLines: 2,
            ),
            const SizedBox(height: 12),
            _buildColorPicker(),
            const SizedBox(height: 12),
            _buildConditionsSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    final theme = Theme.of(context);
    final palette = [
      ('Leaf Green', '4CAF50'),
      ('Stem/Bark Brown', '795548'),
      ('Root Yellow-Brown', 'A1887F'),
      ('Garlic/Onion White', 'F5F5F5'),
      ('Flower Red', 'F44336'),
      ('Flower Pink', 'E91E63'),
    ];

    Color currentColor = const Color(0xFF4CAF50);
    try {
      if (_colorHexController.text.isNotEmpty) {
        currentColor = Color(int.parse(_colorHexController.text.replaceAll('#', ''), radix: 16) | 0xFF000000);
      }
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Silhouette Color', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: palette.map((p) {
            final color = Color(int.parse(p.$2, radix: 16) | 0xFF000000);
            final isSelected = _colorHexController.text.replaceAll('#', '').toUpperCase() == p.$2.toUpperCase();
            return Tooltip(
              message: p.$1,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _colorHexController.text = p.$2;
                  });
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppTheme.botanicalPrimary : Colors.grey.withValues(alpha: 0.3),
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(color: AppTheme.botanicalPrimary.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1)
                    ] : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _colorHexController,
                decoration: const InputDecoration(
                  labelText: 'Custom Hex Color',
                  hintText: 'e.g. 4CAF50',
                  isDense: true,
                  prefixText: '#',
                ),
                onChanged: (v) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Conditions (medical uses)',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _conditions = List.from(_conditions)..add('')),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_conditions.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _EditableListRow(
                    value: _conditions[i],
                    hintText: 'Condition',
                    maxLines: 1,
                    onChanged: (v) {
                      final list = List<String>.from(_conditions)..[i] = v;
                      setState(() => _conditions = list);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => setState(
                      () => _conditions = List.from(_conditions)..removeAt(i)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
