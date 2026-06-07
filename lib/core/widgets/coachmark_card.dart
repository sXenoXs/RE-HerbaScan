import 'package:flutter/material.dart';
import 'package:herbascan/core/theme/app_theme.dart';

/// Floating tooltip card used by every coachmark step.
///
/// Visual match for the Philippine National ID hint card in the spec:
///   * white rounded card with soft shadow
///   * bold short title (e.g. "Tip:") + body text
///   * optional "Don't show this hint again" checkbox at the bottom
///   * Skip / Next (or Done) action row
class CoachmarkCard extends StatefulWidget {
  final String title;
  final String body;
  final String nextLabel;
  final String skipLabel;
  final bool isLast;
  final bool showDontShowAgain;
  final bool initialDontShowAgain;
  final ValueChanged<bool>? onDontShowAgainChanged;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const CoachmarkCard({
    super.key,
    required this.title,
    required this.body,
    required this.onNext,
    required this.onSkip,
    this.nextLabel = 'Next',
    this.skipLabel = 'Skip',
    this.isLast = false,
    this.showDontShowAgain = true,
    this.initialDontShowAgain = false,
    this.onDontShowAgainChanged,
  });

  @override
  State<CoachmarkCard> createState() => _CoachmarkCardState();
}

class _CoachmarkCardState extends State<CoachmarkCard> {
  late bool _dontShowAgain = widget.initialDontShowAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final bodyColor = isDark
        ? Colors.white.withOpacity(0.78)
        : AppTheme.textSecondary;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.5,
                    height: 1.4,
                    color: bodyColor,
                  ),
                  children: [
                    TextSpan(
                      text: '${widget.title} ',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    TextSpan(text: widget.body),
                  ],
                ),
              ),
              if (widget.showDontShowAgain) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    final next = !_dontShowAgain;
                    setState(() => _dontShowAgain = next);
                    widget.onDontShowAgainChanged?.call(next);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: Checkbox(
                            value: _dontShowAgain,
                            onChanged: (v) {
                              final next = v ?? false;
                              setState(() => _dontShowAgain = next);
                              widget.onDontShowAgainChanged?.call(next);
                            },
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Don't show this hint again",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            color: bodyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: widget.onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: bodyColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text(widget.skipLabel),
                  ),
                  FilledButton(
                    onPressed: widget.onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.botanicalPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 6),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child:
                        Text(widget.isLast ? 'Got it' : widget.nextLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
