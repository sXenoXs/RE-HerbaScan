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
import 'package:herbascan/core/services/database_service.dart';
import 'package:herbascan/core/services/habitat_service.dart';
import 'package:herbascan/core/services/safety_profile_service.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/features/scan/habitat_map_screen.dart';

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
  List<String> _knownSideEffects = [];
  List<String> _drugInteractions = [];
  List<String> _strictContraindications = [];

  // Editable habitat (catalog_habitat)
  List<HabitatPoint> _habitatCoordinates = [];
  List<String> _habitatRegionNames = [];
  String _habitatClimateNotes = '';

  final CatalogPlantAdminService _adminService = CatalogPlantAdminService();
  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _plant = widget.plant;
    _tabController = TabController(length: 5, vsync: this);
    _loadCatalog();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() => _loading = true);
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
          _knownSideEffects = List.from(safety.knownSideEffects);
          _drugInteractions = List.from(safety.drugInteractions);
          _strictContraindications = List.from(safety.strictContraindications);
        }
        if (habitat != null) {
          _habitatCoordinates = List.from(habitat.knownCoordinates);
          _habitatRegionNames = List.from(habitat.regionNames);
          _habitatClimateNotes = habitat.climateNotes;
        }
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    // Build objects once — reused for both Supabase and local SQLite writes
    final safetyProfile = SafetyProfile(
      plantId: _plant.id,
      name: _plant.commonName,
      isGenerallySafe: _isGenerallySafe,
      pregnancyWarning: _pregnancyWarning,
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
        content: const Text(
          'This will upsert all 42 plants from the bundled data into Supabase. '
          'Existing catalog data will be overwritten.',
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
    setState(() => _saving = false);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Catalog seeded from defaults')));
        await _loadCatalog();
      } else {
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
          _textField('Common name', _plant.commonName,
              (v) => setState(() => _plant = _copyWith(commonName: v))),
          _textField('Scientific name', _plant.scientificName,
              (v) => setState(() => _plant = _copyWith(scientificName: v))),
          // Grouped row: Family + Genus
          Row(
            children: [
              Expanded(
                child: _textField('Family', _plant.family,
                    (v) => setState(() => _plant = _copyWith(family: v))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _textField('Genus', _plant.genus,
                    (v) => setState(() => _plant = _copyWith(genus: v))),
              ),
            ],
          ),
          // Grouped row: Species + Local Name
          Row(
            children: [
              Expanded(
                child: _textField('Species', _plant.species,
                    (v) => setState(() => _plant = _copyWith(species: v))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _textField('Local name', _plant.localName,
                    (v) => setState(() => _plant = _copyWith(localName: v))),
              ),
            ],
          ),
          _textField('English name', _plant.englishName,
              (v) => setState(() => _plant = _copyWith(englishName: v))),
          _textField('Morphology', _plant.morphology,
              (v) => setState(() => _plant = _copyWith(morphology: v)),
              maxLines: 4),
        ],
      ),
    );
  }

  Widget _textField(String label, String value, void Function(String) onChanged,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        decoration: InputDecoration(labelText: label),
        controller: TextEditingController(text: value)
          ..selection = TextSelection.collapsed(offset: value.length),
        maxLines: maxLines,
        onChanged: onChanged,
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
          _textField('Ecology', _plant.ecology,
              (v) => setState(() => _plant = _copyWith(ecology: v)),
              maxLines: 4),
          _textField('Habitat', _plant.habitat,
              (v) => setState(() => _plant = _copyWith(habitat: v)),
              maxLines: 4),
          _textField('Climate notes (plant)', _climateNotes ?? '',
              (v) => setState(() => _climateNotes = v),
              maxLines: 3),
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
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                            isDense: true, labelText: 'Lat'),
                        controller:
                            TextEditingController(text: pt.lat.toString())
                              ..selection = TextSelection.collapsed(
                                  offset: pt.lat.toString().length),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (v) {
                          final n = double.tryParse(v);
                          if (n != null) {
                            final list =
                                List<HabitatPoint>.from(_habitatCoordinates);
                            list[i] = HabitatPoint(lat: n, lng: list[i].lng);
                            setState(() => _habitatCoordinates = list);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                            isDense: true, labelText: 'Lng'),
                        controller:
                            TextEditingController(text: pt.lng.toString())
                              ..selection = TextSelection.collapsed(
                                  offset: pt.lng.toString().length),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (v) {
                          final n = double.tryParse(v);
                          if (n != null) {
                            final list =
                                List<HabitatPoint>.from(_habitatCoordinates);
                            list[i] = HabitatPoint(lat: list[i].lat, lng: n);
                            setState(() => _habitatCoordinates = list);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        setState(() {
                          _habitatCoordinates =
                              List<HabitatPoint>.from(_habitatCoordinates)
                                ..removeAt(i);
                        });
                      },
                    ),
                  ],
                ),
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
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                            isDense: true, hintText: 'Region name'),
                        controller:
                            TextEditingController(text: _habitatRegionNames[i])
                              ..selection = TextSelection.collapsed(
                                  offset: _habitatRegionNames[i].length),
                        onChanged: (v) {
                          final list = List<String>.from(_habitatRegionNames);
                          list[i] = v;
                          setState(() => _habitatRegionNames = list);
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        setState(() => _habitatRegionNames =
                            List<String>.from(_habitatRegionNames)
                              ..removeAt(i));
                      },
                    ),
                  ],
                ),
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
          _textField('Habitat climate notes', _habitatClimateNotes,
              (v) => setState(() => _habitatClimateNotes = v),
              maxLines: 2),
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

  Widget _buildListSection(ThemeData theme, String title, List<String> items,
      void Function(List<String>) onChanged,
      {Color? borderColor}) {
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
              Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
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
                    child: TextField(
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        hintText: 'Item',
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: borderColor ?? AppTheme.botanicalPrimary,
                              width: 2),
                        ),
                      ),
                      controller: TextEditingController(text: items[i])
                        ..selection =
                            TextSelection.collapsed(offset: (items[i]).length),
                      maxLines: 1,
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
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _buildStringListSection(theme, 'Active compounds', _activeCompounds,
                (list) => setState(() => _activeCompounds = list)),
            const SizedBox(height: 12),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(labelText: 'Dosage'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration'),
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
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
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
                    maxLines: 1,
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
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _buildStringListSection(theme, 'Steps', _steps,
                (list) => setState(() => _steps = list)),
            const SizedBox(height: 12),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(labelText: 'Dosage'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _frequencyController,
              decoration: const InputDecoration(labelText: 'Frequency'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration'),
            ),
            const SizedBox(height: 12),
            _buildStringListSection(theme, 'Warnings', _warnings,
                (list) => setState(() => _warnings = list)),
            const SizedBox(height: 12),
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                  labelText: 'ID (unique)',
                  helperText: 'Auto-generated if empty',
                  helperStyle:
                      TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStringListSection(ThemeData theme, String title,
      List<String> items, void Function(List<String>) onChanged) {
    final hintText = title == 'Steps' ? 'Step instruction' : 'Item';
    final maxLines = title == 'Steps' ? 2 : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
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
