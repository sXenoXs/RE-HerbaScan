import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/features/scan/plant_detail_screen.dart';
import 'package:herbascan/features/browse/condition_search_screen.dart';
import 'package:herbascan/core/services/usage_analytics.dart';
import 'dart:io';

enum BrowseFilter { all, doh, byCondition }

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final TextEditingController _searchController = TextEditingController();
  final UsageAnalytics _analytics = UsageAnalytics();
  BrowseFilter _selectedFilter = BrowseFilter.all;
  String _searchQuery = '';
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    // Track browse screen view
    _analytics.trackBrowseViewed();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Plant> _filterPlants(List<Plant> plants) {
    List<Plant> filtered = plants;

    // Apply filter
    switch (_selectedFilter) {
      case BrowseFilter.all:
        // No filter
        break;
      case BrowseFilter.doh:
        filtered = filtered.where((plant) => plant.isDOHApproved).toList();
        break;
      case BrowseFilter.byCondition:
        // For now, show all plants with medicinal uses
        filtered =
            filtered.where((plant) => plant.medicinalUses.isNotEmpty).toList();
        break;
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((plant) {
        final query = _searchQuery.toLowerCase();
        return plant.commonName.toLowerCase().contains(query) ||
            plant.scientificName.toLowerCase().contains(query) ||
            plant.localName.toLowerCase().contains(query) ||
            plant.medicinalUses
                .any((use) => use.condition.toLowerCase().contains(query));
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLocalizations = AppLocalizations.of(context);
    final plantProvider = Provider.of<PlantProvider>(context);
    final filteredPlants = _filterPlants(plantProvider.plants);

    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.browse),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: _isGridView ? 'List View' : 'Grid View',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: appLocalizations.searchPlants,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildFilterChip(
                  appLocalizations.allPlants,
                  BrowseFilter.all,
                  theme,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  appLocalizations.dohApproved,
                  BrowseFilter.doh,
                  theme,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  appLocalizations.byCondition,
                  BrowseFilter.byCondition,
                  theme,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  '${filteredPlants.length} ${appLocalizations.plantCount}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Plant List/Grid
          Expanded(
            child: plantProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredPlants.isEmpty
                    ? _buildEmptyState(context, theme, appLocalizations)
                    : _isGridView
                        ? _buildGridView(filteredPlants, theme)
                        : _buildListView(filteredPlants, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, BrowseFilter filter, ThemeData theme) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        // Navigate to condition search screen for "By Condition" filter
        if (filter == BrowseFilter.byCondition) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ConditionSearchScreen(),
            ),
          );
        } else {
          setState(() {
            _selectedFilter = filter;
          });
        }
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme,
      AppLocalizations appLocalizations) {
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
            appLocalizations.noResultsFound,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            appLocalizations.tryDifferentSearch,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<Plant> plants, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: plants.length,
      itemBuilder: (context, index) {
        final plant = plants[index];
        return _buildPlantGridCard(plant, theme);
      },
    );
  }

  Widget _buildListView(List<Plant> plants, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: plants.length,
      itemBuilder: (context, index) {
        final plant = plants[index];
        return _buildPlantListCard(plant, theme);
      },
    );
  }

  Widget _buildPlantGridCard(Plant plant, ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Track plant view
          _analytics.trackPlantViewed();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlantDetailScreen(plant: plant),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plant Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: theme.colorScheme.surfaceContainerHighest,
                child: plant.imagePath.isNotEmpty
                    ? Image.file(
                        File(plant.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage(theme);
                        },
                      )
                    : _buildPlaceholderImage(theme),
              ),
            ),
            // Plant Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plant.commonName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plant.scientificName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (plant.isDOHApproved)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF48BB78).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF48BB78),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified,
                              size: 12,
                              color: Color(0xFF48BB78),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'DOH',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF48BB78),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantListCard(Plant plant, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Track plant view
          _analytics.trackPlantViewed();
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
                child: plant.imagePath.isNotEmpty
                    ? Image.file(
                        File(plant.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage(theme);
                        },
                      )
                    : _buildPlaceholderImage(theme),
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
                    const SizedBox(height: 4),
                    Text(
                      plant.localName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    if (plant.isDOHApproved) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF48BB78).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF48BB78),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified,
                              size: 14,
                              color: Color(0xFF48BB78),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'DOH Approved',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF48BB78),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

  Widget _buildPlaceholderImage(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.local_florist,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
      ),
    );
  }
}
