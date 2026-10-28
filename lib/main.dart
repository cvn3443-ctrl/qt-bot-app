import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QTXSY Early Interceptor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const QuotexEarlyScreen(),
    );
  }
}

class QuotexEarlyScreen extends StatefulWidget {
  const QuotexEarlyScreen({super.key});

  @override
  State<QuotexEarlyScreen> createState() => _QuotexEarlyScreenState();
}

class _QuotexEarlyScreenState extends State<QuotexEarlyScreen> {
  late WebViewController _controller;
  final List<String> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36")
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          setState(() {
            String msg = message.message;
            if (msg.length > 150) {
              msg = msg.substring(0, 150) + "...";
            }
            _logs.add("📥 ${msg}");
            if (_logs.length > 50) _logs.removeAt(0);
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
        ),
      )
      // نضيف السكريبت كـ "userScript" عشان يشتغل مع كل صفحة جديدة
      ..addUserScript(WebViewUserScript(
        source: """
          (function() {
            if (window._ws_intercepted) return;
            window._ws_intercepted = true;
            var originalWebSocket = window.WebSocket;
            window.WebSocket = function(url, protocols) {
              FlutterChannel.postMessage("🔌 WebSocket URL: " + url);
              var ws = new originalWebSocket(url, protocols);
              ws.addEventListener('message', function(event) {
                var data = event.data;
                if (typeof data === 'string' && (data.includes('history') || data.includes('candles') || data.includes('tick'))) {
                  FlutterChannel.postMessage("📊 بيانات: " + data.substring(0, 100));
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
        """,
        injectionTime: UserScriptInjectionTime.documentStart, // هاد المفتاح
      ))
      ..loadRequest(Uri.parse('https://quotex.com/ar/demo-trade'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اعتراض مبكر (Document Start)', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading) const Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(_logs[index], style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
