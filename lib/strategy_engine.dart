class Candle {
  final DateTime time;
  final double open, high, low, close;
  Candle(this.time, this.open, this.high, this.low, this.close);
}

class StrategySignal {
  final String direction; // 'up' أو 'down'
  final double strength;  // 0..1
  final String name;
  StrategySignal(this.direction, this.strength, this.name);
}

List<int> _swingHighs(List<Candle> c, {int window = 3}) {
  final idx = <int>[];
  for (int i = window; i < c.length - window; i++) {
    bool isHigh = true;
    for (int j = i - window; j <= i + window; j++) {
      if (j != i && c[j].high >= c[i].high) { isHigh = false; break; }
    }
    if (isHigh) idx.add(i);
  }
  return idx;
}

List<int> _swingLows(List<Candle> c, {int window = 3}) {
  final idx = <int>[];
  for (int i = window; i < c.length - window; i++) {
    bool isLow = true;
    for (int j = i - window; j <= i + window; j++) {
      if (j != i && c[j].low <= c[i].low) { isLow = false; break; }
    }
    if (isLow) idx.add(i);
  }
  return idx;
}

StrategySignal? breakoutRetest(List<Candle> c) {
  if (c.length < 30) return null;
  final highs = _swingHighs(c.sublist(0, c.length - 5));
  final lows = _swingLows(c.sublist(0, c.length - 5));
  final last = c.last;
  final recent = c.sublist(c.length - 10);
  if (highs.isNotEmpty) {
    final level = c[highs.last].high;
    final broke = recent.any((k) => k.close > level);
    final retest = (last.low - level).abs() / level < 0.0015 && last.close > level;
    if (broke && retest) return StrategySignal('up', 0.7, 'breakout_retest');
  }
  if (lows.isNotEmpty) {
    final level = c[lows.last].low;
    final broke = recent.any((k) => k.close < level);
    final retest = (last.high - level).abs() / level < 0.0015 && last.close < level;
    if (broke && retest) return StrategySignal('down', 0.7, 'breakout_retest');
  }
  return null;
}

StrategySignal? supportResistance(List<Candle> c) {
  if (c.length < 30) return null;
  final highs = _swingHighs(c);
  final lows = _swingLows(c);
  final last = c.last;
  const tol = 0.0012;
  double touches(List<int> idxs, double level, bool isHigh) {
    int t = 0;
    for (final i in idxs) {
      final v = isHigh ? c[i].high : c[i].low;
      if ((v - level).abs() / level < tol) t++;
    }
    return t.toDouble();
  }
  if (highs.isNotEmpty) {
    final level = c[highs.last].high;
    final near = (last.high - level).abs() / level < tol;
    final rejecting = last.close < last.open && last.high >= level;
    if (near && rejecting && touches(highs, level, true) >= 2) {
      return StrategySignal('down', 0.6, 'support_resistance');
    }
  }
  if (lows.isNotEmpty) {
    final level = c[lows.last].low;
    final near = (last.low - level).abs() / level < tol;
    final rejecting = last.close > last.open && last.low <= level;
    if (near && rejecting && touches(lows, level, false) >= 2) {
      return StrategySignal('up', 0.6, 'support_resistance');
    }
  }
  return null;
}

StrategySignal? pinBarSniper(List<Candle> c) {
  if (c.length < 5) return null;
  final k = c.last;
  final range = k.high - k.low;
  if (range <= 0) return null;
  final body = (k.close - k.open).abs();
  final upperWick = k.high - (k.close > k.open ? k.close : k.open);
  final lowerWick = (k.close < k.open ? k.close : k.open) - k.low;
  final smallBody = body / range < 0.35;
  if (smallBody && lowerWick / range > 0.55) return StrategySignal('up', 0.65, 'pin_bar');
  if (smallBody && upperWick / range > 0.55) return StrategySignal('down', 0.65, 'pin_bar');
  return null;
}

StrategySignal? combineForPair(List<Candle> candles) {
  final sigs = [breakoutRetest(candles), supportResistance(candles), pinBarSniper(candles)]
      .whereType<StrategySignal>().toList();
  if (sigs.isEmpty) return null;
  final up = sigs.where((s) => s.direction == 'up').toList();
  final down = sigs.where((s) => s.direction == 'down').toList();
  final agreeing = up.length >= down.length ? up : down;
  if (agreeing.length < 2) return null;
  final avg = agreeing.map((s) => s.strength).reduce((a, b) => a + b) / agreeing.length;
  return StrategySignal(agreeing.first.direction, avg * (agreeing.length / 3),
      agreeing.map((s) => s.name).join('+'));
}

class PairChoice {
  final String pair;
  final StrategySignal signal;
  PairChoice(this.pair, this.signal);
}

PairChoice? pickBestPair(Map<String, List<Candle>> allPairsCandles) {
  PairChoice? best;
  allPairsCandles.forEach((pair, candles) {
    final sig = combineForPair(candles);
    if (sig != null && (best == null || sig.strength > best!.signal.strength)) {
      best = PairChoice(pair, sig);
    }
  });
  return best;
}
