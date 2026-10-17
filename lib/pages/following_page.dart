import 'package:flutter/material.dart';

import '../api/bili.dart';
import '../api/models.dart';
import '../ui/video_list.dart';
import 'login.dart';

/// 首页 = 关注的 UP 主视频更新（按时间倒序，无任何算法推荐）
class FollowingPage extends StatelessWidget {
  const FollowingPage({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<UserInfo?>(
        valueListenable: Bili.instance.user,
        builder: (_, u, __) => u == null
            ? Column(children: const [
                SizedBox(height: 16),
                Expanded(child: LoginPrompt()),
              ])
            : PagedVideoView(
                key: ValueKey(u.mid),
                title: '关注',
                loader: Bili.instance.followingFeed,
                emptyText: '关注的 UP 主还没有更新',
              ),
      );
}
