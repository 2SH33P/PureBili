// 只为当前已存在的平台目录生成应用图标：dart run tool/gen_icons.dart
// 原因：flutter_launcher_icons 会对配置里开启的每个平台写文件，
// 而 CI 的每个 job 只生成了自己的平台目录，缺目录就会报 PathNotFoundException。
import 'dart:io';

bool has(String p) => Directory(p).existsSync();

Future<void> main() async {
  final b = StringBuffer()
    ..writeln('flutter_launcher_icons:')
    ..writeln('  image_path: "assets/icon/icon.png"');
  final enabled = <String>[];

  if (has('android/app/src/main/res')) {
    enabled.add('android');
    b
      ..writeln('  android: "launcher_icon"')
      ..writeln('  adaptive_icon_background: "#FB7299"')
      ..writeln('  adaptive_icon_foreground: "assets/icon/icon_foreground.png"')
      ..writeln('  min_sdk_android: 21');
  } else {
    b.writeln('  android: false');
  }

  if (has('ios/Runner/Assets.xcassets/AppIcon.appiconset')) {
    enabled.add('ios');
    b
      ..writeln('  ios: true')
      ..writeln('  remove_alpha_ios: true');
  } else {
    b.writeln('  ios: false');
  }

  if (has('windows/runner/resources')) {
    enabled.add('windows');
    b
      ..writeln('  windows:')
      ..writeln('    generate: true')
      ..writeln('    image_path: "assets/icon/icon_desktop.png"')
      ..writeln('    icon_size: 256');
  }

  if (has('macos/Runner/Assets.xcassets/AppIcon.appiconset')) {
    enabled.add('macos');
    b
      ..writeln('  macos:')
      ..writeln('    generate: true')
      ..writeln('    image_path: "assets/icon/icon_desktop.png"');
  }

  if (enabled.isEmpty) {
    stdout.writeln('gen_icons: no platform folders found, skipped.');
    return;
  }
  stdout.writeln('gen_icons: platforms = ${enabled.join(', ')}');

  final cfg = File('.flutter_launcher_icons.gen.yaml')..writeAsStringSync(b.toString());
  try {
    final p = await Process.start(
      'dart',
      ['run', 'flutter_launcher_icons', '-f', cfg.path],
      runInShell: true,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await p.exitCode;
    if (code != 0) exit(code);
  } finally {
    if (cfg.existsSync()) cfg.deleteSync();
  }
}
