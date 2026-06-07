import 'package:shared_preferences/shared_preferences.dart';

/// Persistent flags for in-app coachmark tours.
///
/// Each tour has two gates:
///   * `<tour>_done`        — the user finished or skipped the tour at least once.
///   * `<tour>_dont_show`   — the user ticked "Don't show this hint again" and the
///                            tour must never auto-fire again (even if `_done` is reset).
///
/// Tours can be re-played manually from Settings via [resetAll], which clears both.
class TutorialPreferences {
  TutorialPreferences._();

  static const String _kHomeDone = 'coachmark_home_done';
  static const String _kHomeDontShow = 'coachmark_home_dont_show';

  /// Whether the home dashboard tour should auto-fire on first visit.
  static Future<bool> shouldShowHomeTour() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_kHomeDone) ?? false;
    final dontShow = prefs.getBool(_kHomeDontShow) ?? false;
    return !done && !dontShow;
  }

  /// Mark the home tour as completed/skipped for this device.
  static Future<void> setHomeTourDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHomeDone, true);
  }

  /// Persist the "Don't show this hint again" checkbox state for the home tour.
  static Future<void> setHomeDontShowAgain(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHomeDontShow, value);
  }

  /// Re-enable every tour. Used by Settings → "Replay tutorial".
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHomeDone);
    await prefs.remove(_kHomeDontShow);
  }
}
