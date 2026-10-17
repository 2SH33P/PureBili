import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api/bili.dart';
import '../api/models.dart';
import '../ui/glass.dart';
import '../ui/theme.dart';

/// 评论区（作为 Sliver 列表使用，或单独嵌入侧栏）
class CommentsPanel extends StatefulWidget {
  const CommentsPanel({super.key, required this.aid, this.shrinkWrap = false});
  final int aid;
  final bool shrinkWrap;

  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel> {
  final List<Reply> _items = [];
  String? _next = '';
  bool _hot = true, _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && _next == null)) return;
    if (reset) {
      _items.clear();
      _next = '';
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (list, next) = await Bili.instance.replies(widget.aid, offset: _next ?? '', hot: _hot);
      if (!mounted) return;
      setState(() {
        _items.addAll(list);
        _next = next;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _compose({Reply? to}) async {
    if (Bili.instance.me == null) return toast(context, '请先登录');
    final text = await showReplyInput(context, hint: to == null ? '发一条友善的评论' : '回复 @${to.uname}');
    if (text == null || text.trim().isEmpty) return;
    try {
      final r = await Bili.instance.addReply(widget.aid, text.trim(),
          root: to == null ? 0 : (to.root == 0 ? to.rpid : to.root), parent: to?.rpid ?? 0);
      if (!mounted) return;
      toast(context, '发送成功');
      if (to == null && r != null) setState(() => _items.insert(0, r));
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Row(children: [
          const Text('评论', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const Spacer(),
          CupertinoSlidingSegmentedControl<bool>(
            groupValue: _hot,
            children: const {true: Text('热门'), false: Text('最新')},
            onValueChanged: (v) {
              _hot = v ?? true;
              _load(reset: true);
            },
          ),
          const SizedBox(width: 8),
          GlassCircleButton(icon: CupertinoIcons.pencil, size: 36, onTap: _compose),
        ]),
      ),
      for (final r in _items) ReplyTile(r, aid: widget.aid, onReply: (x) => _compose(to: x)),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: _loading
              ? const CupertinoActivityIndicator()
              : _error != null
                  ? TextButton(onPressed: _load, child: Text('加载失败：$_error'))
                  : _next == null
                      ? Text(_items.isEmpty ? '还没有评论' : '没有更多评论了',
                          style: TextStyle(color: secondaryLabel(context), fontSize: 12))
                      : TextButton(onPressed: _load, child: const Text('加载更多')),
        ),
      ),
    ];
    if (widget.shrinkWrap) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _load();
        return false;
      },
      child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 40), children: children),
    );
  }
}

class ReplyTile extends StatefulWidget {
  const ReplyTile(this.r, {super.key, required this.aid, required this.onReply, this.showSub = true});
  final Reply r;
  final int aid;
  final bool showSub;
  final ValueChanged<Reply> onReply;

  @override
  State<ReplyTile> createState() => _ReplyTileState();
}

class _ReplyTileState extends State<ReplyTile> {
  late int _likes = widget.r.like;
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final sub = secondaryLabel(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Glass(
        blur: 0,
        radius: 20,
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(r.avatar, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(r.uname, style: TextStyle(fontSize: 13, color: sub, fontWeight: FontWeight.w600))),
                const SizedBox(width: 4),
                Text('LV${r.level}', style: const TextStyle(fontSize: 10, color: kPink)),
                if (r.pinned) ...[
                  const SizedBox(width: 6),
                  const Text('置顶', style: TextStyle(fontSize: 11, color: kPink, fontWeight: FontWeight.w700)),
                ],
              ]),
              const SizedBox(height: 4),
              SelectableText(r.message, style: const TextStyle(fontSize: 15, height: 1.4)),
              const SizedBox(height: 6),
              Row(children: [
                Text(fmtTime(r.ctime), style: TextStyle(fontSize: 12, color: sub)),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    try {
                      await Bili.instance.likeReply(widget.aid, r.rpid, !_liked);
                      setState(() {
                        _liked = !_liked;
                        _likes += _liked ? 1 : -1;
                      });
                    } catch (e) {
                      if (context.mounted) toast(context, '$e');
                    }
                  },
                  child: Row(children: [
                    Icon(_liked ? CupertinoIcons.hand_thumbsup_fill : CupertinoIcons.hand_thumbsup,
                        size: 15, color: _liked ? kPink : sub),
                    const SizedBox(width: 3),
                    Text(fmtCount(_likes), style: TextStyle(fontSize: 12, color: sub)),
                  ]),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: () => widget.onReply(r),
                  child: Icon(CupertinoIcons.chat_bubble, size: 15, color: sub),
                ),
              ]),
              if (widget.showSub && r.rcount > 0)
                GestureDetector(
                  onTap: () => showSubReplies(context, widget.aid, r, widget.onReply),
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final s in r.preview.take(2))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('${s.uname}：${s.message}',
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                        ),
                      Text('共 ${r.rcount} 条回复 ›', style: const TextStyle(fontSize: 13, color: kPink)),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<void> showSubReplies(BuildContext context, int aid, Reply root, ValueChanged<Reply> onReply) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (c) => FractionallySizedBox(
      heightFactor: .85,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Glass(radius: 34, child: _SubList(aid: aid, root: root, onReply: onReply)),
      ),
    ),
  );
}

class _SubList extends StatefulWidget {
  const _SubList({required this.aid, required this.root, required this.onReply});
  final int aid;
  final Reply root;
  final ValueChanged<Reply> onReply;
  @override
  State<_SubList> createState() => _SubListState();
}

class _SubListState extends State<_SubList> {
  final _items = <Reply>[];
  int? _pn = 1;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || _pn == null) return;
    setState(() => _loading = true);
    try {
      final (list, next) = await Bili.instance.subReplies(widget.aid, widget.root.rpid, _pn!);
      if (mounted) {
        setState(() {
          _items.addAll(list);
          _pn = next;
        });
      }
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(children: [
            Text('${widget.root.rcount} 条回复', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            GlassCircleButton(icon: CupertinoIcons.xmark, size: 34, onTap: () => Navigator.pop(context)),
          ]),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _load();
              return false;
            },
            child: ListView(padding: const EdgeInsets.all(12), children: [
              ReplyTile(widget.root, aid: widget.aid, onReply: widget.onReply, showSub: false),
              const Divider(),
              for (final r in _items) ReplyTile(r, aid: widget.aid, onReply: widget.onReply, showSub: false),
              if (_loading) const Padding(padding: EdgeInsets.all(12), child: CupertinoActivityIndicator()),
            ]),
          ),
        ),
      ]);
}

Future<String?> showReplyInput(BuildContext context, {required String hint}) {
  final ctl = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Glass(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(children: [
            Expanded(
              child: CupertinoTextField(
                controller: ctl,
                autofocus: true,
                placeholder: hint,
                minLines: 1,
                maxLines: 5,
                decoration: null,
                style: TextStyle(color: Theme.of(c).colorScheme.onSurface),
              ),
            ),
            CapsuleButton(label: '发送', onTap: () => Navigator.pop(c, ctl.text)),
          ]),
        ),
      ),
    ),
  );
}
