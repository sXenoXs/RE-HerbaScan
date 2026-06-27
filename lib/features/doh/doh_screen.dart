import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/plant_image.dart';
import 'package:herbascan/features/scan/plant_detail_screen.dart';
import 'package:herbascan/core/services/usage_analytics.dart';

class DOHScreen extends StatefulWidget {
  const DOHScreen({super.key});

  @override
  State<DOHScreen> createState() => _DOHScreenState();
}

class _DOHScreenState extends State<DOHScreen> {
  final UsageAnalytics _analytics = UsageAnalytics();

  @override
  void initState() {
    super.initState();
    _analytics.trackDOHScreenViewed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final plantProvider = Provider.of<PlantProvider>(context, listen: false);
      plantProvider.refreshPlants();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLocalizations = AppLocalizations.of(context);
    final plantProvider = Provider.of<PlantProvider>(context);
    final dohPlants = plantProvider.dohApprovedPlants;

    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.dohApproved),
      ),
      body: plantProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await plantProvider.refreshPlants();
              },
              child: CustomScrollView(
                slivers: [
                  // Medical disclaimer banner — visible immediately at top
                  SliverToBoxAdapter(
                    child: _buildDisclaimerBanner(context, theme, appLocalizations),
                  ),

                  // Plant count info
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Showing ${dohPlants.length} DOH Approved Plants',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),

                  // Plants grid or empty state
                  if (dohPlants.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(context, theme, appLocalizations),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildDOHPlantCard(context, theme, dohPlants[index]),
                          childCount: dohPlants.length,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildDisclaimerBanner(BuildContext context, ThemeData theme,
      AppLocalizations appLocalizations) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningBgLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services_rounded,
            color: AppTheme.warningAmber,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Always consult a physician before use.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.warningColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
            Icons.verified_rounded,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No DOH plants available',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDOHPlantCard(BuildContext context, ThemeData theme, Plant plant) {
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
                // Image fills 65% of card height
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

            // DOH badge: glassmorphic pill top-right
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
                      color: AppTheme.botanicalPrimary.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                        SizedBox(width: 3),
                        Text(
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

  Widget _buildPlaceholderImage(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.local_florist,
          size: 32,
          color: theme.colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
    );
  }
}
