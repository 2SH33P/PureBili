import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api/bili.dart';
import '../api/models.dart';
import '../ui/glass.dart';
import '../ui/theme.dart';
import '../ui/video_list.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) =>
      PagedVideoView(title: '历史记录', loader: Bili.instance.history);
}

class ToviewPage extends StatelessWidget {
  const ToviewPage({super.key});
  @override
  Widget build(BuildContext context) =>
      PagedVideoView(title: '稍后再看', loader: Bili.instance.toview);
}

class FavFoldersPage extends StatefulWidget {
  const FavFoldersPage({super.key});
  @override
  State<FavFoldersPage> createState() => _FavFoldersPageState();
}

class _FavFoldersPageState extends State<FavFoldersPage> {
  late Future<List<FavFolder>> _f = Bili.instance.favFolders();

  @override
  Widget build(BuildContext context) => Column(children: [
        const LargeTitle('我的收藏'),
        Expanded(
          child: FutureBuilder<List<FavFolder>>(
            future: _f,
            builder: (c, s) {
              if (s.hasError) {
                return ErrorView('${s.error}',
                    onRetry: () => setState(() => _f = Bili.instance.favFolders()));
              }
              if (!s.hasData) return const Loading();
              return ListView(padding: const EdgeInsets.only(bottom: kBottomInset), children: [
                GlassSection(children: [
                  for (final f in s.data!)
                    GlassTile(
                      icon: CupertinoIcons.folder_fill,
                      iconColor: const Color(0xFFFFCC00),
                      title: f.title,
                      subtitle: '${f.count} 个内容',
                      onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                          builder: (_) => GlassScaffold(
                                child: PagedVideoView(
                                  title: f.title,
                                  loader: (cur) => Bili.instance.favResources(f.id, cur),
                                ),
                              ))),
                    ),
                ]),
              ]);
            },
          ),
        ),
      ]);
}
