import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/models/cloud_scan.dart';
import 'package:herbascan/core/services/herbarium_service.dart';
import 'package:intl/intl.dart';

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
      final list = await HerbariumService().getAdminScans();
      if (mounted)
        setState(() {
          _scans = list;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _updateStatus(CloudScan scan, String status) async {
    final ok = await HerbariumService().updateScanStatus(scan.id, status);
    if (ok && mounted) _load();
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
            child: Text('Delete',
                style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await HerbariumService().adminDeleteScan(scan);
      if (mounted) _load();
    }
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
        title: const Text('Review submissions'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _scans.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          Text(
                            'No submissions yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _scans.length,
                        itemBuilder: (context, index) {
                          final scan = _scans[index];
                          return _buildScanTile(context, theme, scan);
                        },
                      ),
                    ),
    );
  }

  Widget _buildScanTile(BuildContext context, ThemeData theme, CloudScan scan) {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (scan.imageUrl != null && scan.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      scan.imageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.eco,
                          size: 48, color: theme.colorScheme.outline),
                    ),
                  )
                else
                  Icon(Icons.eco, size: 48, color: theme.colorScheme.outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scan.plantId ?? 'Unknown',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(scan.scanDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(scan.status),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (scan.status != 'approved')
                  FilledButton.icon(
                    onPressed: () => _updateStatus(scan, 'approved'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                  ),
                if (scan.status != 'rejected')
                  OutlinedButton.icon(
                    onPressed: () => _updateStatus(scan, 'rejected'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                  ),
                TextButton.icon(
                  onPressed: () => _deleteScan(scan),
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: theme.colorScheme.error),
                  label: Text('Delete',
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
