import 'package:flutter/material.dart';
import 'package:herbascan/core/models/user_feedback.dart';
import 'package:herbascan/core/services/feedback_service.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/features/feedback/feedback_form_content.dart';

/// Full-screen feedback. Optional [scanId], [plantName], [confidence] are
/// attached to feedback metadata (e.g. when opened from Plant Result or milestone).
class FeedbackScreen extends StatefulWidget {
  final String? scanId;
  final String? plantName;
  final double? confidence;

  const FeedbackScreen({
    super.key,
    this.scanId,
    this.plantName,
    this.confidence,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _feedbackService = FeedbackService();
  final _commentController = TextEditingController();
  final _featureController = TextEditingController();
  bool _isSubmitting = false;

  Map<String, dynamic> get _metadata {
    final m = <String, dynamic>{};
    if (widget.scanId != null) m['scan_id'] = widget.scanId;
    if (widget.plantName != null) m['plant_name'] = widget.plantName;
    if (widget.confidence != null) m['confidence'] = widget.confidence;
    return m;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _featureController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit(UserFeedback feedback) async {
    setState(() => _isSubmitting = true);
    try {
      await _feedbackService.saveFeedback(feedback);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: Text(AppLocalizations.of(context).thankYou),
          content: Text(AppLocalizations.of(context).feedbackSubmitted),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context).done),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sendFeedback),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.viewInsetsOf(context).bottom + 80,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.feedback_outlined,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.yourFeedbackMatters,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Help us improve HerbaScan by sharing your experience',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FeedbackFormContent(
              commentController: _commentController,
              featureSuggestionController: _featureController,
              metadata: _metadata,
              onSubmit: _onSubmit,
              isSubmitting: _isSubmitting,
              compact: false,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your feedback is stored locally and used for thesis research purposes only.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
