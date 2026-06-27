import 'package:flutter/material.dart';
import 'package:herbascan/core/models/user_feedback.dart';
import 'package:herbascan/core/services/feedback_service.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/features/feedback/feedback_form_content.dart';

/// Bottom sheet content for contextual feedback (e.g. from Plant Result).
/// Pass [scanId], [plantName], [confidence] to attach to feedback metadata.
/// Controllers are created and disposed by this widget.
class FeedbackBottomSheetContent extends StatefulWidget {
  final String? scanId;
  final String? plantName;
  final double? confidence;
  final VoidCallback? onClosed;

  const FeedbackBottomSheetContent({
    super.key,
    this.scanId,
    this.plantName,
    this.confidence,
    this.onClosed,
  });

  @override
  State<FeedbackBottomSheetContent> createState() =>
      _FeedbackBottomSheetContentState();
}

class _FeedbackBottomSheetContentState extends State<FeedbackBottomSheetContent> {
  final _feedbackService = FeedbackService();
  late final TextEditingController _commentController;
  late final TextEditingController _featureController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _featureController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _featureController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _metadata {
    final m = <String, dynamic>{};
    if (widget.scanId != null) m['scan_id'] = widget.scanId;
    if (widget.plantName != null) m['plant_name'] = widget.plantName;
    if (widget.confidence != null) m['confidence'] = widget.confidence;
    return m;
  }

  Future<void> _onSubmit(UserFeedback feedback) async {
    setState(() => _isSubmitting = true);
    try {
      await _feedbackService.saveFeedback(feedback);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onClosed?.call();
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

  // IMPORTANT CALLER INSTRUCTION: 
  // Any parent function calling showModalBottomSheet for this widget MUST have 
  // `isScrollControlled: true` set, otherwise Flutter will forcefully cap the height 
  // to 50% and ruin the layout.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: ScaffoldMessenger(
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    l10n.sendFeedback,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: FeedbackFormContent(
                    commentController: _commentController,
                    featureSuggestionController: _featureController,
                    metadata: _metadata,
                    onSubmit: _onSubmit,
                    isSubmitting: _isSubmitting,
                    compact: true,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
