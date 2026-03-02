import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/constants/condition_icons.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/models/catalog_condition.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/services/condition_service.dart';
import 'package:herbascan/core/widgets/plant_image.dart';
import 'package:herbascan/features/scan/plant_detail_screen.dart';

class ConditionSearchScreen extends StatefulWidget {
  const ConditionSearchScreen({super.key});

  @override
  State<ConditionSearchScreen> createState() => _ConditionSearchScreenState();
}

class _ConditionSearchScreenState extends State<ConditionSearchScreen>
    with AutomaticKeepAliveClientMixin {
  CatalogCondition? _selectedCondition;
  List<Plant> _filteredPlants = [];
  List<CatalogCondition> _conditions = [];
  bool _loadingConditions = true;
  final ConditionService _conditionService = ConditionService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadConditions();
  }

  Future<void> _loadConditions() async {
    final list = await _conditionService.getConditions();
    if (mounted) setState(() {
      _conditions = list;
      _loadingConditions = false;
    });
  }

  Future<void> _selectCondition(CatalogCondition condition) async {
    final plantProvider = Provider.of<PlantProvider>(context, listen: false);
    final plantIds = await _conditionService.getPlantIdsForCondition(condition.id);
    List<Plant> plants;
    if (plantIds.isNotEmpty) {
      plants = plantProvider.plants.where((p) => plantIds.contains(p.id)).toList();
    } else {
      plants = plantProvider.getPlantsByCondition(condition.name);
    }
    if (mounted) setState(() {
      _selectedCondition = condition;
      _filteredPlants = plants;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final appLocalizations = AppLocalizations.of(context);

    return PopScope(
      canPop: _selectedCondition == null,
      onPopInvoked: (didPop) {
        if (!didPop && _selectedCondition != null) {
          // Clear the selected condition instead of popping
          setState(() {
            _selectedCondition = null;
            _filteredPlants = [];
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(appLocalizations.browseByCondition),
        ),
        body: Column(
          children: [
            // Header Info
            if (_selectedCondition == null)
              _buildHeader(context, theme, appLocalizations),

            // Selected Condition Banner
            if (_selectedCondition != null)
              _buildSelectedConditionBanner(theme),

            // Content
            Expanded(
              child: _loadingConditions
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedCondition == null
                      ? _buildConditionGrid(theme)
                      : _buildPlantResults(theme, appLocalizations),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme,
      AppLocalizations appLocalizations) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_hospital,
            size: 40,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            appLocalizations.browseByCondition,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            appLocalizations.selectCondition,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedConditionBanner(ThemeData theme) {
    final c = _selectedCondition!;
    final color = c.color;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(getConditionIcon(c.iconKey), color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '${_filteredPlants.length} plants found',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCondition = null;
                _filteredPlants = [];
              });
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionGrid(ThemeData theme) {
    return GridView.builder(
      key: const PageStorageKey<String>('condition_search_grid'),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: _conditions.length,
      itemBuilder: (context, index) {
        final condition = _conditions[index];
        return _buildConditionCard(condition, theme);
      },
    );
  }

  Widget _buildConditionCard(CatalogCondition condition, ThemeData theme) {
    final name = condition.name;
    final icon = getConditionIcon(condition.iconKey);
    final color = condition.color;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: () => _selectCondition(condition),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlantResults(
      ThemeData theme, AppLocalizations appLocalizations) {
    if (_filteredPlants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No plants found for this condition',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: PageStorageKey<String>('condition_search_plants_${_selectedCondition?.name ?? ''}'),
      padding: const EdgeInsets.all(16),
      itemCount: _filteredPlants.length,
      itemBuilder: (context, index) {
        final plant = _filteredPlants[index];
        return _buildPlantCard(plant, theme);
      },
    );
  }

  Widget _buildPlantCard(Plant plant, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlantDetailScreen(plant: plant),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Plant Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: PlantImage(
                  plant: plant,
                  fit: BoxFit.cover,
                  width: 80,
                  height: 80,
                  errorWidget: (_, __, ___) => _buildPlaceholderImage(theme),
                ),
              ),
              const SizedBox(width: 16),
              // Plant Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.commonName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plant.scientificName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getRelevantUses(plant),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _getRelevantUses(Plant plant) {
    final conditionName = _selectedCondition?.name ?? '';
    final relevantUses = plant.medicinalUses
        .where((use) => use.condition.contains(conditionName))
        .map((use) => use.condition)
        .toList();

    if (relevantUses.isNotEmpty) {
      return relevantUses.join(', ');
    }

    // Fallback to all conditions if no exact match
    return plant.medicinalUses.map((use) => use.condition).take(2).join(', ');
  }

  Widget _buildPlaceholderImage(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.local_florist,
        size: 40,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
      ),
    );
  }
}
