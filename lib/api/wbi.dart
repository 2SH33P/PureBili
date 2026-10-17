import 'dart:convert';

import 'package:crypto/crypto.dart';

/// WBI 签名（Bilibili Web 端接口鉴权）
class Wbi {
  static const _tab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, //
    33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40, //
    61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, //
    36, 20, 34, 44, 52,
  ];

  String? _mixin;
  DateTime? _at;

  void setKeys(String imgUrl, String subUrl) {
    String key(String u) => u.substring(u.lastIndexOf('/') + 1).split('.').first;
    final raw = key(imgUrl) + key(subUrl);
    if (raw.length < 64) return;
    _mixin = _tab.map((i) => raw[i]).join().substring(0, 32);
    _at = DateTime.now();
  }

  bool get stale =>
      _mixin == null || DateTime.now().difference(_at!) > const Duration(hours: 12);

  /// 返回已签名的 query string（含 wts 与 w_rid）
  String sign(Map<String, dynamic> params) {
    final p = <String, String>{
      for (final e in params.entries) e.key: e.value.toString(),
    };
    p['wts'] = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final keys = p.keys.toList()..sort();
    final filter = RegExp(r"[!'()*]");
    final qs = keys
        .map((k) =>
            '${Uri.encodeComponent(k)}=${Uri.encodeComponent(p[k]!.replaceAll(filter, ''))}')
        .join('&');
    final wRid = md5.convert(utf8.encode(qs + (_mixin ?? ''))).toString();
    return '$qs&w_rid=$wRid';
  }
}
