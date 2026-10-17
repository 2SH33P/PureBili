import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'api/bili.dart';
import 'core/prefs.dart';
import 'pages/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 820),
        minimumSize: Size(400, 600),
        center: true,
        title: 'PureBili',
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  await Prefs.instance.load();
  await Bili.instance.init();
  runApp(const PureBiliApp());
}

class PureBiliApp extends StatelessWidget {
  const PureBiliApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PureBili',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const Shell(),
      );
}
