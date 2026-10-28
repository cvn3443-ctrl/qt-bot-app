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
      title: 'QTXSY Chart Reader',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const QuotexChartScreen(),
    );
  }
}

class QuotexChartScreen extends StatefulWidget {
  const QuotexChartScreen({super.key});

  @override
  State<QuotexChartScreen> createState() => _QuotexChartScreenState();
}

class _QuotexChartScreenState extends State<QuotexChartScreen> {
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

  void _readChartData() async {
    setState(() {
      _logs.clear();
      _logs.add("--- جاري قراءة بيانات الشموع ---");
    });

    try {
      // سكريبت يدور على أي مفتاح فيه "q_chart"، ويطبع اللي جواته
      final result = await _controller.runJavaScriptReturningResult("""
        (function() {
          let chartKeys = [];
          for (let key in window) {
            if (key.includes('q_chart')) {
              chartKeys.push(key);
            }
          }
          
          if (chartKeys.length === 0) return "لم يتم العثور على أي شارت.";

          let firstKey = chartKeys[0];
          let chartObj = window[firstKey];
          
          if (!chartObj) return "الشارت موجود ولكن فارغ.";

          // نحاول نلاقي مصفوفة الشموع جوا الكائن
          let dataKeys = Object.keys(chartObj);
          let output = "مفاتيح الشارت: " + dataKeys.join(", ") + "\\n";
          
          // غالباً الشموع تكون بمفتاح اسمه 'data' أو 'candles'
          if (chartObj.data) {
             output += "عدد الشموع: " + chartObj.data.length + "\\n";
             output += "آخر شمعة: " + JSON.stringify(chartObj.data[chartObj.data.length - 1]);
          } else if (chartObj.candles) {
             output += "عدد الشموع: " + chartObj.candles.length + "\\n";
             output += "آخر شمعة: " + JSON.stringify(chartObj.candles[chartObj.candles.length - 1]);
          } else {
             output += "لم نجد مصفوفة شموع مباشرة، سنطبع أول 500 حرف من الكائن:\\n";
             output += JSON.stringify(chartObj).substring(0, 500);
          }

          return output;
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
        title: const Text('قراءة الشموع', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.tealAccent),
            onPressed: _readChartData,
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
