import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/services/preparation_notification_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/utils/preparation_step_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Full-screen, one-step-per-page wizard with timer, mark-done, and
/// a completion overlay animation.
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
    extends State<PreparationFocusModeScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late List<bool> _stepCompleted;
  int _currentPage = 0;
  int? _activeTimerStepIndex;
  int? _timerRemainingSeconds;
  bool _timerPaused = false;
  Timer? _timer;

  // Completion overlay state
  bool _showCompletion = false;
  late AnimationController _completionAnimController;
  late Animation<double> _completionScaleAnim;

  static String _prefsKey(PreparationMethod method) =>
      'prep_state_${method.id}';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _stepCompleted = List.filled(
      widget.preparationMethod.stepInstructions.length,
      false,
    );
    _completionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _completionScaleAnim = CurvedAnimation(
      parent: _completionAnimController,
      curve: Curves.elasticOut,
    );
    _loadState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _completionAnimController.dispose();
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
      if (activeIndex != null &&
          activeIndex >= 0 &&
          activeIndex < stepCount &&
          remaining > 0) {
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
    if (_activeTimerStepIndex != null && !_timerPaused && _timer != null && _timerRemainingSeconds != null) {
      map['timerEndEpochMs'] =
          DateTime.now()
              .add(Duration(seconds: _timerRemainingSeconds!))
              .millisecondsSinceEpoch;
    }
    await prefs.setString(key, jsonEncode(map));
  }

  Future<void> _resetProgress() async {
    _timer?.cancel();
    _timer = null;
    final stepCount = widget.preparationMethod.stepInstructions.length;
    for (int i = 0; i < stepCount; i++) {
      await PreparationNotificationService().cancelTimer(_stepId(i));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(widget.preparationMethod));
    setState(() {
      _stepCompleted = List.filled(stepCount, false);
      _activeTimerStepIndex = null;
      _timerRemainingSeconds = null;
      _timerPaused = false;
      _currentPage = 0;
      _showCompletion = false;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).progressReset)),
      );
    }
  }

  String _stepId(int index) => '${widget.preparationMethod.id}_$index';

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
    PreparationNotificationService().scheduleTimer(
      _stepId(_currentPage),
      durationSeconds,
    );
    _saveState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timerRemainingSeconds == null) return;
        _timerRemainingSeconds = _timerRemainingSeconds! - 1;
        if (_timerRemainingSeconds! <= 0) {
          _timer?.cancel();
          _timer = null;
          final s = _activeTimerStepIndex ?? _currentPage;
          PreparationNotificationService().cancelTimer(_stepId(s));
          _timerRemainingSeconds = null;
          _timerPaused = false;
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

  void _toggleTimer(int timerSeconds) {
    if (_activeTimerStepIndex == _currentPage &&
        _timerRemainingSeconds != null) {
      if (_timerPaused) {
        _resumeTimer();
      } else {
        _pauseTimer();
      }
    } else {
      _startTimer(timerSeconds);
    }
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
    PreparationNotificationService().scheduleTimer(
      _stepId(step),
      _timerRemainingSeconds!,
    );
    _saveState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timerRemainingSeconds = _timerRemainingSeconds! - 1;
        if (_timerRemainingSeconds! <= 0) {
          _timer?.cancel();
          _timer = null;
          final s = _activeTimerStepIndex ?? _currentPage;
          PreparationNotificationService().cancelTimer(_stepId(s));
          _timerRemainingSeconds = null;
          _timerPaused = false;
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

  void _completeAndContinue(int index, int totalSteps) {
    HapticFeedback.mediumImpact();
    setState(() => _stepCompleted[index] = true);
    _saveState();

    if (index < totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      // Last step — show completion overlay
      setState(() => _showCompletion = true);
      _completionAnimController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = widget.preparationMethod.stepInstructions;

    if (steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(child: Text(AppLocalizations.of(context).noStepsAvailable)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Progress',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(AppLocalizations.of(context).resetProgressTitle),
                  content: Text(AppLocalizations.of(context).resetProgressBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(AppLocalizations.of(context).cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(AppLocalizations.of(context).reset),
                    ),
                  ],
                ),
              );
              if (confirm == true) await _resetProgress();
            },
          ),
        ],
        // Segmented progress bar replaces "Step X of Y" chip
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _buildProgressBar(steps.length, theme),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              _saveState();
            },
            itemCount: steps.length,
            itemBuilder: (context, index) {
              return _buildStepPage(context, index, steps, theme);
            },
          ),
          // Completion overlay
          if (_showCompletion) _buildCompletionOverlay(theme),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int totalSteps, ThemeData theme) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final isCompleted = _stepCompleted[i];
        final isCurrent = i == _currentPage;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < totalSteps - 1 ? 2 : 0),
            decoration: BoxDecoration(
              color:
                  isCompleted
                      ? AppTheme.botanicalPrimary
                      : isCurrent
                      ? AppTheme.botanicalPrimaryL
                      : theme.colorScheme.outlineVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  /// Maps step instruction keywords to a (icon, color) pair for visual context.
  static (IconData, Color) _getStepVisual(String instruction) {
    final lower = instruction.toLowerCase();
    if (lower.contains('strain') ||
        lower.contains('filter') ||
        lower.contains('sieve') ||
        lower.contains('cheesecloth')) {
      return (Icons.filter_alt_rounded, const Color(0xFF0D9488));
    }
    if (lower.contains('boil') ||
        lower.contains('simmer') ||
        lower.contains('heat')) {
      return (Icons.local_fire_department_rounded, const Color(0xFFEA580C));
    }
    if (lower.contains('leaf') ||
        lower.contains('leaves') ||
        lower.contains('herb') ||
        lower.contains('bark') ||
        lower.contains('root')) {
      return (Icons.eco_rounded, const Color(0xFF16A34A));
    }
    if (lower.contains('wash') ||
        lower.contains('rinse') ||
        lower.contains('clean')) {
      return (Icons.water_drop_rounded, const Color(0xFF2563EB));
    }
    if (lower.contains('chop') ||
        lower.contains('cut') ||
        lower.contains('slice') ||
        lower.contains('pound') ||
        lower.contains('crush')) {
      return (Icons.content_cut_rounded, const Color(0xFFD97706));
    }
    if (lower.contains('cool') ||
        lower.contains('chill') ||
        lower.contains('temperature')) {
      return (Icons.ac_unit_rounded, const Color(0xFF0284C7));
    }
    if (lower.contains('drink') ||
        lower.contains('consume') ||
        lower.contains('serve') ||
        lower.contains('take')) {
      return (Icons.local_cafe_rounded, const Color(0xFFB45309));
    }
    if (lower.contains('mix') ||
        lower.contains('stir') ||
        lower.contains('blend') ||
        lower.contains('combine')) {
      return (Icons.loop_rounded, const Color(0xFF7C3AED));
    }
    if (lower.contains('grind') ||
        lower.contains('powder') ||
        lower.contains('mash')) {
      return (Icons.grain_rounded, const Color(0xFF92400E));
    }
    if (lower.contains('add') ||
        lower.contains('measure') ||
        lower.contains('cup') ||
        lower.contains('tablespoon') ||
        lower.contains('teaspoon')) {
      return (Icons.science_rounded, const Color(0xFF059669));
    }
    if (lower.contains('water') || lower.contains('pour')) {
      return (Icons.water_drop_rounded, const Color(0xFF0369A1));
    }
    if (lower.contains('dry') || lower.contains('sun')) {
      return (Icons.wb_sunny_rounded, const Color(0xFFCA8A04));
    }
    return (Icons.spa_rounded, const Color(0xFF16A34A));
  }

  Widget _buildStepPage(
    BuildContext context,
    int index,
    List<String> steps,
    ThemeData theme,
  ) {
    final instruction = steps[index];
    final timerSeconds = _getTimerSecondsForStep(index);
    final isCompleted = _stepCompleted[index];
    final isCurrentStep = index == _currentPage;
    final isTimerStep = (_activeTimerStepIndex ?? _currentPage) == index;
    final timerRemaining =
        isTimerStep && _timerRemainingSeconds != null
            ? _timerRemainingSeconds!
            : 0;
    final showTimerRunning =
        isTimerStep &&
        _timerRemainingSeconds != null &&
        _timerRemainingSeconds! > 0;

    final (stepIcon, stepColor) = _getStepVisual(instruction);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Giant muted step number ────────────────────────────────────
            Text(
              (index + 1).toString().padLeft(2, '0'),
              style: theme.textTheme.displayLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.10),
                fontWeight: FontWeight.w900,
                height: 1,
              ),
              textAlign: TextAlign.left,
            ),

            // ── Step instruction ───────────────────────────────────────────
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Large animated step icon
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: CurvedAnimation(
                            parent: anim,
                            curve: Curves.elasticOut,
                          ),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Container(
                          key: ValueKey('step_icon_${index}_$isCompleted'),
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color:
                                isCompleted
                                    ? AppTheme.botanicalPrimary.withOpacity(0.12)
                                    : stepColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isCompleted
                                      ? AppTheme.botanicalPrimary.withOpacity(0.30)
                                      : stepColor.withOpacity(0.30),
                              width: 2.5,
                            ),
                          ),
                          child: Icon(
                            isCompleted
                                ? Icons.check_circle_rounded
                                : stepIcon,
                            size: 46,
                            color:
                                isCompleted
                                    ? AppTheme.botanicalPrimary
                                    : stepColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        instruction,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                          color:
                              isCompleted
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Timer (circular progress + tap to toggle) ──────────────────
            if (isCurrentStep && timerSeconds != null && timerSeconds > 0) ...[
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => _toggleTimer(timerSeconds),
                  onLongPress: showTimerRunning ? _resetTimer : null,
                  child: _buildCircularTimer(
                    context,
                    timerSeconds,
                    timerRemaining,
                    showTimerRunning,
                    theme,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  showTimerRunning
                      ? (_timerPaused
                          ? AppLocalizations.of(context).tapToResume
                          : AppLocalizations.of(context).tapToPause)
                      : AppLocalizations.of(context).tapToStartTimer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Complete & Continue button ──────────────────────────────────
            if (isCurrentStep)
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed:
                      isCompleted
                          ? null
                          : () =>
                              _completeAndContinue(index, steps.length),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.botanicalPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.botanicalPrimary
                        .withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isCompleted
                        ? (index < steps.length - 1
                            ? AppLocalizations.of(context).stepDone
                            : AppLocalizations.of(context).allDone)
                        : (index < steps.length - 1
                            ? AppLocalizations.of(context).completeAndContinue
                            : AppLocalizations.of(context).completePreparation),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularTimer(
    BuildContext context,
    int totalSeconds,
    int remainingSeconds,
    bool isRunning,
    ThemeData theme,
  ) {
    final progress =
        totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;
    final isTimerPausedForCurrentStep =
        _activeTimerStepIndex == _currentPage && _timerPaused;

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: isRunning ? progress : 0,
              strokeWidth: 6,
              backgroundColor: AppTheme.botanicalPrimary.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                isTimerPausedForCurrentStep
                    ? AppTheme.warningAmber
                    : AppTheme.botanicalPrimary,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRunning) ...[
                Text(
                  PreparationStepParser.formatMinutesSeconds(remainingSeconds),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFeatures: [const FontFeature.tabularFigures()],
                    color:
                        isTimerPausedForCurrentStep
                            ? AppTheme.warningAmber
                            : AppTheme.botanicalPrimary,
                  ),
                ),
                Icon(
                  isTimerPausedForCurrentStep
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  size: 20,
                  color:
                      isTimerPausedForCurrentStep
                          ? AppTheme.warningAmber
                          : AppTheme.botanicalPrimary,
                ),
              ] else ...[
                Icon(
                  Icons.timer_outlined,
                  size: 28,
                  color: AppTheme.botanicalPrimary,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(totalSeconds),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.botanicalPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionOverlay(ThemeData theme) {
    return GestureDetector(
      onTap: () {}, // absorb taps
      child: Container(
        color: theme.scaffoldBackgroundColor.withOpacity(0.97),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _completionScaleAnim,
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.botanicalPrimary,
                  size: 80,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context).preparationComplete,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.botanicalPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).completedAllSteps,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.botanicalPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context).returnToGuide,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
