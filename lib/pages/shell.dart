import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../ui/glass.dart';
import '../ui/theme.dart';
import 'following_page.dart';
import 'me_page.dart';
import 'messages_page.dart';
import 'search_page.dart';

class _Tab {
  final String label;
  final IconData icon, active;
  const _Tab(this.label, this.icon, this.active);
}

const _tabs = [
  _Tab('关注', CupertinoIcons.person_2, CupertinoIcons.person_2_fill),
  _Tab('消息', CupertinoIcons.bell, CupertinoIcons.bell_fill),
  _Tab('我的', CupertinoIcons.person_crop_circle, CupertinoIcons.person_crop_circle_fill),
  _Tab('搜索', CupertinoIcons.search, CupertinoIcons.search),
];

/// 主框架：窄屏为悬浮玻璃 Tab Bar，宽屏（iPad / 桌面）为玻璃侧边栏。
/// 注意：没有“首页推荐 / 热门 / 排行 / 商城”入口。
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  final _navKeys = List.generate(_tabs.length, (_) => GlobalKey<NavigatorState>());

  Widget _page(int i) => switch (i) {
        0 => const FollowingPage(),
        1 => const MessagesPage(),
        2 => const MePage(),
        _ => const SearchPage(),
      };

  void _select(int i) {
    if (i == _index) {
      _navKeys[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _index = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final stack = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < _tabs.length; i++)
          Navigator(
            key: _navKeys[i],
            onGenerateRoute: (_) => CupertinoPageRoute(
              builder: (_) => GlassScaffold(child: _page(i)),
            ),
          ),
      ],
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = _navKeys[_index].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: AmbientBackground()),
          if (wide)
            Row(children: [
              SafeArea(
                right: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(width: 232, child: _Sidebar(index: _index, onSelect: _select)),
                ),
              ),
              Expanded(child: stack),
            ])
          else ...[
            Positioned.fill(child: stack),
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  Expanded(child: _TabBar(index: _index, onSelect: _select)),
                  const SizedBox(width: 10),
                  GlassCircleButton(
                    icon: CupertinoIcons.search,
                    size: 64,
                    color: _index == 3 ? kPink : null,
                    onTap: () => _select(3),
                  ),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Glass(
        radius: 32,
        padding: const EdgeInsets.all(6),
        child: Row(children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: iosDur,
                  curve: iosCurve,
                  height: 52,
                  decoration: BoxDecoration(
                    color: index == i ? fillColor(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(index == i ? _tabs[i].active : _tabs[i].icon,
                        size: 22, color: index == i ? kPink : null),
                    const SizedBox(height: 2),
                    Text(_tabs[i].label,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: index == i ? kPink : null)),
                  ]),
                ),
              ),
            ),
        ]),
      );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Glass(
        radius: 28,
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 14, 12, 18),
            child: Text('PureBili',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kPink, letterSpacing: -.5)),
          ),
          for (final i in [3, 0, 1, 2])
            GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: iosDur,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: index == i ? kPink.withValues(alpha: .14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(children: [
                  Icon(index == i ? _tabs[i].active : _tabs[i].icon,
                      size: 20, color: index == i ? kPink : null),
                  const SizedBox(width: 12),
                  Text(_tabs[i].label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: index == i ? FontWeight.w700 : FontWeight.w500,
                          color: index == i ? kPink : null)),
                ]),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('无推荐 · 无广告 · 无购买',
                style: TextStyle(fontSize: 11, color: secondaryLabel(context))),
          ),
        ]),
      );
}
