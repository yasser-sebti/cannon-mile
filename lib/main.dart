import 'package:flutter/material.dart';

import 'app/app_config.dart';
import 'app/desktop_preview.dart';
import 'app/platform_bootstrap.dart';
import 'ui/stage/game_shell.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await configurePlatformForGame();

  runApp(CannonMileApp(desktopPreview: DesktopPreview.parse(args)));
}

class CannonMileApp extends StatelessWidget {
  const CannonMileApp({super.key, this.desktopPreview});

  final DesktopPreview? desktopPreview;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.title,
      color: AppConfig.backgroundColor,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppConfig.backgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: AppConfig.progressColor,
          surface: AppConfig.backgroundColor,
        ),
      ),
      home: DesktopPreviewSurface(
        preview: desktopPreview,
        child: const GameShell(),
      ),
    );
  }
}
