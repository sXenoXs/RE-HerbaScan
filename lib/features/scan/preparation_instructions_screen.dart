import 'dart:async';
import 'dart:convert';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/services/preparation_notification_service.dart';
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
          DateTime.now().add(Duration(seconds: _timerRemainingSeconds))
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

  String _stepId(int stepIndex) =>
      '${widget.preparationMethod.id}_$stepIndex';

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

  /// Timer duration for this step: from stepDetails first, else parsed from instruction text.
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
    final startDate =
        DateTime(now.year, now.month, now.day, 8, 0); // 8 AM today
    final endDate = startDate.add(const Duration(hours: 1));

    int durationDays = 7;
    int frequencyHours = 24;
    if (method.schedule != null) {
      durationDays = method.schedule!.durationDays;
      frequencyHours = method.schedule!.frequencyHours;
    }

    // Title: include plant and preparation so calendar event is identifiable
    final title = '${plant.commonName}: ${method.title}';

    // Description: full dosage, frequency, duration so user doesn't need to switch back to the app
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

    Frequency frequency = Frequency.daily;
    int interval = 1;
    if (frequencyHours >= 24) {
      interval = frequencyHours ~/ 24;
      if (interval < 1) interval = 1;
    }

    final recurrence = Recurrence(
      frequency: frequency,
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
    PreparationNotificationService().scheduleTimer(_stepId(stepIndex), durationSeconds);
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
    PreparationNotificationService().cancelTimer(_stepId(_activeTimerStepIndex!));
    setState(() => _timerPaused = true);
    _saveState();
  }

  void _resumeTimer() {
    if (_activeTimerStepIndex == null || _timerRemainingSeconds <= 0) return;
    setState(() => _timerPaused = false);
    PreparationNotificationService().scheduleTimer(_stepId(_activeTimerStepIndex!), _timerRemainingSeconds);
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
      PreparationNotificationService().cancelTimer(_stepId(_activeTimerStepIndex!));
    }
    setState(() {
      _activeTimerStepIndex = null;
      _timerRemainingSeconds = 0;
      _timerPaused = false;
    });
    _saveState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plant = widget.plant;
    final preparationMethod = widget.preparationMethod;

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
                builder: (ctx) => AlertDialog(
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title (H1) – confirms user opened the right recipe
                  Text(
                    preparationMethod.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Preparation Type Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38A169)
                          .withOpacity(0.15), // Light green background
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF38A169).withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      preparationMethod.preparationType.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF38A169), // Dark green text
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Steps Section (interactive checklist)
                  _buildSectionHeader(
                    context,
                    'Preparation Steps',
                    theme,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap each step to mark it done.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => PreparationFocusModeScreen(
                            plant: widget.plant,
                            preparationMethod: widget.preparationMethod,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.fullscreen),
                    label: Text(
                        AppLocalizations.of(context).startPreparationFocusMode),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

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
                        timerRemainingSeconds: _activeTimerStepIndex == index
                            ? _timerRemainingSeconds
                            : 0,
                        isTimerPaused: _activeTimerStepIndex == index && _timerPaused,
                        onStartTimer: timerSec != null
                            ? () => _startTimer(index, timerSec)
                            : null,
                        onPauseTimer: _activeTimerStepIndex == index ? _pauseTimer : null,
                        onResumeTimer: _activeTimerStepIndex == index ? _resumeTimer : null,
                        onResetTimer: _activeTimerStepIndex == index ? _resetTimer : null,
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Unified Regimen card (Dosage, Frequency, Duration + Calendar button)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.medication_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text('Dosage'),
                          subtitle: Text(preparationMethod.dosage),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.schedule_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text('Frequency'),
                          subtitle: Text(preparationMethod.frequency),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.calendar_today_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text('Duration'),
                          subtitle: Text(preparationMethod.duration),
                        ),
                        const Divider(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _addScheduleToCalendar(context),
                            icon: const Icon(Icons.calendar_today, size: 20),
                            label: Text(AppLocalizations.of(context)
                                .addScheduleToCalendar),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Warnings Section
                  if (preparationMethod.warnings.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      '⚠️ Important Warnings',
                      theme,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B2D2D),
                        border: Border.all(
                          color: theme.colorScheme.error.withOpacity(0.6),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: preparationMethod.warnings.map((warning) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    warning,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // General Safety Warnings
                  if (plant.safetyWarnings.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      '🛡️ General Safety Information',
                      theme,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: plant.safetyWarnings.map((warning) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    warning,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    ThemeData theme,
  ) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
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
    VoidCallback? onStartTimer,
    VoidCallback? onPauseTimer,
    VoidCallback? onResumeTimer,
    VoidCallback? onResetTimer,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: isCompleted
                ? theme.colorScheme.surfaceContainerLow.withOpacity(0.5)
                : theme.colorScheme.surfaceContainerLow.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF48BB78)
                            : theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : Text(
                                stepNumber.toString(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          step,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isCompleted
                                ? theme.colorScheme.onSurface.withOpacity(0.5)
                                : theme.colorScheme.onSurface,
                            height: 1.5,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (timerSeconds != null && timerSeconds > 0) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: isTimerActive
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_formatDuration(timerRemainingSeconds)} remaining',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        if (isTimerPaused)
                          TextButton.icon(
                            onPressed: onResumeTimer,
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Resume'),
                          )
                        else
                          TextButton.icon(
                            onPressed: onPauseTimer,
                            icon: const Icon(Icons.pause, size: 18),
                            label: const Text('Pause'),
                          ),
                        if (onResetTimer != null)
                          TextButton.icon(
                            onPressed: onResetTimer,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Reset'),
                          ),
                      ],
                    )
                  : ElevatedButton.icon(
                      onPressed: onStartTimer,
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label:
                          Text('Start ${_formatDuration(timerSeconds)} timer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
