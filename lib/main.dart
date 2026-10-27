import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

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
// شاشة تسجيل الدخول
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
  
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            if (url.contains('qxbroker.com') || url.contains('quotex.io')) {
              final result = await _webViewController.runJavaScriptReturningResult("JSON.stringify(document.cookie)");
              debugPrint("Cookies: $result");
            }
          },
        ),
      );
  }

  void _login() async {
    setState(() {
      _isLoading = true;
      _status = 'جاري الاتصال...';
    });
    // محاكاة تسجيل الدخول
    await Future.delayed(const Duration(seconds: 2)); 
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
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
              const Text('تسجيل الدخول لـ QTXSY', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.password), border: OutlineInputBorder()),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 30),
              if (_status.isNotEmpty) Text(_status, style: const TextStyle(color: Colors.tealAccent, fontSize: 16)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('دخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
// لوحة التحكم
// ==========================================
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة التحكم', style: TextStyle(color: Colors.tealAccent)), backgroundColor: Colors.black87, centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('مرحباً بك في QTXSY Bot', style: TextStyle(fontSize: 22, color: Colors.white)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
              icon: const Icon(Icons.monitor),
              label: const Text('شاشة المراقبة الحية'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LiveMonitorScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// شاشة المراقبة الحية (Live Monitor)
// ==========================================
class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  final List<FlSpot> _spots = [];
  Timer? _timer;
  double _currentPrice = 1.0850;
  final Random _random = Random();
  
  // بيانات وهمية للتحليل
  String _asset = "EUR/USD (Global)";
  String _strategySignal = "قناص (Sniper)";
  String _signalDirection = "CALL";
  bool _isAnalyzing = true;

  @override
  void initState() {
    super.initState();
    // توليد بيانات أولية
    for (int i = 0; i < 20; i++) {
      _spots.add(FlSpot(i.toDouble(), _currentPrice + (_random.nextDouble() - 0.5) * 0.002));
    }
    // تشغيل محاكاة السوق
    _startLiveSimulation();
  }

  void _startLiveSimulation() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        // تحريك السعر
        _currentPrice += (_random.nextDouble() - 0.5) * 0.0005;
        _spots.add(FlSpot(_spots.last.x + 1, _currentPrice));
        if (_spots.length > 20) _spots.removeAt(0);
        
        // محاكاة تغيير الإشارة
        int r = _random.nextInt(10);
        if (r > 7) {
          _strategySignal = ["كسر وإعادة اختبار", "دعوم ومقاومات", "قناص (Sniper)", "سيكولوجية الشموع"][_random.nextInt(4)];
          _signalDirection = _random.nextBool() ? "CALL" : "PUT";
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مراقبة: $_asset', style: const TextStyle(color: Colors.tealAccent, fontSize: 16)),
        backgroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // الشارت
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _spots,
                      isCurved: true,
                      color: Colors.tealAccent,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: Colors.tealAccent.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // لوحة التحليل
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoCard("السعر الحالي", _currentPrice.toStringAsFixed(5)),
                      _buildInfoCard("الفريم", "15 دقيقة"),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoCard("الاستراتيجية", _strategySignal),
                      _buildSignalCard(),
                    ],
                  ),
                  const Spacer(),
                  const Text("البوت يقوم بتحليل الشموع...", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSignalCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _signalDirection == "CALL" ? Colors.tealAccent : Colors.redAccent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text("الإشارة", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_signalDirection, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
