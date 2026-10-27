import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QTXSY Engine',
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
  WebSocketChannel? _channel;
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
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/demo-trade'));
  }

  void _testConnection() async {
    setState(() {
        _logs.clear();
        _logs.add("--- بدء الاختبار ---");
    });

    try {
      // 1. محاولة سحب المفتاح من localStorage (الأكثر ترجيحاً)
      final lsResult = await _controller.runJavaScriptReturningResult("JSON.stringify(localStorage)");
      _logs.add("📦 localStorage: $lsResult");

      // 2. سحب الكوكيز (كاحتياط)
      final cookies = await _controller.runJavaScriptReturningResult("document.cookie");
      _logs.add("🍪 الكوكيز: $cookies");

      // --- سنحاول استخدام localStorage أولاً، أو الكوكيز ---
      String authPayload = "";
      
      // إذا كان localStorage يحتوي على شيء، نحاول استخراجه
      if (lsResult != "{}" && lsResult != "null") {
          _logs.add("✅ وجدنا بيانات في localStorage");
          // هنا سنضع منطق استخراج الـ session لاحقاً
      }

      _logs.add("🔌 جاري الاتصال بالسيرفر...");
      final uri = Uri.parse('wss://ws2.quotex.com/socket.io/?EIO=3&transport=websocket');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (message) {
          setState(() {
            _logs.add("📥 استقبلنا: $message");
            if (message.toString() == "40") {
              _logs.add("📤 إرسال التصريح...");
              // نرسل بيانات وهمية الآن، فقط لاختبار أن الاتصال يعمل
              // السيرفر سيرفضها لأنه لا يوجد ssid حقيقي
              _channel?.sink.add('42["auth",{"ssid":"test"}]');
            }
          });
        },
        onError: (error) => setState(() => _logs.add("❌ خطأ: $error")),
        onDone: () => setState(() => _logs.add("🔌 انقطع الاتصال.")),
      );
    } catch (e) {
      setState(() => _logs.add("❌ فشل: $e"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار المحرك المتقدم', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.tealAccent),
            onPressed: _testConnection,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.tealAccent), // إعادة زر الإعدادات
            onPressed: () {
                // يمكننا إضافة الإعدادات هنا لاحقاً
            },
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
