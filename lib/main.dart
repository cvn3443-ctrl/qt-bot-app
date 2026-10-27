import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QTXSY Test',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const SocketTestScreen(),
    );
  }
}

class SocketTestScreen extends StatefulWidget {
  const SocketTestScreen({super.key});

  @override
  State<SocketTestScreen> createState() => _SocketTestScreenState();
}

class _SocketTestScreenState extends State<SocketTestScreen> {
  WebSocketChannel? _channel;
  final List<String> _logs = [];
  String _status = "غير متصل";

  void _connect() {
    setState(() {
      _logs.clear();
      _status = "جاري الاتصال...";
      _logs.add("محاولة الاتصال بـ wss://ws2.quotex.com...");
    });

    try {
      // الرابط يلي طلع من ترمكس
      final uri = Uri.parse('wss://ws2.quotex.com/socket.io/?EIO=3&transport=websocket');
      
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (message) {
          setState(() {
            _status = "متصل ويستقبل بيانات";
            _logs.add("📥 استقبلنا: $message");
          });
        },
        onError: (error) {
          setState(() {
            _status = "خطأ في الاتصال";
            _logs.add("❌ خطأ: $error");
          });
        },
        onDone: () {
          setState(() {
            _status = "انقطع الاتصال";
            _logs.add("🔌 تم إغلاق الاتصال.");
          });
        },
      );

      // إرسال رسالة ترحيب (أول رسالة بـ socket.io)
      _channel!.sink.add("40");
      _logs.add("📤 أرسلنا: 40");

    } catch (e) {
      setState(() {
        _status = "فشل الاتصال";
        _logs.add("❌ فشل: $e");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تجربة اتصال Quotex', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'الحالة: $_status',
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: _connect,
            child: const Text('بدء الاتصال التجريبي'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    _logs[index],
                    style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
