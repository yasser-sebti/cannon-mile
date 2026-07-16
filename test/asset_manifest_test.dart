import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cannon_mile/app/app_config.dart';

void main() {
  testWidgets('only the approved branding file enters the asset bundle', (
    tester,
  ) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final projectAssets =
        manifest
            .listAssets()
            .where((asset) => asset.startsWith('assets/'))
            .toList()
          ..sort();

    expect(projectAssets, [AppConfig.brandingAsset]);
  });
}
