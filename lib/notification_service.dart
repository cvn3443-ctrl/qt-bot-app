import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // لازم تنادى مرة وحدة بس، بعد أول frame — مش قبل ما تفتح الواجهة
  static Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  // إشعار خفيف — كل 5 دقايق، يأكد إنو البوت شغال وعم يحلل
  static Future<void> showHeartbeat(String statusText) async {
    const details = AndroidNotificationDetails(
      'heartbeat_channel', 'حالة البوت',
      importance: Importance.low,
      priority: Priority.low,
      playSound: true,
      enableVibration: false,
    );
    await _plugin.show(100, 'البوت شغال', statusText, const NotificationDetails(android: details));
  }

  // إشعار قوي — لحظة دخول صفقة فعلية
  static Future<void> showTradeAlert(String pair, String direction) async {
    const details = AndroidNotificationDetails(
      'trade_alerts', 'تنبيهات الصفقات',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      // لصوت مخصص: حطوا ملف mp3 بـ android/app/src/main/res/raw/trade_sound.mp3
      // وفعلوا: sound: RawResourceAndroidNotificationSound('trade_sound'),
    );
    await _plugin.show(200, 'دخلنا صفقة', '$pair — $direction', const NotificationDetails(android: details));
  }
}
