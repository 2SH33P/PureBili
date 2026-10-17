import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const kPink = Color(0xFFFB7299);
const kBottomInset = 120.0;

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: kPink, brightness: b).copyWith(
    primary: kPink,
    surface: dark ? const Color(0xFF1C1C1E) : Colors.white,
  );
  const transitions = PageTransitionsTheme(builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
  });
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? Colors.black : const Color(0xFFF2F2F7),
    fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei UI', 'Microsoft YaHei', 'Noto Sans SC'],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    pageTransitionsTheme: transitions,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: dark ? const Color(0xF02C2C2E) : const Color(0xF5FFFFFF),
    ),
  );
}

Color secondaryLabel(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0x99EBEBF5)
    : const Color(0x993C3C43);

Color fillColor(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0x3D767680)
    : const Color(0x1F767680);

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}

const iosCurve = Curves.easeOutCubic;
const iosDur = Duration(milliseconds: 280);

IconData get backIcon => CupertinoIcons.chevron_left;
