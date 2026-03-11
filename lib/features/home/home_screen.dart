import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/features/scan/scan_screen.dart';
import 'package:herbascan/features/browse/browse_screen.dart';
import 'package:herbascan/features/history/history_screen.dart';
import 'package:herbascan/features/doh/doh_screen.dart';
import 'package:herbascan/features/settings/settings_screen.dart';
import 'package:herbascan/features/scan/plant_result_screen.dart';
import 'package:herbascan/features/scan/plant_detail_screen.dart';
import 'package:herbascan/core/models/scan_result.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/widgets/plant_image.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.showUnauthorizedSnackBar = false});

  final bool showUnauthorizedSnackBar;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 4 real tabs: 0=Home, 1=Browse, 2=History, 3=Settings
  // Index 2 in the BottomAppBar row is the FAB slot (camera), not a tab
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    if (widget.showUnauthorizedSnackBar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unauthorized access.')),
          );
        }
      });
    }
    _screens = [
      HomeDashboard(onNavigate: (index) {
        setState(() {
          _currentIndex = index;
        });
      }),
      const BrowseScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];
  }

  void _openScan() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ScanScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _openScan,
        backgroundColor: AppTheme.botanicalPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.camera_alt_rounded),
      ),
      bottomNavigationBar: BottomAppBar(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 8,
        notchMargin: 8,
        height: 60,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _NavItem(
              icon: Icons.search_rounded,
              label: AppLocalizations.of(context).browse,
              selected: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            // Center gap for FAB
            const SizedBox(width: 56),
            _NavItem(
              icon: Icons.history_rounded,
              label: AppLocalizations.of(context).history,
              selected: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              label: AppLocalizations.of(context).settings,
              selected: _currentIndex == 3,
              onTap: () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.5);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class HomeDashboard extends StatefulWidget {
  final Function(int)? onNavigate;

  const HomeDashboard({super.key, this.onNavigate});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PlantProvider>(context, listen: false).loadPlants();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plantProvider = Provider.of<PlantProvider>(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        centerTitle: false,
        title: Text(
          'HerbaScan',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => widget.onNavigate?.call(3),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await plantProvider.loadPlants();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero section
              _buildHeroSection(context, theme),

              const SizedBox(height: 20),

              // Stats ribbon
              _buildStatsRibbon(context, theme, plantProvider),

              const SizedBox(height: 28),

              // Recent Scans horizontal scroll
              _buildRecentScans(context, theme, plantProvider),

              const SizedBox(height: 28),

              // DOH Spotlight carousel
              _buildDOHSpotlight(context, theme, plantProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.safeBgLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What plant are you identifying?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the camera button below to start.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRibbon(
      BuildContext context, ThemeData theme, PlantProvider plantProvider) {
    final stats = plantProvider.getStatistics();
    final totalScans = stats['totalScans'] as int? ?? 0;
    final dohPlants = stats['dohApprovedPlants'] as int? ?? 0;
    final avgConfidence = stats['averageConfidence'] as double? ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCell(
            theme,
            '$totalScans',
            'Scans',
          ),
          _buildStatDivider(),
          _buildStatCell(
            theme,
            '$dohPlants',
            'DOH Plants',
          ),
          _buildStatDivider(),
          _buildStatCell(
            theme,
            '${(avgConfidence * 100).toStringAsFixed(0)}%',
            'Accuracy',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell(ThemeData theme, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.botanicalPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 32,
      color: AppTheme.textTertiary.withOpacity(0.3),
    );
  }

  Widget _buildRecentScans(
      BuildContext context, ThemeData theme, PlantProvider plantProvider) {
    final recentScans = plantProvider.scanHistory.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).recentScans,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (recentScans.isNotEmpty)
                TextButton(
                  onPressed: () => widget.onNavigate?.call(2),
                  child: const Text('View All'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (recentScans.isEmpty)
          _buildEmptyScans(theme)
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recentScans.length,
              itemBuilder: (context, index) {
                return _buildScanCard(context, theme, recentScans[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyScans(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
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
        child: Column(
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No scans yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start by scanning your first plant!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard(
      BuildContext context, ThemeData theme, ScanResult scan) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.72;
    final confidence = scan.confidenceScore;
    final confidenceColor = confidence >= 0.8
        ? AppTheme.safeGreen
        : confidence >= 0.6
            ? AppTheme.warningAmber
            : AppTheme.errorDeep;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlantResultScreen.fromScanResult(scan),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
        color: theme.cardTheme.color ?? Colors.white,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plant photo
              SizedBox(
                height: 120,
                width: double.infinity,
                child: scan.imagePath.isNotEmpty
                    ? Image.file(
                        File(scan.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, _, __) =>
                            _scanImageFallback(theme),
                      )
                    : _scanImageFallback(theme),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scan.plant?.commonName ??
                          scan.topPrediction?.plantName ??
                          'Unknown Plant',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scan.formattedScanDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Confidence pill top-right
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: confidenceColor,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${(confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _scanImageFallback(ThemeData theme) {
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

  Widget _buildDOHSpotlight(
      BuildContext context, ThemeData theme, PlantProvider plantProvider) {
    final dohPlants = plantProvider.dohApprovedPlants.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DOH Approved Plants',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DOHScreen()),
                  );
                },
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (dohPlants.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No DOH approved plants loaded.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          )
        else
          SizedBox(
            height: 104,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dohPlants.length,
              itemBuilder: (context, index) {
                return _buildDOHPlantItem(context, theme, dohPlants[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDOHPlantItem(
      BuildContext context, ThemeData theme, Plant plant) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlantDetailScreen(plant: plant),
          ),
        );
      },
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: PlantImage(
                plant: plant,
                fit: BoxFit.cover,
                width: 64,
                height: 64,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              plant.commonName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
