import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_habitat.dart';
import 'package:herbascan/core/models/safety_profile.dart';
import 'package:herbascan/core/widgets/plant_image.dart';
import 'package:herbascan/core/services/catalog_plant_admin_service.dart';
import 'package:herbascan/core/services/habitat_service.dart';
import 'package:herbascan/core/services/safety_profile_service.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
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
    extends State<AdminPlantCatalogEditorScreen> with SingleTickerProviderStateMixin {
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
    if (safety == null) {
      safety = await SafetyProfileService().getSafetyProfile(widget.plant);
    }
    var habitat = await _adminService.getCatalogHabitat(widget.plant.id);
    if (habitat == null) {
      habitat = await HabitatService().getHabitat(widget.plant);
    }
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
    var ok = await _adminService.saveCatalogPlant(_plant, climateNotes: _climateNotes);
    if (ok) {
      final safetyProfile = SafetyProfile(
        plantId: _plant.id,
        name: _plant.commonName,
        isGenerallySafe: _isGenerallySafe,
        pregnancyWarning: _pregnancyWarning,
        knownSideEffects: _knownSideEffects,
        drugInteractions: _drugInteractions,
        strictContraindications: _strictContraindications,
      );
      ok = await _adminService.saveCatalogSafety(_plant.id, safetyProfile);
    }
    if (ok) {
      final habitat = PlantHabitat(
        plantId: _plant.id,
        knownCoordinates: _habitatCoordinates,
        regionNames: _habitatRegionNames,
        climateNotes: _habitatClimateNotes,
      );
      ok = await _adminService.saveCatalogHabitat(_plant.id, habitat);
    }
    setState(() => _saving = false);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to catalog')));
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Save failed')));
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded. Tap Save to update catalog.')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed')));
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Seed')),
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seed failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          TextButton(
            onPressed: _saving ? null : _seedFromDefaults,
            child: const Text('Seed defaults'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIdentityTab(theme),
          _buildEcologyTab(theme),
          _buildMedicinalTab(theme),
          _buildPreparationsTab(theme),
          _buildSafetyTab(theme),
        ],
      ),
    );
  }

  Widget _buildIdentityTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          _textField('Common name', _plant.commonName, (v) => setState(() => _plant = _copyWith(commonName: v))),
          _textField('Scientific name', _plant.scientificName, (v) => setState(() => _plant = _copyWith(scientificName: v))),
          _textField('Local name', _plant.localName, (v) => setState(() => _plant = _copyWith(localName: v))),
          _textField('English name', _plant.englishName, (v) => setState(() => _plant = _copyWith(englishName: v))),
          _textField('Family', _plant.family, (v) => setState(() => _plant = _copyWith(family: v))),
          _textField('Genus', _plant.genus, (v) => setState(() => _plant = _copyWith(genus: v))),
          _textField('Species', _plant.species, (v) => setState(() => _plant = _copyWith(species: v))),
          _textField('Morphology', _plant.morphology, (v) => setState(() => _plant = _copyWith(morphology: v)), maxLines: 4),
          SwitchListTile(
            title: const Text('DOH approved'),
            value: _plant.isDOHApproved,
            onChanged: (v) => setState(() => _plant = _copyWith(isDOHApproved: v)),
          ),
        ],
      ),
    );
  }

  Widget _textField(String label, String value, void Function(String) onChanged, {int maxLines = 1}) {
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

  Widget _buildEcologyTab(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final hasHabitatData = _habitatCoordinates.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _textField('Ecology', _plant.ecology, (v) => setState(() => _plant = _copyWith(ecology: v)), maxLines: 4),
          _textField('Habitat', _plant.habitat, (v) => setState(() => _plant = _copyWith(habitat: v)), maxLines: 4),
          _textField('Climate notes (plant)', _climateNotes ?? '', (v) => setState(() => _climateNotes = v), maxLines: 3),
          const SizedBox(height: 20),
          Text('Known habitat regions', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Coordinates (lat, lng)', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ...List.generate(_habitatCoordinates.length, (i) {
            final pt = _habitatCoordinates[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: TextField(
                      decoration: const InputDecoration(isDense: true, labelText: 'Lat'),
                      controller: TextEditingController(text: pt.lat.toString())
                        ..selection = TextSelection.collapsed(offset: pt.lat.toString().length),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final n = double.tryParse(v);
                        if (n != null) {
                          final list = List<HabitatPoint>.from(_habitatCoordinates);
                          list[i] = HabitatPoint(lat: n, lng: list[i].lng);
                          setState(() => _habitatCoordinates = list);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      decoration: const InputDecoration(isDense: true, labelText: 'Lng'),
                      controller: TextEditingController(text: pt.lng.toString())
                        ..selection = TextSelection.collapsed(offset: pt.lng.toString().length),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final n = double.tryParse(v);
                        if (n != null) {
                          final list = List<HabitatPoint>.from(_habitatCoordinates);
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
                        _habitatCoordinates = List<HabitatPoint>.from(_habitatCoordinates)..removeAt(i);
                      });
                    },
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _habitatCoordinates = List<HabitatPoint>.from(_habitatCoordinates)..add(const HabitatPoint(lat: 14.6, lng: 121.0))),
            icon: const Icon(Icons.add),
            label: const Text('Add coordinate'),
          ),
          const SizedBox(height: 12),
          Text('Region names', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ...List.generate(_habitatRegionNames.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(isDense: true, hintText: 'Region name'),
                      controller: TextEditingController(text: _habitatRegionNames[i])
                        ..selection = TextSelection.collapsed(offset: _habitatRegionNames[i].length),
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
                      setState(() => _habitatRegionNames = List<String>.from(_habitatRegionNames)..removeAt(i));
                    },
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _habitatRegionNames = List<String>.from(_habitatRegionNames)..add('')),
            icon: const Icon(Icons.add),
            label: const Text('Add region'),
          ),
          const SizedBox(height: 12),
          _textField('Habitat climate notes', _habitatClimateNotes, (v) => setState(() => _habitatClimateNotes = v), maxLines: 2),
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
                      Icon(Icons.map_outlined, color: theme.colorScheme.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.whereItGrows,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
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

  Widget _buildMedicinalTab(ThemeData theme) {
    final uses = _plant.medicinalUses;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Medicinal uses (${uses.length})', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  final added = await _showMedicinalUseDialog(null);
                  if (added != null && mounted) {
                    setState(() {
                      _plant = _copyWith(medicinalUses: List<MedicinalUse>.from(uses)..add(added));
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(use.condition.isEmpty ? '(No condition)' : use.condition, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () async {
                            final updated = await _showMedicinalUseDialog(use);
                            if (updated != null && mounted) {
                              setState(() {
                                final list = List<MedicinalUse>.from(uses)..[i] = updated;
                                _plant = _copyWith(medicinalUses: list);
                              });
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () {
                            setState(() {
                              final list = List<MedicinalUse>.from(uses)..removeAt(i);
                              _plant = _copyWith(medicinalUses: list);
                            });
                          },
                        ),
                      ],
                    ),
                    if (use.effectiveness.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(use.effectiveness, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    if (use.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(use.description, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<MedicinalUse?> _showMedicinalUseDialog(MedicinalUse? initial) async {
    return showDialog<MedicinalUse>(
      context: context,
      builder: (ctx) => _MedicinalUseEditDialog(initial: initial),
    );
  }

  Widget _buildPreparationsTab(ThemeData theme) {
    final methods = _plant.preparationMethods;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Preparation methods (${methods.length})', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  final added = await _showPreparationMethodDialog(null);
                  if (added != null && mounted) {
                    setState(() {
                      _plant = _copyWith(preparationMethods: List<PreparationMethod>.from(methods)..add(added));
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(method.title.isEmpty ? '(No title)' : method.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () async {
                            final updated = await _showPreparationMethodDialog(method);
                            if (updated != null && mounted) {
                              setState(() {
                                final list = List<PreparationMethod>.from(methods)..[i] = updated;
                                _plant = _copyWith(preparationMethods: list);
                              });
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () {
                            setState(() {
                              final list = List<PreparationMethod>.from(methods)..removeAt(i);
                              _plant = _copyWith(preparationMethods: list);
                            });
                          },
                        ),
                      ],
                    ),
                    if (method.condition.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('For: ${method.condition}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    if (method.preparationType.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(method.preparationType, style: theme.textTheme.bodySmall),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<PreparationMethod?> _showPreparationMethodDialog(PreparationMethod? initial) async {
    return showDialog<PreparationMethod>(
      context: context,
      builder: (ctx) => _PreparationMethodEditDialog(initial: initial, plantId: _plant.id),
    );
  }

  Widget _buildSafetyTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            title: const Text('Generally safe for consumption'),
            value: _isGenerallySafe,
            onChanged: (v) => setState(() => _isGenerallySafe = v),
          ),
          SwitchListTile(
            title: const Text('Pregnancy warning'),
            value: _pregnancyWarning,
            onChanged: (v) => setState(() => _pregnancyWarning = v),
          ),
          const SizedBox(height: 16),
          _buildListSection(theme, 'Known side effects', _knownSideEffects, (list) => setState(() => _knownSideEffects = list)),
          _buildListSection(theme, 'Drug interactions', _drugInteractions, (list) => setState(() => _drugInteractions = list)),
          _buildListSection(theme, 'Strict contraindications', _strictContraindications, (list) => setState(() => _strictContraindications = list)),
        ],
      ),
    );
  }

  Widget _buildListSection(ThemeData theme, String title, List<String> items, void Function(List<String>) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        hintText: 'Item',
                      ),
                      controller: TextEditingController(text: items[i])
                        ..selection = TextSelection.collapsed(offset: (items[i]).length),
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

/// Dialog to add or edit a [MedicinalUse].
class _MedicinalUseEditDialog extends StatefulWidget {
  const _MedicinalUseEditDialog({this.initial});

  final MedicinalUse? initial;

  @override
  State<_MedicinalUseEditDialog> createState() => _MedicinalUseEditDialogState();
}

class _MedicinalUseEditDialogState extends State<_MedicinalUseEditDialog> {
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
    _effectivenessController = TextEditingController(text: u?.effectiveness ?? '');
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

  void _save() {
    final use = MedicinalUse(
      condition: _conditionController.text.trim(),
      effectiveness: _effectivenessController.text.trim(),
      description: _descriptionController.text.trim(),
      activeCompounds: _activeCompounds.where((s) => s.trim().isNotEmpty).toList(),
      dosage: _dosageController.text.trim(),
      duration: _durationController.text.trim(),
    );
    Navigator.of(context).pop(use);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add medicinal use' : 'Edit medicinal use'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                decoration: const InputDecoration(labelText: 'Effectiveness (e.g. High – DOH approved)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _buildStringListSection(theme, 'Active compounds', _activeCompounds, (list) => setState(() => _activeCompounds = list)),
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
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _buildStringListSection(ThemeData theme, String title, List<String> items, void Function(List<String>) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                  child: TextField(
                    decoration: const InputDecoration(isDense: true, hintText: 'Compound'),
                    controller: TextEditingController(text: items[i])
                      ..selection = TextSelection.collapsed(offset: items[i].length),
                    onChanged: (v) {
                      final list = List<String>.from(items)..[i] = v;
                      onChanged(list);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => onChanged(List<String>.from(items)..removeAt(i)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Dialog to add or edit a [PreparationMethod].
class _PreparationMethodEditDialog extends StatefulWidget {
  const _PreparationMethodEditDialog({this.initial, required this.plantId});

  final PreparationMethod? initial;
  final String plantId;

  @override
  State<_PreparationMethodEditDialog> createState() => _PreparationMethodEditDialogState();
}

class _PreparationMethodEditDialogState extends State<_PreparationMethodEditDialog> {
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
    final id = m?.id ?? '${widget.plantId}-prep-${DateTime.now().millisecondsSinceEpoch}';
    _idController = TextEditingController(text: id);
    _conditionController = TextEditingController(text: m?.condition ?? '');
    _titleController = TextEditingController(text: m?.title ?? '');
    _descriptionController = TextEditingController(text: m?.description ?? '');
    _preparationTypeController = TextEditingController(text: m?.preparationType ?? '');
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

  void _save() {
    final method = PreparationMethod(
      id: _idController.text.trim().isEmpty ? '${widget.plantId}-prep-${DateTime.now().millisecondsSinceEpoch}' : _idController.text.trim(),
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
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add preparation method' : 'Edit preparation method'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'ID (unique)', helperText: 'Auto-generated if empty'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _conditionController,
                decoration: const InputDecoration(labelText: 'Condition (e.g. Cough)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _preparationTypeController,
                decoration: const InputDecoration(labelText: 'Preparation type (e.g. decoction, tea)'),
              ),
              const SizedBox(height: 12),
              _buildStringListSection(theme, 'Steps', _steps, (list) => setState(() => _steps = list)),
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
              _buildStringListSection(theme, 'Warnings', _warnings, (list) => setState(() => _warnings = list)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _buildStringListSection(ThemeData theme, String title, List<String> items, void Function(List<String>) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                  child: TextField(
                    decoration: InputDecoration(isDense: true, hintText: title == 'Steps' ? 'Step instruction' : 'Item'),
                    controller: TextEditingController(text: items[i])
                      ..selection = TextSelection.collapsed(offset: items[i].length),
                    maxLines: title == 'Steps' ? 2 : 1,
                    onChanged: (v) {
                      final list = List<String>.from(items)..[i] = v;
                      onChanged(list);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => onChanged(List<String>.from(items)..removeAt(i)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
