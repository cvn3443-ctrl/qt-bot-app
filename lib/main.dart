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

  void _extractLocalStorage() async {
    setState(() {
      _logs.clear();
      _logs.add("--- جاري فحص الذاكرة المخفية ---");
    });

    try {
      // سحب كل شي موجود في الـ localStorage
      final lsResult = await _controller.runJavaScriptReturningResult("JSON.stringify(localStorage)");
      _logs.add("المحتوى الكامل لـ localStorage:");
      _logs.add(lsResult.toString());

    } catch (e) {
      setState(() => _logs.add("❌ فشل: $e"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فحص الذاكرة (localStorage)', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.tealAccent),
            onPressed: _extractLocalStorage,
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
