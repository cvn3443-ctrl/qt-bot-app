import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة الإشعارات
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await _notificationsPlugin.initialize(initializationSettings);

  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'qtxsy_bot_service',
      channelName: 'QTXSY Bot Service',
      channelDescription: 'Keeps the bot running.',
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
  WebViewController? _controller; // خليها nullable عشان ما تسبب مشاكل
  bool _isLoading = true;
  bool _isBotActive = false;
  bool _isDemoMode = true;
  bool _showPlatform = true;

  final TextEditingController _amountController = TextEditingController(text: "1.0");
  bool _useMartingale = false;
  double _currentAmount = 1.0;

  Timer? _tradeTimer;
  bool _isCallTurn = true;

  @override
  void initState() {
    super.initState();
    // تهيئة المتصفح
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
  }

  void _clickButton(String text) {
    if (_controller == null) return;
    _controller!.runJavaScript("""
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
    if (_controller == null) return;
    String buttonText = direction == "CALL" ? "شراء" : "بيع";
    
    _controller!.runJavaScript("""
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
    
    HapticFeedback.heavyImpact();
    _showNotification("دخول صفقة", "تم الدخول بـ $_currentAmount\$ على $direction");
  }

  void _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trade_channel', 'Trade Notifications',
      importance: Importance.max, priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(0, title, body, platformDetails);
  }

  void _startBot() async {
    setState(() => _isBotActive = true);
    _currentAmount = double.tryParse(_amountController.text) ?? 1.0;
    
    if (_isDemoMode) {
      _clickButton("ديمو");
    } else {
      _clickButton("حقيقي");
    }

    await FlutterForegroundTask.startService(
      notificationTitle: 'QTXSY Bot Active',
      notificationText: 'البوت شغال...',
      callback: startCallback,
    );

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('إعدادات البوت', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                  const Divider(color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('نوع الحساب:', style: TextStyle(color: Colors.white)),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('ديمو'),
                            selected: _isDemoMode,
                            onSelected: (val) => setModalState(() => _isDemoMode = true),
                          ),
                          const SizedBox(width: 10),
                          ChoiceChip(
                            label: const Text('حقيقي'),
                            selected: !_isDemoMode,
                            onSelected: (val) => setModalState(() => _isDemoMode = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'قيمة الصفقة (\$)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('تفعيل المضاعفة', style: TextStyle(color: Colors.white)),
                    value: _useMartingale,
                    activeColor: Colors.tealAccent,
                    onChanged: (val) => setModalState(() => _useMartingale = val),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isBotActive ? Colors.redAccent : Colors.tealAccent,
                        foregroundColor: Colors.black,
                      ),
                      icon: Icon(_isBotActive ? Icons.stop : Icons.play_arrow),
                      label: Text(_isBotActive ? 'إيقاف البوت' : 'تنشيط البوت', style: const TextStyle(fontSize: 18)),
                      onPressed: () {
                        if (_isBotActive) {
                          _stopBot();
                        } else {
                          _startBot();
                        }
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _tradeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          if (_showPlatform && _controller != null)
            WebViewWidget(controller: _controller!)
          else if (!_showPlatform)
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
