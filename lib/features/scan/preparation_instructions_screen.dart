import 'dart:async';
import 'dart:convert';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/services/preparation_notification_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/utils/preparation_step_parser.dart';
import 'package:herbascan/features/scan/preparation_focus_mode_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreparationInstructionsScreen extends StatefulWidget {
  final Plant plant;
  final PreparationMethod preparationMethod;

  const PreparationInstructionsScreen({
    super.key,
    required this.plant,
    required this.preparationMethod,
  });

  @override
  State<PreparationInstructionsScreen> createState() =>
      _PreparationInstructionsScreenState();
}

class _PreparationInstructionsScreenState
    extends State<PreparationInstructionsScreen> {
  late List<bool> _stepCompleted;
  int? _activeTimerStepIndex;
  int _timerRemainingSeconds = 0;
  bool _timerPaused = false;
  Timer? _timer;

  static String _prefsKey(PreparationMethod method) =>
      'prep_state_${method.id}';

  @override
  void initState() {
    super.initState();
    final stepCount = widget.preparationMethod.stepInstructions.length;
    _stepCompleted = List.filled(stepCount, false);
    _loadState();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
        setState(() {
          _stepCompleted = completed.cast<bool>();
        });
      }
      final activeIndex = map['activeTimerStepIndex'] as int?;
      final remaining = map['timerRemainingSeconds'] as int? ?? 0;
      final paused = map['timerPaused'] as bool? ?? false;
      final endEpochMs = map['timerEndEpochMs'] as int?;
      if (activeIndex != null && activeIndex >= 0 && activeIndex < stepCount) {
        int remainingToUse = remaining;
        if (!paused && endEpochMs != null) {
          final end = DateTime.fromMillisecondsSinceEpoch(endEpochMs);
          final now = DateTime.now();
          if (end.isAfter(now)) {
            remainingToUse = end.difference(now).inSeconds;
          } else {
            remainingToUse = 0;
          }
        }
        if (remainingToUse > 0) {
          setState(() {
            _activeTimerStepIndex = activeIndex;
            _timerRemainingSeconds = remainingToUse;
            _timerPaused = paused;
          });
          if (!paused) _startTimer(activeIndex, remainingToUse);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(widget.preparationMethod);
    final map = <String, dynamic>{
      'stepCompleted': _stepCompleted,
      'activeTimerStepIndex': _activeTimerStepIndex,
      'timerRemainingSeconds': _timerRemainingSeconds,
      'timerPaused': _timerPaused,
    };
    if (_activeTimerStepIndex != null && !_timerPaused && _timer != null) {
      map['timerEndEpochMs'] =
          DateTime.now()
              .add(Duration(seconds: _timerRemainingSeconds))
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
      _timerRemainingSeconds = 0;
      _timerPaused = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress reset')),
      );
    }
  }

  String _stepId(int stepIndex) => '${widget.preparationMethod.id}_$stepIndex';

  int? _getTimerSecondsForStep(int index) {
    final stepDetails = widget.preparationMethod.stepDetails;
    if (stepDetails == null ||
        index >= stepDetails.length ||
        !stepDetails[index].hasTimer) {
      return null;
    }
    final sec = stepDetails[index].timerDurationSeconds;
    return (sec != null && sec > 0) ? sec : null;
  }

  int? _getEffectiveTimerSeconds(int index) {
    final fromDetails = _getTimerSecondsForStep(index);
    if (fromDetails != null) return fromDetails;
    final instruction = widget.preparationMethod.stepInstructions[index];
    return PreparationStepParser.parseTimerSecondsFromInstruction(instruction);
  }

  Future<void> _addScheduleToCalendar(BuildContext context) async {
    final plant = widget.plant;
    final method = widget.preparationMethod;
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day, 8, 0);
    final endDate = startDate.add(const Duration(hours: 1));

    int durationDays = 7;
    int frequencyHours = 24;
    if (method.schedule != null) {
      durationDays = method.schedule!.durationDays;
      frequencyHours = method.schedule!.frequencyHours;
    }

    final title = '${plant.commonName}: ${method.title}';

    final description = StringBuffer();
    description.writeln('DOSAGE: ${method.dosage}');
    description.writeln('');
    description.writeln('FREQUENCY: ${method.frequency}');
    description.writeln('');
    description.writeln('DURATION: ${method.duration}');
    if (method.warnings.isNotEmpty) {
      description.writeln('');
      description.writeln('Note: ${method.warnings.first}');
    }

    int interval = 1;
    if (frequencyHours >= 24) {
      interval = frequencyHours ~/ 24;
      if (interval < 1) interval = 1;
    }

    final recurrence = Recurrence(
      frequency: Frequency.daily,
      interval: interval,
      endDate: startDate.add(Duration(days: durationDays)),
    );

    final event = Event(
      title: title,
      description: description.toString(),
      startDate: startDate,
      endDate: endDate,
      recurrence: recurrence,
    );

    try {
      final added = await Add2Calendar.addEvent2Cal(event);
      if (!context.mounted) return;
      if (added) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).openingCalendar),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Calendar could not be opened. Check that a calendar app is installed and try again.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open calendar: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _startTimer(int stepIndex, int durationSeconds) {
    _timer?.cancel();
    setState(() {
      _activeTimerStepIndex = stepIndex;
      _timerRemainingSeconds = durationSeconds;
      _timerPaused = false;
    });
    PreparationNotificationService().scheduleTimer(
      _stepId(stepIndex),
      durationSeconds,
    );
    _saveState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timerRemainingSeconds--;
        if (_timerRemainingSeconds <= 0) {
          _timer?.cancel();
          _timer = null;
          _activeTimerStepIndex = null;
          _timerPaused = false;
        }
      });
      _saveState();
      if (_timerRemainingSeconds == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).timerFinished),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _pauseTimer() {
    if (_activeTimerStepIndex == null) return;
    _timer?.cancel();
    _timer = null;
    PreparationNotificationService().cancelTimer(
      _stepId(_activeTimerStepIndex!),
    );
    setState(() => _timerPaused = true);
    _saveState();
  }

  void _resumeTimer() {
    if (_activeTimerStepIndex == null || _timerRemainingSeconds <= 0) return;
    setState(() => _timerPaused = false);
    PreparationNotificationService().scheduleTimer(
      _stepId(_activeTimerStepIndex!),
      _timerRemainingSeconds,
    );
    _saveState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timerRemainingSeconds--;
        if (_timerRemainingSeconds <= 0) {
          _timer?.cancel();
          _timer = null;
          _activeTimerStepIndex = null;
          _timerPaused = false;
        }
      });
      _saveState();
      if (_timerRemainingSeconds == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).timerFinished),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = null;
    if (_activeTimerStepIndex != null) {
      PreparationNotificationService().cancelTimer(
        _stepId(_activeTimerStepIndex!),
      );
    }
    setState(() {
      _activeTimerStepIndex = null;
      _timerRemainingSeconds = 0;
      _timerPaused = false;
    });
    _saveState();
  }

  void _toggleTimer(int stepIndex, int timerSec) {
    if (_activeTimerStepIndex == stepIndex) {
      if (_timerPaused) {
        _resumeTimer();
      } else {
        _pauseTimer();
      }
    } else {
      _startTimer(stepIndex, timerSec);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preparationMethod = widget.preparationMethod;
    final hasWarnings = preparationMethod.warnings.isNotEmpty;
    final hasPlantWarnings = widget.plant.safetyWarnings.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).preparationGuide),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Progress',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('Reset Progress?'),
                      content: const Text(
                        'This will clear all completed steps and stop any running timer.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
              );
              if (confirm == true) await _resetProgress();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder:
                  (context) => PreparationFocusModeScreen(
                    plant: widget.plant,
                    preparationMethod: widget.preparationMethod,
                  ),
            ),
          );
        },
        backgroundColor: AppTheme.botanicalPrimary,
        foregroundColor: Colors.white,
        tooltip: 'Focus Mode',
        child: const Icon(Icons.fullscreen, size: 28),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ROADMAP B 4.1: Medical disclaimer at top (theme-aware for dark mode readability)
            Builder(
              builder: (context) {
                final isDark = theme.brightness == Brightness.dark;
                final disclaimerBg = isDark
                    ? AppTheme.warningAmber.withValues(alpha: 0.2)
                    : AppTheme.warningBgLight;
                final disclaimerTextColor = isDark
                    ? theme.colorScheme.onSurface
                    : AppTheme.textPrimary;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: disclaimerBg,
                    border: Border(
                      left: BorderSide(
                        color: AppTheme.warningAmber.withValues(alpha: 0.8),
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.medical_services_rounded,
                        color: AppTheme.warningAmber,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'HerbaScan is an educational tool. Always consult a licensed physician before using any herbal remedy.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: disclaimerTextColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // ── Important Warnings (moved to top) ──────────────────────────
            if (hasWarnings)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: const BoxDecoration(
                  color: AppTheme.errorBgLight,
                  border: Border(
                    left: BorderSide(color: AppTheme.errorDeep, width: 4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: AppTheme.errorDeep,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Important Warnings',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppTheme.errorDeep,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...preparationMethod.warnings.map(
                      (warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          warning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.errorDark,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── General Safety Warnings ────────────────────────────────────
            if (hasPlantWarnings)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: const BoxDecoration(
                  color: AppTheme.warningBgLight,
                  border: Border(
                    left: BorderSide(color: AppTheme.warningAmber, width: 4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppTheme.warningDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'General Safety Information',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppTheme.warningDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...widget.plant.safetyWarnings.map(
                      (warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          warning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.warningDark,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title + Preparation Type Badge ─────────────────────────
                  Text(
                    preparationMethod.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.botanicalPrimary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      preparationMethod.preparationType.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.botanicalPrimaryD,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Preparation Steps ──────────────────────────────────────
                  Text(
                    'Steps',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...List.generate(
                    preparationMethod.stepInstructions.length,
                    (index) {
                      final timerSec = _getEffectiveTimerSeconds(index);
                      return _buildStepItem(
                        context,
                        index + 1,
                        preparationMethod.stepInstructions[index],
                        theme,
                        isCompleted: _stepCompleted[index],
                        onTap: () {
                          setState(() {
                            _stepCompleted[index] = !_stepCompleted[index];
                          });
                          _saveState();
                        },
                        stepIndex: index,
                        timerSeconds: timerSec,
                        isTimerActive: _activeTimerStepIndex == index,
                        timerRemainingSeconds:
                            _activeTimerStepIndex == index
                                ? _timerRemainingSeconds
                                : 0,
                        isTimerPaused:
                            _activeTimerStepIndex == index && _timerPaused,
                        onToggleTimer:
                            timerSec != null
                                ? () => _toggleTimer(index, timerSec)
                                : null,
                        onLongPressTimer:
                            _activeTimerStepIndex == index
                                ? _resetTimer
                                : null,
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Regimen Card ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.botanicalPrimary.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Regimen',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.botanicalPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(
                            Icons.medication_outlined,
                            color: AppTheme.botanicalPrimary,
                          ),
                          title: const Text('Dosage'),
                          subtitle: Text(preparationMethod.dosage),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(
                            Icons.schedule_outlined,
                            color: AppTheme.botanicalPrimary,
                          ),
                          title: const Text('Frequency'),
                          subtitle: Text(preparationMethod.frequency),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(
                            Icons.calendar_today_outlined,
                            color: AppTheme.botanicalPrimary,
                          ),
                          title: const Text('Duration'),
                          subtitle: Text(preparationMethod.duration),
                        ),
                        const Divider(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _addScheduleToCalendar(context),
                            icon: const Icon(Icons.calendar_today, size: 20),
                            label: Text(
                              AppLocalizations.of(context).addScheduleToCalendar,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.botanicalPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom padding so FAB doesn't overlap last content
                  const SizedBox(height: 88),
                ],
              ),
            ),
          ],
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

  Widget _buildStepItem(
    BuildContext context,
    int stepNumber,
    String step,
    ThemeData theme, {
    required bool isCompleted,
    VoidCallback? onTap,
    int? stepIndex,
    int? timerSeconds,
    bool isTimerActive = false,
    int timerRemainingSeconds = 0,
    bool isTimerPaused = false,
    VoidCallback? onToggleTimer,
    VoidCallback? onLongPressTimer,
  }) {
    final (stepIcon, stepColor) = _getStepVisual(step);
    final timerColor =
        isTimerActive
            ? (isTimerPaused ? AppTheme.warningAmber : AppTheme.botanicalPrimary)
            : AppTheme.botanicalPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color:
              isCompleted
                  ? stepColor.withValues(alpha: 0.06)
                  : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: isCompleted ? stepColor.withValues(alpha: 0.4) : stepColor,
              width: 4,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: stepColor.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row: icon + "Step N" label + timer ─────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Step type icon circle
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Container(
                          key: ValueKey(isCompleted ? 'done_$stepNumber' : 'todo_$stepNumber'),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                isCompleted
                                    ? AppTheme.botanicalPrimary.withValues(alpha: 0.12)
                                    : stepColor.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCompleted
                                ? Icons.check_circle_rounded
                                : stepIcon,
                            color:
                                isCompleted
                                    ? AppTheme.botanicalPrimary
                                    : stepColor,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Step label
                      Expanded(
                        child: Text(
                          'Step $stepNumber',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color:
                                isCompleted
                                    ? theme.colorScheme.onSurfaceVariant
                                    : stepColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      // Timer pill
                      if (timerSeconds != null && timerSeconds > 0) ...[
                        GestureDetector(
                          onTap: onToggleTimer,
                          onLongPress: onLongPressTimer,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: timerColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: timerColor.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isTimerActive
                                      ? (isTimerPaused
                                          ? Icons.play_arrow_rounded
                                          : Icons.pause_rounded)
                                      : Icons.timer_outlined,
                                  size: 14,
                                  color: timerColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isTimerActive
                                      ? _formatDuration(timerRemainingSeconds)
                                      : _formatDuration(timerSeconds),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: timerColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  // ── Instruction text (indented to align under label) ────────
                  Padding(
                    padding: const EdgeInsets.only(left: 54),
                    child: Text(
                      step,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            isCompleted
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurface,
                        height: 1.55,
                        decoration:
                            isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                        decorationColor:
                            isCompleted
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
