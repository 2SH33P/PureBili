import 'package:flutter/material.dart';

import '../api/bili.dart';
import '../ui/glass.dart';
import '../ui/video_list.dart';

/// UP 主空间：仅投稿视频（按时间），无充电 / 商品橱窗等
class SpacePage extends StatelessWidget {
  const SpacePage({super.key, required this.mid, required this.name, this.embedded = false});
  final int mid;
  final String name;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = PagedVideoView(
      title: name.isEmpty ? 'UP 主' : name,
      loader: (c) => Bili.instance.spaceVideos(mid, c),
      emptyText: '还没有投稿',
    );
    return embedded ? body : GlassScaffold(child: body);
  }
}
