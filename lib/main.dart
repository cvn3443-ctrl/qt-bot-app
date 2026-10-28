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
      title: 'QTXSY Binary Decoder',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const QuotexBinaryScreen(),
    );
  }
}

class QuotexBinaryScreen extends StatefulWidget {
  const QuotexBinaryScreen({super.key});

  @override
  State<QuotexBinaryScreen> createState() => _QuotexBinaryScreenState();
}

class _QuotexBinaryScreenState extends State<QuotexBinaryScreen> {
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
            if (msg.isNotEmpty) {
              _logs.add("📥 $msg");
            }
            if (_logs.length > 30) _logs.removeAt(0);
          });
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
                  ws.binaryType = 'arraybuffer'; // استقبال البيانات الثنائية
                  
                  ws.addEventListener('message', function(event) {
                    var data = event.data;
                    if (typeof data === 'string') {
                      if (data.includes('quotes') || data.includes('depth') || data.includes('history')) {
                         FlutterChannel.postMessage("🔍 نص: " + data);
                      }
                    } else if (data instanceof ArrayBuffer) {
                      var uint8 = new Uint8Array(data);
                      var str = "";
                      for (var i = 0; i < uint8.length; i++) {
                          str += String.fromCharCode(uint8[i]);
                      }
                      FlutterChannel.postMessage("📦 باينري: " + str.substring(0, 100));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استقبال البيانات الثنائية', style: TextStyle(color: Colors.tealAccent)),
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
