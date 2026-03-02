import 'package:flutter/material.dart';
import 'package:herbascan/core/constants/condition_icons.dart';
import 'package:herbascan/core/models/catalog_condition.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/services/catalog_plant_admin_service.dart';
import 'package:herbascan/core/services/plant_data_service.dart';

/// Admin: Condition Search management. Add custom conditions, edit, delete (custom only), map plants.
class AdminConditionSearchScreen extends StatefulWidget {
  const AdminConditionSearchScreen({super.key});

  @override
  State<AdminConditionSearchScreen> createState() =>
      _AdminConditionSearchScreenState();
}

class _AdminConditionSearchScreenState
    extends State<AdminConditionSearchScreen> {
  List<CatalogCondition> _conditions = [];
  Map<int, int> _plantCounts = {};
  bool _loading = true;
  String? _error;
  final CatalogPlantAdminService _admin = CatalogPlantAdminService();

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
      final list = await _admin.listCatalogConditions();
      final counts = <int, int>{};
      for (var c in list) {
        final ids = await _admin.getPlantIdsForCatalogCondition(c.id);
        counts[c.id] = ids.length;
      }
      if (mounted) {
        setState(() {
          _conditions = list;
          _plantCounts = counts;
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

  Future<void> _seedConditions() async {
    await _admin.seedCatalogConditionsFromDefaults();
    if (mounted) _load();
  }

  Future<void> _showAddCondition() async {
    final result = await _showConditionForm();
    if (result == null || !mounted) return;
    final id = await _admin.addCatalogCondition(
      name: result.name,
      iconKey: result.iconKey,
      colorHex: result.colorHex,
      sortOrder: result.sortOrder,
    );
    if (id != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Condition added')),
      );
      _load();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add condition')),
      );
    }
  }

  Future<void> _showEditCondition(CatalogCondition c) async {
    final result = await _showConditionForm(
      initialName: c.name,
      initialIconKey: c.iconKey,
      initialColorHex: c.colorHex,
      initialSortOrder: c.sortOrder,
    );
    if (result == null || !mounted) return;
    final ok = await _admin.updateCatalogCondition(
      c.id,
      name: result.name,
      iconKey: result.iconKey,
      colorHex: result.colorHex,
      sortOrder: result.sortOrder,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Condition updated')),
      );
      _load();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update')),
      );
    }
  }

  Future<void> _showMapPlants(CatalogCondition c) async {
    final messenger = ScaffoldMessenger.of(context);
    final plantIds = await _admin.getPlantIdsForCatalogCondition(c.id);
    final plants = PlantDataService.getAllMedicinalPlantsData();
    final selected = Set<String>.from(plantIds);

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _PlantSelectorDialog(
        conditionName: c.name,
        plants: plants,
        selectedIds: selected,
      ),
    );
    if (result == null || !mounted) return;
    final ok = await _admin.saveConditionPlants(c.id, result.toList());
    if (ok && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Mapped ${result.length} plants to ${c.name}')),
      );
      _load();
    } else if (mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to save plant mapping')),
      );
    }
  }

  Future<void> _deleteCondition(CatalogCondition c) async {
    if (c.isDefault) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete condition?'),
        content: Text('Delete "${c.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await _admin.deleteCatalogCondition(c.id);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Condition deleted')),
      );
      _load();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete default condition')),
      );
    }
  }

  Future<_ConditionFormResult?> _showConditionForm({
    String? initialName,
    String? initialIconKey,
    String? initialColorHex,
    int? initialSortOrder,
  }) async {
    return showDialog<_ConditionFormResult>(
      context: context,
      builder: (ctx) => _ConditionFormDialog(
        initialName: initialName ?? '',
        initialIconKey: initialIconKey ?? 'healing',
        initialColorHex: initialColorHex ?? '6366F1',
        initialSortOrder: initialSortOrder ?? 999,
        isEdit: initialName != null,
      ),
    );
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
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('Condition Search'),
            actions: [
              if (_conditions.isEmpty)
                TextButton.icon(
                  onPressed: _seedConditions,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Seed defaults'),
                )
              else
                IconButton(
                  onPressed: _seedConditions,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Re-seed conditions',
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _showAddCondition,
                icon: const Icon(Icons.add),
                label: const Text('Add condition'),
              ),
              const SizedBox(width: 16),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Manage conditions shown in Browse by Condition. Default conditions (15) cannot be deleted. Add custom conditions and map which plants treat each.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (_conditions.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_hospital_outlined,
                        size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                        'No conditions yet. Tap "Seed defaults" to add the 15 default conditions.'),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final c = _conditions[index];
                  final count = _plantCounts[c.id] ?? 0;
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(getConditionIcon(c.iconKey),
                            color: c.color, size: 24),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (c.isDefault) ...[
                            const SizedBox(width: 8),
                            Chip(
                              label: const Text('Default'),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text('$count plants'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.link),
                            tooltip: 'Map plants',
                            onPressed: () => _showMapPlants(c),
                          ),
                          if (!c.isDefault) ...[
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Edit',
                              onPressed: () => _showEditCondition(c),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete,
                                  color: theme.colorScheme.error),
                              tooltip: 'Delete',
                              onPressed: () => _deleteCondition(c),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
                childCount: _conditions.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _ConditionFormResult {
  final String name;
  final String iconKey;
  final String colorHex;
  final int sortOrder;
  _ConditionFormResult({
    required this.name,
    required this.iconKey,
    required this.colorHex,
    required this.sortOrder,
  });
}

class _ConditionFormDialog extends StatefulWidget {
  final String initialName;
  final String initialIconKey;
  final String initialColorHex;
  final int initialSortOrder;
  final bool isEdit;

  const _ConditionFormDialog({
    required this.initialName,
    required this.initialIconKey,
    required this.initialColorHex,
    required this.initialSortOrder,
    required this.isEdit,
  });

  @override
  State<_ConditionFormDialog> createState() => _ConditionFormDialogState();
}

class _ConditionFormDialogState extends State<_ConditionFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _sortController;
  late String _iconKey;
  late String _colorHex;

  static const _colorPresets = [
    ('6366F1', 'Purple'),
    ('3B82F6', 'Blue'),
    ('10B981', 'Green'),
    ('F59E0B', 'Amber'),
    ('EF4444', 'Red'),
    ('EC4899', 'Pink'),
    ('8B5CF6', 'Violet'),
    ('06B6D4', 'Cyan'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _sortController =
        TextEditingController(text: widget.initialSortOrder.toString());
    _iconKey = widget.initialIconKey;
    _colorHex = widget.initialColorHex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final sortOrder =
        int.tryParse(_sortController.text) ?? widget.initialSortOrder;
    Navigator.pop(
        context,
        _ConditionFormResult(
          name: name,
          iconKey: conditionIconRegistry.containsKey(_iconKey)
              ? _iconKey
              : 'healing',
          colorHex: _colorHex.length >= 6 ? _colorHex : '6366F1',
          sortOrder: sortOrder,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final keys = conditionIconRegistry.keys.toList()..sort();
    if (!keys.contains(_iconKey)) _iconKey = keys.first;

    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit condition' : 'Add condition'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Name'),
              controller: _nameController,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: keys.contains(_iconKey) ? _iconKey : keys.first,
              decoration: const InputDecoration(labelText: 'Icon'),
              isExpanded: true,
              items: keys
                  .map((k) => DropdownMenuItem(
                        value: k,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(conditionIconRegistry[k], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(k, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _iconKey = v ?? _iconKey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorPresets.map((preset) {
                final hex = preset.$1;
                final label = preset.$2;
                final isSelected =
                    _colorHex.toUpperCase().replaceAll('#', '') ==
                        hex.toUpperCase();
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _colorHex = hex),
                  selectedColor: Color(0xFF000000 + int.parse(hex, radix: 16)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Sort order',
                hintText: '0 = first',
              ),
              keyboardType: TextInputType.number,
              controller: _sortController,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _PlantSelectorDialog extends StatefulWidget {
  final String conditionName;
  final List<Plant> plants;
  final Set<String> selectedIds;

  const _PlantSelectorDialog({
    required this.conditionName,
    required this.plants,
    required this.selectedIds,
  });

  @override
  State<_PlantSelectorDialog> createState() => _PlantSelectorDialogState();
}

class _PlantSelectorDialogState extends State<_PlantSelectorDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Map plants to ${widget.conditionName}'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: ListView.builder(
          itemCount: widget.plants.length,
          itemBuilder: (ctx, i) {
            final p = widget.plants[i];
            final isSelected = _selected.contains(p.id);
            return CheckboxListTile(
              value: isSelected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(p.id);
                  } else {
                    _selected.remove(p.id);
                  }
                });
              },
              title: Text(p.commonName),
              subtitle: Text(p.scientificName,
                  style: const TextStyle(
                      fontStyle: FontStyle.italic, fontSize: 12)),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text('Save (${_selected.length} plants)'),
        ),
      ],
    );
  }
}
