import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:herbascan/core/services/admin_user_service.dart';

/// User Management: list users (email, join date, scan count), Deactivate and Delete only. No password/email editing.
class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  List<AdminProfileRow> _profiles = [];
  bool _loading = true;
  String? _error;

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
      final list = await AdminUserService().listProfiles();
      if (mounted) {
        setState(() {
          _profiles = list;
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

  Future<void> _setActive(AdminProfileRow row, bool active) async {
    final ok = await AdminUserService().setActive(row.id, active);
    if (ok && mounted) _load();
  }

  Future<void> _deleteUser(AdminProfileRow row) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text(
          'This will permanently delete ${row.email} and all their cloud scans. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await AdminUserService().deleteUser(row.id);
        if (mounted) _load();
      } catch (e, stack) {
        if (kDebugMode) {
          debugPrint('[AdminUserManagement][_deleteUser] Delete failed for ${row.email} (${row.id}): $e');
          if (e is FunctionException) {
            debugPrint('[AdminUserManagement][_deleteUser] FunctionException status: ${e.status}, details: ${e.details}');
          }
          debugPrint('[AdminUserManagement][_deleteUser] stack: $stack');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      }
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
    if (_profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No users',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Text(
                'User Management',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: _profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final row = _profiles[index];
              return _UserCard(
                theme: theme,
                row: row,
                dateFormat: dateFormat,
                onSetActive: _setActive,
                onDelete: _deleteUser,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One user as a card: no horizontal scroll, works on all screen sizes.
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.theme,
    required this.row,
    required this.dateFormat,
    required this.onSetActive,
    required this.onDelete,
  });

  final ThemeData theme;
  final AdminProfileRow row;
  final DateFormat dateFormat;
  final void Function(AdminProfileRow row, bool active) onSetActive;
  final void Function(AdminProfileRow row) onDelete;

  @override
  Widget build(BuildContext context) {
    final isActive = row.isActive;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.email.isEmpty ? '(no email)' : row.email,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(row.role),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text(
                  row.createdAt != null
                      ? dateFormat.format(row.createdAt!)
                      : '—',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${row.scanCount} scan${row.scanCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.shade700
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Deactivated',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isActive
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                if (isActive)
                  TextButton(
                    onPressed: () => onSetActive(row, false),
                    child: const Text('Deactivate'),
                  )
                else
                  TextButton(
                    onPressed: () => onSetActive(row, true),
                    child: const Text('Activate'),
                  ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => onDelete(row),
                  child: Text(
                    'Delete',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
