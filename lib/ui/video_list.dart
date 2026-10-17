import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/bili.dart';
import '../api/models.dart';
import '../pages/space_page.dart';
import '../pages/video_page.dart';
import 'glass.dart';
import 'theme.dart';

typedef VideoLoader = Future<(List<VideoCard>, Object?)> Function(Object? cursor);

void openVideo(BuildContext context, String bvid) {
  Navigator.of(context).push(CupertinoPageRoute(builder: (_) => VideoPage(bvid: bvid)));
}

class VideoCardView extends StatelessWidget {
  const VideoCardView(this.v, {super.key});
  final VideoCard v;

  Future<void> _menu(BuildContext context, Offset pos) async {
    final sel = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        const PopupMenuItem(value: 'later', child: Text('稍后再看')),
        const PopupMenuItem(value: 'copy', child: Text('复制链接')),
        if (v.authorMid > 0) PopupMenuItem(value: 'up', child: Text('查看 UP 主：${v.author}')),
      ],
    );
    if (!context.mounted || sel == null) return;
    switch (sel) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: 'https://www.bilibili.com/video/${v.bvid}'));
        if (context.mounted) toast(context, '已复制链接');
      case 'up':
        Navigator.of(context).push(CupertinoPageRoute(
            builder: (_) => SpacePage(mid: v.authorMid, name: v.author)));
      case 'later':
        try {
          final d = await Bili.instance.view(v.bvid);
          await Bili.instance.toviewAdd(d.aid);
          if (context.mounted) toast(context, '已添加到稍后再看');
        } catch (e) {
          if (context.mounted) toast(context, '$e');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openVideo(context, v.bvid),
      onSecondaryTapDown: (d) => _menu(context, d.globalPosition),
      onLongPressStart: (d) => _menu(context, d.globalPosition),
      child: Glass(
        blur: 0,
        radius: 22,
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14), // 同心圆角：22 - 8
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                NetImage(thumb(v.cover)),
                if (v.duration.isNotEmpty)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(100)),
                      child: Text(v.duration,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (v.progress >= 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: v.progress.clamp(0, 1).toDouble(),
                      minHeight: 3,
                      color: kPink,
                      backgroundColor: Colors.black26,
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3)),
                const Spacer(),
                Text(
                  [
                    if (v.author.isNotEmpty) v.author,
                    if (v.play.isNotEmpty && v.play != '-') '${v.play}播放',
                    if (v.sub.isNotEmpty) v.sub,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: secondaryLabel(context)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 通用分页视频网格（下拉刷新 + 触底加载）
class PagedVideoView extends StatefulWidget {
  const PagedVideoView({super.key, required this.loader, this.title, this.initialCursor, this.actions = const [], this.emptyText = '这里空空如也'});
  final VideoLoader loader;
  final String? title;
  final Object? initialCursor;
  final List<Widget> actions;
  final String emptyText;

  @override
  State<PagedVideoView> createState() => _PagedVideoViewState();
}

class _PagedVideoViewState extends State<PagedVideoView> {
  final List<VideoCard> _items = [];
  Object? _cursor;
  bool _end = false, _loading = false;
  String? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _cursor = widget.initialCursor;
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading && !refresh) return;
    if (!refresh && _end) return;
    final gen = refresh ? ++_gen : _gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (list, next) = await widget.loader(refresh ? widget.initialCursor : _cursor);
      if (!mounted || gen != _gen) return;
      setState(() {
        if (refresh) _items.clear();
        final seen = _items.map((e) => e.bvid).toSet();
        _items.addAll(list.where((e) => seen.add(e.bvid)));
        _cursor = next;
        _end = next == null;
      });
    } catch (e) {
      if (mounted && gen == _gen) setState(() => _error = e.toString());
    } finally {
      if (mounted && gen == _gen) setState(() => _loading = false);
    }
    // 过滤后数量太少时自动继续加载
    if (mounted && !_end && _error == null && _items.length < 12) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: kPink,
      onRefresh: () => _load(refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 600) _load();
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            if (widget.title != null)
              SliverToBoxAdapter(child: LargeTitle(widget.title!, actions: widget.actions)),
            if (_error != null && _items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(_error!, onRetry: () => _load(refresh: true)),
              )
            else if (_items.isEmpty && _end && !_loading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(widget.emptyText, style: TextStyle(color: secondaryLabel(context)))),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (c, i) => VideoCardView(_items[i]),
                    childCount: _items.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: _loading
                      ? const CupertinoActivityIndicator()
                      : (_error != null && _items.isNotEmpty)
                          ? TextButton(onPressed: _load, child: Text('加载失败，点击重试：$_error'))
                          : (_end && _items.isNotEmpty)
                              ? Text('没有更多了', style: TextStyle(color: secondaryLabel(context), fontSize: 12))
                              : const SizedBox(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: kBottomInset)),
          ],
        ),
      ),
    );
  }
}
