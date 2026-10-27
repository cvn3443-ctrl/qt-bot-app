import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

void main() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'qtxsy_bot_service',
      channelName: 'QTXSY Bot Service',
      channelDescription: 'Keeps the trading bot running in the background.',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(FirstTaskHandler());
}

class FirstTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('Bot Service Started at $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    debugPrint('Bot is checking market... $timestamp');
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('Bot Service Destroyed');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QTXSY Bot',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('QTXSY Bot', style: TextStyle(color: Colors.tealAccent)),
          backgroundColor: Colors.black87,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.analytics, size: 80, color: Colors.tealAccent),
              const SizedBox(height: 20),
              const Text(
                'مرحباً بك في بوت QTXSY',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('تشغيل الخلفية (تجربة)', style: TextStyle(fontSize: 18)),
                onPressed: () async {
                  await FlutterForegroundTask.startService(
                    notificationTitle: 'QTXSY Bot Active',
                    notificationText: 'The bot is running in the background.',
                    callback: startCallback,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تشغيل الخدمة بالخلفية!')),
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                icon: const Icon(Icons.stop),
                label: const Text('إيقاف الخلفية', style: TextStyle(fontSize: 18)),
                onPressed: () async {
                  await FlutterForegroundTask.stopService();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إيقاف الخدمة.')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
