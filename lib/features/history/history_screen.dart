import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:herbascan/core/constants/toxic_plant_blacklist.dart';
import 'package:herbascan/core/models/scan_result.dart';
import 'package:herbascan/core/models/cloud_scan.dart';
import 'package:herbascan/core/services/herbarium_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/features/auth/login_screen.dart';
import 'package:herbascan/features/scan/no_match_found_screen.dart';
import 'package:herbascan/features/scan/plant_result_screen.dart';
import 'package:herbascan/features/scan/scan_screen.dart';
import 'package:herbascan/core/services/usage_analytics.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  final UsageAnalytics _analytics = UsageAnalytics();
  late final TabController _tabController;
  String _sortBy = 'recent'; // recent, oldest, confidence
  String _cloudSortBy = 'recent'; // recent, oldest, confidence
  int _historyTabIndex = 0; // 0 = Device, 1 = Cloud
  List<CloudScan> _cloudScans = [];
  bool _cloudLoading = false;
  bool _selectMode = false;
  final Set<String> _selectedDeviceIds = {};
  final Set<String> _selectedCloudIds = {};
  bool _batchOperationInProgress = false;

  @override
  void initState() {
    super.initState();
    _analytics.trackHistoryViewed();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Eagerly load local scan history from SQLite as soon as the widget mounts,
    // independent of the full PlantProvider initialization chain (which waits
    // for Supabase catalog sync before calling loadScanHistory).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PlantProvider>().loadScanHistory();
      }
    });
  }

  void _onTabChanged() {
    // Guard: only react to settled tab changes, not mid-animation events
    if (_tabController.indexIsChanging) return;
    final idx = _tabController.index;
    if (idx == _historyTabIndex) return; // no actual change
    setState(() => _historyTabIndex = idx);
    if (idx == 1) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) _loadCloudScans();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  static void _debugHistory(String message) {
    if (kDebugMode) debugPrint('[HistoryScreen] $message');
  }

  Future<void> _loadCloudScans() async {
    final auth = context.read<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;
    final userId = auth.user?.id;
    _debugHistory(
        '_loadCloudScans: start isLoggedIn=$isLoggedIn userId=$userId');
    setState(() => _cloudLoading = true);
    final list = await HerbariumService().getMyScans();
    _debugHistory(
        '_loadCloudScans: getMyScans returned ${list.length} scan(s)');
    if (mounted) {
      setState(() {
        _cloudScans = list;
        _cloudLoading = false;
      });
    }
  }

  List<ScanResult> _sortScans(List<ScanResult> scans) {
    List<ScanResult> sorted = List.from(scans);

    switch (_sortBy) {
      case 'recent':
        sorted.sort((a, b) => b.scanDate.compareTo(a.scanDate));
        break;
      case 'oldest':
        sorted.sort((a, b) => a.scanDate.compareTo(b.scanDate));
        break;
      case 'confidence':
        sorted.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
        break;
    }

    return sorted;
  }

  List<CloudScan> _sortCloudScans(List<CloudScan> scans) {
    final list = List<CloudScan>.from(scans);
    switch (_cloudSortBy) {
      case 'recent':
        list.sort((a, b) => b.scanDate.compareTo(a.scanDate));
        break;
      case 'oldest':
        list.sort((a, b) => a.scanDate.compareTo(b.scanDate));
        break;
      case 'confidence':
        list.sort((a, b) {
          final ca = _cloudScanConfidence(a) ?? 0.0;
          final cb = _cloudScanConfidence(b) ?? 0.0;
          return cb.compareTo(ca);
        });
        break;
    }
    return list;
  }

  void _showDeleteAllConfirmation(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(appLocalizations.confirmDelete),
          content:
              const Text('Are you sure you want to delete all scan history?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(appLocalizations.cancel),
            ),
            TextButton(
              onPressed: () {
                final plantProvider =
                    Provider.of<PlantProvider>(context, listen: false);
                plantProvider.clearScanHistory();
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('All scans deleted'),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              },
              child: Text(
                appLocalizations.deleteAll,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAllCloudConfirmation(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(appLocalizations.deleteAll),
          content: const Text(
              'Are you sure you want to delete all scans from the cloud?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(appLocalizations.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final toDelete = List<CloudScan>.from(_cloudScans);
                setState(() {
                  _selectMode = false;
                  _selectedCloudIds.clear();
                  _batchOperationInProgress = true;
                });
                int deleted = 0;
                for (final cloud in toDelete) {
                  if (!mounted) break;
                  final ok = await HerbariumService().deleteScan(cloud.id);
                  if (ok) deleted++;
                }
                if (mounted) {
                  setState(() => _batchOperationInProgress = false);
                  _loadCloudScans();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$deleted cloud scan(s) deleted'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              },
              child: Text(
                appLocalizations.deleteAll,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLocalizations = AppLocalizations.of(context);
    final plantProvider = Provider.of<PlantProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final offlineProvider = Provider.of<OfflineProvider>(context);
    final sortedScans = _sortScans(plantProvider.scanHistory);

    final avgConfidence = sortedScans.isEmpty
        ? 0.0
        : sortedScans.map((s) => s.confidenceScore).reduce((a, b) => a + b) /
            sortedScans.length;

    final hasSelection =
        _selectedDeviceIds.isNotEmpty || _selectedCloudIds.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: true,
                floating: false,
                title: Text(_selectMode
                    ? '${_historyTabIndex == 0 ? _selectedDeviceIds.length : _selectedCloudIds.length} selected'
                    : appLocalizations.scanHistory),
                leading: _selectMode
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectMode = false;
                            _selectedDeviceIds.clear();
                            _selectedCloudIds.clear();
                          });
                        },
                        tooltip: 'Cancel',
                      )
                    : null,
                actions: [
                  if (_selectMode && _historyTabIndex == 0) ...[
                    TextButton(
                      onPressed: sortedScans.isEmpty
                          ? null
                          : () {
                              setState(() {
                                final allSelected = _selectedDeviceIds.length ==
                                    sortedScans.length;
                                if (allSelected) {
                                  _selectedDeviceIds.clear();
                                } else {
                                  _selectedDeviceIds
                                      .addAll(sortedScans.map((s) => s.id));
                                }
                              });
                            },
                      child: Text(
                        _selectedDeviceIds.length == sortedScans.length &&
                                sortedScans.isNotEmpty
                            ? 'Deselect all'
                            : 'Select all',
                      ),
                    ),
                    if (sortedScans.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep),
                        onPressed: () => _showDeleteAllConfirmation(context),
                        tooltip: appLocalizations.deleteAll,
                      ),
                  ],
                  if (_selectMode && _historyTabIndex == 1) ...[
                    TextButton(
                      onPressed: _cloudScans.isEmpty
                          ? null
                          : () {
                              setState(() {
                                final allSelected = _selectedCloudIds.length ==
                                    _cloudScans.length;
                                if (allSelected) {
                                  _selectedCloudIds.clear();
                                } else {
                                  _selectedCloudIds
                                      .addAll(_cloudScans.map((c) => c.id));
                                }
                              });
                            },
                      child: Text(
                        _selectedCloudIds.length == _cloudScans.length &&
                                _cloudScans.isNotEmpty
                            ? 'Deselect all'
                            : 'Select all',
                      ),
                    ),
                    if (_cloudScans.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep),
                        onPressed: () =>
                            _showDeleteAllCloudConfirmation(context),
                        tooltip: appLocalizations.deleteAll,
                      ),
                  ],
                  if (!_selectMode)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'select') {
                          setState(() => _selectMode = true);
                        } else if (value.startsWith('sort_')) {
                          final sort = value.replaceFirst('sort_', '');
                          setState(() {
                            if (_historyTabIndex == 0) {
                              _sortBy = sort;
                            } else {
                              _cloudSortBy = sort;
                            }
                          });
                        }
                      },
                      itemBuilder: (context) {
                        final activeSortBy =
                            _historyTabIndex == 0 ? _sortBy : _cloudSortBy;
                        final hasItems = _historyTabIndex == 0
                            ? sortedScans.isNotEmpty
                            : _cloudScans.isNotEmpty;

                        Widget sortLeading(String key) {
                          return activeSortBy == key
                              ? Icon(Icons.check,
                                  color: theme.colorScheme.primary, size: 20)
                              : const SizedBox(width: 20);
                        }

                        return [
                          PopupMenuItem<String>(
                            enabled: false,
                            height: 32,
                            child: Text(
                              'SORT',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'sort_recent',
                            child: Row(children: [
                              sortLeading('recent'),
                              const SizedBox(width: 12),
                              Text(
                                'Most Recent',
                                style: TextStyle(
                                  fontWeight: activeSortBy == 'recent'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ]),
                          ),
                          PopupMenuItem<String>(
                            value: 'sort_oldest',
                            child: Row(children: [
                              sortLeading('oldest'),
                              const SizedBox(width: 12),
                              Text(
                                'Oldest First',
                                style: TextStyle(
                                  fontWeight: activeSortBy == 'oldest'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ]),
                          ),
                          PopupMenuItem<String>(
                            value: 'sort_confidence',
                            child: Row(children: [
                              sortLeading('confidence'),
                              const SizedBox(width: 12),
                              Text(
                                'Highest Confidence',
                                style: TextStyle(
                                  fontWeight: activeSortBy == 'confidence'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ]),
                          ),
                          if (hasItems) ...[
                            const PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'select',
                              child: const Row(children: [
                                SizedBox(width: 20),
                                SizedBox(width: 12),
                                Text('Select Items'),
                              ]),
                            ),
                          ],
                        ];
                      },
                    ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.phone_android), text: 'Device'),
                    Tab(icon: Icon(Icons.cloud), text: 'Cloud'),
                  ],
                ),
              ),
              // Single-line stats below TabBar (device tab only, non-empty)
              if (_historyTabIndex == 0 && sortedScans.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                    child: Text(
                      '${sortedScans.length} Scans saved • ${(avgConfidence * 100).toStringAsFixed(1)}% Avg Match',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ),
                ),
            ],
            body: Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDeviceHistory(context, theme, appLocalizations,
                        plantProvider, sortedScans),
                    _buildCloudHistory(
                        context, theme, authProvider, offlineProvider),
                  ],
                ),
                if (_batchOperationInProgress)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          // AnimatedSlide batch FAB — sits above the BottomAppBar (60px) + camera FAB (56px) + margin
          Positioned(
            left: 16,
            right: 16,
            bottom: 60 + 14 + 12 + MediaQuery.of(context).padding.bottom,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              offset: (_selectMode && hasSelection)
                  ? Offset.zero
                  : const Offset(0, 2.5),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: (_selectMode && hasSelection) ? 1.0 : 0.0,
                child: FilledButton.icon(
                  onPressed: (_selectMode &&
                          hasSelection &&
                          !_batchOperationInProgress)
                      ? () {
                          if (_historyTabIndex == 0) {
                            _batchSyncSelectedToCloud(
                                context, plantProvider, sortedScans);
                          } else {
                            _batchDownloadSelectedToDevice(
                                context, plantProvider);
                          }
                        }
                      : null,
                  icon: Icon(_historyTabIndex == 0
                      ? Icons.cloud_upload
                      : Icons.download),
                  label: Text(_historyTabIndex == 0
                      ? 'Upload Selected Images'
                      : 'Download Selected Images'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                    shadowColor: Colors.black38,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _batchSyncSelectedToCloud(
    BuildContext context,
    PlantProvider plantProvider,
    List<ScanResult> sortedScans,
  ) async {
    final toSync =
        sortedScans.where((s) => _selectedDeviceIds.contains(s.id)).toList();
    if (toSync.isEmpty) return;
    setState(() => _batchOperationInProgress = true);
    int done = 0;
    try {
      for (final scan in toSync) {
        if (!mounted) break;
        final id = await HerbariumService().uploadScan(scan, scan.imagePath);
        if (id != null) done++;
      }
      if (mounted) {
        setState(() {
          _selectMode = false;
          _selectedDeviceIds.clear();
          _batchOperationInProgress = false;
        });
        _loadCloudScans();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$done scan(s) synced to cloud')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _batchOperationInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _batchDownloadSelectedToDevice(
    BuildContext context,
    PlantProvider plantProvider,
  ) async {
    final toDownload =
        _cloudScans.where((c) => _selectedCloudIds.contains(c.id)).toList();
    if (toDownload.isEmpty) return;
    setState(() => _batchOperationInProgress = true);
    int done = 0;
    try {
      for (final cloud in toDownload) {
        if (!mounted) break;
        final result = await HerbariumService().downloadToDevice(cloud);
        if (result != null) {
          await plantProvider.addScanResult(result);
          done++;
        }
      }
      if (mounted) {
        setState(() {
          _selectMode = false;
          _selectedCloudIds.clear();
          _batchOperationInProgress = false;
        });
        await plantProvider.loadScanHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$done scan(s) downloaded to device')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _batchOperationInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Widget _buildDeviceHistory(
      BuildContext context,
      ThemeData theme,
      AppLocalizations appLocalizations,
      PlantProvider plantProvider,
      List<ScanResult> sortedScans) {
    Future<void> onRefresh() async {
      await plantProvider.loadScanHistory();
    }

    if (plantProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (sortedScans.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: _buildEmptyState(context, theme, appLocalizations),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 60 + 56 + 60 + MediaQuery.of(context).padding.bottom),
        itemCount: sortedScans.length,
        itemBuilder: (context, index) {
          final scan = sortedScans[index];
          final isSelected = _selectedDeviceIds.contains(scan.id);
          return Dismissible(
            key: ValueKey(scan.id),
            background: _buildSwipeBackground(
              color: AppTheme.botanicalPrimary,
              icon: Icons.cloud_upload_rounded,
              alignment: Alignment.centerLeft,
              label: appLocalizations.saveToCloud,
            ),
            secondaryBackground: _buildSwipeBackground(
              color: theme.colorScheme.error,
              icon: Icons.delete_rounded,
              alignment: Alignment.centerRight,
              label: appLocalizations.delete,
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                // Save to Cloud — don't dismiss the item
                final auth = context.read<AuthProvider>();
                final offline = context.read<OfflineProvider>();
                if (!auth.isLoggedIn) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sign in to save to cloud')),
                    );
                  }
                  return false;
                }
                if (!offline.isOnline) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No internet connection')),
                    );
                  }
                  return false;
                }
                if (scan.imagePath.isEmpty || !File(scan.imagePath).existsSync()) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Image file not found')),
                    );
                  }
                  return false;
                }
                final id =
                    await HerbariumService().uploadScan(scan, scan.imagePath);
                if (mounted) {
                  if (id != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved to cloud')),
                    );
                    _loadCloudScans();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to save to cloud')),
                    );
                  }
                }
                return false;
              } else {
                // Delete — confirm first
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(appLocalizations.confirmDelete),
                    content: Text(appLocalizations.deleteConfirmation),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(appLocalizations.cancel)),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(appLocalizations.delete,
                            style: TextStyle(color: theme.colorScheme.error)),
                      ),
                    ],
                  ),
                );
                return ok ?? false;
              }
            },
            onDismissed: (direction) {
              if (direction == DismissDirection.endToStart) {
                plantProvider.deleteScanResult(scan.id);
                _selectedDeviceIds.remove(scan.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Scan deleted'),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }
            },
            child: _buildScanCard(
              context,
              theme,
              scan,
              isSelectMode: _selectMode,
              isSelected: isSelected,
              onToggleSelect: () {
                setState(() {
                  if (isSelected) {
                    _selectedDeviceIds.remove(scan.id);
                  } else {
                    _selectedDeviceIds.add(scan.id);
                  }
                });
              },
            ),
          );
        },
      ),
    );
  }

  /// Swipe action background with icon + label (matches Admin dashboard pattern).
  Widget _buildSwipeBackground({
    required Color color,
    required IconData icon,
    required AlignmentGeometry alignment,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ] else ...[
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildCloudHistory(BuildContext context, ThemeData theme,
      AuthProvider authProvider, OfflineProvider offlineProvider) {
    final isOnline = offlineProvider.isOnline;

    // Offline: show "No internet" state so Cloud tab updates immediately when Wi‑Fi is turned off
    if (!isOnline) {
      return _buildCloudPullToRefresh(
        context: context,
        theme: theme,
        onRefresh: _loadCloudScans,
        child: _buildCloudOfflineState(theme),
      );
    }

    if (!authProvider.isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Sign in to view your cloud backup',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                        builder: (context) => const LoginScreen()),
                  );
                  if (mounted && authProvider.isLoggedIn) _loadCloudScans();
                },
                icon: const Icon(Icons.login),
                label: const Text('Sign in'),
              ),
            ],
          ),
        ),
      );
    }
    if (_cloudLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_cloudScans.isEmpty) {
      return _buildCloudPullToRefresh(
        context: context,
        theme: theme,
        onRefresh: _loadCloudScans,
        child: _buildCloudEmptyState(theme),
      );
    }
    final sortedCloudScans = _sortCloudScans(_cloudScans);
    final appLocalizations = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _loadCloudScans,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedCloudScans.length,
        itemBuilder: (context, index) {
          final cloud = sortedCloudScans[index];
          final isSelected = _selectedCloudIds.contains(cloud.id);
          return Dismissible(
            key: ValueKey(cloud.id),
            background: _buildSwipeBackground(
              color: AppTheme.botanicalPrimary,
              icon: Icons.download_rounded,
              alignment: Alignment.centerLeft,
              label: appLocalizations.saveToDevice,
            ),
            secondaryBackground: _buildSwipeBackground(
              color: theme.colorScheme.error,
              icon: Icons.delete_rounded,
              alignment: Alignment.centerRight,
              label: appLocalizations.delete,
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                await _downloadCloudScanToDevice(context, cloud);
                return false;
              } else {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete from cloud?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(appLocalizations.cancel)),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(appLocalizations.delete,
                            style: TextStyle(
                                color: theme.colorScheme.error)),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await HerbariumService().deleteScan(cloud.id);
                  if (mounted) _loadCloudScans();
                  return true;
                }
                return false;
              }
            },
            onDismissed: (_) {},
            child: _buildCloudScanCard(
              context,
              theme,
              cloud,
              isSelectMode: _selectMode,
              isSelected: isSelected,
              onToggleSelect: () {
                setState(() {
                  if (isSelected) {
                    _selectedCloudIds.remove(cloud.id);
                  } else {
                    _selectedCloudIds.add(cloud.id);
                  }
                });
              },
            ),
          );
        },
      ),
    );
  }

  /// Scrollable wrapper so pull-to-refresh works on non-list Cloud content (offline / empty).
  Widget _buildCloudPullToRefresh({
    required BuildContext context,
    required ThemeData theme,
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: child,
        ),
      ),
    );
  }

  /// Shown when there is no internet (different from "No cloud scans yet").
  Widget _buildCloudOfflineState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No internet connection',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cloud scans will appear when you\'re back online.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown when online, signed in, but user has no cloud uploads yet.
  Widget _buildCloudEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_queue, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No cloud scans yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scans are backed up here when you\'re signed in',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Display name for a cloud scan: plant_id, or first prediction (from predictions or metadata), or fallback.
  String _cloudScanDisplayName(CloudScan cloud) {
    if (cloud.plantId != null && cloud.plantId!.trim().isNotEmpty) {
      return cloud.plantId!;
    }
    final predictions =
        cloud.predictions ?? cloud.metadata?['predictions'] as List<dynamic>?;
    if (predictions != null && predictions.isNotEmpty) {
      final first = predictions.first as Map<String, dynamic>?;
      final name = first?['plantName'] ?? first?['plantId'] ?? first?['label'];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString();
      }
    }
    return 'Unknown plant';
  }

  /// Cloud tab card: same layout as Device tab (_buildScanCard) — 60×60 thumbnail,
  /// confidence pill, plant name, date row, right-side cloud icon, soft shadow.
  /// No trailing Download/Trash icons (swipe only).
  Widget _buildCloudScanCard(
    BuildContext context,
    ThemeData theme,
    CloudScan cloud, {
    bool isSelectMode = false,
    bool isSelected = false,
    VoidCallback? onToggleSelect,
  }) {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
    final confidence = _cloudScanConfidence(cloud);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        onTap: () async {
          if (isSelectMode && onToggleSelect != null) {
            onToggleSelect();
            return;
          }
          final scan = _cloudScanToScanResult(cloud);
          if (!mounted) return;
          if (isScanResultTopPredictionBlacklisted(scan)) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NoMatchFoundScreen(
                  imagePath: scan.imagePath,
                  isToxicPlant: true,
                  detectedToxicPlantName: toxicPlantDisplayName(
                    scan.topPrediction?.plantName,
                  ),
                ),
              ),
            );
          } else {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PlantResultScreen.fromScanResult(scan),
              ),
            );
          }
          if (mounted) _loadCloudScans();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: cloud.imageUrl != null &&
                                cloud.imageUrl!.isNotEmpty
                            ? Image.network(
                                cloud.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildPlaceholderImage(theme),
                              )
                            : _buildPlaceholderImage(theme),
                      ),
                    ),
                    if (isSelectMode)
                      Positioned(
                        top: -6,
                        left: -6,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.botanicalPrimary
                                : theme.colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.botanicalPrimary,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 13)
                              : null,
                        ),
                      ),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: confidence != null
                          ? _buildConfidencePill(confidence)
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.botanicalPrimary,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Icon(Icons.cloud_done,
                                  color: Colors.white, size: 14),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _cloudScanDisplayName(cloud),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _getCloudMethodIcon(cloud) ??
                            const Tooltip(
                              message: 'Saved to cloud',
                              child: Icon(Icons.cloud_done_outlined,
                                  size: 16, color: AppTheme.botanicalPrimary),
                            ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.45),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            dateFormat.format(cloud.scanDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.5),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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

  /// Confidence from CloudScan: direct score or first prediction's confidence.
  double? _cloudScanConfidence(CloudScan cloud) {
    if (cloud.confidenceScore != null) return cloud.confidenceScore;
    final preds = cloud.predictions ?? cloud.metadata?['predictions'] as List<dynamic>?;
    if (preds != null && preds.isNotEmpty) {
      final first = preds.first as Map<String, dynamic>?;
      final c = first?['confidence'];
      if (c != null) return (c is num) ? c.toDouble() : double.tryParse(c.toString());
    }
    return null;
  }

  Future<void> _downloadCloudScanToDevice(
      BuildContext context, CloudScan cloud) async {
    setState(() => _batchOperationInProgress = true);
    try {
      final result = await HerbariumService().downloadToDevice(cloud);
      if (result != null && mounted) {
        await context.read<PlantProvider>().addScanResult(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Downloaded to device')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not download. Check connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _batchOperationInProgress = false);
    }
  }

  ScanResult _cloudScanToScanResult(CloudScan cloud) {
    final rawPreds = cloud.predictions ??
        cloud.metadata?['predictions'] as List<dynamic>? ??
        [];

    final predictions = rawPreds
        .whereType<Map<String, dynamic>>()
        .map((p) => Prediction(
              plantId: p['plantId']?.toString() ??
                  p['plantName']?.toString() ??
                  p['label']?.toString() ??
                  '',
              plantName: p['plantName']?.toString() ??
                  p['plantId']?.toString() ??
                  p['label']?.toString() ??
                  'Unknown',
              scientificName: p['scientificName']?.toString() ?? '',
              confidence: (p['confidence'] is num)
                  ? (p['confidence'] as num).toDouble()
                  : double.tryParse(p['confidence']?.toString() ?? '') ?? 0.0,
              features:
                  (p['features'] as Map<String, dynamic>?) ?? {},
            ))
        .toList();

    return ScanResult(
      id: cloud.id,
      imagePath: cloud.imageUrl ?? '',
      scanDate: cloud.scanDate,
      predictions: predictions,
      confidenceScore: _cloudScanConfidence(cloud) ?? 0.0,
      isOfflineScan: false,
      metadata: cloud.metadata ?? {},
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme,
      AppLocalizations appLocalizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            appLocalizations.noScansYet,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            appLocalizations.startScanning,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to scan screen
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ScanScreen(),
                ),
              );
            },
            icon: const Icon(Icons.camera_alt),
            label: Text(appLocalizations.scanPlant),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanCard(
    BuildContext context,
    ThemeData theme,
    ScanResult scan, {
    bool isSelectMode = false,
    bool isSelected = false,
    VoidCallback? onToggleSelect,
  }) {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
    final methodIcon = _getMethodIcon(scan);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        onTap: () async {
          if (isSelectMode && onToggleSelect != null) {
            onToggleSelect();
            return;
          }
          if (!mounted) return;
          if (isScanResultTopPredictionBlacklisted(scan)) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NoMatchFoundScreen(
                  imagePath: scan.imagePath,
                  isToxicPlant: true,
                  detectedToxicPlantName: toxicPlantDisplayName(
                    scan.topPrediction?.plantName,
                  ),
                ),
              ),
            );
          } else {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PlantResultScreen.fromScanResult(scan),
              ),
            );
          }
          if (mounted) _loadCloudScans();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail with overlaid checkbox in select mode — no row resize
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: scan.imagePath.isNotEmpty
                            ? Image.file(
                                File(scan.imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPlaceholderImage(theme),
                              )
                            : _buildPlaceholderImage(theme),
                      ),
                    ),
                    if (isSelectMode)
                      Positioned(
                        top: -6,
                        left: -6,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.botanicalPrimary
                                : theme.colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.botanicalPrimary,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 13)
                              : null,
                        ),
                      ),
                    // Confidence badge anchored top-right of thumbnail
                    Positioned(
                      top: -4,
                      right: -4,
                      child: _buildConfidencePill(scan.confidenceScore),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            scan.plant?.commonName ??
                                scan.topPrediction?.plantName ??
                                'Unknown Plant',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (methodIcon != null) ...[
                          const SizedBox(width: 6),
                          methodIcon,
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.45),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            dateFormat.format(scan.scanDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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

  Widget _buildConfidencePill(double confidence) {
    final percentage = (confidence * 100).toStringAsFixed(0);
    final Color badgeColor;
    if (confidence >= 0.8) {
      badgeColor = AppTheme.safeGreen;
    } else if (confidence >= 0.6) {
      badgeColor = AppTheme.warningAmber;
    } else {
      badgeColor = AppTheme.errorDeep;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '$percentage%',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 9,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.local_florist,
        size: 40,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
      ),
    );
  }

  /// Returns method icon for a cloud scan (online = green cloud, offline = yellow chip), or null to show generic "Saved to cloud".
  Widget? _getCloudMethodIcon(CloudScan cloud) {
    final meta = cloud.metadata ?? {};
    final method = meta['method'] as String?;
    final fallbackUsed = meta['fallbackUsed'] as bool? ?? false;

    final bool isOffline = fallbackUsed || method == 'cam';
    final bool isOnline = method == 'grad-cam';

    if (isOnline) {
      return const Tooltip(
        message: 'AI Heatmap (Cloud)',
        child: Icon(Icons.cloud_done_outlined,
            size: 16, color: AppTheme.botanicalPrimary),
      );
    } else if (isOffline) {
      return Tooltip(
        message: fallbackUsed ? 'Fallback (Offline)' : 'CAM (Offline)',
        child: Icon(Icons.memory_outlined,
            size: 16, color: AppTheme.warningAmber),
      );
    }
    return null;
  }

  /// Returns an icon-only widget indicating scan method, or null if unknown.
  Widget? _getMethodIcon(ScanResult scan) {
    final method = scan.metadata['method'] as String?;
    final fallbackUsed = scan.metadata['fallbackUsed'] as bool? ?? false;

    final bool isOffline =
        fallbackUsed || method == 'cam' || scan.isOfflineScan;
    final bool isOnline = method == 'grad-cam';

    if (isOnline) {
      return const Tooltip(
        message: 'AI Heatmap (Cloud)',
        child: Icon(Icons.cloud_done_outlined,
            size: 16, color: AppTheme.botanicalPrimary),
      );
    } else if (isOffline) {
      return Tooltip(
        message: fallbackUsed ? 'Fallback (Offline)' : 'CAM (Offline)',
        child:
            Icon(Icons.memory_outlined, size: 16, color: AppTheme.warningAmber),
      );
    }
    return null;
  }
}
