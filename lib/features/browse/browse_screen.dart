import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/toxic_plant_entry.dart';
import 'package:herbascan/core/services/toxic_plant_image_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/plant_image.dart';
import 'package:herbascan/features/scan/plant_detail_screen.dart';
import 'package:herbascan/features/browse/condition_search_screen.dart';
import 'package:herbascan/features/browse/toxic_plant_detail_screen.dart';
import 'package:herbascan/core/services/usage_analytics.dart';

enum BrowseFilter { all, doh, toxic }

// ---------------------------------------------------------------------------
// Static toxic / harmful plant data
// ---------------------------------------------------------------------------
const _toxicPlants = [
  ToxicPlantEntry(
    slug: 'dumb-cane',
    commonName: 'Dumb Cane',
    scientificName: 'Dieffenbachia picta',
    harm: 'Heavy toxins',
    toxin: 'Calcium oxalate crystals',
    symptoms:
        'Intense oral burning, swollen tongue and throat, impaired speech, difficulty swallowing',
    appearance:
        'Large tropical shrub with broad, glossy leaves patterned in green and white or yellow. Stems are thick and cane-like, reaching up to 1.5 m indoors.',
    habitat:
        'Native to tropical Americas; widely cultivated as an indoor ornamental plant in the Philippines and worldwide.',
  ),
  ToxicPlantEntry(
    slug: 'physic-nut-tuba-tuba',
    commonName: 'Physic Nut / Tuba-tuba',
    scientificName: 'Jatropha curcas',
    localName: 'Tuba-tuba',
    harm: 'Poisoning in children',
    toxin: 'Curcin (toxalbumin), phorbol esters',
    symptoms:
        'Nausea, vomiting, severe diarrhea, abdominal pain; potentially fatal in children',
    appearance:
        'Small deciduous tree or large shrub with smooth, pale-grey bark. Leaves are broadly ovate with 3–5 lobes; flowers are small and yellowish-green. Seeds resemble edible nuts.',
    habitat:
        'Thrives in tropical and subtropical areas. Found along roadsides, farm borders, and abandoned lots throughout the Philippines.',
  ),
  ToxicPlantEntry(
    slug: 'snake-plant',
    commonName: 'Snake Plant',
    scientificName: 'Dracaena trifasciata',
    localName: 'Espada',
    harm: 'Mild toxins',
    toxin: 'Steroidal saponins',
    symptoms: 'Nausea, vomiting, excessive salivation, mild mouth irritation',
    appearance:
        'Stiff, upright sword-shaped leaves with dark green banding and yellow margins. Grows in rosette clumps up to 1 m tall.',
    habitat:
        'Native to West Africa; extremely common as a low-maintenance indoor and outdoor ornamental plant in Filipino homes and offices.',
  ),
  ToxicPlantEntry(
    slug: 'cycads',
    commonName: 'Cycads',
    scientificName: 'Cycadophyta',
    localName: 'Pitogo',
    harm: 'Heavy toxins',
    toxin: 'Cycasin, BMAA neurotoxin',
    symptoms:
        'Vomiting, liver damage, neurological deterioration; potentially fatal',
    appearance:
        'Palm-like plants with a stout trunk topped by a crown of stiff, pinnate fronds. Seeds are large, orange-red, and nut-like in appearance.',
    habitat:
        'Found in tropical and subtropical forests, coastal areas, and rocky slopes. Several species are native to the Philippines (e.g., Cycas riuminiana).',
  ),
  ToxicPlantEntry(
    slug: 'daphne',
    commonName: 'Daphne',
    scientificName: 'Daphne laureola',
    harm: 'Blistering, irritation',
    toxin: 'Daphnetoxin, mezerein',
    symptoms:
        'Severe mouth and skin blistering, vomiting; convulsions in large doses',
    appearance:
        'Evergreen shrub with glossy, dark-green leathery leaves. Produces small tubular flowers (white, pink, or yellow) and bright red or black berries.',
    habitat:
        'Native to Europe and Asia; grown as an ornamental shrub in gardens. Prefers cool, well-drained soils in partial shade.',
  ),
  ToxicPlantEntry(
    slug: 'angels-trumpet',
    commonName: "Angel's Trumpet",
    scientificName: 'Brugmansia spp.',
    localName: 'Kampanilya',
    harm: 'Toxic',
    toxin: 'Scopolamine, atropine, hyoscyamine',
    symptoms:
        'Hallucinations, delirium, rapid heartbeat, dilated pupils, respiratory failure',
    appearance:
        'Large woody shrub or small tree with pendulous, trumpet-shaped flowers up to 50 cm long in white, yellow, pink, or orange. Large, oval, softly hairy leaves.',
    habitat:
        'Grown as an ornamental in Philippine gardens and parks. Prefers warm, humid climates with well-drained soil.',
  ),
  ToxicPlantEntry(
    slug: 'lantana',
    commonName: 'Lantana',
    scientificName: 'Lantana camara',
    localName: 'Kambantiling',
    harm: 'Toxic berries',
    toxin: 'Lantadene A & B',
    symptoms:
        'Vomiting, diarrhea, liver damage from unripe berries; photosensitization',
    appearance:
        'Woody shrub with rough, aromatic leaves. Bears small clustered flowers that change colour as they mature (yellow to orange to red). Unripe berries are green, ripening to black.',
    habitat:
        'Invasive weed throughout the Philippines; common along roadsides, forest edges, and disturbed lands in tropical lowland areas.',
  ),
  ToxicPlantEntry(
    slug: 'calla-lily',
    commonName: 'Calla Lily',
    scientificName: 'Zantedeschia spp.',
    localName: 'Calla',
    harm: 'Toxic',
    toxin: 'Calcium oxalate crystals',
    symptoms:
        'Intense oral burning, lip and tongue swelling, difficulty swallowing',
    appearance:
        'Elegant perennial with large, arrow-shaped glossy leaves and a distinctive funnel-shaped spathe (usually white) surrounding a yellow spike (spadix).',
    habitat:
        'Native to southern Africa; commonly grown as a garden and cut-flower ornamental in the Philippines, preferring moist, fertile soils.',
  ),
  ToxicPlantEntry(
    slug: 'poinsettia',
    commonName: 'Poinsettia',
    scientificName: 'Euphorbia pulcherrima',
    localName: 'Pascua',
    harm: 'Irritant sap',
    toxin: 'Euphorbol esters, saponins',
    symptoms: 'Skin and eye irritation; mild nausea and vomiting if ingested',
    appearance:
        'Shrub with dark green leaves and vivid red (or pink/white) bracts surrounding small yellow flowers. White milky sap is released when stems are cut.',
    habitat:
        'Native to Mexico; popular Christmas ornamental widely sold and planted in Philippine homes and gardens throughout the holiday season.',
  ),
  ToxicPlantEntry(
    slug: 'cacti-and-succulents',
    commonName: 'Cacti and Succulents',
    scientificName: 'Various',
    localName: 'Kaktus',
    harm: 'Physical harm (thorns)',
    toxin: 'Spines; alkaloids in select species',
    symptoms: 'Puncture wounds; certain species cause nausea or hallucinations',
    appearance:
        'Highly variable; typically thick, fleshy stems or leaves adapted to store water. Spines replace leaves in true cacti. Shapes range from globular to columnar to paddle-like.',
    habitat:
        'Popular pot plants and garden ornamentals across the Philippines. In the wild, cacti are native to the Americas; succulents occur globally in arid and semi-arid regions.',
  ),
  ToxicPlantEntry(
    slug: 'rhus-wax-tree',
    commonName: 'Rhus / Wax Tree',
    scientificName: 'Toxicodendron spp.',
    harm: 'Allergic reactions',
    toxin: 'Urushiol (phenolic resin)',
    symptoms:
        'Severe allergic contact dermatitis, intense itching, fluid-filled blisters',
    appearance:
        'Deciduous shrubs or small trees with compound leaves of 3–13 leaflets. Produces small whitish-green flowers and waxy, pale berries. Leaves turn vivid red in autumn.',
    habitat:
        'Native to temperate North America and East Asia. Occasionally encountered as an ornamental or naturalized plant; all plant parts exude urushiol sap.',
  ),
];

Color _harmColor(String harm) {
  final h = harm.toLowerCase();
  if (h.contains('heavy') || h.contains('poison') || h.contains('toxic')) {
    return Colors.red.shade700;
  }
  if (h.contains('mild') || h.contains('irritant') || h.contains('blister')) {
    return Colors.orange.shade700;
  }
  return Colors.orange.shade700;
}

// ---------------------------------------------------------------------------

class BrowseScreen extends StatefulWidget {
  final BrowseFilter initialFilter;

  const BrowseScreen({super.key, this.initialFilter = BrowseFilter.all});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final UsageAnalytics _analytics = UsageAnalytics();
  final ToxicPlantImageService _toxicImageService = ToxicPlantImageService();

  late BrowseFilter _selectedFilter;
  String _searchQuery = '';
  bool _isGridView = true;

  // slug → imageUrl, loaded from Supabase
  Map<String, String> _toxicPlantImages = {};

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _analytics.trackBrowseViewed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final plantProvider = Provider.of<PlantProvider>(context, listen: false);
      plantProvider.refreshPlants();
    });
    _loadToxicPlantImages();
  }

  Future<void> _loadToxicPlantImages() async {
    final images = await _toxicImageService.getImageUrls();
    if (mounted) setState(() => _toxicPlantImages = images);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<Plant> _filterPlants(List<Plant> plants) {
    List<Plant> filtered = plants;

    if (_selectedFilter == BrowseFilter.doh) {
      filtered = filtered.where((plant) => plant.isDOHApproved).toList();
    }

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

  List<ToxicPlantEntry> _filterToxicPlants() {
    if (_searchQuery.isEmpty) return _toxicPlants;
    final query = _searchQuery.toLowerCase();
    return _toxicPlants.where((p) {
      return p.commonName.toLowerCase().contains(query) ||
          p.scientificName.toLowerCase().contains(query) ||
          p.localName.toLowerCase().contains(query) ||
          p.harm.toLowerCase().contains(query) ||
          p.toxin.toLowerCase().contains(query) ||
          p.symptoms.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plantProvider = Provider.of<PlantProvider>(context);
    final filteredPlants = _filterPlants(plantProvider.plants);
    final filteredToxic = _filterToxicPlants();

    final isToxic = _selectedFilter == BrowseFilter.toxic;
    final showingCount = isToxic ? filteredToxic.length : filteredPlants.length;

    return GestureDetector(
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: RefreshIndicator(
          onRefresh: () async {
            if (isToxic) {
              await _loadToxicPlantImages();
            } else {
              await context.read<PlantProvider>().refreshPlants();
            }
          },
          child: CustomScrollView(
            slivers: [
            // Safe-area top padding
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
            ),

            // Search bar — constrained to 48px height
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  height: 48,
                  child: SearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    hintText: isToxic
                        ? 'Search ${_toxicPlants.length} Toxic Plants'
                        : 'Search ${plantProvider.plants.length} Plants',
                    leading: Icon(
                      Icons.search_rounded,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      size: 20,
                    ),
                    trailing: _searchQuery.isNotEmpty
                        ? [
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ]
                        : null,
                    elevation: const WidgetStatePropertyAll(2),
                    backgroundColor: WidgetStatePropertyAll(
                      theme.colorScheme.surface,
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 16),
                    ),
                    textStyle: WidgetStatePropertyAll(
                      theme.textTheme.bodyMedium,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
            ),

            // Segmented filter SliverToBoxAdapter
            // Added showSelectedIcon: false to reclaim the checkmark's ~24dp, and
            // textStyle at 12sp so all three labels fit on one line at ~109dp per segment.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SegmentedButton<BrowseFilter>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: BrowseFilter.all,
                      label: Text('All Plants'),
                      icon: Icon(Icons.eco_rounded),
                    ),
                    ButtonSegment(
                      value: BrowseFilter.doh,
                      label: Text('DOH Approved'),
                      icon: Icon(Icons.verified_rounded),
                    ),
                    ButtonSegment(
                      value: BrowseFilter.toxic,
                      label: Text('Toxic Plants'),
                      icon: Icon(Icons.warning_amber_rounded),
                    ),
                  ],
                  selected: {_selectedFilter},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedFilter = selection.first;
                    });
                  },
                  style: ButtonStyle(
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) {
                        if (states.contains(WidgetState.selected)) {
                          return _selectedFilter == BrowseFilter.toxic
                              ? Colors.red.shade700
                              : AppTheme.botanicalPrimary;
                        }
                        return null;
                      },
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Toxic Plants info banner
            if (isToxic)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'These plants are harmful or toxic. Avoid contact or ingestion.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Toolbar row: count + Medical pill (non-toxic only) + grid/list toggle
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Showing $showingCount ${isToxic ? 'Toxic Plants' : 'Plants'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (!isToxic) ...[
                      ActionChip(
                        avatar: const Icon(
                          Icons.medical_services_outlined,
                          size: 14,
                          color: AppTheme.botanicalPrimary,
                        ),
                        label: const Text(
                          'Medical',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.botanicalPrimary,
                          ),
                        ),
                        backgroundColor: theme.brightness == Brightness.dark
                            ? AppTheme.darkCard
                            : AppTheme.safeBgLight,
                        side: BorderSide(
                          color: AppTheme.botanicalPrimary.withValues(alpha: 0.4),
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const ConditionSearchScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: Icon(
                        _isGridView
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isGridView = !_isGridView;
                        });
                      },
                      tooltip: _isGridView ? 'List View' : 'Grid View',
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),

            // Plant content — toxic tab
            if (isToxic) ...[
              if (filteredToxic.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(context, theme),
                )
              else if (_isGridView)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildToxicGridCard(filteredToxic[index], theme),
                      childCount: filteredToxic.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildToxicListCard(filteredToxic[index], theme),
                      childCount: filteredToxic.length,
                    ),
                  ),
                ),
            ]
            // Plant content — all / doh tabs
            else ...[
              if (plantProvider.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filteredPlants.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(context, theme),
                )
              else if (_isGridView)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildPlantGridCard(filteredPlants[index], theme),
                      childCount: filteredPlants.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildPlantListCard(filteredPlants[index], theme),
                      childCount: filteredPlants.length,
                    ),
                  ),
                ),
            ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
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
            'Try a different search or filter',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Toxic plant cards
  // ---------------------------------------------------------------------------

  Widget _buildToxicGridCard(ToxicPlantEntry plant, ThemeData theme) {
    final color = _harmColor(plant.harm);
    final imageUrl = _toxicPlantImages[plant.slug];
    return GestureDetector(
      onTap: () => _openToxicDetail(plant),
      child: Container(
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
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image area (58%)
              Expanded(
                flex: 58,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => Container(
                          color: color.withOpacity(0.08),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: color.withOpacity(0.08),
                          child: Center(
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 44,
                              color: color.withOpacity(0.6),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: color.withOpacity(0.08),
                        child: Center(
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 44,
                            color: color.withOpacity(0.6),
                          ),
                        ),
                      ),
              ),
              // Text area (42%)
              Expanded(
                flex: 42,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        plant.commonName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        plant.scientificName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (plant.localName.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          plant.localName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textTertiary,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        plant.symptoms,
                        style: TextStyle(
                          fontSize: 10,
                          color: color.withOpacity(0.85),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Harm badge — top-right glassmorphic pill
          Positioned(
            top: 8,
            right: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 11, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        plant.harm,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _openToxicDetail(ToxicPlantEntry plant) {
    final imageUrl = _toxicPlantImages[plant.slug];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ToxicPlantDetailScreen(
          plant: plant,
          imageBuilder: (p, accent) => imageUrl != null && imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (_, __) => Container(
                    color: accent.withOpacity(0.08),
                    child: Center(
                        child: CircularProgressIndicator(color: accent)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: accent.withOpacity(0.08),
                    child: Center(
                        child: Icon(Icons.warning_amber_rounded,
                            size: 64, color: accent.withOpacity(0.5))),
                  ),
                )
              : Container(
                  color: accent.withOpacity(0.08),
                  child: Center(
                      child: Icon(Icons.warning_amber_rounded,
                          size: 64, color: accent.withOpacity(0.5))),
                ),
        ),
      ),
    );
  }

  Widget _buildToxicListCard(ToxicPlantEntry plant, ThemeData theme) {
    final color = _harmColor(plant.harm);
    final imageUrl = _toxicPlantImages[plant.slug];
    return GestureDetector(
      onTap: () => _openToxicDetail(plant),
      child: Container(
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plant image or warning icon circle
            ClipOval(
              child: SizedBox(
                width: 56,
                height: 56,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: 56,
                        height: 56,
                        placeholder: (_, __) => Container(
                          color: color.withOpacity(0.1),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: color.withOpacity(0.1),
                          child: Icon(Icons.warning_amber_rounded,
                              size: 28, color: color),
                        ),
                      )
                    : Container(
                        color: color.withOpacity(0.1),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 28,
                          color: color,
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
                      const SizedBox(width: 6),
                      Icon(Icons.warning_amber_rounded,
                          color: color, size: 16),
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
                  if (plant.localName.isNotEmpty) ...[
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
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      plant.harm,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.science_rounded,
                          size: 12, color: color.withOpacity(0.75)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Toxin: ${plant.toxin}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.sick_rounded,
                          size: 12, color: color.withOpacity(0.75)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          plant.symptoms,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  // ---------------------------------------------------------------------------
  // Safe-plant cards (unchanged)
  // ---------------------------------------------------------------------------

  Widget _buildPlantGridCard(Plant plant, ThemeData theme) {
    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _analytics.trackPlantViewed();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlantDetailScreen(plant: plant),
            ),
          );
        },
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 65,
                  child: PlantImage(
                    plant: plant,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _buildPlaceholderImage(theme),
                  ),
                ),
                Expanded(
                  flex: 35,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          plant.commonName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plant.scientificName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (plant.isDOHApproved)
              Positioned(
                top: 8,
                right: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.botanicalPrimary.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded,
                              size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          const Text(
                            'DOH',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantListCard(Plant plant, ThemeData theme) {
    final showLocalName = plant.localName.isNotEmpty &&
        plant.localName != plant.commonName;

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
          _analytics.trackPlantViewed();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlantDetailScreen(plant: plant),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
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

  Widget _buildPlaceholderImage(ThemeData theme) {
    return Container(
      color: AppTheme.safeBgLight,
      child: const Center(
        child: Icon(
          Icons.local_florist_rounded,
          size: 40,
          color: AppTheme.botanicalPrimary,
        ),
      ),
    );
  }
}
