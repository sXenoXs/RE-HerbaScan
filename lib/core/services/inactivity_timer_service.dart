// lib/core/services/inactivity_timer_service.dart
//
// Singleton that tracks user activity and fires [onTimeout] when the app has
// been idle for [duration]. Call [reset()] on every user interaction. Call
// [start()] once at app launch and [stop()] when the user signs out manually.

import 'dart:async';
import 'package:flutter/foundation.dart';

class InactivityTimerService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final InactivityTimerService _instance =
      InactivityTimerService._internal();
  factory InactivityTimerService() => _instance;
  InactivityTimerService._internal();

  // ── Configuration ─────────────────────────────────────────────────────────

  /// How long the app may be idle before [_onTimeout] fires.
  static const Duration defaultTimeout = Duration(minutes: 60);

  // ── State ─────────────────────────────────────────────────────────────────
  Timer? _timer;
  VoidCallback? _onTimeout;
  Duration _duration = defaultTimeout;
  bool _active = false;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Whether the timer is currently running (user is logged in).
  bool get isActive => _active;

  /// Start (or restart) the inactivity timer.
  ///
  /// [onTimeout]  called when [duration] of idle time elapses.
  /// [duration]   defaults to [defaultTimeout] (60 min).
  void start({
    required VoidCallback onTimeout,
    Duration duration = defaultTimeout,
  }) {
    _onTimeout = onTimeout;
    _duration = duration;
    _active = true;
    _restart();
    if (kDebugMode) {
      debugPrint('[InactivityTimer] started — timeout in ${_duration.inMinutes} min');
    }
  }

  /// Reset the countdown (call on every user interaction).
  void reset() {
    if (!_active) return;
    _restart();
  }

  /// Stop the timer entirely (call after manual sign-out).
  void stop() {
    _timer?.cancel();
    _timer = null;
    _active = false;
    _onTimeout = null;
    if (kDebugMode) {
      debugPrint('[InactivityTimer] stopped');
    }
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _restart() {
    _timer?.cancel();
    _timer = Timer(_duration, _fire);
  }

  void _fire() {
    if (!_active) return;
    if (kDebugMode) {
      debugPrint('[InactivityTimer] timeout fired after ${_duration.inMinutes} min of inactivity');
    }
    stop(); // prevent double-fire
    _onTimeout?.call();
  }
}
