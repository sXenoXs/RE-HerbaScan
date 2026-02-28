import 'dart:async';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/utils/preparation_step_parser.dart';
import 'package:herbascan/features/scan/preparation_focus_mode_screen.dart';

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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final stepCount = widget.preparationMethod.stepInstructions.length;
    _stepCompleted = List.filled(stepCount, false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timerRemainingSeconds--;
        if (_timerRemainingSeconds <= 0) {
          _timer?.cancel();
          _timer = null;
          _activeTimerStepIndex = null;
        }
      });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plant = widget.plant;
    final preparationMethod = widget.preparationMethod;

    return Scaffold(
      appBar: AppBar(
        title: Text('Preparation Instructions'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.commonName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plant.scientificName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontStyle: FontStyle.italic,
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
                  // Condition Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF48BB78), // Vibrant green
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF48BB78).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.medical_services_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'For ${preparationMethod.condition}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title Section
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

                  // Description
                  Text(
                    preparationMethod.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

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
                        },
                        stepIndex: index,
                        timerSeconds: timerSec,
                        isTimerActive: _activeTimerStepIndex == index,
                        timerRemainingSeconds: _activeTimerStepIndex == index
                            ? _timerRemainingSeconds
                            : 0,
                        onStartTimer: timerSec != null
                            ? () => _startTimer(index, timerSec)
                            : null,
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Dosage Information
                  _buildInfoCard(
                    context,
                    'Dosage',
                    preparationMethod.dosage,
                    const Color(0xFF6366F1), // Vibrant indigo/purple
                    Colors.white,
                    Icons.medication_outlined,
                  ),

                  const SizedBox(height: 12),

                  // Frequency Information
                  _buildInfoCard(
                    context,
                    'Frequency',
                    preparationMethod.frequency,
                    const Color(0xFF48BB78), // Vibrant green
                    Colors.white,
                    Icons.schedule_outlined,
                  ),

                  const SizedBox(height: 12),

                  // Duration Information
                  _buildInfoCard(
                    context,
                    'Duration',
                    preparationMethod.duration,
                    const Color(0xFF38A169), // Darker green
                    Colors.white,
                    Icons.calendar_today_outlined,
                  ),

                  const SizedBox(height: 24),

                  // Add Schedule to Device Calendar
                  FilledButton.icon(
                    onPressed: () => _addScheduleToCalendar(context),
                    icon: const Icon(Icons.calendar_today, size: 20),
                    label: Text(
                        AppLocalizations.of(context).addScheduleToCalendar),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
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
                        color:
                            theme.colorScheme.errorContainer.withOpacity(0.3),
                        border: Border.all(
                          color: theme.colorScheme.error.withOpacity(0.5),
                          width: 2,
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
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    warning,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onErrorContainer,
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

                  // Medical Disclaimer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.3),
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
                            'Always consult with a healthcare professional before using herbal remedies, especially if you are pregnant, nursing, taking medications, or have existing medical conditions.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
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
    VoidCallback? onStartTimer,
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
                  ? Row(
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

  Widget _buildInfoCard(
    BuildContext context,
    String label,
    String value,
    Color bgColor,
    Color textColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 28,
            color: textColor,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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
}
