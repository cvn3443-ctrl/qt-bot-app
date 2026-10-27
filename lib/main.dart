import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.notification.request();

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
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// شاشة تسجيل الدخول الحقيقية
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _status = '';

  void _login() async {
    setState(() {
      _isLoading = true;
      _status = 'جاري الاتصال بـ Quotex...';
    });

    try {
      // هنا نفتح المتصفح المخفي
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) async {
              if (url.contains('qxbroker.com') || url.contains('quotex.io')) {
                // حقن جافا سكربت لاستخراج بيانات الجلسة (SSID)
                // ملاحظة: هذا الجزء يحتاج تعديل حسب صفحة Quotex الحالية
                final result = await controller.runJavaScriptReturningResult(
                  "JSON.stringify(document.cookie)"
                );
                if (mounted) {
                  setState(() {
                    _status = 'تم الاتصال! الكوكيز: ${result.toString().substring(0, 20)}...';
                  });
                  await Future.delayed(const Duration(seconds: 2));
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  );
                }
              }
            },
          ),
        );

      // فتح صفحة تسجيل الدخول
      await controller.loadRequest(Uri.parse('https://qxbroker.com/en/sign-in'));
      
      // محاكاة إدخال البيانات (هذا يحتاج تعديل ليتناسب مع الحقول الحقيقية)
      await Future.delayed(const Duration(seconds: 3));
      await controller.runJavaScript("""
        document.querySelector('input[name="email"]').value = '${_emailController.text}';
        document.querySelector('input[name="password"]').value = '${_passwordController.text}';
        document.querySelector('button[type="submit"]').click();
      """);

      // انتظار النتيجة
      await Future.delayed(const Duration(seconds: 5));

    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'خطأ: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 80, color: Colors.tealAccent),
              const SizedBox(height: 30),
              const Text(
                'تسجيل الدخول لـ QTXSY',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: Icon(Icons.password),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 30),
              if (_status.isNotEmpty)
                Text(
                  _status,
                  style: const TextStyle(color: Colors.tealAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('دخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// الشاشة الرئيسية (لوحة التحكم)
// ==========================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة التحكم', style: TextStyle(color: Colors.tealAccent)),
          backgroundColor: Colors.black87,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'تم تسجيل الدخول بنجاح!',
                style: TextStyle(fontSize: 22, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'الرصيد: جاري التحميل...',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('تشغيل البوت بالخلفية'),
                onPressed: () async {
                  await FlutterForegroundTask.startService(
                    notificationTitle: 'QTXSY Bot Active',
                    notificationText: 'The bot is running in the background.',
                    callback: startCallback,
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
                label: const Text('إيقاف البوت'),
                onPressed: () async {
                  await FlutterForegroundTask.stopService();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
