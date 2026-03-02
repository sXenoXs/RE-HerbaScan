import 'package:flutter/material.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_metadata_override.dart';
import 'package:herbascan/core/services/catalog_plant_admin_service.dart';
import 'package:herbascan/core/services/plant_data_service.dart';
import 'package:herbascan/core/services/plant_metadata_service.dart';
import 'package:herbascan/features/admin/admin_plant_catalog_editor_screen.dart';

/// Plant Metadata Editor: list of fixed plants, edit description/safety/preparation only. No add/delete plant.
class AdminPlantMetadataScreen extends StatefulWidget {
  const AdminPlantMetadataScreen({super.key});

  @override
  State<AdminPlantMetadataScreen> createState() => _AdminPlantMetadataScreenState();
}

class _AdminPlantMetadataScreenState extends State<AdminPlantMetadataScreen> {
  List<Plant> _plants = [];
  Map<String, PlantMetadataOverride> _overrides = {};
  bool _loading = true;
  bool _resetting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
          _overrides = overrides;
          _loading = false;
        });
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Factory Reset catalog?'),
        content: const Text(
          'Restore the entire Supabase catalog to bundled defaults. '
          'This will overwrite all 42 plants, safety, habitat, and conditions. '
          'Uploaded plant images in Storage will be removed.\n\n'
          'After reset, sync the app (pull-to-refresh or restart) to load the new data.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset all')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _resetting = true);
    final ok = await CatalogPlantAdminService().factoryResetCatalog(clearPlantCatalogStorage: true);
    if (mounted) {
      setState(() => _resetting = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catalog reset to defaults. Sync the app (e.g. restart) to load new data.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Factory reset failed. Check connection and try again.')),
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Plant Metadata (${_plants.length} plants)',
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: _resetting ? null : _factoryReset,
                icon: _resetting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restart_alt, size: 20),
                label: const Text('Factory Reset'),
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _resetting ? null : _load),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _plants.length,
            itemBuilder: (context, index) {
              final plant = _plants[index];
              final hasOverride = _overrides.containsKey(plant.id);
              return ListTile(
                title: Text(plant.commonName),
                subtitle: Text(plant.scientificName),
                trailing: hasOverride ? const Icon(Icons.edit, color: Colors.green) : const Icon(Icons.edit_outlined),
                onTap: () => _openEditor(plant),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlantMetadataEditorPage extends StatefulWidget {
  const _PlantMetadataEditorPage({
    required this.plant,
    required this.initialOverride,
    required this.onSaved,
  });

  final Plant plant;
  final PlantMetadataOverride? initialOverride;
  final VoidCallback onSaved;

  @override
  State<_PlantMetadataEditorPage> createState() => _PlantMetadataEditorPageState();
}

class _PlantMetadataEditorPageState extends State<_PlantMetadataEditorPage> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _safetyController;
  late final TextEditingController _preparationController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final o = widget.initialOverride;
    _descriptionController = TextEditingController(text: o?.description ?? widget.plant.morphology);
    _safetyController = TextEditingController(text: o?.safetyWarnings ?? widget.plant.safetyWarnings.join('\n'));
    _preparationController = TextEditingController(
      text: o?.preparationStepsJson ?? _preparationToJson(widget.plant.preparationMethods),
    );
  }

  String _preparationToJson(List<PreparationMethod> methods) {
    try {
      final list = methods.map((m) => {
        'title': m.title,
        'condition': m.condition,
        'steps': m.stepInstructions,
        'dosage': m.dosage,
        'frequency': m.frequency,
        'duration': m.duration,
      }).toList();
      return list.toString();
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _safetyController.dispose();
    _preparationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await PlantMetadataService().save(
      plantId: widget.plant.id,
      description: _descriptionController.text.trim(),
      safetyWarnings: _safetyController.text.trim(),
      preparationStepsJson: _preparationController.text.trim().isEmpty ? null : _preparationController.text.trim(),
    );
    setState(() => _saving = false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      widget.onSaved();
    }
  }

  Future<void> _factoryReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Factory Reset?'),
        content: const Text('Restore default data for this plant. Your edits will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    final ok = await PlantMetadataService().factoryReset(widget.plant.id);
    setState(() => _saving = false);
    if (ok && mounted) {
      _descriptionController.text = widget.plant.morphology;
      _safetyController.text = widget.plant.safetyWarnings.join('\n');
      _preparationController.text = _preparationToJson(widget.plant.preparationMethods);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset to default')));
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plant.commonName),
        actions: [
          TextButton(
            onPressed: _saving ? null : _factoryReset,
            child: const Text('Factory Reset'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Morphology / general description',
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _safetyController,
                decoration: const InputDecoration(
                  labelText: 'Safety Warnings',
                  hintText: 'One per line or paragraph',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _preparationController,
                decoration: const InputDecoration(
                  labelText: 'Preparation Steps (JSON or text)',
                  hintText: 'Preparation method details',
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
