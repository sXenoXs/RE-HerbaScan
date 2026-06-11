import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/models/cloud_scan.dart';
import 'package:herbascan/core/models/data_deletion_request.dart';
import 'package:herbascan/core/services/data_deletion_service.dart';
import 'package:herbascan/core/services/herbarium_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

enum _ApproveChoice { approveOnly, approveAndTrain }

/// Data collection admin: review, approve, reject, or delete user-submitted scans.
/// Shown only when user role is admin (RBAC). RLS enforces on backend.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<CloudScan> _scans = [];
  bool _loading = true;
  String? _error;

  bool _pendingOnly = true;

  // Data Deletion Requests panel
  bool _showDeletionRequests = false;
  List<DataDeletionRequest> _deletionRequests = [];
  bool _loadingDeletions = false;
  String? _deletionError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await HerbariumService().getAdminScans(
        statusFilter: _pendingOnly ? 'pending' : null,
      );
      if (mounted) {
        setState(() {
          _scans = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(CloudScan scan, String status) async {
    final ok = await HerbariumService().updateScanStatus(scan.id, status);
    if (ok && mounted) _load();
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.9,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Full resolution – pinch to zoom'),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 64),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteScan(CloudScan scan) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete submission?'),
        content: const Text(
          'This will remove the scan from the database and storage. It cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await HerbariumService().adminDeleteScan(scan);
      if (mounted) _load();
    }
  }

  // ── Data Deletion Requests ──────────────────────────────────────────────────

  Future<void> _loadDeletionRequests() async {
    setState(() {
      _loadingDeletions = true;
      _deletionError = null;
    });
    try {
      final list = await DataDeletionService().fetchAllAdmin();
      if (mounted) {
        setState(() {
          _deletionRequests = list;
          _loadingDeletions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deletionError = e.toString();
          _loadingDeletions = false;
        });
      }
    }
  }

  Future<void> _updateDeletionStatus(int requestId, String status) async {
    final ok =
        await DataDeletionService().updateRequestStatus(requestId, status);
    if (ok && mounted) _loadDeletionRequests();
  }

  Future<void> _deleteDeletionRequest(int requestId) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete request?'),
        content:
            const Text('Remove this deletion request from the database.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DataDeletionService().adminDeleteRequest(requestId);
      if (mounted) _loadDeletionRequests();
    }
  }

  // ── Approve sheet ────────────────────────────────────────────────────────────

  /// Shows the approve action sheet. Approve direction swipe or "Approve" menu tap
  /// both land here. Returns after side-effects complete and list has been reloaded.
  Future<void> _showApproveSheet(CloudScan scan) async {
    final choice = await showModalBottomSheet<_ApproveChoice>(
      context: context,
      builder: (_) => _ApproveActionSheet(scan: scan),
    );
    if (choice == null || !mounted) return;

    if (choice == _ApproveChoice.approveOnly) {
      await _updateStatus(scan, 'approved');
      return;
    }

    // approveAndTrain — show blocking progress overlay while storage copy runs
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CopyingProgressDialog(),
    );

    final plantSlug = scan.plantId ?? '';
    final ok =
        await HerbariumService().approveForTraining(scan.id, plantSlug);

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss progress dialog

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Image added to training dataset for $plantSlug'
              : 'Storage copy failed — scan approved but not in training-datasets',
        ),
        backgroundColor:
            ok ? AppTheme.botanicalPrimary : AppTheme.errorColor,
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(child: Text('Access denied. Admin only.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
            _showDeletionRequests ? 'Data Deletion Requests' : 'Submission Triage'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        actions: [
          IconButton(
            icon: Icon(_showDeletionRequests
                ? Icons.inbox_rounded
                : Icons.delete_sweep_outlined),
            onPressed: () {
              setState(() => _showDeletionRequests = !_showDeletionRequests);
              if (_showDeletionRequests) _loadDeletionRequests();
            },
            tooltip: _showDeletionRequests
                ? 'Back to Submissions'
                : 'Data Deletion Requests',
          ),
        ],
        bottom: _showDeletionRequests
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                                value: true,
                                label: Text('Pending'),
                                icon: Icon(Icons.pending_outlined)),
                            ButtonSegment(
                                value: false,
                                label: Text('All'),
                                icon: Icon(Icons.list)),
                          ],
                          selected: {_pendingOnly},
                          onSelectionChanged: (Set<bool> sel) {
                            setState(() => _pendingOnly = sel.first);
                            _load();
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith<
                                Color?>((states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppTheme.botanicalPrimary;
                              }
                              return theme.colorScheme.surface;
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith<
                                Color?>((states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.white;
                              }
                              return theme.colorScheme.onSurface;
                            }),
                            iconColor: WidgetStateProperty.resolveWith<
                                Color?>((states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.white;
                              }
                              return theme.colorScheme.onSurface;
                            }),
                            side: WidgetStateProperty.all(
                              BorderSide(
                                  color: theme.colorScheme.outline
                                      .withValues(alpha: 0.4)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _load,
                          tooltip: 'Refresh'),
                    ],
                  ),
                ),
              ),
      ),
      body: _showDeletionRequests
          ? _buildDeletionRequestsBody(theme)
          : GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -300 && _pendingOnly) {
                  setState(() => _pendingOnly = false);
                  _load();
                } else if (velocity > 300 && !_pendingOnly) {
                  setState(() => _pendingOnly = true);
                  _load();
                }
              },
              behavior: HitTestBehavior.translucent,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_error!,
                                    style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 16),
                                FilledButton(
                                    onPressed: _load,
                                    child: const Text('Retry')),
                              ],
                            ),
                          ),
                        )
                      : _scans.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox_rounded,
                                      size: 64,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.35)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Inbox Zero. All submissions reviewed.',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                itemCount: _scans.length,
                                itemBuilder: (context, index) {
                                  final scan = _scans[index];
                                  return _buildDismissibleTile(
                                      context, theme, scan);
                                },
                              ),
                            ),
            ),
    );
  }

  Widget _buildDeletionRequestsBody(ThemeData theme) {
    if (_loadingDeletions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_deletionError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_deletionError!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _loadDeletionRequests,
                  child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_deletionRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist_rounded,
                size: 64,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              'No deletion requests.',
              style: theme.textTheme.titleMedium?.copyWith(
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadDeletionRequests,
      child: ListView.builder(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _deletionRequests.length,
        itemBuilder: (context, index) {
          final req = _deletionRequests[index];
          return _buildDeletionRequestCard(context, theme, req);
        },
      ),
    );
  }

  Widget _buildDeletionRequestCard(
      BuildContext context, ThemeData theme, DataDeletionRequest req) {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
    final statusColor = switch (req.status) {
      'approved' => AppTheme.safeGreen,
      'rejected' => AppTheme.errorColor,
      _ => AppTheme.warningAmber,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.warningAmber,
                  radius: 18,
                  child: Icon(Icons.delete_forever_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.email ?? 'Unknown',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateFormat.format(req.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    req.status,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3),
                  ),
                ),
              ],
            ),
            if (req.reason != null && req.reason!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  req.reason!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ),
            ],
            if (req.status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _updateDeletionStatus(req.id, 'rejected'),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        _updateDeletionStatus(req.id, 'approved'),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.safeGreen,
                    ),
                  ),
                ],
              ),
            ],
            if (req.status != 'pending') ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _deleteDeletionRequest(req.id),
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: theme.colorScheme.error),
                  label: Text('Remove',
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDismissibleTile(
      BuildContext context, ThemeData theme, CloudScan scan) {
    return Dismissible(
      key: Key('scan_${scan.id}'),
      background: _buildSwipeBackground(
        color: AppTheme.safeGreen,
        icon: Icons.check_rounded,
        alignment: Alignment.centerLeft,
        label: 'Approve',
      ),
      secondaryBackground: _buildSwipeBackground(
        color: AppTheme.errorColor,
        icon: Icons.close_rounded,
        alignment: Alignment.centerRight,
        label: 'Reject',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Approve direction: handle via bottom sheet, never auto-dismiss.
          await _showApproveSheet(scan);
          return false;
        }
        // Reject direction: let dismiss animate, then update status in onDismissed.
        return true;
      },
      onDismissed: (direction) {
        // Only reject reaches here (approve returns false from confirmDismiss).
        if (direction == DismissDirection.endToStart) {
          _updateStatus(scan, 'rejected');
        }
      },
      child: _buildScanRow(context, theme, scan),
    );
  }

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

  Widget _buildScanRow(
      BuildContext context, ThemeData theme, CloudScan scan) {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
    final statusColor = switch (scan.status) {
      'approved' => AppTheme.safeGreen,
      'rejected' => AppTheme.errorColor,
      _ => AppTheme.warningAmber,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            GestureDetector(
              onTap: scan.imageUrl != null && scan.imageUrl!.isNotEmpty
                  ? () => _showImageDialog(context, scan.imageUrl!)
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: scan.imageUrl != null && scan.imageUrl!.isNotEmpty
                    ? Image.network(
                        scan.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.eco,
                              size: 36, color: theme.colorScheme.outline),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.eco,
                            size: 36, color: theme.colorScheme.outline),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan.plantId ?? 'Unknown Plant',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(scan.scanDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          scan.status,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3),
                        ),
                      ),
                      if (scan.trainingEligible)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.botanicalPrimary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.model_training_rounded,
                                  size: 11,
                                  color: AppTheme.botanicalPrimary),
                              SizedBox(width: 4),
                              Text(
                                'Training eligible',
                                style: TextStyle(
                                    color: AppTheme.botanicalPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) {
                switch (action) {
                  case 'approve':
                    _showApproveSheet(scan);
                  case 'reject':
                    _updateStatus(scan, 'rejected');
                  case 'delete':
                    _deleteScan(scan);
                }
              },
              itemBuilder: (ctx) => [
                if (scan.status != 'approved')
                  const PopupMenuItem(
                    value: 'approve',
                    child: Row(children: [
                      Icon(Icons.check_circle_outline,
                          color: AppTheme.safeGreen),
                      SizedBox(width: 12),
                      Text('Approve…'),
                    ]),
                  ),
                if (scan.status != 'rejected')
                  const PopupMenuItem(
                    value: 'reject',
                    child: Row(children: [
                      Icon(Icons.cancel_outlined),
                      SizedBox(width: 12),
                      Text('Reject'),
                    ]),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Text('Delete Permanently',
                        style:
                            TextStyle(color: theme.colorScheme.error)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Approve action bottom sheet ───────────────────────────────────────────────

class _ApproveActionSheet extends StatelessWidget {
  const _ApproveActionSheet({required this.scan});

  final CloudScan scan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Approve submission',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              scan.plantId ?? 'Unknown Plant',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppTheme.safeGreen,
                radius: 20,
                child: Icon(Icons.check_rounded,
                    color: Colors.white, size: 20),
              ),
              title: const Text('Approve only',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Mark as approved; image stays in herbarium.'),
              onTap: () =>
                  Navigator.pop(context, _ApproveChoice.approveOnly),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppTheme.botanicalPrimary,
                radius: 20,
                child: Icon(Icons.model_training_rounded,
                    color: Colors.white, size: 20),
              ),
              title: const Text('Approve + Add to Training Data',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Copies image to training-datasets bucket for the next training run.'),
              onTap: () =>
                  Navigator.pop(context, _ApproveChoice.approveAndTrain),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Progress overlay shown while storage copy runs ────────────────────────────

class _CopyingProgressDialog extends StatelessWidget {
  const _CopyingProgressDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(
              color: AppTheme.botanicalPrimary, strokeWidth: 3),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              'Copying image to training dataset…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
