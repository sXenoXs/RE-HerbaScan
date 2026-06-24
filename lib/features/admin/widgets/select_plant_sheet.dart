import 'package:flutter/material.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/services/catalog_plant_admin_service.dart';
import 'package:herbascan/core/services/plant_data_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/plant_image.dart';

class SelectPlantSheet extends StatefulWidget {
  const SelectPlantSheet({
    super.key,
    required this.title,
    this.filter,
    required this.onPlantSelected,
  });

  final String title;
  /// Optional filter. Return true to include the plant in the list.
  final bool Function(Plant plant, CatalogPlantEntry? cloudEntry)? filter;
  final void Function(Plant plant, CatalogPlantEntry? cloudEntry) onPlantSelected;

  @override
  State<SelectPlantSheet> createState() => _SelectPlantSheetState();
}

class _SelectPlantSheetState extends State<SelectPlantSheet> {
  List<Plant> _allPlants = [];
  Map<String, CatalogPlantEntry> _cloudById = {};
  List<Plant> _filteredPlants = [];
  bool _loading = true;
  String? _error;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applySearchFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final localPlants = PlantDataService.getAllMedicinalPlantsData();
      final cloudEntries = await CatalogPlantAdminService().listCatalogPlantsWithStatus();
      
      if (mounted) {
        final localIds = {for (final p in localPlants) p.id};
        final cloudOnlyStubs = cloudEntries
            .where((e) => !localIds.contains(e.id))
            .map((e) => Plant(
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
                ))
            .toList();

        final all = [...localPlants, ...cloudOnlyStubs];
        final cloudMap = {for (final e in cloudEntries) e.id: e};

        // Apply caller's filter
        final initialFiltered = all.where((p) {
          if (widget.filter != null) {
            return widget.filter!(p, cloudMap[p.id]);
          }
          return true;
        }).toList();

        setState(() {
          _allPlants = initialFiltered;
          _cloudById = cloudMap;
          _filteredPlants = initialFiltered;
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

  void _applySearchFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredPlants = _allPlants.where((p) {
        if (q.isEmpty) return true;
        return p.commonName.toLowerCase().contains(q) ||
               p.scientificName.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search plants...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            
            // List
            if (_filteredPlants.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No plants found.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _filteredPlants.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                  itemBuilder: (context, index) {
                    final plant = _filteredPlants[index];
                    final cloudEntry = _cloudById[plant.id];
                    final status = cloudEntry?.status ?? 'active';
                    final isDraft = status == 'draft';
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: PlantImage(plant: plant, fit: BoxFit.cover),
                        ),
                      ),
                      title: Text(
                        plant.commonName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        plant.scientificName,
                        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                      ),
                      trailing: isDraft
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.warningAmber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Draft',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.warningAmber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context); // Close sheet
                        widget.onPlantSelected(plant, cloudEntry);
                      },
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}
