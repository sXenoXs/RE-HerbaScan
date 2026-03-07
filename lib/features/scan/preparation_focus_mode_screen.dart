import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/services/preparation_notification_service.dart';
import 'package:herbascan/core/utils/preparation_step_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _PreparationFocusModeScreenState
    extends State<PreparationFocusModeScreen> {
  late PageController _pageController;
  late List<bool> _stepCompleted;
  int _currentPage = 0;
  int? _activeTimerStepIndex;
  int? _timerRemainingSeconds;
  bool _timerPaused = false;
  Timer? _timer;

  static String _prefsKey(PreparationMethod method) =>
      'prep_state_${method.id}';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _stepCompleted =
        List.filled(widget.preparationMethod.stepInstructions.length, false);
    _loadState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(widget.preparationMethod);
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final completed = map['stepCompleted'] as List<dynamic>?;
      final stepCount = widget.preparationMethod.stepInstructions.length;
      if (completed != null && completed.length == stepCount) {
        setState(() => _stepCompleted = completed.cast<bool>());
      }
      final activeIndex = map['activeTimerStepIndex'] as int?;
      final remaining = map['timerRemainingSeconds'] as int? ?? 0;
      final paused = map['timerPaused'] as bool? ?? false;
      if (activeIndex != null && activeIndex >= 0 && activeIndex < stepCount && remaining > 0) {
        setState(() {
          _activeTimerStepIndex = activeIndex;
          _timerRemainingSeconds = remaining;
          _timerPaused = paused;
          _currentPage = activeIndex;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(activeIndex);
          }
        });
        if (!paused) _startTimer(remaining);
      }
    } catch (_) {}
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(widget.preparationMethod);
    final map = <String, dynamic>{
      'stepCompleted': _stepCompleted,
      'activeTimerStepIndex': _activeTimerStepIndex ?? _currentPage,
      'timerRemainingSeconds': _timerRemainingSeconds ?? 0,
      'timerPaused': _timerPaused,
    };
    await prefs.setString(key, jsonEncode(map));
  }

  String _stepId(int index) =>
      '${widget.preparationMethod.id}_$index';

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
      _activeTimerStepIndex = _currentPage;
      _timerRemainingSeconds = durationSeconds;
      _timerPaused = false;
    });
    PreparationNotificationService().scheduleTimer(_stepId(_currentPage), durationSeconds);
    _saveState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timerRemainingSeconds == null) return;
        _timerRemainingSeconds = _timerRemainingSeconds! - 1;
        if (_timerRemainingSeconds! <= 0) {
          _timer?.cancel();
          _timer = null;
          _timerRemainingSeconds = null;
          _timerPaused = false;
          final s = _activeTimerStepIndex ?? _currentPage;
          PreparationNotificationService().cancelTimer(_stepId(s));
          _activeTimerStepIndex = null;
        }
      });
      _saveState();
      if (_timerRemainingSeconds == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).timerFinished),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    final step = _activeTimerStepIndex ?? _currentPage;
    PreparationNotificationService().cancelTimer(_stepId(step));
    setState(() => _timerPaused = true);
    _saveState();
  }

  void _resumeTimer() {
    if (_timerRemainingSeconds == null || _timerRemainingSeconds! <= 0) return;
    final step = _activeTimerStepIndex ?? _currentPage;
    setState(() => _timerPaused = false);
    PreparationNotificationService().scheduleTimer(_stepId(step), _timerRemainingSeconds!);
    _saveState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timerRemainingSeconds = _timerRemainingSeconds! - 1;
        if (_timerRemainingSeconds! <= 0) {
          _timer?.cancel();
          _timer = null;
          _timerRemainingSeconds = null;
          _timerPaused = false;
          final s = _activeTimerStepIndex ?? _currentPage;
          PreparationNotificationService().cancelTimer(_stepId(s));
          _activeTimerStepIndex = null;
        }
      });
      _saveState();
      if (_timerRemainingSeconds == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).timerFinished),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _resetTimer() {
    final step = _activeTimerStepIndex ?? _currentPage;
    _timer?.cancel();
    _timer = null;
    PreparationNotificationService().cancelTimer(_stepId(step));
    setState(() {
      _timerRemainingSeconds = null;
      _timerPaused = false;
      _activeTimerStepIndex = null;
    });
    _saveState();
  }

  void _goToNextStep() {
    if (_currentPage < widget.preparationMethod.stepInstructions.length - 1) {
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
        title: Text(
            '${widget.plant.commonName} – ${widget.preparationMethod.title}'),
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
                setState(() => _currentPage = index);
                _saveState();
              },
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final instruction = steps[index];
                final timerSeconds = _getTimerSecondsForStep(index);
                final isCompleted = _stepCompleted[index];
                final isCurrentStep = index == _currentPage;
                final isTimerStep = (_activeTimerStepIndex ?? _currentPage) == index;
                final showTimerRunning =
                    isTimerStep && _timerRemainingSeconds != null;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                                  color: theme
                                      .colorScheme.surfaceContainerHighest
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
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
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
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
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
                      if (isCurrentStep &&
                          timerSeconds != null &&
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
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
                                      style:
                                          theme.textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontFeatures: [
                                          const FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    if (_timerPaused)
                                      FilledButton.icon(
                                        onPressed: _resumeTimer,
                                        icon: const Icon(Icons.play_arrow, size: 18),
                                        label: const Text('Resume'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: theme.colorScheme.primary,
                                          foregroundColor: theme.colorScheme.onPrimary,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 10),
                                        ),
                                      )
                                    else
                                      FilledButton.icon(
                                        onPressed: _pauseTimer,
                                        icon: const Icon(Icons.pause, size: 18),
                                        label: const Text('Pause'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: theme.colorScheme.primary,
                                          foregroundColor: theme.colorScheme.onPrimary,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 10),
                                        ),
                                      ),
                                    OutlinedButton.icon(
                                      onPressed: _resetTimer,
                                      icon: const Icon(Icons.refresh, size: 18),
                                      label: const Text('Reset'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                      ),
                                    ),
                                  ],
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
                                _saveState();
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
