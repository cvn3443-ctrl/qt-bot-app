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
  final List<String> _foundAssets = []; // لتخزين الأزواج المكتشفة
  String _currentAsset = "EURUSD";
  String _lastSignal = "";
  double _currentPrice = 0.0;

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
    if (raw.startsWith("ASSETS_FOUND:")) {
      String jsonStr = raw.substring(13);
      try {
        final List<dynamic> assets = jsonDecode(jsonStr);
        setState(() {
          _foundAssets.clear();
          for (var a in assets) {
            if (!_foundAssets.contains(a.toString())) {
              _foundAssets.add(a.toString());
            }
          }
        });
      } catch (e) {}
    } else if (raw.startsWith("BIN:")) {
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
              if (_candles.isNotEmpty) {
                _currentPrice = _candles.last['price'];
                _analyzeMarket();
              }
            });
          }
        }
      } catch (e) {}
    }
  }

  void _analyzeMarket() {
    if (!_isBotActive || _candles.length < 10) return;
    double lastPrice = _candles.last['price'];
    double prevPrice = _candles[_candles.length - 2]['price'];
    String signal = "";
    if (lastPrice > prevPrice) {
      signal = "CALL";
    } else if (lastPrice < prevPrice) {
      signal = "PUT";
    }
    if (signal.isNotEmpty && signal != _lastSignal) {
      setState(() {
        _lastSignal = signal;
      });
      _executeTrade(signal);
    }
  }

  void _executeTrade(String direction) {
    String buttonText = direction == "CALL" ? "شراء" : "بيع";
    _controller.runJavaScript("""
      (function() {
        let buttons = document.querySelectorAll('button, div[role="button"], div');
        for (let i = 0; i < buttons.length; i++) {
          let el = buttons[i];
          if (el.innerText && el.innerText.trim() === "$buttonText") {
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

  // دالة لزر التحديث
  void _refreshPage() {
    _controller.reload();
    setState(() {
      _candles.clear();
      _isLoading = true;
    });
  }

  // دالة لزر الإعدادات
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

  // دالة البحث عن الأزواج
  void _findAssets() {
    _controller.runJavaScript("""
      (function() {
        let elements = document.querySelectorAll('div, span, button, a');
        let found = [];
        for (let i = 0; i < elements.length; i++) {
          let el = elements[i];
          let text = el.innerText ? el.innerText.trim() : "";
          if (text.length > 5 && text.length < 15 && (text.includes('USD') || text.includes('EUR') || text.includes('JPY') || text.includes('GBP') || text.includes('OTC'))) {
            found.push(text);
          }
        }
        FlutterChannel.postMessage("ASSETS_FOUND:" + JSON.stringify(found));
      })();
    """);
    setState(() {
      _showPlatform = false; // نروح لشاشة البوت عشان نشوف النتيجة
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QTXSY', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.tealAccent), onPressed: _refreshPage),
          IconButton(icon: const Icon(Icons.settings, color: Colors.tealAccent), onPressed: _showBotSettings),
          IconButton(icon: const Icon(Icons.list, color: Colors.tealAccent), onPressed: _findAssets), // زر البحث عن الأزواج
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
              child: _foundAssets.isEmpty
                  ? const Center(child: Text('جاري البحث عن الأزواج... دوس على أيقونة القائمة', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _foundAssets.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(_foundAssets[index], style: const TextStyle(color: Colors.white)),
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
