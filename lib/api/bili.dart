import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'purify.dart';
import 'wbi.dart';

// 注意：UA 中不能含逗号（mpv 的 http-header-fields 以逗号分隔）
const kUA =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML like Gecko) Chrome/126.0.0.0 Safari/537.36';
const kReferer = 'https://www.bilibili.com/';
const _api = 'https://api.bilibili.com';

class BiliException implements Exception {
  final int code;
  final String message;
  BiliException(this.code, this.message);
  @override
  String toString() {
    if (code == -101) return '账号未登录';
    if (code == -352 || code == -412) return '请求被风控拦截，请稍后再试（$code）';
    return message.isEmpty ? '错误 $code' : message;
  }
}

class Bili {
  Bili._();
  static final Bili instance = Bili._();

  late final Dio dio;
  late final PersistCookieJar jar;
  final _wbi = Wbi();
  final user = ValueNotifier<UserInfo?>(null);
  UserInfo? get me => user.value;

  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    jar = PersistCookieJar(storage: FileStorage('${dir.path}${Platform.pathSeparator}cookies'));
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'User-Agent': kUA, 'Referer': kReferer, 'Origin': 'https://www.bilibili.com'},
    ));
    dio.interceptors.add(WhitelistInterceptor());
    dio.interceptors.add(CookieManager(jar));
    await _ensureBuvid();
    await refreshNav();
  }

  // ---------------- 基础 ----------------

  Future<dynamic> get(String url,
      {Map<String, dynamic>? query, bool wbi = false, bool allowCodes = false}) async {
    Response r;
    if (wbi) {
      if (_wbi.stale) await refreshNav();
      r = await dio.get('$url?${_wbi.sign(query ?? {})}');
    } else {
      r = await dio.get(url, queryParameters: query);
    }
    return _unwrap(r.data, allowCodes: allowCodes);
  }

  Future<dynamic> post(String url, Map<String, dynamic> form) async {
    final csrf = await csrfToken();
    if (csrf.isEmpty) throw BiliException(-101, '账号未登录');
    final r = await dio.post(url,
        data: {...form, 'csrf': csrf},
        options: Options(contentType: Headers.formUrlEncodedContentType));
    return _unwrap(r.data);
  }

  dynamic _unwrap(dynamic body, {bool allowCodes = false}) {
    if (body is String) body = jsonDecode(body);
    final code = asInt(body['code']);
    if (code != 0 && !allowCodes) {
      throw BiliException(code, asStr(body['message']));
    }
    return body['data'] ?? body['result'];
  }

  Future<String> csrfToken() async {
    final c = await jar.loadForRequest(Uri.parse('$_api/'));
    for (final e in c) {
      if (e.name == 'bili_jct') return e.value;
    }
    return '';
  }

  Future<void> _ensureBuvid() async {
    try {
      final cookies = await jar.loadForRequest(Uri.parse('$_api/'));
      if (cookies.any((c) => c.name == 'buvid3')) return;
      final r = await dio.get('$_api/x/frontend/finger/spi');
      final d = r.data['data'];
      await jar.saveFromResponse(Uri.parse(kReferer), [
        Cookie('buvid3', asStr(d['b_3']))
          ..domain = '.bilibili.com'
          ..path = '/',
        Cookie('buvid4', asStr(d['b_4']))
          ..domain = '.bilibili.com'
          ..path = '/',
      ]);
    } catch (e) {
      debugPrint('buvid failed: $e');
    }
  }

  Future<void> refreshNav() async {
    try {
      final d = await get('$_api/x/web-interface/nav', allowCodes: true);
      if (d == null) return;
      final img = d['wbi_img'];
      if (img != null) _wbi.setKeys(asStr(img['img_url']), asStr(img['sub_url']));
      user.value = d['isLogin'] == true ? UserInfo.fromNav(d) : null;
    } catch (e) {
      debugPrint('nav failed: $e');
    }
  }

  Future<void> logout() async {
    await jar.deleteAll();
    user.value = null;
    await _ensureBuvid();
  }

  // ---------------- 登录 ----------------

  Future<(String, String)> qrGenerate() async {
    final d = await get('https://passport.bilibili.com/x/passport-login/web/qrcode/generate');
    return (asStr(d['url']), asStr(d['qrcode_key']));
  }

  /// 0 成功；86101 未扫码；86090 已扫码未确认；86038 已过期
  Future<int> qrPoll(String key) async {
    final d = await get('https://passport.bilibili.com/x/passport-login/web/qrcode/poll',
        query: {'qrcode_key': key});
    final code = asInt(d['code']);
    if (code == 0) await refreshNav();
    return code;
  }

  // ---------------- 列表 ----------------

  /// 关注的 UP 视频更新（纯时间线，无推荐）
  Future<(List<VideoCard>, Object?)> followingFeed(Object? cursor) async {
    final d = await get('$_api/x/polymer/web-dynamic/v1/feed/all', query: {
      'type': 'video',
      'offset': asStr(cursor),
      'features': 'itemOpusStyle',
    });
    final list = <VideoCard>[];
    for (final it in (d['items'] as List? ?? []).cast<Map>()) {
      if (!Purify.dynamicAllowed(it)) continue;
      final m = it['modules'];
      final a = m['module_author'] ?? {};
      final ar = m['module_dynamic']['major']['archive'];
      list.add(VideoCard(
        bvid: asStr(ar['bvid']),
        title: asStr(ar['title']),
        cover: fixUrl(ar['cover']),
        author: asStr(a['name']),
        authorMid: asInt(a['mid']),
        duration: asStr(ar['duration_text']),
        play: asStr(ar['stat']?['play']),
        sub: asStr(a['pub_time']),
      ));
    }
    final more = d['has_more'] == true;
    return (list, more ? asStr(d['offset']) : null);
  }

  static const searchOrders = ['totalrank', 'click', 'pubdate', 'dm', 'stow'];

  Future<(List<VideoCard>, Object?)> search(String kw, Object? cursor, {int order = 0}) async {
    final page = cursor is int ? cursor : 1;
    final d = await get('$_api/x/web-interface/wbi/search/type', wbi: true, query: {
      'search_type': 'video',
      'keyword': kw,
      'page': page,
      'order': searchOrders[order],
    });
    final res = (d['result'] as List? ?? []).cast<Map>();
    final list = [
      for (final r in res)
        if (Purify.searchAllowed(r))
          VideoCard(
            bvid: asStr(r['bvid']),
            title: stripHtml(asStr(r['title'])),
            cover: fixUrl(r['pic']),
            author: asStr(r['author']),
            authorMid: asInt(r['mid']),
            duration: asStr(r['duration']),
            play: fmtCount(r['play']),
            sub: fmtTime(asInt(r['pubdate'])),
          ),
    ];
    final pages = asInt(d['numPages']);
    return (list, page < pages ? page + 1 : null);
  }

  Future<(List<VideoCard>, Object?)> history(Object? cursor) async {
    final c = cursor is Map ? cursor : null;
    final d = await get('$_api/x/web-interface/history/cursor', query: {
      'ps': 20,
      'type': 'archive',
      if (c != null) 'max': c['max'],
      if (c != null) 'view_at': c['view_at'],
      if (c != null) 'business': c['business'],
    });
    final raw = (d['list'] as List? ?? []).cast<Map>();
    final list = <VideoCard>[];
    for (final h in raw) {
      final bvid = asStr(h['history']?['bvid']);
      if (bvid.isEmpty) continue;
      final dur = asInt(h['duration']);
      final prog = asInt(h['progress']);
      String cover = fixUrl(h['cover']);
      if (cover.isEmpty && h['covers'] is List && (h['covers'] as List).isNotEmpty) {
        cover = fixUrl((h['covers'] as List).first);
      }
      list.add(VideoCard(
        bvid: bvid,
        title: asStr(h['title']),
        cover: cover,
        author: asStr(h['author_name']),
        authorMid: asInt(h['author_mid']),
        duration: dur > 0 ? fmtDur(dur) : '',
        sub: prog < 0 ? '已看完' : '看到 ${fmtDur(prog)}',
        progress: prog < 0 ? 1 : (dur > 0 ? prog / dur : -1),
      ));
    }
    return (list, raw.isEmpty ? null : d['cursor']);
  }

  Future<(List<VideoCard>, Object?)> toview(Object? _) async {
    final d = await get('$_api/x/v2/history/toview');
    final list = [
      for (final v in (d?['list'] as List? ?? []).cast<Map>())
        VideoCard(
          bvid: asStr(v['bvid']),
          title: asStr(v['title']),
          cover: fixUrl(v['pic']),
          author: asStr(v['owner']?['name']),
          authorMid: asInt(v['owner']?['mid']),
          duration: fmtDur(asInt(v['duration'])),
          play: fmtCount(v['stat']?['view']),
        ),
    ];
    return (list, null);
  }

  Future<void> toviewAdd(int aid) => post('$_api/x/v2/history/toview/add', {'aid': aid});

  Future<List<FavFolder>> favFolders({int aid = 0}) async {
    final d = await get('$_api/x/v3/fav/folder/created/list-all', query: {
      'up_mid': me?.mid ?? 0,
      if (aid > 0) 'type': 2,
      if (aid > 0) 'rid': aid,
    });
    return [
      for (final f in (d?['list'] as List? ?? []).cast<Map>())
        FavFolder(
          id: asInt(f['id']),
          title: asStr(f['title']),
          count: asInt(f['media_count']),
          fav: asInt(f['fav_state']) == 1,
        ),
    ];
  }

  Future<(List<VideoCard>, Object?)> favResources(int mediaId, Object? cursor) async {
    final pn = cursor is int ? cursor : 1;
    final d = await get('$_api/x/v3/fav/resource/list',
        query: {'media_id': mediaId, 'pn': pn, 'ps': 20, 'platform': 'web'});
    final list = [
      for (final v in (d?['medias'] as List? ?? []).cast<Map>())
        if (asStr(v['bvid']).isNotEmpty && asInt(v['attr']) == 0)
          VideoCard(
            bvid: asStr(v['bvid']),
            title: asStr(v['title']),
            cover: fixUrl(v['cover']),
            author: asStr(v['upper']?['name']),
            authorMid: asInt(v['upper']?['mid']),
            duration: fmtDur(asInt(v['duration'])),
            play: fmtCount(v['cnt_info']?['play']),
          ),
    ];
    return (list, d?['has_more'] == true ? pn + 1 : null);
  }

  Future<(List<VideoCard>, Object?)> spaceVideos(int mid, Object? cursor) async {
    final pn = cursor is int ? cursor : 1;
    final d = await get('$_api/x/space/wbi/arc/search', wbi: true, query: {
      'mid': mid,
      'pn': pn,
      'ps': 30,
      'order': 'pubdate',
      'platform': 'web',
      'web_location': 1550101,
      'dm_img_list': '[]',
      'dm_img_str': 'V2ViR0wgMS4wIChPcGVuR0wgRVMgMi4wIENocm9taXVtKQ',
      'dm_cover_img_str':
          'QU5HTEUgKEludGVsLCBJbnRlbChSKSBVSEQgR3JhcGhpY3MgNjMwIERpcmVjdDNEMTEgdnNfNV8wIHBzXzVfMCwgRDNEMTEpR29vZ2xlIEluYy4gKEludGVsKQ',
      'dm_img_inter': '{"ds":[],"wh":[0,0,0],"of":[0,0,0]}',
    });
    final vlist = (d?['list']?['vlist'] as List? ?? []).cast<Map>();
    final list = [
      for (final v in vlist)
        VideoCard(
          bvid: asStr(v['bvid']),
          title: asStr(v['title']),
          cover: fixUrl(v['pic']),
          author: asStr(v['author']),
          authorMid: mid,
          duration: asStr(v['length']),
          play: fmtCount(v['play']),
          sub: fmtTime(asInt(v['created'])),
        ),
    ];
    final count = asInt(d?['page']?['count']);
    return (list, pn * 30 < count ? pn + 1 : null);
  }

  // ---------------- 视频 ----------------

  Future<VideoDetail> view(String bvid) async {
    final d = await get('$_api/x/web-interface/wbi/view', query: {'bvid': bvid}, wbi: true);
    return VideoDetail.fromJson(d);
  }

  Future<Relation> relation(String bvid) async {
    final d = await get('$_api/x/web-interface/archive/relation', query: {'bvid': bvid});
    return Relation(
      like: d['like'] == true,
      fav: d['favorite'] == true,
      follow: d['attention'] == true,
      coin: asInt(d['coin']),
    );
  }

  Future<PlayInfo> playUrl(String bvid, int cid, {int qn = 80}) async {
    final d = await get('$_api/x/player/wbi/playurl', wbi: true, query: {
      'bvid': bvid,
      'cid': cid,
      'qn': qn,
      'fnval': 4048,
      'fnver': 0,
      'fourk': 1,
    });
    final accept = [for (final q in (d['accept_quality'] as List? ?? [])) asInt(q)];
    final desc = [for (final s in (d['accept_description'] as List? ?? [])) asStr(s)];
    final quals = <(int, String)>[
      for (var i = 0; i < accept.length && i < desc.length; i++) (accept[i], desc[i]),
    ];
    final dash = d['dash'];
    if (dash != null && dash['video'] is List && (dash['video'] as List).isNotEmpty) {
      final videos = (dash['video'] as List).cast<Map>();
      final available = videos.map((v) => asInt(v['id'])).toSet();
      var target = available.contains(qn)
          ? qn
          : available.where((q) => q <= qn).fold<int>(0, (a, b) => b > a ? b : a);
      if (target == 0) target = available.reduce((a, b) => a < b ? a : b);
      final same = videos.where((v) => asInt(v['id']) == target).toList()
        ..sort((a, b) => _codecRank(a['codecid']) - _codecRank(b['codecid']));
      final v = same.first;
      final audios = (dash['audio'] as List? ?? []).cast<Map>().toList()
        ..sort((a, b) => asInt(b['bandwidth']) - asInt(a['bandwidth']));
      return PlayInfo(
        video: asStr(v['baseUrl'] ?? v['base_url']),
        audio: audios.isEmpty ? null : asStr(audios.first['baseUrl'] ?? audios.first['base_url']),
        qn: target,
        qualities: quals.where((q) => available.contains(q.$1)).toList(),
      );
    }
    final durl = (d['durl'] as List? ?? []).cast<Map>();
    if (durl.isEmpty) throw BiliException(-1, '无可用播放地址（可能为付费内容）');
    return PlayInfo(video: asStr(durl.first['url']), qn: asInt(d['quality']), qualities: quals);
  }

  // 兼容性优先：AVC > HEVC > AV1
  int _codecRank(dynamic c) => c == 7 ? 0 : (c == 12 ? 1 : 2);

  Future<List<Danmaku>> danmaku(int cid) async {
    final r = await dio.get<List<int>>('https://comment.bilibili.com/$cid.xml',
        options: Options(responseType: ResponseType.bytes));
    final bytes = r.data ?? const <int>[];
    String xml;
    try {
      xml = utf8.decode(ZLibCodec(raw: true).decode(bytes), allowMalformed: true);
    } catch (_) {
      xml = utf8.decode(bytes, allowMalformed: true);
    }
    final out = <Danmaku>[];
    for (final m in RegExp(r'<d p="([^"]+)">([^<]*)</d>').allMatches(xml)) {
      final p = m.group(1)!.split(',');
      if (p.length < 4) continue;
      final mode = int.tryParse(p[1]) ?? 1;
      if (mode != 1 && mode != 4 && mode != 5) continue;
      out.add(Danmaku(double.tryParse(p[0]) ?? 0, mode, int.tryParse(p[3]) ?? 0xFFFFFF,
          unescapeHtml(m.group(2)!)));
    }
    out.sort((a, b) => a.t.compareTo(b.t));
    return out;
  }

  Future<void> heartbeat(int aid, String bvid, int cid, int seconds) =>
      post('$_api/x/click-interface/web/heartbeat',
          {'aid': aid, 'bvid': bvid, 'cid': cid, 'played_time': seconds});

  Future<void> like(int aid, bool on) =>
      post('$_api/x/web-interface/archive/like', {'aid': aid, 'like': on ? 1 : 2});

  Future<void> coin(int aid, int count, {bool alsoLike = false}) => post(
      '$_api/x/web-interface/coin/add',
      {'aid': aid, 'multiply': count, 'select_like': alsoLike ? 1 : 0});

  Future<void> triple(int aid) => post('$_api/x/web-interface/archive/like/triple', {'aid': aid});

  Future<void> favDeal(int aid, List<int> add, List<int> del) =>
      post('$_api/x/v3/fav/resource/deal', {
        'rid': aid,
        'type': 2,
        'add_media_ids': add.join(','),
        'del_media_ids': del.join(','),
      });

  Future<void> follow(int mid, bool on) =>
      post('$_api/x/relation/modify', {'fid': mid, 'act': on ? 1 : 2, 're_src': 11});

  // ---------------- 评论 ----------------

  Future<(List<Reply>, String?)> replies(int aid, {String offset = '', bool hot = true}) async {
    final d = await get('$_api/x/v2/reply/wbi/main', wbi: true, query: {
      'oid': aid,
      'type': 1,
      'mode': hot ? 3 : 2,
      'plat': 1,
      'pagination_str': jsonEncode({'offset': offset}),
    });
    final list = <Reply>[];
    if (offset.isEmpty) {
      for (final t in (d['top_replies'] as List? ?? []).cast<Map>()) {
        list.add(Reply.fromJson(t, pinned: true));
      }
    }
    for (final r in (d['replies'] as List? ?? []).cast<Map>()) {
      final rp = Reply.fromJson(r);
      if (rp.message.trim().isEmpty) continue;
      if (list.any((e) => e.rpid == rp.rpid)) continue;
      list.add(rp);
    }
    final end = d['cursor']?['is_end'] == true;
    final next = asStr(d['cursor']?['pagination_reply']?['next_offset']);
    return (list, end || next.isEmpty ? null : next);
  }

  Future<(List<Reply>, int?)> subReplies(int aid, int root, int pn) async {
    final d = await get('$_api/x/v2/reply/reply',
        query: {'oid': aid, 'type': 1, 'root': root, 'pn': pn, 'ps': 20});
    final list = [for (final r in (d['replies'] as List? ?? []).cast<Map>()) Reply.fromJson(r)];
    final count = asInt(d['page']?['count']);
    return (list, pn * 20 < count ? pn + 1 : null);
  }

  Future<Reply?> addReply(int aid, String message, {int root = 0, int parent = 0}) async {
    final d = await post('$_api/x/v2/reply/add', {
      'oid': aid,
      'type': 1,
      'message': message,
      if (root > 0) 'root': root,
      if (parent > 0) 'parent': parent,
    });
    final r = d?['reply'];
    return r is Map ? Reply.fromJson(r) : null;
  }

  Future<void> likeReply(int aid, int rpid, bool on) => post('$_api/x/v2/reply/action',
      {'oid': aid, 'type': 1, 'rpid': rpid, 'action': on ? 1 : 0});

  // ---------------- 消息 ----------------

  /// kind: reply / at / like
  Future<List<MsgItem>> messages(String kind) async {
    final d = await get('$_api/x/msgfeed/$kind',
        query: {'platform': 'web', 'build': 0, 'mobi_app': 'web'});
    final items = kind == 'like'
        ? (d?['total']?['items'] as List? ?? [])
        : (d?['items'] as List? ?? []);
    return [
      for (final it in items.cast<Map>())
        if (kind == 'like')
          MsgItem(
            name: asStr((it['users'] as List?)?.isNotEmpty == true ? it['users'][0]['nickname'] : ''),
            avatar: fixUrl((it['users'] as List?)?.isNotEmpty == true ? it['users'][0]['avatar'] : ''),
            text: '赞了你的${asStr(it['item']?['business'])}${asInt(it['counts']) > 1 ? ' 等 ${it['counts']} 人' : ''}',
            title: Purify.text(asStr(it['item']?['title'])),
            uri: asStr(it['item']?['uri']),
            time: asInt(it['like_time']),
          )
        else
          MsgItem(
            name: asStr(it['user']?['nickname']),
            avatar: fixUrl(it['user']?['avatar']),
            text: Purify.text(asStr(it['item']?['source_content'])),
            title: Purify.text(asStr(it['item']?['title'])),
            uri: asStr(it['item']?['uri']),
            time: asInt(it[kind == 'at' ? 'at_time' : 'reply_time']),
          ),
    ];
  }
}
