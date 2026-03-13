import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/services/admin_user_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';

/// User Management: list users (email, join date, scan count), Suspend, Reactivate, Delete only.
class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState
    extends State<AdminUserManagementScreen> {
  List<AdminProfileRow> _profiles = [];
  List<AdminProfileRow> _filtered = [];
  bool _loading = true;
  String? _error;
  // Prevents concurrent suspend/reactivate/delete operations from overlapping
  bool _actionInProgress = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_profiles);
      } else {
        _filtered = _profiles
            .where((p) => p.email.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AdminUserService().listProfiles();
      if (mounted) {
        setState(() {
          _profiles = list;
          _filtered = List.from(list);
          _loading = false;
        });
        _applyFilter();
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

  Future<void> _setActive(AdminProfileRow row, bool active) async {
    if (_actionInProgress) return;
    _actionInProgress = true;
    try {
      final ok = await AdminUserService().setActive(row.id, active);
      if (ok && mounted) await _load();
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _setRole(AdminProfileRow row, String role) async {
    if (_actionInProgress) return;
    final isMakingAdmin = role == 'admin';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (!isMakingAdmin && currentUserId == row.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot remove your own admin role.')),
        );
      }
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMakingAdmin ? 'Make admin?' : 'Remove admin?'),
        content: Text(
          isMakingAdmin
              ? '${row.email} will be able to access the admin dashboard and manage users and catalog.'
              : '${row.email} will no longer have admin access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isMakingAdmin ? 'Make admin' : 'Remove admin'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    _actionInProgress = true;
    try {
      final ok = await AdminUserService().setRole(row.id, role);
      if (!mounted) return;
      if (ok) {
        await _load();
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isMakingAdmin ? l10n.userNowAdmin : l10n.adminRemoved,
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update role.')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _deleteUser(AdminProfileRow row) async {
    if (_actionInProgress) return;

    // Capture theme values synchronously before any await
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Delete user data?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete ${row.email} and all their cloud scans. It cannot be undone.',
              ),
              const SizedBox(height: 16),
              Text(
                'Type DELETE to confirm:',
                style: TextStyle(
                    color: errorColor, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  border: const OutlineInputBorder(),
                  errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: errorColor)),
                ),
                onChanged: (_) {
                  if (ctx.mounted) setDialogState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: confirmController.text.trim().toUpperCase() == 'DELETE'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: FilledButton.styleFrom(backgroundColor: errorColor),
              child: const Text('Delete User Data'),
            ),
          ],
        ),
      ),
    );

    // Defer disposal by two frames so the dialog route is fully torn down before we dispose.
    // Fixes _dependents.isEmpty when tapping Cancel or Confirm (TextField still dependent in single-frame defer).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        confirmController.dispose();
      });
    });

    if (confirm != true || !mounted) return;

    _actionInProgress = true;
    try {
      await AdminUserService().deleteUser(row.id);
      if (mounted) await _load();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint(
            '[AdminUserManagement][_deleteUser] Delete failed for ${row.email} (${row.id}): $e');
        if (e is FunctionException) {
          debugPrint(
              '[AdminUserManagement][_deleteUser] FunctionException status: ${e.status}, details: ${e.details}');
        }
        debugPrint('[AdminUserManagement][_deleteUser] stack: $stack');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Text(
                'User Directory',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by email…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        if (_filtered.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.isNotEmpty
                        ? 'No users match your search.'
                        : 'No users found.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = _filtered[index];
                return _buildUserRow(context, theme, row, dateFormat);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildUserRow(BuildContext context, ThemeData theme,
      AdminProfileRow row, DateFormat dateFormat) {
    final isAdmin = row.role == 'admin';
    final isActive = row.isActive;
    final initials = row.email.isNotEmpty
        ? row.email[0].toUpperCase()
        : '?';

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: isAdmin
            ? AppTheme.darkSurface
            : theme.colorScheme.surfaceContainerHighest,
        foregroundColor:
            isAdmin ? Colors.white : theme.colorScheme.onSurfaceVariant,
        child: Text(initials,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      title: Text(
        row.email.isEmpty ? '(no email)' : row.email,
        style: theme.textTheme.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.visible,
        softWrap: true,
      ),
      subtitle: Text(
        [
          row.createdAt != null
              ? 'Joined ${dateFormat.format(row.createdAt!)}'
              : null,
          '${row.scanCount} Scan${row.scanCount == 1 ? '' : 's'}',
        ].whereType<String>().join(' • '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppTheme.safeGreen : AppTheme.errorColor,
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) {
              switch (action) {
                case 'suspend':
                  _setActive(row, false);
                case 'reactivate':
                  _setActive(row, true);
                case 'make_admin':
                  _setRole(row, 'admin');
                case 'remove_admin':
                  _setRole(row, 'user');
                case 'delete':
                  _deleteUser(row);
              }
            },
            itemBuilder: (ctx) {
              final currentUserId = Supabase.instance.client.auth.currentUser?.id;
              final isCurrentUser = currentUserId == row.id;
              return [
                if (isActive)
                  const PopupMenuItem(
                    value: 'suspend',
                    child: Row(children: [
                      Icon(Icons.block_outlined),
                      SizedBox(width: 12),
                      Text('Suspend Account'),
                    ]),
                  )
                else
                  const PopupMenuItem(
                    value: 'reactivate',
                    child: Row(children: [
                      Icon(Icons.check_circle_outline,
                          color: AppTheme.safeGreen),
                      SizedBox(width: 12),
                      Text('Reactivate Account'),
                    ]),
                  ),
                if (!isAdmin)
                  PopupMenuItem(
                    value: 'make_admin',
                    child: Row(children: [
                      const Icon(Icons.admin_panel_settings_outlined),
                      const SizedBox(width: 12),
                      Text(AppLocalizations.of(context).makeAdmin),
                    ]),
                  ),
                if (isAdmin && !isCurrentUser)
                  PopupMenuItem(
                    value: 'remove_admin',
                    child: Row(children: [
                      const Icon(Icons.admin_panel_settings_rounded),
                      const SizedBox(width: 12),
                      Text(AppLocalizations.of(context).removeAdmin),
                    ]),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.person_remove_outlined,
                        color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Text('Delete User Data',
                        style:
                            TextStyle(color: theme.colorScheme.error)),
                  ]),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

