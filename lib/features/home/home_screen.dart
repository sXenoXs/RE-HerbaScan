import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/app_provider.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:herbascan/core/widgets/offline_indicator.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/features/scan/scan_screen.dart';
import 'package:herbascan/features/browse/browse_screen.dart';
import 'package:herbascan/features/history/history_screen.dart';
import 'package:herbascan/features/doh/doh_screen.dart';
import 'package:herbascan/features/settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeDashboard(),
    const BrowseScreen(),
    const HistoryScreen(),
    const DOHScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: AppLocalizations.of(context).scan,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search),
            label: AppLocalizations.of(context).browse,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: AppLocalizations.of(context).history,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.verified),
            label: AppLocalizations.of(context).dohApproved,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: AppLocalizations.of(context).settings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ScanScreen()),
          );
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

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
    final appProvider = Provider.of<AppProvider>(context);
    final plantProvider = Provider.of<PlantProvider>(context);
    final offlineProvider = Provider.of<OfflineProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).appTitle),
        actions: [
          // Offline indicator
          OfflineIndicator(
            margin: const EdgeInsets.only(right: 16),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await plantProvider.loadPlants();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              _buildWelcomeSection(context, theme),

              const SizedBox(height: 16),

              // Offline Status
              OfflineStatusCard(),

              const SizedBox(height: 16),

              // Quick Actions
              _buildQuickActions(context, theme),

              const SizedBox(height: 24),

              // Statistics
              _buildStatistics(context, theme, plantProvider),

              const SizedBox(height: 24),

              // Recent Scans
              _buildRecentScans(context, theme, plantProvider),

              const SizedBox(height: 24),

              // DOH Approved Plants Preview
              _buildDOHPreview(context, theme, plantProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to HerbaScan! 🌿',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).welcomeMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _buildActionCard(
              context,
              theme,
              Icons.camera_alt,
              AppLocalizations.of(context).scanPlant,
              'Identify using camera',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ScanScreen()),
                );
              },
            ),
            _buildActionCard(
              context,
              theme,
              Icons.search,
              AppLocalizations.of(context).browsePlants,
              'Explore database',
              () {
                // Navigate to browse screen
              },
            ),
            _buildActionCard(
              context,
              theme,
              Icons.history,
              AppLocalizations.of(context).recentScans,
              'View history',
              () {
                // Navigate to history screen
              },
            ),
            _buildActionCard(
              context,
              theme,
              Icons.verified,
              AppLocalizations.of(context).dohPlants,
              'Official list',
              () {
                // Navigate to DOH screen
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        key: ValueKey('action_card_${title}_$subtitle'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatistics(
      BuildContext context, ThemeData theme, PlantProvider plantProvider) {
    final stats = plantProvider.getStatistics();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Stats',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                theme,
                '${stats['totalScans']}',
                'Plants Identified',
                Icons.eco,
              ),
              _buildStatItem(
                theme,
                '${stats['dohApprovedPlants']}',
                'DOH Approved',
                Icons.verified,
              ),
              _buildStatItem(
                theme,
                '${(stats['averageConfidence'] * 100).toStringAsFixed(1)}%',
                'Avg Accuracy',
                Icons.analytics,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
      ThemeData theme, String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRecentScans(
      BuildContext context, ThemeData theme, PlantProvider plantProvider) {
    final recentScans = plantProvider.scanHistory.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).recentScans,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (recentScans.isNotEmpty)
              TextButton(
                onPressed: () {
                  // Navigate to history screen
                },
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (recentScans.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'No scans yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start by scanning your first plant!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          )
        else
          ...recentScans.map((scan) => _buildScanItem(context, theme, scan)),
      ],
    );
  }

  Widget _buildScanItem(BuildContext context, ThemeData theme, dynamic scan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.eco,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.plant?.commonName ?? 'Unknown Plant',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(scan.confidenceScore * 100).toStringAsFixed(1)}% confidence',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            scan.formattedScanDate,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDOHPreview(
      BuildContext context, ThemeData theme, PlantProvider plantProvider) {
    final dohPlants = plantProvider.dohApprovedPlants.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).dohApproved,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to DOH screen
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FFF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF48BB78),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified,
                    color: Color(0xFF48BB78),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).philippineDepartmentOfHealth,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF48BB78),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${dohPlants.length} ${AppLocalizations.of(context).clinicallyValidated}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF38A169),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
          ),
          itemCount: dohPlants.length,
          itemBuilder: (context, index) {
            final plant = dohPlants[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF48BB78).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF48BB78).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.eco,
                      color: Color(0xFF48BB78),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plant.commonName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
