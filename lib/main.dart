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
      title: 'QTXSY Interceptor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const QuotexInterceptorScreen(),
    );
  }
}

class QuotexInterceptorScreen extends StatefulWidget {
  const QuotexInterceptorScreen({super.key});

  @override
  State<QuotexInterceptorScreen> createState() => _QuotexInterceptorScreenState();
}

class _QuotexInterceptorScreenState extends State<QuotexInterceptorScreen> {
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
            // نعرض بس أول 100 حرف عشان الشاشة ما تغرق
            String msg = message.message;
            if (msg.length > 100) {
              msg = msg.substring(0, 100) + "...";
            }
            _logs.add("📥 ${msg}");
            // نخلي الشاشة تنزل لتحت تلقائياً
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
      ..loadRequest(Uri.parse('https://quotex.com/ar/demo-trade'));
  }

  // دالة لحقن السكريبت الاعتراضي
  void _injectInterceptor() async {
    setState(() {
      _logs.clear();
      _logs.add("--- جاري حقن السكريبت الاعتراضي ---");
    });

    try {
      // هاد السكريبت بيعترض WebSocket قبل ما يفتحه الموقع
      await _controller.runJavaScript("""
        (function() {
          // إذا كان السكريبت محقون من قبل، نوقف
          if (window._ws_intercepted) return;
          window._ws_intercepted = true;

          var originalWebSocket = window.WebSocket;
          
          window.WebSocket = function(url, protocols) {
            // نطبع الرابط يلي عم يتصل فيه
            FlutterChannel.postMessage("🔌 WebSocket URL: " + url);
            
            var ws = new originalWebSocket(url, protocols);
            
            // نعترض الرسائل الجاية
            ws.addEventListener('message', function(event) {
              var data = event.data;
              // إذا كانت الرسالة عبارة عن نص وفيه كلمة "history" أو "candles" أو "tick"
              if (typeof data === 'string' && (data.includes('history') || data.includes('candles') || data.includes('tick'))) {
                FlutterChannel.postMessage("📊 بيانات: " + data);
              }
            });
            
            return ws;
          };
          
          // نرجع باقي الخصائص للـ WebSocket الأصلي
          window.WebSocket.prototype = originalWebSocket.prototype;
          window.WebSocket.CONNECTING = originalWebSocket.CONNECTING;
          window.WebSocket.OPEN = originalWebSocket.OPEN;
          window.WebSocket.CLOSING = originalWebSocket.CLOSING;
          window.WebSocket.CLOSED = originalWebSocket.CLOSED;
          
          FlutterChannel.postMessage("✅ تم حقن السكريبت بنجاح! جاري اعتراض البيانات...");
        })();
      """);
    } catch (e) {
      setState(() => _logs.add("❌ خطأ: $e"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اعتراض بيانات WebSocket', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.security, color: Colors.tealAccent),
            tooltip: 'حقن السكريبت',
            onPressed: _injectInterceptor,
          ),
        ],
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
