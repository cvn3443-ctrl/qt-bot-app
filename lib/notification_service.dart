import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  // إشعار خفيف (النبضة) - Importance.defaultImportance عشان الصوت يشتغل
  static Future<void> showHeartbeat(String statusText) async {
    const details = AndroidNotificationDetails(
      'heartbeat_channel_v2', 'حالة البوت',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: false,
    );
    await _plugin.show(100, 'البوت شغال', statusText, const NotificationDetails(android: details));
  }

  // إشعار قوي (الصفقة) - Importance.max
  static Future<void> showTradeAlert(String pair, String direction) async {
    const details = AndroidNotificationDetails(
      'trade_alerts_v2', 'تنبيهات الصفقات',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );
    await _plugin.show(200, 'دخلنا صفقة', '$pair — $direction', const NotificationDetails(android: details));
  }
}
