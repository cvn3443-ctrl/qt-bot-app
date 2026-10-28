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
      title: 'QTXSY Fetch Candles',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const QuotexFetchScreen(),
    );
  }
}

class QuotexFetchScreen extends StatefulWidget {
  const QuotexFetchScreen({super.key});

  @override
  State<QuotexFetchScreen> createState() => _QuotexFetchScreenState();
}

class _QuotexFetchScreenState extends State<QuotexFetchScreen> {
  late WebViewController _controller;
  final List<String> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) => setState(() => _isLoading = true),
          onPageFinished: (String url) => setState(() => _isLoading = false),
          // استقبال الرسائل من الجافا سكربت
          onPageFinished: (String url) {
             setState(() => _isLoading = false);
             // نضيف جسر تواصل عشان السكريبت يبعتلنا البيانات
             _controller.addJavaScriptChannel(
                'FlutterChannel',
                onMessageReceived: (JavaScriptMessage message) {
                  setState(() {
                    _logs.add("📥 استقبلنا من السيرفر: ${message.message}");
                  });
                },
             );
          },
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/demo-trade'));
  }

  void _fetchCandlesFromBrowser() async {
    setState(() {
      _logs.clear();
      _logs.add("--- محاولة سحب الشموع من داخل المتصفح ---");
    });

    try {
      // سكريبت يفتح اتصال وهمي من داخل المتصفح ويطلب الشموع
      await _controller.runJavaScript("""
        (function() {
          // محاولة الاتصال بالسيرفر الداخلي للمنصة
          let socket = new WebSocket("wss://ws2.quotex.com/socket.io/?EIO=3&transport=websocket");
          
          socket.onopen = function(e) {
              // إرسال طلب الشموع بعد الاتصال
              socket.send('40');
              setTimeout(() => {
                  // طلب شموع EURUSD
                  socket.send('42["loadHistoryPeriod",{"asset":"EURUSD","time":' + Math.floor(Date.now() / 1000) + ',"period":300}]');
              }, 1000);
          };

          socket.onmessage = function(event) {
              // بمجرد وصول الرد، نبعته لـ Flutter
              if (event.data.includes('history')) {
                  FlutterChannel.postMessage(event.data.substring(0, 500));
                  socket.close();
              }
          };
        })();
      """);
      
      setState(() {
        _logs.add("📤 تم إرسال طلب الشموع. جاري انتظار الرد...");
      });

    } catch (e) {
      setState(() => _logs.add("❌ خطأ: $e"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سحب الشموع من المتصفح', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.tealAccent),
            onPressed: _fetchCandlesFromBrowser,
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
