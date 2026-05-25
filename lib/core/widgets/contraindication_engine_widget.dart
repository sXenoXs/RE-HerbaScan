import 'package:flutter/material.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/safety_profile.dart';
import 'package:herbascan/core/services/safety_profile_service.dart';
import 'package:herbascan/core/localization/app_localizations.dart';

/// Reusable educational disclaimer. Shown below safety cards.
class SafetyDisclaimerWidget extends StatelessWidget {
  const SafetyDisclaimerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_hospital,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.safetyDisclaimerEducational,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confidence threshold below which a prediction is treated as a no-match
/// (routed to NoMatchFoundScreen) and safety info is suppressed.
const double kLowConfidenceThreshold = 0.90;

/// Deterministic Contraindication Engine: color-coded safety cards from
/// structured SafetyProfile only (no LLM). Always shows disclaimer below.
/// When [confidence] is non-null and < [kLowConfidenceThreshold], shows
/// a suppressed state instead of profile (safety-first).
class ContraindicationEngineWidget extends StatefulWidget {
  final Plant? plant;
  final String? plantId;
  final String? commonName;
  /// When non-null and < kLowConfidenceThreshold, safety cards are suppressed.
  final double? confidence;

  const ContraindicationEngineWidget({
    super.key,
    this.plant,
    this.plantId,
    this.commonName,
    this.confidence,
  });

  @override
  State<ContraindicationEngineWidget> createState() =>
      _ContraindicationEngineWidgetState();
}

class _ContraindicationEngineWidgetState
    extends State<ContraindicationEngineWidget> {
  SafetyProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant ContraindicationEngineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plant?.id != widget.plant?.id ||
        oldWidget.plantId != widget.plantId ||
        oldWidget.commonName != widget.commonName) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final service = SafetyProfileService();
    SafetyProfile? profile;
    if (widget.plant != null) {
      profile = await service.getSafetyProfile(widget.plant!);
    } else if (widget.plantId != null && widget.plantId!.isNotEmpty) {
      profile = await service.getSafetyProfileByPlantId(widget.plantId!);
    } else if (widget.commonName != null && widget.commonName!.isNotEmpty) {
      profile = await service.getSafetyProfileByCommonName(widget.commonName!);
    }
    if (mounted) {
      setState(() {
        _profile = profile;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // ROADMAP B 1.1: Suppress safety when confidence too low; still show long disclaimer
    if (widget.confidence != null &&
        widget.confidence! < kLowConfidenceThreshold) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSuppressedState(context),
          const SizedBox(height: 12),
          SafetyDisclaimerWidget(),
        ],
      );
    }

    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          SafetyDisclaimerWidget(),
        ],
      );
    }

    final profile = _profile;
    final hasProfile = profile != null;
    final isEmptySafe =
        hasProfile &&
        profile.isGenerallySafe &&
        profile.knownSideEffects.isEmpty &&
        profile.drugInteractions.isEmpty &&
        profile.strictContraindications.isEmpty &&
        !profile.pregnancyWarning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasProfile) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.noStructuredSafetyData,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ] else ...[
          if (profile.needsStrictContraindications) _buildStrictCautionCard(context),
          if (profile.drugInteractions.isNotEmpty) _buildOrangeCard(context, l10n.drugInteractions, '${l10n.avoidUseWith} ${profile.drugInteractions.join(', ')}.'),
          if (profile.pregnancyWarning) _buildRedCard(context, l10n.notSafeForPregnancy),
          if (profile.knownSideEffects.isNotEmpty) _buildYellowSection(context, l10n.knownSideEffects, profile.knownSideEffects),
          if (profile.strictContraindications.isNotEmpty) _buildRedCard(context, l10n.strictContraindications, profile.strictContraindications.join('. ')),
          if (isEmptySafe) _buildGreenCard(context, l10n.generallySafeForConsumption),
        ],
        const SizedBox(height: 12),
        SafetyDisclaimerWidget(),
      ],
    );
  }

  /// ROADMAP B 1.1: Shown when confidence < kLowConfidenceThreshold.
  Widget _buildSuppressedState(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.safetyInformationUnavailable,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.safetyInformationUnavailableBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Prominent card when plant has needs_strict_contraindications (e.g. Kamias, Kamoteng Kahoy, Kakawate).
  Widget _buildStrictCautionCard(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.orange.withOpacity(0.2)
        : Colors.orange.shade100;
    final borderColor = isDark
        ? Colors.orange.withOpacity(0.6)
        : Colors.orange.shade700;
    final titleColor = isDark ? Colors.orange.shade200 : Colors.orange.shade900;
    final bodyColor = isDark
        ? Colors.orange.shade100
        : Colors.orange.shade900.withOpacity(0.9);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: titleColor, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.useWithStrictCaution,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.useWithStrictCautionBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: bodyColor,
                      height: 1.4,
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

  Widget _buildOrangeCard(BuildContext context, String title, String body) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.orange.withOpacity(0.15)
        : Colors.orange.shade50;
    final borderColor = isDark
        ? Colors.orange.withOpacity(0.4)
        : Colors.orange.shade300;
    final titleColor = isDark ? Colors.orange.shade200 : Colors.orange.shade900;
    final bodyColor = isDark
        ? Colors.orange.shade100
        : Colors.orange.shade900.withOpacity(0.85);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: titleColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: bodyColor,
                      height: 1.4,
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

  Widget _buildRedCard(BuildContext context, String title, [String? body]) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
          border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cancel_outlined, color: theme.colorScheme.error, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  if (body != null && body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYellowSection(
      BuildContext context, String title, List<String> items) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.amber.withOpacity(0.15)
        : Colors.amber.shade50;
    final borderColor = isDark
        ? Colors.amber.withOpacity(0.4)
        : Colors.amber.shade300;
    final titleColor = isDark ? Colors.amber.shade200 : Colors.amber.shade900;
    final bodyColor = isDark
        ? Colors.amber.shade100
        : Colors.amber.shade900.withOpacity(0.85);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: titleColor)),
                      Expanded(
                        child: Text(
                          e,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: bodyColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildGreenCard(BuildContext context, String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.green.withOpacity(0.15)
        : Colors.green.shade50;
    final borderColor = isDark
        ? Colors.green.withOpacity(0.4)
        : Colors.green.shade300;
    final iconColor = isDark ? Colors.green.shade300 : Colors.green.shade700;
    final textColor = isDark ? Colors.green.shade100 : Colors.green.shade900;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: iconColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
