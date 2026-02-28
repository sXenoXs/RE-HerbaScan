import 'package:flutter/material.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/services/habitat_service.dart';
import 'package:herbascan/core/widgets/contraindication_engine_widget.dart';
import 'package:herbascan/features/scan/habitat_map_screen.dart';
import 'package:herbascan/features/scan/preparation_instructions_screen.dart';

class PlantDetailScreen extends StatefulWidget {
  final Plant plant;

  const PlantDetailScreen({
    super.key,
    required this.plant,
  });

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            // App Bar with Plant Image
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              centerTitle: true,
              forceElevated: innerBoxIsScrolled,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  widget.plant.commonName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3.0,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Plant image or gradient background
                    widget.plant.imagePath.isNotEmpty
                        ? Image.asset(
                            widget.plant.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.secondary,
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              ),
                            ),
                          ),
                    // Overlay for better text readability
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Scientific Name, English Name, and DOH Badge
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      widget.plant.scientificName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.plant.englishName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    if (widget.plant.isDOHApproved)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                              0xFF48BB78), // Vibrant green for better visibility
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF48BB78).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'DOH Approved',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Tab Bar - Pinned at the top when scrolling
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: false, // Fixed tabs, evenly distributed
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.science, size: 22), text: 'Taxonomy'),
                    Tab(icon: Icon(Icons.nature, size: 22), text: 'Ecology'),
                    Tab(
                        icon: Icon(Icons.medical_services, size: 22),
                        text: 'Medicinal'),
                    Tab(icon: Icon(Icons.warning, size: 22), text: 'Safety'),
                  ],
                ),
                theme.colorScheme.surface,
              ),
            ),
          ];
        },
        // Tab Views - Body content that scrolls with the header
        body: TabBarView(
          controller: _tabController,
          physics: const ClampingScrollPhysics(), // Enable swipe navigation
          children: [
            _buildTaxonomyTab(theme),
            _buildEcologyTab(theme),
            _buildMedicinalTab(theme),
            _buildSafetyTab(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxonomyTab(ThemeData theme) {
    return Builder(
      builder: (context) {
        return CustomScrollView(
          // Use the inner scroll controller from NestedScrollView
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionTitle('Scientific Classification', theme),
                  const SizedBox(height: 12),
                  _buildTaxonomyCard(theme),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Morphology', theme),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    theme,
                    widget.plant.morphology,
                    Icons.eco,
                  ),
                  const SizedBox(
                      height:
                          20), // Extra padding at bottom for better scrolling
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEcologyTab(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionTitle('Ecology', theme),
              const SizedBox(height: 12),
              _buildInfoCard(
                theme,
                widget.plant.ecology,
                Icons.public,
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Habitat', theme),
              const SizedBox(height: 12),
              _buildInfoCard(
                theme,
                widget.plant.habitat,
                Icons.landscape,
              ),
              const SizedBox(height: 20),
              FutureBuilder<bool>(
                future: HabitatService().hasHabitatData(widget.plant.id),
                builder: (context, snapshot) {
                  if (snapshot.data != true) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildHabitatMapCard(theme, l10n),
                  );
                },
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicinalTab(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionTitle('Medicinal Uses', theme),
              const SizedBox(height: 12),
              ...widget.plant.medicinalUses
                  .map((use) => _buildMedicinalUseCard(theme, use)),
              const SizedBox(height: 20),
              _buildSectionTitle('Preparation Methods', theme),
              const SizedBox(height: 12),
              ...widget.plant.preparationMethods
                  .map((method) => _buildPreparationMethodCard(theme, method)),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyTab(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionTitle('⚠️ Safety & Contraindications', theme),
              const SizedBox(height: 12),
              ContraindicationEngineWidget(plant: widget.plant),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildTaxonomyCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTaxonomyRow('Kingdom', 'Plantae', theme),
            const Divider(),
            _buildTaxonomyRow('Family', widget.plant.family, theme),
            const Divider(),
            _buildTaxonomyRow('Genus', widget.plant.genus, theme),
            const Divider(),
            _buildTaxonomyRow('Species', widget.plant.species, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxonomyRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, String content, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitatMapCard(
      ThemeData theme, AppLocalizations l10n) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => HabitatMapScreen(plant: widget.plant),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.viewHabitatMap,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.whereItGrows,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicinalUseCard(ThemeData theme, MedicinalUse use) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: Icon(
          Icons.local_hospital,
          color: const Color(0xFF48BB78), // Vibrant green for better visibility
          size: 28,
        ),
        title: Text(
          use.condition,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            use.effectiveness,
            style: TextStyle(
              color:
                  const Color(0xFF38A169), // Darker green for better contrast
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  use.description,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 12),
                _buildInfoItem(
                    'Active Compounds', use.activeCompounds.join(', '), theme),
                _buildInfoItem('Dosage', use.dosage, theme),
                _buildInfoItem('Duration', use.duration, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreparationMethodCard(
      ThemeData theme, PreparationMethod method) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PreparationInstructionsScreen(
                plant: widget.plant,
                preparationMethod: method,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF48BB78), // Vibrant green background
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.medical_information,
                  color: Colors.white, // White icon for better contrast
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'For ${method.condition}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38A169)
                            .withOpacity(0.15), // Light green background
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF38A169).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        method.preparationType.toUpperCase(),
                        style: TextStyle(
                          color: const Color(0xFF38A169), // Dark green text
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom delegate for the TabBar to be used as a pinned SliverPersistentHeader
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
