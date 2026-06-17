import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/models/catalog_condition.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/services/condition_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/plant_image.dart';
import 'package:herbascan/features/scan/plant_detail_screen.dart';

class ConditionResultsScreen extends StatefulWidget {
  final CatalogCondition condition;

  const ConditionResultsScreen({super.key, required this.condition});

  @override
  State<ConditionResultsScreen> createState() => _ConditionResultsScreenState();
}

class _ConditionResultsScreenState extends State<ConditionResultsScreen> {
  List<Plant> _plants = [];
  bool _loading = true;
  final ConditionService _conditionService = ConditionService();

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    final plantProvider = Provider.of<PlantProvider>(context, listen: false);
    final plantIds =
        await _conditionService.getPlantIdsForCondition(widget.condition.id);

    List<Plant> plants;
    if (plantIds.isNotEmpty) {
      plants =
          plantProvider.plants.where((p) => plantIds.contains(p.id)).toList();
    } else {
      plants = plantProvider.getPlantsByCondition(widget.condition.name);
    }

    if (mounted) {
      setState(() {
        _plants = plants;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.condition.name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plants.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _plants.length,
                  itemBuilder: (context, index) =>
                      _buildListCard(_plants[index], theme),
                ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No plants found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No plants are mapped to "${widget.condition.name}" yet.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(Plant plant, ThemeData theme) {
    final showLocalName =
        plant.localName.isNotEmpty && plant.localName != plant.commonName;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlantDetailScreen(plant: plant),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Circular plant image 56x56
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: PlantImage(
                  plant: plant,
                  fit: BoxFit.cover,
                  width: 56,
                  height: 56,
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.safeBgLight,
                    child: const Icon(
                      Icons.local_florist_rounded,
                      size: 28,
                      color: AppTheme.botanicalPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plant.commonName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (plant.isDOHApproved) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppTheme.botanicalPrimary,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plant.scientificName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showLocalName) ...[
                      const SizedBox(height: 2),
                      Text(
                        plant.localName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
