import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../api/bili.dart';
import '../api/models.dart';
import '../core/prefs.dart';
import '../ui/glass.dart';
import '../ui/theme.dart';
import 'comments.dart';
import 'player_view.dart';
import 'space_page.dart';

/// 视频详情：播放器 + 信息 + 互动 + 分P + 评论。
/// 已移除：相关推荐、商品卡片、充电按钮、广告位。
class VideoPage extends StatefulWidget {
  const VideoPage({super.key, required this.bvid});
  final String bvid;
  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  VideoDetail? _d;
  Relation _rel = Relation();
  String? _error;
  int _cid = 0;
  bool _full = false;
  final _playerKey = GlobalKey<PlayerViewState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_full) _setFull(false);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await Bili.instance.view(widget.bvid);
      if (!mounted) return;
      setState(() {
        _d = d;
        _cid = d.cid;
      });
      if (Bili.instance.me != null) {
        final r = await Bili.instance.relation(widget.bvid);
        if (mounted) setState(() => _rel = r);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _setFull(bool v) async {
    if (isDesktop) {
      await windowManager.setFullScreen(v);
    } else {
      await SystemChrome.setEnabledSystemUIMode(v ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(
          v ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : []);
    }
  }

  void _toggleFull() {
    setState(() => _full = !_full);
    _setFull(_full);
  }

  bool _needLogin() {
    if (Bili.instance.me != null) return false;
    toast(context, '请先登录');
    return true;
  }

  Future<void> _act(Future<void> Function() f, String ok) async {
    if (_needLogin()) return;
    try {
      await f();
      if (mounted) toast(context, ok);
    } on BiliException catch (e) {
      final msg = switch (e.code) { -104 => '硬币不足', 34005 => '已达投币上限', _ => '$e' };
      if (mounted) toast(context, msg);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Widget _player() {
    final d = _d!;
    if (d.locked) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Text('该视频为付费/充电专属内容，PureBili 不提供购买入口',
            style: TextStyle(color: Colors.white70)),
      );
    }
    return PlayerView(
      key: _playerKey,
      detail: d,
      cid: _cid,
      fullscreen: _full,
      onFullscreen: _toggleFull,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_d == null) {
      return GlassScaffold(
        child: Column(children: [
          const LargeTitle(''),
          Expanded(child: _error != null ? ErrorView(_error!, onRetry: _load) : const Loading()),
        ]),
      );
    }
    final d = _d!;
    final player = _player();
    if (_full) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _toggleFull();
        },
        child: Scaffold(backgroundColor: Colors.black, body: player),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final playerBox = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(aspectRatio: 16 / 9, child: player),
      ),
    );
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(children: [
        GlassCircleButton(icon: CupertinoIcons.chevron_left, onTap: () => Navigator.of(context).maybePop()),
        const Spacer(),
        GlassCircleButton(
          icon: CupertinoIcons.link,
          onTap: () {
            Clipboard.setData(ClipboardData(text: 'https://www.bilibili.com/video/${d.bvid}'));
            toast(context, '已复制链接');
          },
        ),
      ]),
    );
    return GlassScaffold(
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(children: [header, playerBox, _info(d), const SizedBox(height: 40)]),
                ),
              ),
              SizedBox(
                width: 400,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 12, 0),
                  child: CommentsPanel(aid: d.aid),
                ),
              ),
            ])
          : Column(children: [
              header,
              playerBox,
              Expanded(
                child: ListView(padding: EdgeInsets.zero, children: [
                  _info(d),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: CommentsPanel(aid: d.aid, shrinkWrap: true),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ]),
    );
  }

  Widget _info(VideoDetail d) {
    final sub = secondaryLabel(context);
    final s = d.stat;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Glass(
          radius: 24,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => SpacePage(mid: d.ownerMid, name: d.ownerName))),
              child: Row(children: [
                Avatar(d.ownerFace, size: 40),
                const SizedBox(width: 10),
                Text(d.ownerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ]),
            ),
            const Spacer(),
            CapsuleButton(
              label: _rel.follow ? '已关注' : '关注',
              filled: !_rel.follow,
              onTap: () => _act(() async {
                await Bili.instance.follow(d.ownerMid, !_rel.follow);
                setState(() => _rel.follow = !_rel.follow);
              }, _rel.follow ? '已取消关注' : '关注成功'),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        SelectableText(d.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3)),
        const SizedBox(height: 6),
        Text('${fmtCount(s['view'])}播放 · ${fmtCount(s['danmaku'])}弹幕 · ${fmtTime(d.pubdate)} · ${d.bvid}',
            style: TextStyle(fontSize: 12, color: sub)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _ActionBtn(
            icon: _rel.like ? CupertinoIcons.hand_thumbsup_fill : CupertinoIcons.hand_thumbsup,
            on: _rel.like,
            label: fmtCount(s['like']),
            onTap: () => _act(() async {
              await Bili.instance.like(d.aid, !_rel.like);
              setState(() => _rel.like = !_rel.like);
            }, _rel.like ? '已取消点赞' : '点赞成功'),
            onLongPress: () => _act(() async {
              await Bili.instance.triple(d.aid);
              setState(() {
                _rel.like = true;
                _rel.fav = true;
                _rel.coin = 2;
              });
            }, '三连成功'),
          ),
          _ActionBtn(
            icon: CupertinoIcons.money_yen_circle,
            on: _rel.coin > 0,
            label: fmtCount(s['coin']),
            onTap: () => _coin(d),
          ),
          _ActionBtn(
            icon: _rel.fav ? CupertinoIcons.star_fill : CupertinoIcons.star,
            on: _rel.fav,
            label: fmtCount(s['favorite']),
            onTap: () => _fav(d),
          ),
          _ActionBtn(
            icon: CupertinoIcons.time,
            label: '稍后看',
            onTap: () => _act(() => Bili.instance.toviewAdd(d.aid), '已添加到稍后再看'),
          ),
        ]),
        Center(
          child: Text('长按点赞可一键三连', style: TextStyle(fontSize: 11, color: sub)),
        ),
        if (d.pages.length > 1) ...[
          const SizedBox(height: 14),
          Text('分P（${d.pages.length}）', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: d.pages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final p = d.pages[i];
                return CapsuleButton(
                  label: 'P${i + 1} ${p.part}',
                  filled: p.cid == _cid,
                  onTap: () => setState(() => _cid = p.cid),
                );
              },
            ),
          ),
        ],
        if (d.desc.isNotEmpty) ...[
          const SizedBox(height: 14),
          Glass(
            blur: 0,
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: SelectableText(d.desc, style: TextStyle(fontSize: 13, color: sub, height: 1.5)),
            ),
          ),
        ],
      ]),
    );
  }

  Future<void> _coin(VideoDetail d) async {
    if (_needLogin()) return;
    if (_rel.coin >= 2) return toast(context, '已达投币上限');
    final n = await showCupertinoModalPopup<int>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: Text('投币（剩余 ${Bili.instance.me?.coins ?? 0}）'),
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(c, 1), child: const Text('投 1 枚')),
          if (_rel.coin == 0)
            CupertinoActionSheetAction(onPressed: () => Navigator.pop(c, 2), child: const Text('投 2 枚')),
        ],
        cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true, onPressed: () => Navigator.pop(c), child: const Text('取消')),
      ),
    );
    if (n == null) return;
    await _act(() async {
      await Bili.instance.coin(d.aid, n);
      setState(() => _rel.coin += n);
      Bili.instance.refreshNav();
    }, '投币成功');
  }

  Future<void> _fav(VideoDetail d) async {
    if (_needLogin()) return;
    List<FavFolder> folders;
    try {
      folders = await Bili.instance.favFolders(aid: d.aid);
    } catch (e) {
      if (mounted) toast(context, '$e');
      return;
    }
    if (!mounted) return;
    final before = {for (final f in folders) f.id: f.fav};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: const EdgeInsets.all(10),
          child: Glass(
            radius: 30,
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('添加到收藏夹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final f in folders)
                    CheckboxListTile(
                      value: f.fav,
                      activeColor: kPink,
                      title: Text(f.title),
                      subtitle: Text('${f.count} 个内容'),
                      onChanged: (v) => set(() => f.fav = v ?? false),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              CapsuleButton(label: '完成', onTap: () => Navigator.pop(c, true)),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final add = [for (final f in folders) if (f.fav && before[f.id] != true) f.id];
    final del = [for (final f in folders) if (!f.fav && before[f.id] == true) f.id];
    if (add.isEmpty && del.isEmpty) return;
    await _act(() async {
      await Bili.instance.favDeal(d.aid, add, del);
      setState(() => _rel.fav = folders.any((f) => f.fav));
    }, '收藏已更新');
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.onTap, this.onLongPress, this.on = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool on;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(children: [
            AnimatedScale(
              scale: on ? 1.12 : 1,
              duration: iosDur,
              curve: Curves.elasticOut,
              child: Icon(icon, size: 28, color: on ? kPink : secondaryLabel(context)),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: secondaryLabel(context))),
          ]),
        ),
      );
}
