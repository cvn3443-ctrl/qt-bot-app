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
      title: 'QTXSY Inspector',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const QuotexInspectorScreen(),
    );
  }
}

class QuotexInspectorScreen extends StatefulWidget {
  const QuotexInspectorScreen({super.key});

  @override
  State<QuotexInspectorScreen> createState() => _QuotexInspectorScreenState();
}

class _QuotexInspectorScreenState extends State<QuotexInspectorScreen> {
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

  void _inspectButtons() async {
    setState(() {
      _logs.clear();
      _logs.add("--- جاري فحص أزرار الصفحة ---");
    });

    try {
      // تعديل: استبدلنا ${} بعلامات + عشان الـ Dart ما يدخل بالجافا سكربت
      final result = await _controller.runJavaScriptReturningResult("""
        (function() {
          let buttons = document.querySelectorAll('button, div[role="button"], a.button');
          let output = [];
          buttons.forEach(function(btn, index) {
            if (index < 20) {
              let text = btn.innerText.trim();
              let cls = btn.className;
              if (text !== "") {
                output.push("زر: " + text + " | كلاس: " + cls);
              }
            }
          });
          return JSON.stringify(output);
        })();
      """);

      setState(() {
        _logs.add(result.toString());
      });

    } catch (e) {
      setState(() => _logs.add("❌ فشل: $e"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فحص أزرار المنصة', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.tealAccent),
            onPressed: _inspectButtons,
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
