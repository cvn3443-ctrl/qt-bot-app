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
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          setState(() {
            _logs.add("📥 استقبلنا من السيرفر: ${message.message}");
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) => setState(() => _isLoading = true),
          // دمجنا onPageFinished هون عشان ما يتكرر
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
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
      await _controller.runJavaScript("""
        (function() {
          let socket = new WebSocket("wss://ws2.quotex.com/socket.io/?EIO=3&transport=websocket");
          
          socket.onopen = function(e) {
              socket.send('40');
              setTimeout(function() {
                  let timestamp = Math.floor(Date.now() / 1000);
                  socket.send('42["loadHistoryPeriod",{"asset":"EURUSD","time":' + timestamp + ',"period":300}]');
              }, 1000);
          };

          socket.onmessage = function(event) {
              if (event.data.includes('history')) {
                  FlutterChannel.postMessage(event.data.substring(0, 200));
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
