#!/usr/bin/env bash
# 用法: ./build.sh android | macos | ios
# macos / ios 需要在 Mac 上运行（已装 Xcode）；android 需要 Android SDK + JDK 17。
set -euo pipefail
cd "$(dirname "$0")"
P="${1:-}"
case "$P" in android|macos|ios) ;; *) echo "usage: $0 android|macos|ios"; exit 1;; esac
command -v flutter >/dev/null || { echo "Flutter SDK not found"; exit 1; }
[ -d "$P" ] || flutter create --org com.purebili --project-name purebili --platforms="$P" .
dart run tool/patch_platforms.dart
flutter pub get
dart run flutter_launcher_icons
case "$P" in
  android)
    flutter build apk --release --split-per-abi
    echo "APK: build/app/outputs/flutter-apk/" ;;
  macos)
    flutter build macos --release
    ditto -c -k --keepParent build/macos/Build/Products/Release/purebili.app PureBili-macos.zip
    echo "App: PureBili-macos.zip" ;;
  ios)
    flutter build ios --release --no-codesign
    rm -rf Payload && mkdir Payload && cp -R build/ios/iphoneos/Runner.app Payload/
    zip -qr PureBili-ios-unsigned.ipa Payload && rm -rf Payload
    echo "IPA (unsigned): PureBili-ios-unsigned.ipa" ;;
esac
