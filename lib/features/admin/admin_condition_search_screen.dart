import 'package:flutter/material.dart';
import 'package:herbascan/core/constants/condition_icons.dart';
import 'package:herbascan/core/models/catalog_condition.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/services/catalog_plant_admin_service.dart';
import 'package:herbascan/core/services/database_service.dart';
import 'package:herbascan/core/services/plant_data_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';

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
  final DatabaseService _db = DatabaseService();

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
      // Load all bundled plants once for the keyword-match fallback
      final allPlants = PlantDataService.getAllMedicinalPlantsData();
      final counts = <int, int>{};
      for (var c in list) {
        // Step 1: check explicit cloud mappings in catalog_condition_plants
        final ids = await _admin.getPlantIdsForCatalogCondition(c.id);
        if (ids.isNotEmpty) {
          // Count only plants that actually exist in the local catalog
          final knownIds = allPlants.map((p) => p.id).toSet();
          counts[c.id] = ids.where((id) => knownIds.contains(id)).length;
        } else {
          // Step 2: fallback — keyword match on medicinalUses (same as browse screen)
          counts[c.id] = allPlants
              .where((p) => p.medicinalUses.any((use) =>
                  use.condition
                      .toLowerCase()
                      .contains(c.name.toLowerCase())))
              .length;
        }
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

  /// After any Supabase mutation, pull the latest conditions + plant links
  /// from Supabase and write them straight into local SQLite so the browse
  /// screen reflects the change immediately — no app restart needed.
  Future<void> _syncToLocal() async {
    try {
      // Re-fetch all conditions from Supabase
      final conditions = await _admin.listCatalogConditions();
      if (conditions.isNotEmpty) {
        await _db.replaceConditionsFromSync(conditions);
      }
      // Re-fetch all condition–plant links from Supabase
      final allPlants = PlantDataService.getAllMedicinalPlantsData();
      final pairs = <MapEntry<int, String>>[];
      for (final c in conditions) {
        final ids = await _admin.getPlantIdsForCatalogCondition(c.id);
        for (final pid in ids) {
          if (allPlants.any((p) => p.id == pid)) {
            pairs.add(MapEntry(c.id, pid));
          }
        }
      }
      // replaceConditionPlantsFromSync does a full replace, so only call
      // it when there are explicit mappings to avoid wiping keyword fallback
      if (pairs.isNotEmpty) {
        await _db.replaceConditionPlantsFromSync(pairs);
      }
    } catch (_) {
      // Sync failure is non-fatal — Supabase write already succeeded
    }
  }

  Future<void> _seedConditions() async {
    await _admin.seedCatalogConditionsFromDefaults();
    if (mounted) {
      await _syncToLocal();
      _load();
    }
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
      await _syncToLocal();
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
      await _syncToLocal();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Condition updated')));
      _load();
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to update')));
    }
  }

  Future<void> _showMapPlants(CatalogCondition c) async {
    final messenger = ScaffoldMessenger.of(context);
    final plantIds = await _admin.getPlantIdsForCatalogCondition(c.id);
    final plants = PlantDataService.getAllMedicinalPlantsData();
    final selected = Set<String>.from(plantIds);

    if (!mounted) return;

    // Use a bottom sheet instead of a dialog
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _PlantSelectorBottomSheet(
        conditionName: c.name,
        plants: plants,
        selectedIds: selected,
        onSave: (result) async {
          Navigator.pop(ctx);
          final ok = await _admin.saveConditionPlants(c.id, result.toList());
          if (ok && mounted) {
            await _syncToLocal();
            messenger.showSnackBar(
              SnackBar(
                  content:
                      Text('Mapped ${result.length} plants to ${c.name}')),
            );
            _load();
          } else if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                  content: Text('Failed to save plant mapping')),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteCondition(CatalogCondition c) async {
    if (c.isDefault) return;
    final theme = Theme.of(context);
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
                style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await _admin.deleteCatalogCondition(c.id);
    if (ok && mounted) {
      await _syncToLocal();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Condition deleted')));
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
            automaticallyImplyLeading: false,
            title: const Text('Health Conditions'),
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
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Manage conditions that appear in Browse.',
                style: theme.textTheme.bodySmall?.copyWith(
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
                  return _buildConditionRow(context, theme, c, count);
                },
                childCount: _conditions.length,
              ),
            ),
          // bottom padding for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCondition,
        backgroundColor: AppTheme.botanicalPrimary,
        foregroundColor: Colors.white,
        tooltip: 'New Condition',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildConditionRow(BuildContext context, ThemeData theme,
      CatalogCondition c, int count) {
    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                Icon(getConditionIcon(c.iconKey), color: c.color, size: 22),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  c.name,
                  overflow: TextOverflow.visible,
                  maxLines: 2,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              if (c.isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('Default',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ),
              ],
            ],
          ),
          subtitle: Text('$count plant${count == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall),
          trailing: c.isDefault
              ? IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  tooltip: 'Map plants',
                  onPressed: () => _showMapPlants(c),
                )
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (action) {
                    switch (action) {
                      case 'link':
                        _showMapPlants(c);
                      case 'edit':
                        _showEditCondition(c);
                      case 'delete':
                        _deleteCondition(c);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'link',
                      child: Row(children: [
                        Icon(Icons.link),
                        SizedBox(width: 12),
                        Text('Map Plants'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            color: theme.colorScheme.error),
                        const SizedBox(width: 12),
                        Text('Delete',
                            style: TextStyle(
                                color: theme.colorScheme.error)),
                      ]),
                    ),
                  ],
                ),
        ),
        const Divider(height: 1, indent: 72),
      ],
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
    _iconKey = widget.initialIconKey;
    _colorHex = widget.initialColorHex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    // Auto-assign sort order from list length (UI hides this from user)
    Navigator.pop(
      context,
      _ConditionFormResult(
        name: name,
        iconKey: conditionIconRegistry.containsKey(_iconKey)
            ? _iconKey
            : 'healing',
        colorHex: _colorHex.length >= 6 ? _colorHex : '6366F1',
        sortOrder: widget.initialSortOrder,
      ),
    );
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
            const Text('Icon',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: keys.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (ctx, i) {
                  final k = keys[i];
                  final isSelected = _iconKey == k;
                  return GestureDetector(
                    onTap: () => setState(() => _iconKey = k),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.botanicalPrimary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: AppTheme.botanicalPrimary, width: 2)
                            : null,
                      ),
                      child: Icon(conditionIconRegistry[k],
                          size: 22,
                          color: isSelected
                              ? AppTheme.botanicalPrimary
                              : null),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('Color',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
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
                  selectedColor:
                      Color(0xFF000000 + int.parse(hex, radix: 16)),
                );
              }).toList(),
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

/// Bottom sheet for mapping plants to a condition.
class _PlantSelectorBottomSheet extends StatefulWidget {
  final String conditionName;
  final List<Plant> plants;
  final Set<String> selectedIds;
  final void Function(Set<String>) onSave;

  const _PlantSelectorBottomSheet({
    required this.conditionName,
    required this.plants,
    required this.selectedIds,
    required this.onSave,
  });

  @override
  State<_PlantSelectorBottomSheet> createState() =>
      _PlantSelectorBottomSheetState();
}

class _PlantSelectorBottomSheetState
    extends State<_PlantSelectorBottomSheet> {
  late Set<String> _selected;
  final TextEditingController _searchCtrl = TextEditingController();
  List<Plant> _filtered = [];

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedIds);
    _filtered = List.from(widget.plants);
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_filter);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(widget.plants)
          : widget.plants
              .where((p) =>
                  p.commonName.toLowerCase().contains(q) ||
                  p.scientificName.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Grabber
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Map plants — ${widget.conditionName}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton(
                  onPressed: () => widget.onSave(_selected),
                  child: Text('Save (${_selected.length})'),
                ),
              ],
            ),
          ),
          // Pinned search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search plants…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final p = _filtered[i];
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
                  activeColor: AppTheme.botanicalPrimary,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

