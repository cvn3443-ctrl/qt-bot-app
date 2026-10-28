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
      title: 'QTXSY Deep Search',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const QuotexDeepScreen(),
    );
  }
}

class QuotexDeepScreen extends StatefulWidget {
  const QuotexDeepScreen({super.key});

  @override
  State<QuotexDeepScreen> createState() => _QuotexDeepScreenState();
}

class _QuotexDeepScreenState extends State<QuotexDeepScreen> {
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
            _logs.add("📥 ${message.message}");
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/demo-trade'));
  }

  void _deepSearch() async {
    setState(() {
      _logs.clear();
      _logs.add("--- جاري البحث العميق عن الشموع ---");
    });

    try {
      await _controller.runJavaScript("""
        (function() {
          // 1. البحث في الـ window عن أي كائن يحتوي على بيانات شموع
          let foundData = null;
          for (let key in window) {
            try {
                let obj = window[key];
                // إذا كان الكائن فيه خصائص شبيهة بالشموع
                if (obj && (obj.candles || obj.data || obj.history || obj.quotes)) {
                    let arr = obj.candles || obj.data || obj.history || obj.quotes;
                    if (Array.isArray(arr) && arr.length > 0) {
                        // نتأكد إنه العنصر الأول فيه خصائص open/high/low/close أو time
                        let sample = arr[0];
                        if (sample && (sample.open !== undefined || sample.time !== undefined || sample.close !== undefined)) {
                            foundData = arr;
                            break;
                        }
                    }
                }
            } catch(e) {}
          }

          if (foundData) {
              FlutterChannel.postMessage("✅ لقينا شموع! عددها: " + foundData.length + "\\nعينة: " + JSON.stringify(foundData[foundData.length - 1]));
          } else {
              // 2. إذا ما لقينا بالـ window، نبحث في مخزن البيانات IndexedDB
              let req = indexedDB.open('firebaseLocalStorageDb'); // اسم شائع
              req.onsuccess = function() {
                  FlutterChannel.postMessage("⚠️ ما لقينا شموع مباشرة. جربنا IndexedDB بس ما في نتيجة.");
              };
              req.onerror = function() {
                  FlutterChannel.postMessage("❌ ما لقينا شموع مباشرة، ولا في IndexedDB.");
              };
          }
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
        title: const Text('البحث العميق عن الشموع', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.tealAccent),
            onPressed: _deepSearch,
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
