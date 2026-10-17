import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// 本地设置（JSON 文件）
class Prefs {
  Prefs._();
  static final Prefs instance = Prefs._();

  File? _file;
  Map<String, dynamic> _m = {};

  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}${Platform.pathSeparator}prefs.json');
      if (await _file!.exists()) {
        _m = Map<String, dynamic>.from(jsonDecode(await _file!.readAsString()) as Map);
      }
    } catch (_) {}
  }

  T get<T>(String k, T def) {
    final v = _m[k];
    return v is T ? v : def;
  }

  Future<void> set(String k, Object? v) async {
    _m[k] = v;
    try {
      await _file?.writeAsString(jsonEncode(_m));
    } catch (_) {}
  }

  List<String> get searchHistory =>
      [for (final s in (_m['searchHistory'] as List? ?? [])) s.toString()];

  Future<void> pushSearch(String kw) async {
    final list = searchHistory..remove(kw);
    list.insert(0, kw);
    await set('searchHistory', list.take(20).toList());
  }
}
