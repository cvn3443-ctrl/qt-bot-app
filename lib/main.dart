import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';
import 'notification_service.dart';
import 'foreground_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة الإشعارات (بس للصفقات)
  await NotificationService.init();

  FlutterForegroundTask.initCommunicationPort();
  runApp(const MyApp());
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
  bool _isDemoMode = true;
  bool _showPlatform = true;

  final TextEditingController _amountController = TextEditingController(text: "1.0");
  bool _useMartingale = false;
  double _currentAmount = 1.0;
  
  Timer? _tradeTimer;
  bool _isCallTurn = true;

  // قائمة الأزواج
  final List<String> _targetAssets = [
    "EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", 
    "USDCHF", "NZDUSD", "EURGBP", "EURJPY", "GBPJPY",
    "CHFJPY_otc", "USDCAD_otc", "EURJPY_otc", "AUDCAD_otc", "EURAUD_otc",
    "AUDUSD_otc", "GBPUSD_otc", "EURUSD_otc", "NZDUSD_otc", "GBPJPY_otc"
  ];

  @override
  void initState() {
    super.initState();
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

    // إعدادات الخلفية (بعد فتح الشاشة)
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

  void _executeTrade(String direction) {
    if (!_isBotActive) return;
    String buttonText = direction == "CALL" ? "شراء" : "بيع";
    
    _controller.runJavaScript("""
      (function() {
        let input = document.querySelector('input[type="number"]') || document.querySelector('input[inputmode="decimal"]');
        if (input) {
          input.value = "$_currentAmount";
          input.dispatchEvent(new Event('input', { bubbles: true }));
          input.dispatchEvent(new Event('change', { bubbles: true }));
        }
      })();
    """);
    
    _clickButton(buttonText);
    
    // اهتزاز + إشعار
    HapticFeedback.heavyImpact();
    NotificationService.showTradeNotification("دخول صفقة", "تم الدخول بـ $_currentAmount\$ على $direction");
  }

  void _startBot() async {
    setState(() => _isBotActive = true);
    _currentAmount = double.tryParse(_amountController.text) ?? 1.0;
    
    if (_isDemoMode) {
      _clickButton("ديمو");
    } else {
      _clickButton("حقيقي");
    }

    // تشغيل الخلفية
    await FlutterForegroundTask.startService(
      notificationTitle: 'QTXSY Bot Active',
      notificationText: 'البوت شغال...',
      callback: startCallback, // من ملف foreground_service.dart
    );

    // المؤقت
    _tradeTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      _executeTrade(_isCallTurn ? "CALL" : "PUT");
      _isCallTurn = !_isCallTurn;

      if (_useMartingale) {
        _currentAmount *= 2.0;
      } else {
        _currentAmount = double.tryParse(_amountController.text) ?? 1.0;
      }
    });
  }

  void _stopBot() async {
    setState(() => _isBotActive = false);
    _tradeTimer?.cancel();
    await FlutterForegroundTask.stopService();
  }

  void _showBotSettings() {
    // نفس كود الإعدادات (ديمو/حقيقي، المبلغ، المضاعفة، الأزواج)
    // ... (نفس الكود اللي كان بالرسالة السابقة)
  }

  @override
  void dispose() {
    _tradeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // نفس كود الواجهة
    return Scaffold(
      appBar: AppBar(
        title: const Text('QTXSY', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(icon: const Icon(Icons.settings, color: Colors.tealAccent), onPressed: _showBotSettings),
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
                _isBotActive ? "البوت يعمل..." : "البوت متوقف",
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
