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

  final List<String> _foundAssets = [];
  String _status = "جاري البحث...";

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
            // السكريبت يلي بيلقط رسائل السيرفر
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
                      // نلقط رسائل قائمة الأزواج
                      if (data.includes('instruments') || data.includes('asset')) {
                         FlutterChannel.postMessage("RAW:" + data);
                      }
                    } else if (data instanceof ArrayBuffer) {
                      var uint8 = new Uint8Array(data);
                      var str = "";
                      for (var i = 0; i < uint8.length; i++) {
                          str += String.fromCharCode(uint8[i]);
                      }
                      // نلقط قائمة الأزواج لو كانت بالباينري
                      if (str.includes('instruments') || str.includes('asset')) {
                         FlutterChannel.postMessage("RAW:" + str);
                      }
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
    if (raw.startsWith("RAW:")) {
      String data = raw.substring(4);
      // نحاول نستخرج أسماء الأزواج من الرسالة
      RegExp regExp = RegExp(r'"([A-Z]{3,6}(?:_otc)?)"');
      Iterable<Match> matches = regExp.allMatches(data);
      
      for (var match in matches) {
        String asset = match.group(1) ?? "";
        if (asset.isNotEmpty && !_foundAssets.contains(asset) && !asset.contains('USD_')) {
           setState(() {
             _foundAssets.add(asset);
           });
        }
      }
    }
  }

  void _openAssetsList() {
    setState(() {
      _showPlatform = false;
      _status = "الأزواج المكتشفة: ${_foundAssets.length}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QTXSY', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.tealAccent), onPressed: () {
            _controller.reload();
            setState(() {
              _foundAssets.clear();
            });
          }),
          IconButton(icon: const Icon(Icons.settings, color: Colors.tealAccent), onPressed: () {
             // إعدادات البوت
          }),
          // زر الأزواج
          IconButton(icon: const Icon(Icons.list, color: Colors.tealAccent), onPressed: _openAssetsList),
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_status, style: const TextStyle(color: Colors.tealAccent, fontSize: 18)),
                  ),
                  Expanded(
                    child: _foundAssets.isEmpty
                        ? const Center(child: Text('جاري جمع الأزواج من السيرفر...', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _foundAssets.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                leading: const Icon(Icons.currency_exchange, color: Colors.tealAccent),
                                title: Text(_foundAssets[index], style: const TextStyle(color: Colors.white)),
                              );
                            },
                          ),
                  ),
                ],
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
