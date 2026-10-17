import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api/bili.dart';
import '../api/models.dart';
import '../ui/glass.dart';
import '../ui/theme.dart';
import '../ui/video_list.dart';
import 'login.dart';

/// 消息中心：回复我的 / @我的 / 收到的赞（不包含系统推送与营销通知）
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  String _kind = 'reply';
  late Future<List<MsgItem>> _f;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _f = Bili.instance.messages(_kind);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<UserInfo?>(
        valueListenable: Bili.instance.user,
        builder: (_, u, __) {
          if (u == null) {
            return const Column(children: [
              LargeTitle('消息'),
              Expanded(child: LoginPrompt(text: '登录后查看回复、@ 和点赞')),
            ]);
          }
          return Column(children: [
            const LargeTitle('消息'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<String>(
                  groupValue: _kind,
                  children: const {'reply': Text('回复我的'), 'at': Text('@我的'), 'like': Text('收到的赞')},
                  onValueChanged: (v) => setState(() {
                    _kind = v ?? 'reply';
                    _reload();
                  }),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<MsgItem>>(
                future: _f,
                builder: (c, s) {
                  if (s.hasError) {
                    return ErrorView('${s.error}', onRetry: () => setState(_reload));
                  }
                  if (!s.hasData) return const Loading();
                  final list = s.data!;
                  if (list.isEmpty) {
                    return Center(child: Text('暂无消息', style: TextStyle(color: secondaryLabel(context))));
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(_reload);
                      await _f;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, kBottomInset),
                      itemCount: list.length,
                      itemBuilder: (c, i) => _MsgTile(list[i]),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      );
}

class _MsgTile extends StatelessWidget {
  const _MsgTile(this.m);
  final MsgItem m;

  @override
  Widget build(BuildContext context) {
    final bv = bvPattern.firstMatch(m.uri)?.group(0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: bv == null ? null : () => openVideo(context, bv),
        child: Glass(
          blur: 0,
          radius: 22,
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Avatar(m.avatar, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                      child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(fmtTime(m.time), style: TextStyle(fontSize: 12, color: secondaryLabel(context))),
                ]),
                const SizedBox(height: 4),
                Text(m.text),
                if (m.title.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(10)),
                    child: Text(m.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: secondaryLabel(context))),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
