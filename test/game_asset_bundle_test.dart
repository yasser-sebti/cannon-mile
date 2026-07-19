import 'dart:io';

import 'package:cannon_mile/app/game_asset_bundle_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uses packaged Windows files when the platform bundle is unavailable',
    () async {
      final assetDirectory = await Directory.systemTemp.createTemp(
        'cannon_mile_assets_',
      );
      try {
        final fallbackTankFile = File(
          '${assetDirectory.path}${Platform.pathSeparator}'
          'assets${Platform.pathSeparator}tank%20skins'
          '${Platform.pathSeparator}tank.webp',
        );
        final fallbackEffectFile = File(
          '${assetDirectory.path}${Platform.pathSeparator}'
          'assets${Platform.pathSeparator}effects'
          '${Platform.pathSeparator}fire1.webp',
        );
        await fallbackTankFile.parent.create(recursive: true);
        await fallbackEffectFile.parent.create(recursive: true);
        await fallbackTankFile.writeAsBytes([1, 2, 3, 4]);
        await fallbackEffectFile.writeAsBytes([5, 6, 7, 8]);

        final bundle = ResilientWindowsAssetBundle(
          primary: _UnavailableAssetBundle(),
          assetDirectory: assetDirectory,
        );

        final data = await bundle.load('assets/tank skins/tank.webp');
        expect(data.buffer.asUint8List(), [1, 2, 3, 4]);
        final effectData = await bundle.load('assets/effects/fire1.webp');
        expect(effectData.buffer.asUint8List(), [5, 6, 7, 8]);
      } finally {
        await assetDirectory.delete(recursive: true);
      }
    },
  );

  test(
    'preserves the platform error when neither source has an asset',
    () async {
      final assetDirectory = await Directory.systemTemp.createTemp(
        'cannon_mile_assets_',
      );
      try {
        final bundle = ResilientWindowsAssetBundle(
          primary: _UnavailableAssetBundle(),
          assetDirectory: assetDirectory,
        );

        await expectLater(
          bundle.load('assets/missing.webp'),
          throwsA(
            isA<FlutterError>().having(
              (error) => error.message,
              'message',
              contains('platform asset channel unavailable'),
            ),
          ),
        );
      } finally {
        await assetDirectory.delete(recursive: true);
      }
    },
  );
}

class _UnavailableAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) {
    throw FlutterError('platform asset channel unavailable: $key');
  }
}
