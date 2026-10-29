import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'foreground_service.dart';
import 'notification_service.dart';

const List<String> otcPairs = [
  'CHFJPY_otc','USDCAD_otc','EURJPY_otc','AUDCAD_otc','EURAUD_otc','AUDUSD_otc',
  'GBPUSD_otc','EURUSD_otc','NZDUSD_otc','GBPJPY_otc',
];
const List<String> globalPairs = [
  'EURUSD','GBPUSD','USDJPY','AUDUSD','USDCAD','USDCHF','NZDUSD','EURGBP','EURJPY','GBPJPY',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ForegroundServiceController.initCommunication();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QTXSY Bot',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  late final WebViewController _webController;
  final List<String> _log = [];
  bool _botActive = false;
  bool _isDemo = true;
  double _stake = 1.0;
  bool _martingaleOn = false;
  Timer? _tradeTimer;
  Timer? _heartbeatTimer;
  Timer? _logCleanupTimer;
  final List<DateTime> _logTimes = [];

  @override
  void initState() {
    super.initState();
    _setupWebView();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  void _setupWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('CandlesChannel', onMessageReceived: (msg) {
        if (msg.message.startsWith('ping:')) {
          // _addLog('[Ping] ${msg.message}'); // نشيلها عشان ما تغرق السجل
        }
      })
      ..addJavaScriptChannel('ClickResultChannel', onMessageReceived: (msg) {
        _addLog('نتيجة ضغط: ${msg.message}');
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) => _webController.runJavaScript(_injectedScript),
      ))
      ..loadRequest(Uri.parse('https://quotex.com/ar/trade'));
  }

  static const String _injectedScript = r'''
(function() {
  if (window.__qtxsyPatched) return;
  window.__qtxsyPatched = true;

  const NativeWS = window.WebSocket;
  function PatchedWS(url, protocols) {
    const ws = protocols ? new NativeWS(url, protocols) : new NativeWS(url);
    ws.binaryType = 'arraybuffer';
    ws.addEventListener('message', function(event) {
      try {
        let text = (event.data instanceof ArrayBuffer)
          ? new TextDecoder('utf-8').decode(event.data)
          : event.data;
        if (window.CandlesChannel) window.CandlesChannel.postMessage(text);
      } catch (e) {}
    });
    return ws;
  }
  PatchedWS.prototype = NativeWS.prototype;
  window.WebSocket = PatchedWS;

  window.__qtxsyClick = function(texts) {
    const all = document.querySelectorAll('button, a, div[role="button"], div, span');
    for (const el of all) {
      const t = (el.textContent || '').trim();
      for (const want of texts) {
        if (t.includes(want)) { el.click(); return true; }
      }
    }
    return false;
  };

  // === دالة الكشف عن الحساب (بناءً على الرصيد) ===
  window.__qtxsyGetAccountMode = function() {
    // 1. نشوف إذا في قائمة مفتوحة (بتحتوي على "حساب حقيقي" و "حساب تجريبي")
    const allElements = document.querySelectorAll('div, span');
    let hasReal = false;
    let hasDemo = false;
    for (let i = 0; i < allElements.length; i++) {
      let text = (allElements[i].textContent || '').trim();
      if (text === 'حساب حقيقي' || text === 'Real') hasReal = true;
      if (text === 'حساب تجريبي' || text === 'Demo') hasDemo = true;
    }
    
    // 2. نقرأ الرصيد من أعلى الشاشة
    let balanceText = "";
    for (let i = 0; i < allElements.length; i++) {
      let text = (allElements[i].textContent || '').trim();
      // الرصيد عادة بكون فيه $ أو أرقام كبيرة
      if (text.includes('$') && text.length < 20) {
        balanceText = text;
        break;
      }
    }
    
    // 3. نحدد نوع الحساب
    // إذا القائمة مفتوحة، نشوف الرصيد
    if (hasReal && hasDemo) {
      // ديمو عادة رصيده عالي (9,000+)، حقيقي رصيده 0 أو قليل
      if (balanceText.includes('9,') || balanceText.includes('10,') || balanceText.includes('11,')) {
        return 'demo';
      } else {
        return 'real';
      }
    }
    
    // إذا القائمة مسكرة، نعتمد على الرصيد
    if (balanceText.includes('9,') || balanceText.includes('10,') || balanceText.includes('11,')) {
      return 'demo';
    }
    if (balanceText.includes('0.00') || balanceText === '' || balanceText === '$0.00') {
      return 'real';
    }
    
    return 'unknown';
  };

  // أداة تشخيص (للتأكد)
  window.__qtxsyDumpHeader = function() {
    const header = document.querySelector('header') || document.body;
    return header.outerHTML.substring(0, 2000);
  };

  // Ping (للتأكد إنه الجافاسكربت شغال)
  setInterval(function() {
    if (window.CandlesChannel) window.CandlesChannel.postMessage('ping:' + Date.now());
  }, 10000);
})();
''';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDemo = prefs.getBool('isDemo') ?? true;
      _stake = prefs.getDouble('stake') ?? 1.0;
      _martingaleOn = prefs.getBool('martingaleOn') ?? false;
    });

    final notifStatus = await FlutterForegroundTask.checkNotificationPermission();
    if (notifStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    await NotificationService.init();
    ForegroundServiceController.initOptions();
  }

  Future<bool> _confirmAccountModeMatches() async {
    final r = await _webController.runJavaScriptReturningResult('window.__qtxsyGetAccountMode()');
    final mode = r.toString().replaceAll('"', '');
    final expected = _isDemo ? 'demo' : 'real';
    if (mode != expected) {
      _addLog('⛔ إيقاف أمان: الحساب الحالي ($mode) ≠ المطلوب ($expected) — ما دخلنا الصفقة');
      return false;
    }
    _addLog('✅ الحساب مطابق ($mode)');
    return true;
  }

  void _startBot() async {
    await ForegroundServiceController.start();
    WakelockPlus.enable();

    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      NotificationService.showHeartbeat('عم يراقب ${otcPairs.length + globalPairs.length} زوج...');
    });
    _tradeTimer = Timer.periodic(const Duration(minutes: 1), (_) => _analyzeAndTrade());
    _logCleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) => _cleanOldLogs());

    setState(() => _botActive = true);
  }

  void _stopBot() async {
    _tradeTimer?.cancel();
    _heartbeatTimer?.cancel();
    _logCleanupTimer?.cancel();
    await ForegroundServiceController.stop();
    WakelockPlus.disable();
    setState(() => _botActive = false);
  }

  void _analyzeAndTrade() async {
    // 1. تأكيد الأمان
    if (!await _confirmAccountModeMatches()) return;
    
    // 2. الدوس العشوائي
    final allPairs = [...globalPairs, ...otcPairs];
    final pair = (allPairs..shuffle()).first;
    final direction = DateTime.now().second.isEven ? 'شراء' : 'بيع';
    final texts = direction == 'شراء' ? ['شراء', 'Buy', 'CALL'] : ['بيع', 'Sell', 'PUT'];
    
    _webController.runJavaScript('window.__qtxsyClick(${jsonEncode(texts)});');
    _addLog('[تجربة] $pair — $direction');
    NotificationService.showTradeAlert(pair, direction);
    FlutterForegroundTask.sendDataToTask(jsonEncode('آخر صفقة: $pair'));
  }

  void _addLog(String text) {
    setState(() {
      _log.insert(0, '${TimeOfDay.now().format(context)} — $text');
      _logTimes.insert(0, DateTime.now());
    });
  }

  void _cleanOldLogs() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    setState(() {
      while (_logTimes.isNotEmpty && _logTimes.last.isBefore(cutoff)) {
        _logTimes.removeLast();
        _log.removeLast();
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDemo', _isDemo);
    await prefs.setDouble('stake', _stake);
    await prefs.setBool('martingaleOn', _martingaleOn);
    
    _webController.runJavaScript(
      "window.__qtxsyClick(${jsonEncode(_isDemo ? ['حساب تجريبي','تجريبي','Demo'] : ['حساب حقيقي','حقيقي','Real'])});",
    );
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (ctx) {
        bool demo = _isDemo;
        double stake = _stake;
        bool mart = _martingaleOn;
        return StatefulBuilder(builder: (ctx, setD) {
          return AlertDialog(
            title: const Text('الإعدادات'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              SwitchListTile(
                title: Text(demo ? 'حساب: تجريبي (ديمو)' : 'حساب: حقيقي'),
                value: demo,
                onChanged: (v) => setD(() => demo = v),
              ),
              TextFormField(
                initialValue: stake.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'قيمة الصفقة (\$)'),
                onChanged: (v) => stake = double.tryParse(v) ?? stake,
              ),
              SwitchListTile(
                title: const Text('المضاعفة'),
                value: mart,
                onChanged: (v) => setD(() => mart = v),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () {
                  setState(() { _isDemo = demo; _stake = stake; _martingaleOn = mart; });
                  _saveSettings();
                  Navigator.pop(ctx);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _tradeTimer?.cancel();
    _heartbeatTimer?.cancel();
    _logCleanupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Expanded(child: _TabButton(label: 'المنصة', selected: _tab == 0, onTap: () => setState(() => _tab = 0))),
          const SizedBox(width: 8),
          Expanded(child: _TabButton(label: 'البوت', selected: _tab == 1, onTap: () => setState(() => _tab = 1))),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _webController.reload()),
          IconButton(icon: const Icon(Icons.settings), onPressed: _openSettings),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _webController)),
          
          if (_tab == 1)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.9),
                child: _BotScreen(
                  active: _botActive,
                  log: _log,
                  isDemo: _isDemo,
                  stake: _stake,
                  martingaleOn: _martingaleOn,
                  onStart: _startBot,
                  onStop: _stopBot,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      ),
      child: Text(label),
    );
  }
}

class _BotScreen extends StatelessWidget {
  final bool active;
  final List<String> log;
  final bool isDemo;
  final double stake;
  final bool martingaleOn;
  final VoidCallback onStart;
  final VoidCallback onStop;
  const _BotScreen({
    required this.active,
    required this.log,
    required this.isDemo,
    required this.stake,
    required this.martingaleOn,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        leading: Icon(active ? Icons.check_circle : Icons.hourglass_empty, color: active ? Colors.green : Colors.orange),
        title: Text(active ? 'البوت شغال' : 'البوت متوقف'),
        subtitle: Text('${isDemo ? "ديمو" : "حقيقي"} — \$${stake.toStringAsFixed(2)} — مضاعفة: ${martingaleOn ? "مفعّلة" : "مطفّية"}'),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: active ? Colors.redAccent : Colors.tealAccent,
              foregroundColor: Colors.black,
            ),
            icon: Icon(active ? Icons.stop : Icons.play_arrow),
            label: Text(active ? 'إيقاف البوت' : 'تنشيط البوت', style: const TextStyle(fontSize: 18)),
            onPressed: active ? onStop : onStart,
          ),
        ),
      ),
      const Divider(),
      Expanded(
        child: ListView.builder(
          itemCount: log.length,
          itemBuilder: (ctx, i) => ListTile(dense: true, title: Text(log[i])),
        ),
      ),
    ]);
  }
}
