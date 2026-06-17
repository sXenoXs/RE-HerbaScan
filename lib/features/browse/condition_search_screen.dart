import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/constants/condition_icons.dart';
import 'package:herbascan/core/models/catalog_condition.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/services/condition_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/features/browse/condition_results_screen.dart';

class ConditionSearchScreen extends StatefulWidget {
  const ConditionSearchScreen({super.key});

  @override
  State<ConditionSearchScreen> createState() => _ConditionSearchScreenState();
}

class _ConditionSearchScreenState extends State<ConditionSearchScreen> {
  List<CatalogCondition> _conditions = [];
  bool _loadingConditions = true;
  final ConditionService _conditionService = ConditionService();

  @override
  void initState() {
    super.initState();
    _loadConditions();
  }

  Future<void> _loadConditions() async {
    final list = await _conditionService.getConditions();
    if (mounted) {
      setState(() {
        _conditions = list;
        _loadingConditions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Conditions'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Select a condition to find recommended remedies.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: _loadingConditions
                ? const Center(child: CircularProgressIndicator())
                : _buildConditionGrid(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionGrid(ThemeData theme) {
    if (_conditions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_services_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No conditions available',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: _conditions.length,
      itemBuilder: (context, index) {
        return _buildConditionCard(_conditions[index], theme);
      },
    );
  }

  Widget _buildConditionCard(CatalogCondition condition, ThemeData theme) {
    final icon = getConditionIcon(condition.iconKey);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
              builder: (_) => ConditionResultsScreen(condition: condition),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.botanicalPrimary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: AppTheme.botanicalPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Text(
                  condition.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              _PlantCountPill(
                conditionId: condition.id,
                conditionName: condition.name,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlantCountPill extends StatefulWidget {
  final int conditionId;
  final String conditionName;

  const _PlantCountPill({
    required this.conditionId,
    required this.conditionName,
  });

  @override
  State<_PlantCountPill> createState() => _PlantCountPillState();
}

class _PlantCountPillState extends State<_PlantCountPill> {
  int? _count;
  final ConditionService _conditionService = ConditionService();

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final plantProvider = Provider.of<PlantProvider>(context, listen: false);
    final ids =
        await _conditionService.getPlantIdsForCondition(widget.conditionId);

    int count;
    if (ids.isNotEmpty) {
      count = plantProvider.plants.where((p) => ids.contains(p.id)).length;
    } else {
      count = plantProvider.getPlantsByCondition(widget.conditionName).length;
    }

    if (mounted) {
      setState(() {
        _count = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_count == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.botanicalPrimary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '$_count plants',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme.botanicalPrimary,
        ),
      ),
    );
  }
}
