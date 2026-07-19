import 'package:flutter/material.dart';

import 'app/app_config.dart';
import 'app/desktop_preview.dart';
import 'app/game_asset_bundle.dart';
import 'app/platform_bootstrap.dart';
import 'ui/stage/game_shell.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await configurePlatformForGame();

  final assetBundle = createGameAssetBundle();
  runApp(
    CannonMileApp(
      assetBundle: assetBundle,
      desktopPreview: DesktopPreview.parse(args),
    ),
  );
}

class CannonMileApp extends StatelessWidget {
  const CannonMileApp({
    required this.assetBundle,
    super.key,
    this.desktopPreview,
  });

  final AssetBundle assetBundle;
  final DesktopPreview? desktopPreview;

  @override
  Widget build(BuildContext context) {
    return DefaultAssetBundle(
      bundle: assetBundle,
      child: MaterialApp(
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
          child: GameShell(assetBundle: assetBundle),
        ),
      ),
    );
  }
}
