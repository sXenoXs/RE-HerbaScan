import 'dart:async';
import 'package:flutter/material.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/utils/preparation_step_parser.dart';

/// Full-screen, one-step-per-page wizard with timer and mark-done.
class PreparationFocusModeScreen extends StatefulWidget {
  final Plant plant;
  final PreparationMethod preparationMethod;

  const PreparationFocusModeScreen({
    super.key,
    required this.plant,
    required this.preparationMethod,
  });

  @override
  State<PreparationFocusModeScreen> createState() =>
      _PreparationFocusModeScreenState();
}

class _PreparationFocusModeScreenState extends State<PreparationFocusModeScreen> {
  late PageController _pageController;
  late List<bool> _stepCompleted;
  int _currentPage = 0;
  int? _timerRemainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _stepCompleted =
        List.filled(widget.preparationMethod.stepInstructions.length, false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  int? _getTimerSecondsForStep(int index) {
    final method = widget.preparationMethod;
    final stepDetails = method.stepDetails;
    if (stepDetails != null &&
        index < stepDetails.length &&
        stepDetails[index].hasTimer) {
      final sec = stepDetails[index].timerDurationSeconds;
      if (sec != null && sec > 0) return sec;
    }
    final instruction = method.stepInstructions[index];
    return PreparationStepParser.parseTimerSecondsFromInstruction(instruction);
  }

  void _startTimer(int durationSeconds) {
    _timer?.cancel();
    setState(() {
      _timerRemainingSeconds = durationSeconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timerRemainingSeconds == null) return;
        _timerRemainingSeconds = _timerRemainingSeconds! - 1;
        if (_timerRemainingSeconds! <= 0) {
          _timer?.cancel();
          _timer = null;
          _timerRemainingSeconds = null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).timerFinished),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    });
  }

  void _goToNextStep() {
    if (_currentPage <
        widget.preparationMethod.stepInstructions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = widget.preparationMethod.stepInstructions;
    if (steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Focus Mode')),
        body: const Center(child: Text('No steps available')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.plant.commonName} – ${widget.preparationMethod.title}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                  _timer?.cancel();
                  _timerRemainingSeconds = null;
                });
              },
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final instruction = steps[index];
                final timerSeconds = _getTimerSecondsForStep(index);
                final isCompleted = _stepCompleted[index];
                final isCurrentStep = index == _currentPage;
                final showTimerRunning =
                    isCurrentStep && _timerRemainingSeconds != null;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Step ${index + 1} of ${steps.length}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 28,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest
                                      .withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    if (isCompleted)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green.shade700,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Step done',
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    color: Colors.green.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Text(
                                      instruction,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            height: 1.6,
                                            fontSize: 22,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isCurrentStep && timerSeconds != null &&
                          timerSeconds > 0) ...[
                        const SizedBox(height: 16),
                        if (showTimerRunning)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: 32,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  PreparationStepParser.formatMinutesSeconds(
                                      _timerRemainingSeconds!),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontFeatures: [
                                          const FontFeature.tabularFigures()
                                        ],
                                      ),
                                ),
                              ],
                            ),
                          )
                        else
                          FilledButton.icon(
                            onPressed: () => _startTimer(timerSeconds),
                            icon: const Icon(Icons.timer_outlined, size: 20),
                            label: Text(
                              'Start ${_formatDuration(timerSeconds)} timer',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      if (isCurrentStep) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: () {
                                setState(() {
                                  _stepCompleted[index] =
                                      !_stepCompleted[index];
                                });
                              },
                              icon: Icon(
                                isCompleted
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                                size: 20,
                              ),
                              label: Text(
                                  isCompleted ? 'Mark undone' : 'Mark done'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (index < steps.length - 1)
                              FilledButton.icon(
                                onPressed: _goToNextStep,
                                icon: const Icon(Icons.arrow_forward, size: 20),
                                label: const Text('Next step'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (!isCurrentStep && index < steps.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.swipe_right_alt,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Swipe for next step',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (index == steps.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'You’re done. Close to return.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final min = m % 60;
      return '${h}h ${min}m';
    }
    if (m > 0) return '${m}m';
    return '${s}s';
  }
}
