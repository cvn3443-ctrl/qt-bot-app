import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort(); // رخيص، ما بيعلّق
  runApp(const MyApp()); // فتح الشاشة فوراً
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QTXSY Bot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isBotActive = false;
  bool _showPlatform = true;

  @override
  void initState() {
    super.initState();
    // المتصفح
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/demo-trade'));

    // بعد ما الشاشة تفتح، نطلب الأذونات والخلفية (حسب كلام صديقك)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupBackgroundStuff();
    });
  }

  Future<void> _setupBackgroundStuff() async {
    // طلب إذن الإشعارات
    final status = await FlutterForegroundTask.checkNotificationPermission();
    if (status != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    
    // تهيئة الخلفية
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'qtxsy_service',
        channelName: 'تشغيل البوت',
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        allowWakeLock: true,
      ),
    );
  }

  void _clickButton(String text) {
    _controller.runJavaScript("""
      (function() {
        let buttons = document.querySelectorAll('button, div[role="button"], div, span');
        for (let i = 0; i < buttons.length; i++) {
          let el = buttons[i];
          if (el.innerText && el.innerText.trim() === "$text") {
            if (el.offsetParent !== null) {
              el.click();
              return "Clicked";
            }
          }
        }
        return "Not Found";
      })();
    """);
  }

  void _startBot() async {
    setState(() => _isBotActive = true);
    
    // تشغيل الخلفية
    await FlutterForegroundTask.startService(
      notificationTitle: 'البوت شغال',
      notificationText: 'عم يراقب السوق...',
      callback: startCallback,
    );
    
    // اهتزاز وإشعار
    HapticFeedback.heavyImpact();
  }

  void _stopBot() async {
    setState(() => _isBotActive = false);
    await FlutterForegroundTask.stopService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QTXSY', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.tealAccent),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1E1E1E),
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('إعدادات البوت', style: TextStyle(fontSize: 22, color: Colors.tealAccent)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isBotActive ? Colors.redAccent : Colors.tealAccent,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          if (_isBotActive) {
                            _stopBot();
                          } else {
                            _startBot();
                          }
                          Navigator.pop(context);
                        },
                        child: Text(_isBotActive ? 'إيقاف البوت' : 'تنشيط البوت'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.black,
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showPlatform = true),
                    icon: Icon(Icons.web, color: _showPlatform ? Colors.tealAccent : Colors.grey),
                    label: Text('المنصة', style: TextStyle(color: _showPlatform ? Colors.tealAccent : Colors.grey)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showPlatform = false),
                    icon: Icon(Icons.smart_toy, color: !_showPlatform ? Colors.tealAccent : Colors.grey),
                    label: Text('البوت', style: TextStyle(color: !_showPlatform ? Colors.tealAccent : Colors.grey)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_showPlatform)
            WebViewWidget(controller: _controller)
          else
            Center(
              child: Text(
                _isBotActive ? "البوت يعمل... بيدوس كل دقيقة" : "البوت متوقف",
                style: TextStyle(fontSize: 20, color: _isBotActive ? Colors.tealAccent : Colors.white),
              ),
            ),
          if (_isLoading && _showPlatform)
            const Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
        ],
      ),
    );
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(FirstTaskHandler());
}

class FirstTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
