import 'package:dio/dio.dart';

/// 内容净化层：剔除一切推荐与购买相关内容。
class Purify {
  static final _commerce = RegExp(
    r'https?://\S*(mall\.bilibili|gf\.bilibili|show\.bilibili|manga\.bilibili|cm\.bilibili|vip\.bilibili|pay\.bilibili|upower|/charge|b23\.tv/mall|taobao|tmall|jd\.com|pinduoduo)\S*',
    caseSensitive: false,
  );

  /// 去掉文本中的商品 / 充电 / 会员购买链接
  static String text(String s) => s.replaceAll(_commerce, '').trimRight();

  /// 关注动态：只保留普通视频投稿，丢弃广告、课程、充电专属等
  static bool dynamicAllowed(Map item) {
    if (item['type'] != 'DYNAMIC_TYPE_AV') return false;
    final major = item['modules']?['module_dynamic']?['major'];
    if (major == null || major['type'] != 'MAJOR_TYPE_ARCHIVE') return false;
    final badge = (major['archive']?['badge']?['text'] ?? '').toString();
    if (badge.contains('充电') || badge.contains('付费')) return false;
    return true;
  }

  /// 搜索结果：只保留视频，丢弃推广、付费
  static bool searchAllowed(Map r) {
    if (r['type'] != 'video') return false;
    if (r['is_pay'] == 1 || r['is_charge_video'] == 1) return false;
    return (r['bvid'] ?? '').toString().isNotEmpty;
  }
}

/// 接口白名单：只放行下列接口，推荐 / 购买类接口在网络层就被拦截。
class WhitelistInterceptor extends Interceptor {
  static const allowed = [
    'api.bilibili.com/x/frontend/finger/spi',
    'api.bilibili.com/x/web-interface/nav',
    'passport.bilibili.com/x/passport-login/web/qrcode/',
    'api.bilibili.com/x/polymer/web-dynamic/v1/feed/all',
    'api.bilibili.com/x/web-interface/wbi/search/type',
    'api.bilibili.com/x/web-interface/wbi/view',
    'api.bilibili.com/x/web-interface/archive/relation',
    'api.bilibili.com/x/web-interface/archive/like',
    'api.bilibili.com/x/web-interface/coin/add',
    'api.bilibili.com/x/player/wbi/playurl',
    'api.bilibili.com/x/click-interface/web/heartbeat',
    'api.bilibili.com/x/v2/reply/wbi/main',
    'api.bilibili.com/x/v2/reply/reply',
    'api.bilibili.com/x/v2/reply/add',
    'api.bilibili.com/x/v2/reply/action',
    'api.bilibili.com/x/v3/fav/folder/created/list-all',
    'api.bilibili.com/x/v3/fav/resource/list',
    'api.bilibili.com/x/v3/fav/resource/deal',
    'api.bilibili.com/x/relation/modify',
    'api.bilibili.com/x/web-interface/history/cursor',
    'api.bilibili.com/x/v2/history/toview',
    'api.bilibili.com/x/space/wbi/arc/search',
    'api.bilibili.com/x/msgfeed/',
    'comment.bilibili.com/',
  ];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final u = options.uri;
    final s = '${u.host}${u.path}';
    if (allowed.any(s.startsWith)) return handler.next(options);
    handler.reject(DioException(
      requestOptions: options,
      message: 'PureBili 已拦截非白名单接口：$s',
    ));
  }
}
