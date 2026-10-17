import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api/bili.dart';
import '../api/models.dart';
import '../core/prefs.dart';
import '../ui/glass.dart';
import '../ui/theme.dart';
import '../ui/video_list.dart';

/// 搜索：无热搜、无搜索发现、无联想推荐，只有你自己的搜索历史。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctl = TextEditingController();
  String _kw = '';
  int _order = 0;

  void _submit(String s) {
    s = s.trim();
    if (s.isEmpty) return;
    final bv = bvPattern.firstMatch(s);
    if (bv != null) {
      openVideo(context, bv.group(0)!);
      return;
    }
    Prefs.instance.pushSearch(s);
    setState(() => _kw = s);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const LargeTitle('搜索'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Glass(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: CupertinoSearchTextField(
            controller: _ctl,
            placeholder: '搜索视频或粘贴 BV 号',
            backgroundColor: Colors.transparent,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            onSubmitted: _submit,
            onSuffixTap: () {
              _ctl.clear();
              setState(() => _kw = '');
            },
          ),
        ),
      ),
      if (_kw.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _order,
              children: const {
                0: Text('综合'),
                1: Text('播放'),
                2: Text('最新'),
                3: Text('弹幕'),
                4: Text('收藏'),
              },
              onValueChanged: (v) => setState(() => _order = v ?? 0),
            ),
          ),
        ),
      Expanded(
        child: _kw.isEmpty
            ? _history()
            : PagedVideoView(
                key: ValueKey('$_kw#$_order'),
                loader: (c) => Bili.instance.search(_kw, c, order: _order),
                emptyText: '没有找到相关视频',
              ),
      ),
    ]);
  }

  Widget _history() {
    final h = Prefs.instance.searchHistory;
    if (h.isEmpty) {
      return Center(
        child: Text('这里不会出现热搜和推荐', style: TextStyle(color: secondaryLabel(context))),
      );
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Text('搜索历史', style: TextStyle(color: secondaryLabel(context), fontSize: 13)),
        const Spacer(),
        TextButton(
          onPressed: () async {
            await Prefs.instance.set('searchHistory', <String>[]);
            setState(() {});
          },
          child: const Text('清空'),
        ),
      ]),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in h)
          GestureDetector(
            onTap: () {
              _ctl.text = s;
              _submit(s);
            },
            child: Glass(
              blur: 0,
              radius: 100,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(s),
            ),
          ),
      ]),
    ]);
  }
}
