import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.notification.request();
  
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
      home: const QuotexWebScreen(),
    );
  }
}

class QuotexWebScreen extends StatefulWidget {
  const QuotexWebScreen({super.key});

  @override
  State<QuotexWebScreen> createState() => _QuotexWebScreenState();
}

class _QuotexWebScreenState extends State<QuotexWebScreen> {
  late WebViewController _controller;
  bool _isLoading = true;
  
  // إعدادات البوت
  bool _isDemoMode = true; 
  double _baseAmount = 1.0;
  bool _useMartingale = false; // false = مبلغ ثابت، true = مضاعفات
  bool _isBotActive = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            debugPrint('URL Loaded: $url');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/demo-trade'));
  }

  void _showBotSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // عشان النافذة تكبر مع المحتوى
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
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إعدادات التداول',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 10),
                  
                  // اختيار ديمو / حقيقي
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('نوع الحساب:', style: TextStyle(fontSize: 16, color: Colors.white)),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('ديمو'),
                            selected: _isDemoMode,
                            selectedColor: Colors.tealAccent,
                            onSelected: (val) => setModalState(() => _isDemoMode = true),
                          ),
                          const SizedBox(width: 10),
                          ChoiceChip(
                            label: const Text('حقيقي'),
                            selected: !_isDemoMode,
                            selectedColor: Colors.redAccent,
                            onSelected: (val) => setModalState(() => _isDemoMode = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // المبلغ الأساسي
                  Text('المبلغ الأساسي (\$): ${_baseAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, color: Colors.white)),
                  Slider(
                    value: _baseAmount,
                    min: 1.0,
                    max: 10.0,
                    divisions: 9,
                    label: '\$${_baseAmount.toStringAsFixed(0)}',
                    activeColor: Colors.tealAccent,
                    onChanged: (val) => setModalState(() => _baseAmount = val),
                  ),
                  const SizedBox(height: 10),
                  
                  // نوع إدارة المال (ثابت ضد مضاعفات)
                  const Text('طريقة إدارة رأس المال:', style: TextStyle(fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('مبلغ ثابت', style: TextStyle(color: Colors.white, fontSize: 14)),
                          value: false,
                          groupValue: _useMartingale,
                          activeColor: Colors.tealAccent,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setModalState(() => _useMartingale = false),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('مضاعفات', style: TextStyle(color: Colors.white, fontSize: 14)),
                          value: true,
                          groupValue: _useMartingale,
                          activeColor: Colors.tealAccent,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setModalState(() => _useMartingale = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  // زر التنشيط
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isBotActive ? Colors.redAccent : Colors.tealAccent,
                        foregroundColor: Colors.black,
                      ),
                      icon: Icon(_isBotActive ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        _isBotActive ? 'إيقاف البوت' : 'تنشيط البوت',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        setModalState(() {
                          _isBotActive = !_isBotActive;
                        });
                        setState(() {
                          _isBotActive = _isBotActive;
                        });
                        
                        if (_isBotActive) {
                          // بدء الخلفية
                          FlutterForegroundTask.startService(
                            notificationTitle: 'QTXSY Bot Active',
                            notificationText: 'البوت يعمل الآن على حساب ${_isDemoMode ? "ديمو" : "حقيقي"} بمبلغ ${_baseAmount.toStringAsFixed(0)}\$ ${_useMartingale ? "مع مضاعفات" : "مبلغ ثابت"}.',
                            callback: startCallback,
                          );
                          Navigator.pop(context); // إغلاق النافذة
                        } else {
                          // إيقاف الخلفية
                          FlutterForegroundTask.stopService();
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('منصة Quotex', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: _isBotActive ? Colors.redAccent : Colors.tealAccent),
            onPressed: _showBotSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent),
            ),
          
          // شريط علوي يبين حالة البوت
          if (_isBotActive)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.tealAccent.withOpacity(0.9),
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  'البوت يعمل (${_isDemoMode ? "ديمو" : "حقيقي"}) | ${_baseAmount.toStringAsFixed(0)}\$ ${_useMartingale ? "| مضاعفات" : "| ثابت"}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
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
