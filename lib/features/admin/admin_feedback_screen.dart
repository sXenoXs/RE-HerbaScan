import 'package:flutter/material.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/services/feedback_service.dart';
import 'package:herbascan/core/models/user_feedback.dart';
import 'package:intl/intl.dart';
import 'package:herbascan/core/localization/app_localizations.dart';

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

  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedStatus;

  List<Map<String, dynamic>> get _filteredItems {
    return _items.where((item) {
      final comment = (item['comment'] as String? ?? '').toLowerCase();
      final userId = (item['user_id'] as String? ?? '').toLowerCase();
      final category = item['category'] as String?;
      final status = item['status'] as String? ?? 'pending';

      if (_searchQuery.isNotEmpty && !comment.contains(_searchQuery) && !userId.contains(_searchQuery)) {
        return false;
      }
      if (_selectedCategory != null && category != _selectedCategory) {
        return false;
      }
      if (_selectedStatus != null && status != _selectedStatus) {
        return false;
      }
      return true;
    }).toList();
  }

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
          content: Text('${AppLocalizations.of(context).failedToLoadFeedback}: $e'),
          backgroundColor: AppTheme.errorDeep,
        ),
      );
    }
  }

  String _userLabel(Map<String, dynamic> row, BuildContext context) {
    final userId = row['user_id'];
    if (userId == null) return AppLocalizations.of(context).anonymous;
    final s = userId.toString();
    if (s.length > 12) return '${AppLocalizations.of(context).userText} ${s.substring(0, 8)}…';
    return '${AppLocalizations.of(context).userText} $s';
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
                AppLocalizations.of(context).couldNotLoadFeedback,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        ),
      );
    }

    final displayedItems = _filteredItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    AppLocalizations.of(context).userFeedback,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadData,
                    tooltip: AppLocalizations.of(context).refresh,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).searchFeedbackOrUser,
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DropdownMenu<String?>(
                      initialSelection: null,
                      onSelected: (value) {
                        setState(() {
                          _selectedStatus = value;
                        });
                      },
                      dropdownMenuEntries: [
                        DropdownMenuEntry(value: null, label: AppLocalizations.of(context).allStatuses),
                        DropdownMenuEntry(value: 'pending', label: AppLocalizations.of(context).pending),
                        DropdownMenuEntry(value: 'reviewed', label: AppLocalizations.of(context).reviewed),
                        DropdownMenuEntry(value: 'resolved', label: AppLocalizations.of(context).resolved),
                      ],
                      label: Text(AppLocalizations.of(context).statusLabel),
                      width: 160,
                      inputDecorationTheme: const InputDecorationTheme(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownMenu<String?>(
                      initialSelection: null,
                      onSelected: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                      dropdownMenuEntries: [
                        DropdownMenuEntry(value: null, label: AppLocalizations.of(context).allCategories),
                        ...FeedbackCategory.all.map((c) => DropdownMenuEntry(value: c, label: FeedbackCategory.getDisplayName(c))),
                      ],
                      label: Text(AppLocalizations.of(context).categoryLabel),
                      width: 180,
                      inputDecorationTheme: const InputDecorationTheme(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
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
              itemCount: displayedItems.isEmpty ? 1 : displayedItems.length,
              itemBuilder: (context, index) {
                if (displayedItems.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 48.0),
                    child: Center(
                      child: Text(
                        _items.isEmpty ? AppLocalizations.of(context).noFeedbackInSupabase : AppLocalizations.of(context).noFeedbackMatchesFilters,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                return _FeedbackCard(
                  theme: theme,
                  row: displayedItems[index],
                  userLabel: _userLabel(displayedItems[index], context),
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

  Widget _buildMetaTag(String text) {
    final theme = widget.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _onDelete() async {
    final id = widget.row['id']?.toString();
    if (id == null || id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteFeedbackPrompt),
        content: Text(
          AppLocalizations.of(context).deleteFeedbackDesc,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorDeep),
            child: Text(AppLocalizations.of(context).deleteBtn),
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
          SnackBar(content: Text(AppLocalizations.of(context).feedbackRemoved)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).couldNotDeleteFeedback),
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
    final status = row['status'] as String? ?? 'pending';
    const maxCommentPreview = 120;

    Color statusColor;
    if (status == 'resolved') {
      statusColor = AppTheme.successColor;
    } else if (status == 'reviewed') {
      statusColor = Colors.blue;
    } else {
      statusColor = AppTheme.warningAmber;
    }

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
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          Container(
                            constraints: const BoxConstraints(minWidth: 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              categoryDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.brightness == Brightness.light
                                    ? AppTheme.primaryDark
                                    : theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    icon: _deleteInProgress
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        _onDelete();
                      } else {
                        setState(() => _deleteInProgress = true);
                        try {
                          final ok = await widget.feedbackService.updateFeedbackStatus(widget.row['id'].toString(), value);
                          if (ok) {
                            setState(() {
                              widget.row['status'] = value;
                            });
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).statusUpdated} $value')));
                          } else {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).failedToUpdateStatus), backgroundColor: AppTheme.errorDeep));
                          }
                        } finally {
                          if (mounted) setState(() => _deleteInProgress = false);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      if (status != 'reviewed')
                        PopupMenuItem(
                          value: 'reviewed',
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.blue, size: 22),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context).markReviewed),
                            ],
                          ),
                        ),
                      if (status != 'resolved')
                        PopupMenuItem(
                          value: 'resolved',
                          child: Row(
                            children: [
                              const Icon(Icons.done_all, color: AppTheme.successColor, size: 22),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context).markResolved),
                            ],
                          ),
                        ),
                      if (status != 'pending')
                        PopupMenuItem(
                          value: 'pending',
                          child: Row(
                            children: [
                              const Icon(Icons.pending_actions, color: AppTheme.warningAmber, size: 22),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context).markPending),
                            ],
                          ),
                        ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, color: AppTheme.errorDeep, size: 22),
                            const SizedBox(width: 12),
                            Text(AppLocalizations.of(context).deleteBtn),
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
                '${widget.userLabel} • $created',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                        padding: const EdgeInsets.only(top: 10),
                        child: TextButton(
                          onPressed: () => setState(() => _expanded = !_expanded),
                          child: Text(_expanded ? AppLocalizations.of(context).showLess : AppLocalizations.of(context).showMore),
                        ),
                      ),
                  ],
                ),
              ),
              // 5. Suggestion
              if (featureSuggestion != null && featureSuggestion.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${AppLocalizations.of(context).suggestion}: $featureSuggestion',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                  ),
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
                      Builder(
                        builder: (_) {
                          final s = metaMap['scan_id']!.toString();
                          final truncated =
                              s.length >= 8 ? '${s.substring(0, 8)}...' : s;
                          return _buildMetaTag('scan: $truncated');
                        },
                      ),
                    if (metaMap['plant_name'] != null)
                      _buildMetaTag('${metaMap['plant_name']}'),
                    if (metaMap['confidence'] != null)
                      _buildMetaTag(
                        '${(metaMap['confidence'] * 100).toStringAsFixed(0)}%',
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
