import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Schedules and cancels local notifications for preparation step timers.
/// Singleton; call [init] from main() after WidgetsFlutterBinding.ensureInitialized().
class PreparationNotificationService {
  static final PreparationNotificationService _instance =
      PreparationNotificationService._internal();
  factory PreparationNotificationService() => _instance;
  PreparationNotificationService._internal();

  static const String _channelId = 'preparation_timers';
  static const String _channelName = 'Preparation timers';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Initialize the plugin and create the Android channel. Call once from main().
  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
    );
    const initSettings = InitializationSettings(
      android: android,
      iOS: ios,
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) {},
    );
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'HerbaScan preparation step timer alerts',
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    _initialized = true;
  }

  /// Schedule a notification to fire after [remainingSeconds].
  /// [id] is a unique string for this timer (e.g. step id or "prepId_stepIndex").
  Future<void> scheduleTimer(String id, int remainingSeconds) async {
    if (!_initialized || remainingSeconds <= 0) return;
    final notificationId = id.hashCode.abs().clamp(0, 0x7FFFFFFF);
    await cancelTimer(id);
    final scheduledDate =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: remainingSeconds));
    await _plugin.zonedSchedule(
      notificationId,
      'HerbaScan Timer',
      'Your preparation step is complete!',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'HerbaScan preparation step timer alerts',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel a scheduled timer notification.
  Future<void> cancelTimer(String id) async {
    if (!_initialized) return;
    final notificationId = id.hashCode.abs().clamp(0, 0x7FFFFFFF);
    await _plugin.cancel(notificationId);
  }
}
