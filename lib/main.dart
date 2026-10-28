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
      title: 'QTXSY Data Inspector',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const QuotexDataScreen(),
    );
  }
}

class QuotexDataScreen extends StatefulWidget {
  const QuotexDataScreen({super.key});

  @override
  State<QuotexDataScreen> createState() => _QuotexDataScreenState();
}

class _QuotexDataScreenState extends State<QuotexDataScreen> {
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
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/demo-trade'));
  }

  void _inspectData() async {
    setState(() {
      _logs.clear();
      _logs.add("--- جاري البحث عن بيانات الشموع ---");
    });

    try {
      // سكريبت بيدور على أي كائن فيه بيانات شموع
      final result = await _controller.runJavaScriptReturningResult("""
        (function() {
          let found = [];
          // ندور على الكائنات العامة يلي ممكن تحتوي على بيانات
          if (window.chartData) found.push("window.chartData موجود");
          if (window.candles) found.push("window.candles موجود");
          if (window.ticks) found.push("window.ticks موجود");
          
          // إذا ما لقينا، ندور على أي عنصر فيه كلمة "chart" أو "candle"
          if (found.length === 0) {
             for (let key in window) {
                if (key.toLowerCase().includes('chart') || key.toLowerCase().includes('candle')) {
                    found.push("مفتاح محتمل: " + key);
                }
             }
          }
          
          return JSON.stringify(found);
        })();
      """);

      setState(() {
        _logs.add("النتيجة: $result");
      });

    } catch (e) {
      setState(() => _logs.add("❌ خطأ: $e"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فحص بيانات الشموع', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.tealAccent),
            onPressed: _inspectData,
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
