import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api/bili.dart';
import '../api/models.dart';
import '../core/prefs.dart';
import '../ui/glass.dart';
import '../ui/theme.dart';
import 'library_pages.dart';
import 'login.dart';
import 'space_page.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});
  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  void _push(Widget w) =>
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => GlassScaffold(child: w)));

  static const _qns = [(116, '1080P60'), (80, '1080P'), (64, '720P'), (32, '480P'), (16, '360P')];

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<UserInfo?>(
        valueListenable: Bili.instance.user,
        builder: (_, u, __) => ListView(
          padding: const EdgeInsets.only(bottom: kBottomInset),
          children: [
            const LargeTitle('我的'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Glass(
                radius: 28,
                padding: const EdgeInsets.all(18),
                child: u == null
                    ? Row(children: [
                        const Icon(CupertinoIcons.person_crop_circle, size: 56, color: kPink),
                        const SizedBox(width: 14),
                        const Expanded(child: Text('未登录', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
                        CapsuleButton(label: '扫码登录', onTap: () => showLogin(context)),
                      ])
                    : GestureDetector(
                        onTap: () => _push(SpacePage(mid: u.mid, name: u.name, embedded: true)),
                        child: Row(children: [
                          Avatar(u.face, size: 60),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(u.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('LV${u.level} · 硬币 ${u.coins}',
                                  style: TextStyle(color: secondaryLabel(context))),
                            ]),
                          ),
                          Icon(CupertinoIcons.chevron_right, color: secondaryLabel(context)),
                        ]),
                      ),
              ),
            ),
            if (u != null)
              GlassSection(header: '媒体库', children: [
                GlassTile(icon: CupertinoIcons.clock, title: '历史记录', onTap: () => _push(const HistoryPage())),
                GlassTile(
                    icon: CupertinoIcons.time,
                    iconColor: const Color(0xFFFF9500),
                    title: '稍后再看',
                    onTap: () => _push(const ToviewPage())),
                GlassTile(
                    icon: CupertinoIcons.star,
                    iconColor: const Color(0xFFFFCC00),
                    title: '我的收藏',
                    onTap: () => _push(const FavFoldersPage())),
              ]),
            GlassSection(header: '播放', children: [
              GlassTile(
                icon: CupertinoIcons.text_bubble,
                iconColor: const Color(0xFF34C759),
                title: '默认开启弹幕',
                trailing: CupertinoSwitch(
                  value: Prefs.instance.get('danmaku', true),
                  activeTrackColor: kPink,
                  onChanged: (v) async {
                    await Prefs.instance.set('danmaku', v);
                    setState(() {});
                  },
                ),
              ),
              GlassTile(
                icon: CupertinoIcons.tv,
                iconColor: const Color(0xFF5856D6),
                title: '默认画质',
                trailing: PopupMenuButton<int>(
                  initialValue: Prefs.instance.get('qn', 80),
                  onSelected: (v) async {
                    await Prefs.instance.set('qn', v);
                    setState(() {});
                  },
                  itemBuilder: (_) => [for (final q in _qns) PopupMenuItem(value: q.$1, child: Text(q.$2))],
                  child: Text(
                    _qns.firstWhere((q) => q.$1 == Prefs.instance.get('qn', 80), orElse: () => _qns[1]).$2,
                    style: TextStyle(color: secondaryLabel(context)),
                  ),
                ),
              ),
            ]),
            GlassSection(header: '关于', children: [
              const GlassTile(
                icon: CupertinoIcons.shield,
                iconColor: Color(0xFF8E8E93),
                title: 'PureBili',
                subtitle: '已剔除推荐、广告与一切购买入口。非官方客户端。',
              ),
              if (u != null)
                GlassTile(
                  icon: CupertinoIcons.square_arrow_right,
                  iconColor: const Color(0xFFFF3B30),
                  title: '退出登录',
                  onTap: () async {
                    final ok = await showCupertinoDialog<bool>(
                      context: context,
                      builder: (c) => CupertinoAlertDialog(
                        title: const Text('退出登录？'),
                        actions: [
                          CupertinoDialogAction(child: const Text('取消'), onPressed: () => Navigator.pop(c, false)),
                          CupertinoDialogAction(
                              isDestructiveAction: true,
                              child: const Text('退出'),
                              onPressed: () => Navigator.pop(c, true)),
                        ],
                      ),
                    );
                    if (ok == true) await Bili.instance.logout();
                  },
                ),
            ]),
          ],
        ),
      );
}
