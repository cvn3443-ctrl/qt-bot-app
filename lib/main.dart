import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isBotActive = false;
  bool _isDemoMode = true;
  double _baseAmount = 1.0;
  bool _useMartingale = false;
  bool _showPlatform = true; 

  final List<Map<String, dynamic>> _candles = [];
  String _currentAsset = "EURUSD";

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36")
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _processData(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
            _controller.runJavaScript("""
              (function() {
                if (window._ws_intercepted) return;
                window._ws_intercepted = true;
                var originalWebSocket = window.WebSocket;
                window.WebSocket = function(url, protocols) {
                  var ws = new originalWebSocket(url, protocols);
                  ws.binaryType = 'arraybuffer';
                  ws.addEventListener('message', function(event) {
                    var data = event.data;
                    if (typeof data === 'string') {
                      if (data.includes('quotes') || data.includes('history')) {
                         FlutterChannel.postMessage("TEXT:" + data);
                      }
                    } else if (data instanceof ArrayBuffer) {
                      var uint8 = new Uint8Array(data);
                      var str = "";
                      for (var i = 0; i < uint8.length; i++) {
                          str += String.fromCharCode(uint8[i]);
                      }
                      FlutterChannel.postMessage("BIN:" + str);
                    }
                  });
                  return ws;
                };
                window.WebSocket.prototype = originalWebSocket.prototype;
                window.WebSocket.CONNECTING = originalWebSocket.CONNECTING;
                window.WebSocket.OPEN = originalWebSocket.OPEN;
                window.WebSocket.CLOSING = originalWebSocket.CLOSING;
                window.WebSocket.CLOSED = originalWebSocket.CLOSED;
              })();
            """);
          },
          onPageFinished: (String url) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/demo-trade'));
  }

  void _processData(String raw) {
    if (raw.startsWith("BIN:")) {
      String jsonStr = raw.substring(4);
      try {
        if (jsonStr.contains('"history"')) {
          final data = jsonDecode(jsonStr);
          if (data['history'] != null) {
            setState(() {
              _currentAsset = data['asset'] ?? 'EURUSD';
              _candles.clear();
              for (var c in data['history']) {
                _candles.add({
                  'time': c[0],
                  'price': c[1],
                });
              }
            });
          }
        }
      } catch (e) {
        // تجاهل
      }
    }
  }

  void _refreshPage() {
    _controller.reload();
    setState(() {
      _candles.clear();
      _isLoading = true;
    });
  }

  void _showBotSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
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
                  const Text('المبلغ (\$):', style: TextStyle(color: Colors.white)),
                  Slider(
                    value: _baseAmount,
                    min: 1.0,
                    max: 10.0,
                    divisions: 9,
                    label: '\$${_baseAmount.toStringAsFixed(0)}',
                    activeColor: Colors.tealAccent,
                    onChanged: (val) => setModalState(() => _baseAmount = val),
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
                        setModalState(() => _isBotActive = !_isBotActive);
                        setState(() => _isBotActive = _isBotActive);
                        if (_isBotActive) {
                          FlutterForegroundTask.startService(
                            notificationTitle: 'QTXSY Bot Active',
                            notificationText: 'البوت شغال...',
                            callback: startCallback,
                          );
                        } else {
                          FlutterForegroundTask.stopService();
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QTXSY', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.tealAccent), onPressed: _refreshPage), // زر التحديث
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
            Container(
              color: Colors.black,
              child: _candles.isEmpty
                  ? const Center(child: Text('جاري جمع البيانات... (دوس على تحديث فوق وانت بالمنصة)', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _candles.length,
                      itemBuilder: (context, index) {
                        final c = _candles[index];
                        return ListTile(
                          leading: const Icon(Icons.show_chart, color: Colors.tealAccent),
                          title: Text('الوقت: ${c['time']}', style: const TextStyle(color: Colors.white)),
                          subtitle: Text('السعر: ${c['price']}', style: const TextStyle(color: Colors.grey)),
                        );
                      },
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
