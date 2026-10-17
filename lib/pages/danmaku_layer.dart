import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../api/models.dart';

/// 轻量弹幕渲染：滚动 8s，顶/底 4s，按轨道排布。
class DanmakuLayer extends StatefulWidget {
  const DanmakuLayer({super.key, required this.items, required this.position, required this.playing, this.rate = 1});
  final List<Danmaku> items;
  final Duration Function() position;
  final bool Function() playing;
  final double rate;

  @override
  State<DanmakuLayer> createState() => _DanmakuLayerState();
}

class _DanmakuLayerState extends State<DanmakuLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _t = ValueNotifier<double>(0);
  Duration _lastPos = Duration.zero;
  Duration _lastTick = Duration.zero;
  double _base = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final p = widget.position();
      if (p != _lastPos) {
        _lastPos = p;
        _lastTick = elapsed;
        _base = p.inMilliseconds / 1000;
      }
      final extra = widget.playing() ? (elapsed - _lastTick).inMilliseconds / 1000 * widget.rate : 0;
      _t.value = _base + extra.clamp(0, 1.0);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(painter: _Painter(widget.items, _t), size: Size.infinite),
        ),
      );
}

class _Painter extends CustomPainter {
  _Painter(this.items, this.t) : super(repaint: t);
  final List<Danmaku> items;
  final ValueNotifier<double> t;
  static final Map<String, TextPainter> _cache = {};
  static const lane = 30.0, scrollDur = 8.0, fixedDur = 4.0;

  TextPainter _tp(Danmaku d) {
    final key = '${d.color}|${d.text}';
    if (_cache.length > 800) _cache.clear();
    return _cache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: d.text,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF000000 | d.color),
            shadows: const [Shadow(blurRadius: 3, color: Colors.black87)],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    });
  }

  int _lower(double v) {
    var lo = 0, hi = items.length;
    while (lo < hi) {
      final m = (lo + hi) >> 1;
      if (items[m].t < v) {
        lo = m + 1;
      } else {
        hi = m;
      }
    }
    return lo;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;
    final now = t.value;
    final lanes = (size.height * .75 / lane).floor().clamp(1, 40);
    final start = _lower(now - scrollDur);
    final end = _lower(now + 0.001);
    final scrollEnd = List<double>.filled(lanes, -1e9); // 轨道可用时间
    var topLane = 0, bottomLane = 0;
    for (var i = start; i < end; i++) {
      final d = items[i];
      final age = now - d.t;
      final tp = _tp(d);
      if (d.mode == 1) {
        // 分配轨道：简单地按索引散列，避免状态维护
        var l = i % lanes;
        for (var k = 0; k < lanes; k++) {
          final c = (l + k) % lanes;
          if (scrollEnd[c] <= d.t) {
            l = c;
            break;
          }
        }
        final speed = (size.width + tp.width) / scrollDur;
        scrollEnd[l] = d.t + (tp.width + 24) / speed;
        final x = size.width - age * speed;
        tp.paint(canvas, Offset(x, 6 + l * lane));
      } else if (age <= fixedDur) {
        final x = (size.width - tp.width) / 2;
        if (d.mode == 5) {
          tp.paint(canvas, Offset(x, 6 + (topLane++ % lanes) * lane));
        } else {
          tp.paint(canvas, Offset(x, size.height - 40 - (bottomLane++ % lanes) * lane));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Painter old) => old.items != items;
}
