import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/features/admin/admin_condition_search_screen.dart';
import 'package:herbascan/features/admin/admin_dashboard_screen.dart';
import 'package:herbascan/features/admin/admin_overview_screen.dart';
import 'package:herbascan/features/admin/admin_plant_metadata_screen.dart';
import 'package:herbascan/features/admin/admin_user_management_screen.dart';
import 'package:herbascan/features/admin/admin_system_health_screen.dart';
import 'package:herbascan/features/admin/admin_feedback_screen.dart';
import 'package:herbascan/features/admin/admin_toxic_plants_screen.dart';

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

  static const int _overviewIndex = 0;
  static const int _plantMetadataIndex = 1;
  static const int _conditionSearchIndex = 2;
  static const int _userManagementIndex = 3;
  static const int _systemHealthIndex = 4;
  static const int _feedbackIndex = 5;
  static const int _submissionTriageIndex = 6;
  static const int _toxicPlantsIndex = 7;

  static const _destinations = [
    (
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      label: 'Overview',
    ),
    (
      icon: Icons.eco_outlined,
      selectedIcon: Icons.eco,
      label: 'Plant Catalog',
    ),
    (
      icon: Icons.local_hospital_outlined,
      selectedIcon: Icons.local_hospital,
      label: 'Health Conditions',
    ),
    (
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'User Directory',
    ),
    (
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart,
      label: 'System Health',
    ),
    (
      icon: Icons.feedback_outlined,
      selectedIcon: Icons.feedback,
      label: 'Feedback',
    ),
    (
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox_rounded,
      label: 'Submissions',
    ),
    (
      icon: Icons.warning_amber_outlined,
      selectedIcon: Icons.warning_amber_rounded,
      label: 'Toxic Plants',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useWideLayout = width >= 800 || kIsWeb;

    if (useWideLayout) {
      final theme = Theme.of(context);
      return Scaffold(
        body: Row(
          children: [
            _buildNavigationRail(theme, width),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: _buildModuleContent(),
            ),
          ],
        ),
      );
    }

    // Narrow/mobile: hamburger drawer. AppBar uses theme surface/onSurface so it adapts in dark mode.
    final theme = Theme.of(context);
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        title: const Text('Admin Console'),
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

  // _buildNavigationRail()
  Widget _buildNavigationRail(ThemeData theme, double width) {
    final isExtended = width >= 900;
    final isDark = theme.brightness == Brightness.dark;
    final sidebarBg = isDark ? AppTheme.darkSurface : theme.colorScheme.surface;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.dividerColor.withValues(alpha: 0.5);
    final dividerColor = isDark ? Colors.white12 : theme.dividerColor;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(
          right: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
            child: isExtended
                ? Row(
                    children: [
                      Icon(Icons.security_rounded, color: titleColor, size: 32),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Console',
                              style: TextStyle(
                                  color: titleColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          Text('Elevated Privileges Active',
                              style: TextStyle(
                                  color: AppTheme.warningAmber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Icon(Icons.security_rounded, color: titleColor, size: 32),
                      const SizedBox(height: 4),
                      Text('Admin',
                          style: TextStyle(
                              color: titleColor.withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
          ),
          Expanded(
            child: Column(
              children: _destinations.asMap().entries.map((entry) {
                final i = entry.key;
                final dest = entry.value;
                final isSelected = _selectedIndex == i;
                return _buildRailItem(
                  icon: dest.icon,
                  selectedIcon: dest.selectedIcon,
                  label: dest.label,
                  isSelected: isSelected,
                  isExtended: isExtended,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedIndex = i),
                );
              }).toList(),
            ),
          ),
          // Escape hatch footer
          Divider(color: dividerColor, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: isExtended
                ? TextButton.icon(
                    icon: const Icon(Icons.exit_to_app,
                        color: AppTheme.errorLight, size: 20),
                    label: const Text('Exit Admin Console',
                        style: TextStyle(
                            color: AppTheme.errorLight, fontSize: 13)),
                    onPressed: () => context.go('/home'),
                  )
                : IconButton(
                    icon: const Icon(Icons.exit_to_app,
                        color: AppTheme.errorLight, size: 22),
                    tooltip: 'Exit Admin Console',
                    onPressed: () => context.go('/home'),
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // _buildRailItem()
  Widget _buildRailItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required bool isExtended,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final bg = isSelected
        ? AppTheme.botanicalPrimary.withValues(alpha: 0.15)
        : Colors.transparent;
    final fg = isSelected
        ? AppTheme.botanicalPrimaryL
        : isDark
            ? Colors.white60
            : Colors.black.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: isExtended
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: isExtended
                ? Row(
                    children: [
                      Icon(isSelected ? selectedIcon : icon, color: fg, size: 22),
                      const SizedBox(width: 12),
                      Text(label,
                          style: TextStyle(
                              color: fg,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                    ],
                  )
                : Icon(isSelected ? selectedIcon : icon, color: fg, size: 22),
          ),
        ),
      ),
    );
  }

  // _buildAdminDrawer()
  Widget _buildAdminDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sidebarBg = isDark ? AppTheme.darkSurface : theme.colorScheme.surface;
    final dividerColor = isDark ? Colors.white12 : theme.dividerColor;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    return Drawer(
      backgroundColor: sidebarBg,
      child: Column(
        children: [
          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security_rounded, color: titleColor, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'Admin Console',
                    style: TextStyle(
                        color: titleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Elevated Privileges Active',
                    style: TextStyle(
                        color: AppTheme.warningAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          Divider(color: dividerColor, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              children: _destinations.asMap().entries.map((entry) {
                final i = entry.key;
                final dest = entry.value;
                return _buildDrawerTile(
                  context,
                  icon: dest.icon,
                  selectedIcon: dest.selectedIcon,
                  label: dest.label,
                  index: i,
                  isDark: isDark,
                );
              }).toList(),
            ),
          ),
          // Escape hatch footer
          Divider(color: dividerColor, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: TextButton.icon(
              icon: const Icon(Icons.exit_to_app,
                  color: AppTheme.errorLight, size: 20),
              label: const Text('Exit Admin Console',
                  style: TextStyle(color: AppTheme.errorLight, fontSize: 14)),
              onPressed: () {
                Navigator.pop(context);
                context.go('/home');
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // _buildDrawerTile()
  Widget _buildDrawerTile(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required bool isDark,
  }) {
    final isSelected = _selectedIndex == index;
    final bg = isSelected
        ? AppTheme.botanicalPrimary.withValues(alpha: 0.15)
        : Colors.transparent;
    final fg = isSelected
        ? AppTheme.botanicalPrimaryL
        : isDark
            ? Colors.white60
            : Colors.black.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(30),
        child: ListTile(
          leading: Icon(isSelected ? selectedIcon : icon, color: fg, size: 22),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: fg,
              fontSize: 14,
            ),
          ),
          selected: isSelected,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
      case _overviewIndex:
        return const AdminOverviewScreen();
      case _plantMetadataIndex:
        return const AdminPlantMetadataScreen();
      case _conditionSearchIndex:
        return const AdminConditionSearchScreen();
      case _userManagementIndex:
        return const AdminUserManagementScreen();
      case _systemHealthIndex:
        return const AdminSystemHealthScreen();
      case _feedbackIndex:
        return const AdminFeedbackScreen();
      case _submissionTriageIndex:
        return const AdminDashboardScreen();
      case _toxicPlantsIndex:
        return const AdminToxicPlantsScreen();
      default:
        return const Center(child: Text('Select a module'));
    }
  }
}

