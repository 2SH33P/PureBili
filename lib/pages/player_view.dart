import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../api/bili.dart';
import '../api/models.dart';
import '../core/prefs.dart';
import '../ui/glass.dart';
import '../ui/theme.dart';
import 'danmaku_layer.dart';

/// 播放器：media_kit(libmpv) + DASH 音视频分离流 + 玻璃控制条 + 弹幕层
class PlayerView extends StatefulWidget {
  const PlayerView({super.key, required this.detail, required this.cid, required this.onFullscreen, this.fullscreen = false});
  final VideoDetail detail;
  final int cid;
  final bool fullscreen;
  final VoidCallback onFullscreen;

  @override
  State<PlayerView> createState() => PlayerViewState();
}

class PlayerViewState extends State<PlayerView> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  final _focus = FocusNode();

  PlayInfo? _info;
  String? _error;
  List<Danmaku> _dm = const [];
  bool _dmOn = Prefs.instance.get('danmaku', true);
  bool _controls = true;
  double _rate = 1;
  Timer? _hide, _hb;
  final _subs = <StreamSubscription>[];
  bool _playing = false;
  Duration _pos = Duration.zero, _dur = Duration.zero;
  double? _drag;

  @override
  void initState() {
    super.initState();
    _subs.addAll([
      player.stream.playing.listen((v) => setState(() => _playing = v)),
      player.stream.position.listen((v) => setState(() => _pos = v)),
      player.stream.duration.listen((v) => setState(() => _dur = v)),
    ]);
    _hb = Timer.periodic(const Duration(seconds: 15), (_) => _heartbeat());
    _load(Prefs.instance.get('qn', 80));
    _bumpControls();
  }

  @override
  void didUpdateWidget(PlayerView old) {
    super.didUpdateWidget(old);
    if (old.cid != widget.cid) _load(_info?.qn ?? Prefs.instance.get('qn', 80));
  }

  @override
  void dispose() {
    _heartbeat();
    for (final s in _subs) {
      s.cancel();
    }
    _hide?.cancel();
    _hb?.cancel();
    player.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _heartbeat() {
    if (Bili.instance.me == null || _pos == Duration.zero) return;
    Bili.instance
        .heartbeat(widget.detail.aid, widget.detail.bvid, widget.cid, _pos.inSeconds)
        .catchError((_) {});
  }

  Future<void> _load(int qn, {Duration? resume}) async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      final info = await Bili.instance.playUrl(widget.detail.bvid, widget.cid, qn: qn);
      if (!mounted) return;
      final native = player.platform;
      if (native is NativePlayer) {
        await native.setProperty('http-header-fields', 'Referer: $kReferer,User-Agent: $kUA');
      }
      final durationReady = player.stream.duration.firstWhere((d) => d > Duration.zero);
      await player.open(Media(info.video, httpHeaders: const {'Referer': kReferer, 'User-Agent': kUA}));
      if (info.audio != null && native is NativePlayer) {
        await durationReady.timeout(const Duration(seconds: 15), onTimeout: () => Duration.zero);
        await native.command(['audio-add', info.audio!, 'select']);
      }
      if (resume != null && resume > Duration.zero) await player.seek(resume);
      await player.setRate(_rate);
      setState(() => _info = info);
      Bili.instance.danmaku(widget.cid).then((d) {
        if (mounted) setState(() => _dm = d);
      }).catchError((_) {});
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _bumpControls() {
    _hide?.cancel();
    if (!_controls) setState(() => _controls = true);
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && _playing) setState(() => _controls = false);
    });
  }

  void _seekBy(int s) {
    var t = _pos + Duration(seconds: s);
    if (t < Duration.zero) t = Duration.zero;
    if (_dur > Duration.zero && t > _dur) t = _dur;
    player.seek(t);
    _bumpControls();
  }

  KeyEventResult _onKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space) {
      player.playOrPause();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _seekBy(-5);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _seekBy(5);
    } else if (k == LogicalKeyboardKey.keyF) {
      widget.onFullscreen();
    } else if (k == LogicalKeyboardKey.keyD) {
      setState(() => _dmOn = !_dmOn);
    } else if (k == LogicalKeyboardKey.escape && widget.fullscreen) {
      widget.onFullscreen();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        onHover: (_) => _bumpControls(),
        child: GestureDetector(
          onTap: () {
            _focus.requestFocus();
            if (_controls) {
              setState(() => _controls = false);
            } else {
              _bumpControls();
            }
          },
          onDoubleTap: player.playOrPause,
          child: Container(
            color: Colors.black,
            child: Stack(fit: StackFit.expand, children: [
              Video(controller: controller, controls: NoVideoControls, fill: Colors.black),
              if (_dmOn && _dm.isNotEmpty)
                DanmakuLayer(items: _dm, position: () => _pos, playing: () => _playing, rate: _rate),
              if (_error != null)
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    CapsuleButton(label: '重试', onTap: () => _load(Prefs.instance.get('qn', 80))),
                  ]),
                )
              else if (_info == null)
                const Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 14)),
              AnimatedOpacity(
                opacity: _controls ? 1 : 0,
                duration: iosDur,
                child: IgnorePointer(ignoring: !_controls, child: _controlsBar()),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _controlsBar() {
    final total = _dur.inMilliseconds.toDouble();
    final cur = (_drag ?? _pos.inMilliseconds.toDouble()).clamp(0, total <= 0 ? 1 : total).toDouble();
    const white = TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Glass(
          radius: 24,
          clear: true,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Theme(
            data: Theme.of(context).copyWith(iconTheme: const IconThemeData(color: Colors.white)),
            child: Row(children: [
              IconButton(
                icon: Icon(_playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill),
                onPressed: player.playOrPause,
              ),
              Text(fmtDur(Duration(milliseconds: cur.toInt()).inSeconds), style: white),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: kPink,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Slider(
                      value: cur,
                      max: total <= 0 ? 1 : total,
                      onChanged: (v) {
                        _bumpControls();
                        setState(() => _drag = v);
                      },
                      onChangeEnd: (v) {
                        player.seek(Duration(milliseconds: v.toInt()));
                        setState(() => _drag = null);
                      },
                    ),
                  ),
                ),
              ),
              Text(fmtDur(_dur.inSeconds), style: white),
              if (_info != null && _info!.qualities.isNotEmpty)
                PopupMenuButton<int>(
                  tooltip: '画质',
                  onSelected: (q) {
                    Prefs.instance.set('qn', q);
                    _load(q, resume: _pos);
                  },
                  itemBuilder: (_) => [
                    for (final q in _info!.qualities)
                      CheckedPopupMenuItem(value: q.$1, checked: q.$1 == _info!.qn, child: Text(q.$2)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(_info!.qnLabel, style: white),
                  ),
                ),
              PopupMenuButton<double>(
                tooltip: '倍速',
                onSelected: (r) {
                  setState(() => _rate = r);
                  player.setRate(r);
                },
                itemBuilder: (_) => [
                  for (final r in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                    CheckedPopupMenuItem(value: r, checked: r == _rate, child: Text('${r}x')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(_rate == 1 ? '倍速' : '${_rate}x', style: white),
                ),
              ),
              IconButton(
                tooltip: '弹幕 (D)',
                icon: Icon(_dmOn ? CupertinoIcons.text_bubble_fill : CupertinoIcons.text_bubble),
                onPressed: () => setState(() => _dmOn = !_dmOn),
              ),
              IconButton(
                tooltip: '全屏 (F)',
                icon: Icon(widget.fullscreen
                    ? CupertinoIcons.fullscreen_exit
                    : CupertinoIcons.fullscreen),
                onPressed: widget.onFullscreen,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
