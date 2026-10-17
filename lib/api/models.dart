import 'purify.dart';

String fixUrl(dynamic u) {
  final s = (u ?? '').toString();
  if (s.isEmpty) return '';
  if (s.startsWith('//')) return 'https:$s';
  if (s.startsWith('http://')) return s.replaceFirst('http://', 'https://');
  return s;
}

/// hdslb 图片缩略图
String thumb(String url, {int w = 480, int h = 270}) {
  if (url.isEmpty || !url.contains('hdslb.com') || url.contains('@')) return url;
  return '$url@${w}w_${h}h_1c.webp';
}

String unescapeHtml(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

String stripHtml(String s) => unescapeHtml(s.replaceAll(RegExp(r'<[^>]*>'), ''));

int asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);
String asStr(dynamic v) => v == null ? '' : v.toString();

String fmtCount(dynamic n) {
  if (n is String) return n;
  if (n is! num) return '-';
  if (n >= 100000000) return '${(n / 100000000).toStringAsFixed(1)}亿';
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
  return n.toInt().toString();
}

String _two(int v) => v.toString().padLeft(2, '0');

String fmtDur(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
}

String fmtTime(int ts) {
  if (ts <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  return d.year == now.year
      ? '${_two(d.month)}-${_two(d.day)}'
      : '${d.year}-${_two(d.month)}-${_two(d.day)}';
}

final bvPattern = RegExp(r'BV[0-9A-Za-z]{10}');

class UserInfo {
  final int mid;
  final String name;
  final String face;
  final int level;
  final num coins;
  const UserInfo(
      {required this.mid,
      required this.name,
      required this.face,
      this.level = 0,
      this.coins = 0});

  factory UserInfo.fromNav(Map d) => UserInfo(
        mid: asInt(d['mid']),
        name: asStr(d['uname']),
        face: fixUrl(d['face']),
        level: asInt(d['level_info']?['current_level']),
        coins: d['money'] is num ? d['money'] as num : 0,
      );
}

class VideoCard {
  final String bvid, title, cover, author, duration, play, sub;
  final int authorMid;
  final double progress; // 0..1，<0 表示无进度
  const VideoCard({
    required this.bvid,
    required this.title,
    required this.cover,
    this.author = '',
    this.authorMid = 0,
    this.duration = '',
    this.play = '',
    this.sub = '',
    this.progress = -1,
  });
}

class VideoPart {
  final int cid;
  final String part;
  final int duration;
  const VideoPart(this.cid, this.part, this.duration);
}

class VideoDetail {
  final int aid, cid, ownerMid, pubdate;
  final String bvid, title, cover, desc, ownerName, ownerFace;
  final Map stat;
  final List<VideoPart> pages;
  final bool locked;
  const VideoDetail({
    required this.aid,
    required this.bvid,
    required this.cid,
    required this.title,
    required this.cover,
    required this.desc,
    required this.ownerMid,
    required this.ownerName,
    required this.ownerFace,
    required this.stat,
    required this.pages,
    required this.pubdate,
    required this.locked,
  });

  factory VideoDetail.fromJson(Map d) {
    final Map o = (d['owner'] as Map?) ?? {};
    return VideoDetail(
      aid: asInt(d['aid']),
      bvid: asStr(d['bvid']),
      cid: asInt(d['cid']),
      title: asStr(d['title']),
      cover: fixUrl(d['pic']),
      desc: Purify.text(asStr(d['desc'])),
      ownerMid: asInt(o['mid']),
      ownerName: asStr(o['name']),
      ownerFace: fixUrl(o['face']),
      stat: (d['stat'] as Map?) ?? {},
      pages: [
        for (final p in (d['pages'] as List? ?? []))
          VideoPart(asInt(p['cid']), asStr(p['part']), asInt(p['duration'])),
      ],
      pubdate: asInt(d['pubdate']),
      locked: d['is_upower_exclusive'] == true,
    );
  }
}

class Relation {
  bool like, fav, follow;
  int coin;
  Relation({this.like = false, this.fav = false, this.follow = false, this.coin = 0});
}

class Reply {
  final int rpid, mid, like, ctime, rcount, root, level;
  final String uname, avatar, message;
  final List<Reply> preview;
  final bool pinned;
  const Reply({
    required this.rpid,
    required this.mid,
    required this.like,
    required this.ctime,
    required this.rcount,
    required this.root,
    required this.level,
    required this.uname,
    required this.avatar,
    required this.message,
    required this.preview,
    this.pinned = false,
  });

  factory Reply.fromJson(Map r, {bool pinned = false}) {
    final Map m = (r['member'] as Map?) ?? {};
    return Reply(
      rpid: asInt(r['rpid']),
      mid: asInt(r['mid']),
      like: asInt(r['like']),
      ctime: asInt(r['ctime']),
      rcount: asInt(r['rcount']),
      root: asInt(r['root']),
      level: asInt(m['level_info']?['current_level']),
      uname: asStr(m['uname']),
      avatar: fixUrl(m['avatar']),
      message: Purify.text(asStr(r['content']?['message'])),
      preview: [
        for (final s in (r['replies'] as List? ?? [])) Reply.fromJson(s as Map),
      ],
      pinned: pinned,
    );
  }
}

class Danmaku {
  final double t;
  final int mode; // 1 滚动 4 底部 5 顶部
  final int color;
  final String text;
  const Danmaku(this.t, this.mode, this.color, this.text);
}

class PlayInfo {
  final String video;
  final String? audio;
  final int qn;
  final List<(int, String)> qualities;
  const PlayInfo({required this.video, this.audio, required this.qn, required this.qualities});

  String get qnLabel {
    for (final q in qualities) {
      if (q.$1 == qn) return q.$2;
    }
    return '自动';
  }
}

class FavFolder {
  final int id, count;
  final String title;
  bool fav;
  FavFolder({required this.id, required this.title, required this.count, this.fav = false});
}

class MsgItem {
  final String name, avatar, text, title, uri;
  final int time;
  const MsgItem(
      {required this.name,
      required this.avatar,
      required this.text,
      required this.title,
      required this.uri,
      required this.time});
}
