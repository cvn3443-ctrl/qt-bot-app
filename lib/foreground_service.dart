import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BotTaskHandler());
}

class BotTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // ما في شي، بس بنخلي الخدمة شغالة
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // ما في شي
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // ما في شي
  }
}
