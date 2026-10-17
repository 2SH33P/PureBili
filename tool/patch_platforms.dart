// 在 `flutter create` 生成平台目录后运行：dart run tool/patch_platforms.dart
// 补充各平台必须的网络权限 / 配置（可重复执行）。
import 'dart:io';

void patch(String path, bool Function(String) done, String Function(String) apply) {
  final f = File(path);
  if (!f.existsSync()) return;
  final s = f.readAsStringSync();
  if (done(s)) return;
  f.writeAsStringSync(apply(s));
  stdout.writeln('patched $path');
}

void main() {
  // Android：Release 包默认没有网络权限
  patch(
    'android/app/src/main/AndroidManifest.xml',
    (s) => s.contains('android.permission.INTERNET'),
    (s) => s.replaceFirst('<application',
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application'),
  );

  // macOS：沙盒内允许发起网络请求
  for (final p in ['macos/Runner/DebugProfile.entitlements', 'macos/Runner/Release.entitlements']) {
    patch(
      p,
      (s) => s.contains('com.apple.security.network.client'),
      (s) => s.replaceFirst(RegExp(r'</dict>\s*</plist>\s*$'),
          '\t<key>com.apple.security.network.client</key>\n\t<true/>\n</dict>\n</plist>\n'),
    );
  }

  // iOS / macOS：少量 CDN 地址是 http，放开 ATS
  for (final p in ['ios/Runner/Info.plist', 'macos/Runner/Info.plist']) {
    patch(
      p,
      (s) => s.contains('NSAppTransportSecurity'),
      (s) => s.replaceFirst(RegExp(r'</dict>\s*</plist>\s*$'),
          '\t<key>NSAppTransportSecurity</key>\n\t<dict>\n\t\t<key>NSAllowsArbitraryLoads</key>\n\t\t<true/>\n\t</dict>\n</dict>\n</plist>\n'),
    );
  }

  // 显示名称统一为 PureBili
  patch('android/app/src/main/AndroidManifest.xml', (s) => s.contains('android:label="PureBili"'),
      (s) => s.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="PureBili"'));
  patch('ios/Runner/Info.plist', (s) => s.contains('<string>PureBili</string>'),
      (s) => s.replaceFirstMapped(RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)'),
          (m) => '${m[1]}PureBili${m[2]}'));
}
