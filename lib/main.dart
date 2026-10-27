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
      title: 'QTXSY Clicker Test',
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

  // دالة بتدور على زر الشراء أو البيع وتدوس عليه
  void _clickTradeButton(String textToClick) async {
    setState(() {
      _logs.clear();
      _logs.add("--- محاولة الضغط على زر: $textToClick ---");
    });

    try {
      // سكريبت بيدور على العناصر ويحاول يلاقي زر فيه النص المطلوب
      final result = await _controller.runJavaScriptReturningResult("""
        (function() {
          let found = false;
          // ندور على كل العناصر يلي ممكن تكون أزرار (div أو button)
          let elements = document.querySelectorAll('button, div[role="button"], div');
          for (let i = 0; i < elements.length; i++) {
            let el = elements[i];
            // إذا كان النص تبع العنصر هو نفسه النص المطلوب
            if (el.innerText && el.innerText.trim() === "$textToClick") {
              // نتأكد إنه العنصر ظاهر وقابل للضغط
              if (el.offsetParent !== null) {
                el.click(); // نضغط عليه
                found = true;
                break; // نوقف بعد أول زر نلاقيه
              }
            }
          }
          return found ? "✅ تم الضغط على '$textToClick' بنجاح!" : "❌ لم يتم العثور على زر '$textToClick'.";
        })();
      """);

      setState(() {
        _logs.add(result.toString());
      });

    } catch (e) {
      setState(() => _logs.add("❌ خطأ: $e"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار الضغط على الأزرار', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          // زر تجربة الشراء
          IconButton(
            icon: const Icon(Icons.arrow_upward, color: Colors.greenAccent),
            tooltip: 'تجربة زر الشراء',
            onPressed: () => _clickTradeButton('شراء'),
          ),
          // زر تجربة البيع
          IconButton(
            icon: const Icon(Icons.arrow_downward, color: Colors.redAccent),
            tooltip: 'تجربة زر البيع',
            onPressed: () => _clickTradeButton('بيع'),
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
