import 'package:flutter/material.dart';
import 'package:herbascan/core/models/user_feedback.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Reusable feedback form: rating, category chips, comment, feature suggestion.
/// Parent provides controllers and owns their lifecycle. Optional [metadata] is
/// merged into UserFeedback (e.g. scan_id, plant_name, confidence).
class FeedbackFormContent extends StatefulWidget {
  final TextEditingController commentController;
  final TextEditingController featureSuggestionController;
  final Map<String, dynamic>? metadata;
  final void Function(UserFeedback feedback) onSubmit;
  final bool isSubmitting;
  final bool compact;

  const FeedbackFormContent({
    super.key,
    required this.commentController,
    required this.featureSuggestionController,
    this.metadata,
    required this.onSubmit,
    this.isSubmitting = false,
    this.compact = false,
  });

  @override
  State<FeedbackFormContent> createState() => _FeedbackFormContentState();
}

class _FeedbackFormContentState extends State<FeedbackFormContent> {
  int _rating = 0;
  String? _selectedCategory;
  bool _isAnonymous = false;
  final _commentSectionKey = GlobalKey();
  final _featureSectionKey = GlobalKey();
  late final FocusNode _commentFocusNode;
  late final FocusNode _featureFocusNode;

  @override
  void initState() {
    super.initState();
    _commentFocusNode = FocusNode();
    _featureFocusNode = FocusNode();
    _commentFocusNode.addListener(_scrollToFocusedField);
    _featureFocusNode.addListener(_scrollToFocusedField);
  }

  @override
  void dispose() {
    _commentFocusNode.removeListener(_scrollToFocusedField);
    _featureFocusNode.removeListener(_scrollToFocusedField);
    _commentFocusNode.dispose();
    _featureFocusNode.dispose();
    super.dispose();
  }

  void _scrollToFocusedField() {
    final node = _commentFocusNode.hasFocus ? _commentFocusNode : (_featureFocusNode.hasFocus ? _featureFocusNode : null);
    if (node == null) return;
    final key = _commentFocusNode.hasFocus ? _commentSectionKey : _featureSectionKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 150),
          alignment: 0.15,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      }
    });
  }

  void _submit() {
    if (_rating == 0 || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_rating == 0
              ? AppLocalizations.of(context).pleaseProvideRating
              : 'Please select a feedback category'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final comment = widget.commentController.text.trim();
    if (comment.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least 10 characters in your comment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final meta = Map<String, dynamic>.from(widget.metadata ?? {});
    meta['app_version'] = 'v1.0.28';
    meta['platform'] = Theme.of(context).platform.name;

    final feedback = UserFeedback(
      id: const Uuid().v4(),
      rating: _rating,
      category: _selectedCategory!,
      comment: comment,
      featureSuggestion: widget.featureSuggestionController.text.trim().isEmpty
          ? null
          : widget.featureSuggestionController.text.trim(),
      createdAt: DateTime.now(),
      metadata: meta,
      isAnonymous: _isAnonymous,
    );
    widget.onSubmit(feedback);
  }

  Widget _buildSubmitButton(ThemeData theme, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: widget.isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                l10n.submitFeedback,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  List<Widget> _buildFormFields(ThemeData theme, AppLocalizations l10n) {
    return [
      if (!widget.compact)
        Text(
          l10n.rateYourExperience,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      if (!widget.compact) const SizedBox(height: 12),
      Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNumber = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = starNumber),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    _rating >= starNumber ? Icons.star : Icons.star_border,
                    size: widget.compact ? 36 : 48,
                    color: _rating >= starNumber
                        ? Colors.amber
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        l10n.feedbackCategory,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: FeedbackCategory.all.map((category) {
          final isSelected = _selectedCategory == category;
          return ChoiceChip(
            label: Text(FeedbackCategory.getDisplayName(category)),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) setState(() => _selectedCategory = category);
            },
            selectedColor: Colors.green.shade100,
            labelStyle: TextStyle(
              color: isSelected
                  ? Colors.green.shade900
                  : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      KeyedSubtree(
        key: _commentSectionKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.yourComments,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              focusNode: _commentFocusNode,
              controller: widget.commentController,
              minLines: widget.compact ? 3 : 5,
              maxLines: null,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Share your thoughts about HerbaScan...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      KeyedSubtree(
        key: _featureSectionKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${l10n.featureSuggestion} (${l10n.optional})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              focusNode: _featureFocusNode,
              controller: widget.featureSuggestionController,
              minLines: 2,
              maxLines: null,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Suggest new features or improvements...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('Submit Anonymously'),
        subtitle: const Text(
          'Your identity will not be attached to this feedback.',
        ),
        value: _isAnonymous,
        onChanged: (val) => setState(() => _isAnonymous = val),
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.visibility_off_rounded),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final formFields = _buildFormFields(theme, l10n);

    if (widget.compact) {
      // Bottom sheet: fixed Send feedback button at bottom; scrollable form above.
      // Scrolling does not dismiss keyboard (manual) so user can scroll to bring field above keyboard.
      final horizontalPadding = 16.0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                viewInsets + 24,
              ),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.manual,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: formFields,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _buildSubmitButton(theme, l10n),
          ),
        ],
      );
    }

    // Full-screen: single scroll view with button inside (unchanged structure).
    final bottomPadding = 24 + viewInsets + 80;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...formFields,
          const SizedBox(height: 20),
          _buildSubmitButton(theme, l10n),
        ],
      ),
    );
  }
}
