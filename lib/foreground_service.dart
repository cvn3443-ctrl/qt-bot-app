import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// لازم فنكشن top-level (مش جوا كلاس) ومعلّم عليها هاد الـpragma
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BotTaskHandler());
}

// هاد بيشتغل بسياق منفصل عن الواجهة الرئيسية (main isolate).
// ⚠️ ما تحطوا هون ولا أي كود بيلمس WebView أو أي كائن من الواجهة — هاي القاعدة يلي حلت الـCrash.
class BotTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  void onReceiveData(Object data) {
    // بتوصل هون أي String بعتها main isolate عبر sendDataToTask — نحدث فيها نص الإشعار الدائم
    if (data is String) {
      FlutterForegroundTask.updateService(notificationTitle: 'البوت شغال', notificationText: data);
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

class ForegroundServiceController {
  static void initCommunication() => FlutterForegroundTask.initCommunicationPort();

  static void initOptions() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'qtxsy_service',
        channelName: 'تشغيل البوت',
        channelDescription: 'إشعار دائم طول ما البوت شغال بالخلفية',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start() async {
    if (await FlutterForegroundTask.isRunningService) return;
    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'البوت شغال',
      notificationText: 'عم يراقب السوق...',
      callback: startCallback,
    );
    print('startService result: $result');
  }

  static Future<void> stop() async => FlutterForegroundTask.stopService();
}
