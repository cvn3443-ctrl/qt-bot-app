import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QTXSY Engine Test',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const EngineTestScreen(),
    );
  }
}

class EngineTestScreen extends StatefulWidget {
  const EngineTestScreen({super.key});

  @override
  State<EngineTestScreen> createState() => _EngineTestScreenState();
}

class _EngineTestScreenState extends State<EngineTestScreen> {
  WebSocketChannel? _channel;
  final List<String> _logs = [];
  
  // الإيميل والباسورد تبع حساب الديمو يلي بعته
  final String _email = "inspiring-brown-vjqhth@smail.pw";
  final String _password = "NOOR@#0000";

  void _connectAndLogin() {
    setState(() {
      _logs.clear();
      _logs.add("محاولة الاتصال...");
    });

    try {
      final uri = Uri.parse('wss://ws2.quotex.com/socket.io/?EIO=3&transport=websocket');
      _channel = WebSocketChannel.connect(uri);
      
      _channel!.stream.listen(
        (message) {
          setState(() {
            _logs.add("📥 استقبلنا: $message");
            
            // إذا استقبلنا "40" يعني متصلين، نبعت بيانات الدخول
            if (message.toString() == "40") {
               _logs.add("📤 إرسال بيانات الدخول...");
               // ملاحظة: صيغة الرسالة الفعلية تعتمد على تحليل حزم Quotex
               // هذا مجرد نموذج مبدئي للاختبار
               final payload = jsonEncode({"email": _email, "password": _password});
               _channel?.sink.add('42["auth",$payload]');
            }
            
            // إذا استقبلنا رد فيه توكن أو خطأ
            if (message.toString().contains("token") || message.toString().contains("error")) {
              _logs.add("🎯 الرد على تسجيل الدخول: $message");
            }
          });
        },
        onError: (error) {
          setState(() {
            _logs.add("❌ خطأ: $error");
          });
        },
        onDone: () {
          setState(() {
            _logs.add("🔌 انقطع الاتصال.");
          });
        },
      );
    } catch (e) {
      setState(() {
        _logs.add("❌ فشل: $e");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار محرك QTXSY', style: TextStyle(color: Colors.tealAccent)),
        backgroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: _connectAndLogin,
              child: const Text('اتصال ومحاولة تسجيل دخول'),
            ),
          ),
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
