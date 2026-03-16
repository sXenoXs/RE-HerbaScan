import 'package:flutter/material.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/services/feedback_service.dart';
import 'package:herbascan/core/models/user_feedback.dart';
import 'package:intl/intl.dart';

/// Admin-only screen: list feedback submissions from Supabase (Option B).
/// Requires migration 20260316000000_user_feedback.sql to be run.
class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  final _feedbackService = FeedbackService();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _feedbackService.getFeedbackFromSupabase();
      if (!mounted) return;
      setState(() {
        _items = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load feedback: $e'),
          backgroundColor: AppTheme.errorDeep,
        ),
      );
    }
  }

  String _userLabel(Map<String, dynamic> row) {
    final userId = row['user_id'];
    if (userId == null) return 'Anonymous';
    final s = userId.toString();
    if (s.length > 12) return 'User ${s.substring(0, 8)}…';
    return 'User $s';
  }

  String _formatDate(dynamic v) {
    if (v == null) return '—';
    if (v is String) {
      try {
        final dt = DateTime.parse(v);
        return DateFormat('MMM d, yyyy · HH:mm').format(dt);
      } catch (_) {
        return v;
      }
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Could not load feedback.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Text(
                'User Feedback',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _items.isEmpty ? 1 : _items.length,
              itemBuilder: (context, index) {
                if (_items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 48.0),
                    child: Center(
                      child: Text(
                        'No feedback in Supabase yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                return _FeedbackCard(
                  theme: theme,
                  row: _items[index],
                  userLabel: _userLabel(_items[index]),
                  formatDate: _formatDate,
                  feedbackService: _feedbackService,
                  onDeleted: _loadData,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackCard extends StatefulWidget {
  final ThemeData theme;
  final Map<String, dynamic> row;
  final String userLabel;
  final String Function(dynamic) formatDate;
  final FeedbackService feedbackService;
  final VoidCallback onDeleted;

  const _FeedbackCard({
    required this.theme,
    required this.row,
    required this.userLabel,
    required this.formatDate,
    required this.feedbackService,
    required this.onDeleted,
  });

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  bool _expanded = false;
  bool _deleteInProgress = false;

  Future<void> _onDelete() async {
    final id = widget.row['id']?.toString();
    if (id == null || id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete feedback'),
        content: const Text(
          'Are you sure you want to remove this feedback? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorDeep),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleteInProgress = true);
    try {
      final ok = await widget.feedbackService.deleteFeedbackFromSupabase(id);
      if (!mounted) return;
      if (ok) {
        widget.onDeleted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback removed')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not delete feedback'),
            backgroundColor: AppTheme.errorDeep,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleteInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final row = widget.row;
    final rating = row['rating'] as int? ?? 0;
    final category = row['category'] as String? ?? '—';
    final comment = row['comment'] as String? ?? '';
    final featureSuggestion = row['feature_suggestion'] as String?;
    final metadata = row['metadata'];
    final metaMap = metadata is Map ? Map<String, dynamic>.from(metadata) : null;
    final created = widget.formatDate(row['created_at']);

    final categoryDisplay = FeedbackCategory.getDisplayName(category);
    const maxCommentPreview = 120;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header row: category pill + stars + time + menu
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      categoryDisplay,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.brightness == Brightness.light
                            ? AppTheme.primaryDark
                            : theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ...List.generate(5, (i) {
                    final filled = (i + 1) <= rating;
                    return Icon(
                      filled ? Icons.star : Icons.star_border,
                      size: 20,
                      color: filled ? Colors.amber : theme.colorScheme.onSurfaceVariant,
                    );
                  }),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      created,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: _deleteInProgress
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'delete') _onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: AppTheme.errorDeep, size: 22),
                            SizedBox(width: 12),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // 2. User line
              const SizedBox(height: 6),
              Text(
                widget.userLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // 3. Divider
              const SizedBox(height: 8),
              Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              const SizedBox(height: 8),
              // 4. Body (comment)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _expanded ? comment : (comment.length > maxCommentPreview ? '${comment.substring(0, maxCommentPreview)}…' : comment),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: _expanded ? null : 3,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                    ),
                    if (comment.length > maxCommentPreview)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextButton(
                          onPressed: () => setState(() => _expanded = !_expanded),
                          child: Text(_expanded ? 'Show less' : 'Show more'),
                        ),
                      ),
                  ],
                ),
              ),
              // 5. Suggestion
              if (featureSuggestion != null && featureSuggestion.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Suggestion: $featureSuggestion',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                ),
              ],
              // 6. Metadata chips
              if (metaMap != null && metaMap.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (metaMap['scan_id'] != null)
                      Chip(
                        side: BorderSide(color: theme.colorScheme.outline),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        label: Builder(
                          builder: (_) {
                            final s = metaMap['scan_id']!.toString();
                            final truncated = s.length >= 8 ? '${s.substring(0, 8)}...' : s;
                            return Text('scan: $truncated');
                          },
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (metaMap['plant_name'] != null)
                      Chip(
                        side: BorderSide(color: theme.colorScheme.outline),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        label: Text('${metaMap['plant_name']}'),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (metaMap['confidence'] != null)
                      Chip(
                        side: BorderSide(color: theme.colorScheme.outline),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        label: Text('${(metaMap['confidence'] * 100).toStringAsFixed(0)}%'),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
