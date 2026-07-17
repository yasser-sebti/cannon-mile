import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cannon_mile/app/app_config.dart';

void main() {
  testWidgets('only approved branding and tank files enter the asset bundle', (
    tester,
  ) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final projectAssets =
        manifest
            .listAssets()
            .where((asset) => asset.startsWith('assets/'))
            .toList()
          ..sort();

    expect(projectAssets, [
      AppConfig.brandingAsset,
      'assets/tank skins/default-skin/base-tank.webp',
      'assets/tank skins/default-skin/tank-canon.webp',
      'assets/tank skins/default-skin/wheel-rounded.webp',
      'assets/tank skins/default-skin/wheel1.webp',
      'assets/tank skins/default-skin/wheel2.webp',
    ]);
  });
}
