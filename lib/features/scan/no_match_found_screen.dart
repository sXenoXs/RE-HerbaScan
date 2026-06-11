import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/features/browse/browse_screen.dart';

class NoMatchFoundScreen extends StatelessWidget {
  final String imagePath;
  final bool isToxicPlant;
  final String? detectedToxicPlantName;
  /// Low-confidence predictions to show in the "Look-alike Plants" sheet.
  final List<Map<String, dynamic>> lookalikePredictions;
  /// True when we landed here because the top prediction was a real plant
  /// below the confidence threshold (show "Low Confidence Match" + best guess).
  /// False when the model actually returned UnknownPlant/Not_Plant/empty
  /// (show "No Plant Match Found" with no best guess).
  final bool isLowConfidence;

  const NoMatchFoundScreen({
    super.key,
    required this.imagePath,
    this.isToxicPlant = false,
    this.detectedToxicPlantName,
    this.lookalikePredictions = const [],
    this.isLowConfidence = false,
  });

  void _showLookalikeSheet(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LookalikeSheet(
        predictions: lookalikePredictions,
        theme: theme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isToxic = isToxicPlant;
    final toxicName = detectedToxicPlantName ?? 'Toxic plant';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Blurred background image
          if (imagePath.isNotEmpty)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: AppTheme.darkScaffold),
              ),
            )
          else
            Container(color: AppTheme.darkScaffold),

          // 2. Dark scrim
          Container(color: Colors.black.withOpacity(0.45)),

          // 3. Glassmorphic center card
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon with warning badge (error tint for toxic)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: (isToxic
                                    ? AppTheme.errorDeep
                                    : AppTheme.warningAmber)
                                .withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isToxic
                                ? Icons.warning_amber_rounded
                                : Icons.eco_rounded,
                            size: 40,
                            color: isToxic
                                ? AppTheme.errorDeep
                                : AppTheme.warningAmber,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Title
                        Text(
                          isToxic
                              ? l10n.toxicPlantDetected
                              : isLowConfidence
                                  ? 'Low Confidence Match'
                                  : 'No Plant Match Found',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 10),

                        // Description
                        Text(
                          isToxic
                              ? l10n.toxicPlantBody.replaceFirst('%s', toxicName)
                              : isLowConfidence
                                  ? "We're not confident enough to confirm this as a match. Please retake a clearer photo or browse the catalog manually."
                                  : "We don't recognize this plant. Ensure it's a clear single leaf.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.80),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Best-guess tile: show what the model thought it was
                        // and the confidence %, so the user understands *why*
                        // it was rejected (e.g. "Gumamela @ 73% — below 90%").
                        // Only shown for low-confidence matches, not for true
                        // unknowns (UnknownPlant/Not_Plant) where the guess is
                        // not meaningful.
                        if (!isToxic &&
                            isLowConfidence &&
                            lookalikePredictions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                              ),
                            ),
                            child: Builder(
                              builder: (_) {
                                final top = lookalikePredictions.first;
                                final name = (top['plantName'] as String?) ??
                                    (top['label'] as String?) ??
                                    'Unknown';
                                final conf =
                                    (top['confidence'] as num?)?.toDouble() ??
                                        0.0;
                                final pct = (conf * 100).toStringAsFixed(1);
                                return Text(
                                  'Best guess: $name  ·  $pct%',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.92),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // Retake button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: Text(l10n.retake),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.botanicalPrimary,
                            ),
                          ),
                        ),

                        if (isLowConfidence &&
                            lookalikePredictions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showLookalikeSheet(context, theme),
                              icon: const Icon(Icons.search_rounded, size: 18),
                              label: const Text('Look-alike Plants'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                    color: Colors.white.withOpacity(0.5)),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Browse catalog button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const BrowseScreen(),
                                ),
                                (route) => route.isFirst,
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: Text(l10n.browseCatalog),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LookalikeSheet extends StatelessWidget {
  final List<Map<String, dynamic>> predictions;
  final ThemeData theme;

  const _LookalikeSheet({required this.predictions, required this.theme});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        color: theme.colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.botanicalPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: AppTheme.botanicalPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Look-alike Plants',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'These are possible but uncertain matches',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              ...predictions.take(3).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                final name = p['plantName'] as String? ??
                    p['label'] as String? ??
                    'Unknown';
                return Column(
                  children: [
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: theme.colorScheme.onSurface.withOpacity(0.08),
                      ),
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.botanicalPrimary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppTheme.botanicalPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        () {
                          final conf =
                              (p['confidence'] as num?)?.toDouble() ?? 0.0;
                          return '${(conf * 100).toStringAsFixed(1)}% confidence';
                        }(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.botanicalPrimary,
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
