import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:herbascan/features/admin/admin_condition_search_screen.dart';
import 'package:herbascan/features/admin/admin_dashboard_screen.dart';
import 'package:herbascan/features/admin/admin_plant_metadata_screen.dart';
import 'package:herbascan/features/admin/admin_user_management_screen.dart';

/// Admin web dashboard: desktop layout with NavigationRail and three modules.
/// RBAC guard ensures only admins reach this screen.
class AdminWebScreen extends StatefulWidget {
  const AdminWebScreen({super.key});

  @override
  State<AdminWebScreen> createState() => _AdminWebScreenState();
}

class _AdminWebScreenState extends State<AdminWebScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const int _imageReviewIndex = 0;
  static const int _plantMetadataIndex = 1;
  static const int _conditionSearchIndex = 2;
  static const int _userManagementIndex = 3;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useWideLayout = width >= 800 || kIsWeb;

    if (useWideLayout) {
      final theme = Theme.of(context);
      return Scaffold(
        body: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
              child: NavigationRail(
                extended: width >= 900,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Admin',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: const SizedBox(height: 24),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.photo_library_outlined),
                    selectedIcon: Icon(Icons.photo_library),
                    label: Text('Image Review'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.eco_outlined),
                    selectedIcon: Icon(Icons.eco),
                    label: Text('Plant Metadata'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.local_hospital_outlined),
                    selectedIcon: Icon(Icons.local_hospital),
                    label: Text('Condition Search'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: Text('User Management'),
                  ),
                ],
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: _buildModuleContent(),
            ),
          ],
        ),
      );
    }

    // Narrow/mobile: hamburger (top left) opens drawer; use system back to return to Settings
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Admin'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Menu',
        ),
      ),
      drawer: _buildAdminDrawer(context),
      body: _buildModuleContent(),
    );
  }

  Widget _buildAdminDrawer(BuildContext context) {
    final theme = Theme.of(context);
    // Darker shades of primary so white text (Admin, Review & manage, selected items) is clearly visible
    final primaryDark = Color.lerp(theme.colorScheme.primary, Colors.black, 0.25)!;
    final primaryDarkEnd = Color.lerp(theme.colorScheme.primary, Colors.black, 0.12)!;
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryDark, primaryDarkEnd],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 40,
                      color: theme.colorScheme.onPrimary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Admin',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review & manage',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              children: [
                _buildDrawerTile(
                  context,
                  theme,
                  icon: Icons.photo_library_outlined,
                  selectedIcon: Icons.photo_library,
                  label: 'Image Review',
                  index: _imageReviewIndex,
                ),
                _buildDrawerTile(
                  context,
                  theme,
                  icon: Icons.eco_outlined,
                  selectedIcon: Icons.eco,
                  label: 'Plant Metadata',
                  index: _plantMetadataIndex,
                ),
                _buildDrawerTile(
                  context,
                  theme,
                  icon: Icons.local_hospital_outlined,
                  selectedIcon: Icons.local_hospital,
                  label: 'Condition Search',
                  index: _conditionSearchIndex,
                ),
                _buildDrawerTile(
                  context,
                  theme,
                  icon: Icons.people_outline,
                  selectedIcon: Icons.people,
                  label: 'User Management',
                  index: _userManagementIndex,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    // Darker shade of primary so white text stays clearly visible (no blending)
    final selectedBg = Color.lerp(theme.colorScheme.primary, Colors.black, 0.2)!;
    final selectedFg = theme.colorScheme.onPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(
            isSelected ? selectedIcon : icon,
            color: isSelected ? selectedFg : theme.colorScheme.onSurfaceVariant,
            size: 24,
          ),
          title: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? selectedFg : theme.colorScheme.onSurface,
            ),
          ),
          selected: isSelected,
          onTap: () {
            setState(() => _selectedIndex = index);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Widget _buildModuleContent() {
    switch (_selectedIndex) {
      case _imageReviewIndex:
        return const AdminDashboardScreen();
      case _plantMetadataIndex:
        return const AdminPlantMetadataScreen();
      case _conditionSearchIndex:
        return const AdminConditionSearchScreen();
      case _userManagementIndex:
        return const AdminUserManagementScreen();
      default:
        return const Center(child: Text('Select a module'));
    }
  }
}
