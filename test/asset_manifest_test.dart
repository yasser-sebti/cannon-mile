import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cannon_mile/app/app_config.dart';

void main() {
  testWidgets('only approved game files enter the asset bundle', (
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
      'assets/effects/bullet1.webp',
      'assets/effects/bullet2.webp',
      'assets/effects/bullet3.webp',
      'assets/effects/bullet4.webp',
      'assets/effects/bullet5.webp',
      'assets/effects/bullethit1.webp',
      'assets/effects/bullethit10.webp',
      'assets/effects/bullethit2.webp',
      'assets/effects/bullethit3.webp',
      'assets/effects/bullethit4.webp',
      'assets/effects/bullethit5.webp',
      'assets/effects/bullethit6.webp',
      'assets/effects/bullethit7.webp',
      'assets/effects/bullethit8.webp',
      'assets/effects/bullethit9.webp',
      'assets/effects/bulletshell1.webp',
      'assets/effects/bulletshell2.webp',
      'assets/effects/bulletshell3.webp',
      'assets/effects/bulletshell4.webp',
      'assets/effects/explosion1.webp',
      'assets/effects/explosion2.webp',
      'assets/effects/explosion3.webp',
      'assets/effects/explosion4.webp',
      'assets/effects/explosion5.webp',
      'assets/effects/explosion6.webp',
      'assets/effects/fire1.webp',
      'assets/effects/fire2_1.webp',
      'assets/effects/fire3_1.webp',
      'assets/effects/fire4_1.webp',
      'assets/effects/ground-hit-smoke1.webp',
      'assets/effects/ground-hit-smoke2.webp',
      'assets/effects/ground-hit-smoke3.webp',
      'assets/effects/ground-hit-smoke4.webp',
      'assets/effects/ground-hit-smoke5.webp',
      'assets/effects/ground-hit1.webp',
      'assets/effects/ground-hit10.webp',
      'assets/effects/ground-hit2.webp',
      'assets/effects/ground-hit3.webp',
      'assets/effects/ground-hit4.webp',
      'assets/effects/ground-hit5.webp',
      'assets/effects/ground-hit6.webp',
      'assets/effects/ground-hit7.webp',
      'assets/effects/ground-hit8.webp',
      'assets/effects/ground-hit9.webp',
      'assets/effects/laser-beam-effect-color-dodge.webp',
      'assets/effects/laser-beam-effect.webp',
      'assets/effects/particle1.webp',
      'assets/effects/particle2.webp',
      'assets/effects/particle3.webp',
      'assets/effects/smoke-particle1.webp',
      'assets/effects/smoke-particle2.webp',
      'assets/effects/smoke-particle3.webp',
      'assets/effects/smoke-particle4.webp',
      'assets/effects/smoke-particle5.webp',
      'assets/effects/smoke-particle6.webp',
      'assets/effects/smoke-particle7.webp',
      'assets/effects/smoke1.webp',
      'assets/effects/smoke2.webp',
      'assets/effects/smoke3.webp',
      'assets/effects/smoke4.webp',
      'assets/effects/smoke5.webp',
      'assets/effects/smoke6.webp',
      'assets/enemy/planes/fan-animation.webp',
      'assets/enemy/planes/scout-jet-default.webp',
      'assets/sounds/bomb-explosion1.wav',
      'assets/sounds/bomb-explosion2.wav',
      'assets/sounds/bomb-explosion3.wav',
      'assets/sounds/bulletdrop1.wav',
      'assets/sounds/bulletdrop2.wav',
      'assets/sounds/bulletdrop3.wav',
      'assets/sounds/bulletdrop4.wav',
      'assets/sounds/gunfire1.wav',
      'assets/sounds/gunfire2.wav',
      'assets/sounds/gunfire3.wav',
      'assets/sounds/gunfire4.wav',
      'assets/sounds/gunfire5.wav',
      'assets/sounds/gunfire6.wav',
      'assets/sounds/laser-beam-start.wav',
      'assets/sounds/laser-beam.wav',
      'assets/sounds/metal-hit1.wav',
      'assets/sounds/metal-hit2.wav',
      'assets/sounds/metal-hit3.wav',
      'assets/tank skins/default-skin/base-tank.webp',
      'assets/tank skins/default-skin/tank-canon.webp',
      'assets/tank skins/default-skin/wheel-rounded.webp',
      'assets/tank skins/default-skin/wheel1.webp',
      'assets/tank skins/default-skin/wheel2.webp',
      'assets/tank skins/default-skin/wheel3.webp',
      'assets/tank skins/default-skin/wheel4.webp',
    ]);

    final laserIdle = await rootBundle.load('assets/sounds/laser-beam.wav');
    final laserIdleBytes = laserIdle.buffer.asUint8List(
      laserIdle.offsetInBytes,
      laserIdle.lengthInBytes,
    );
    expect(laserIdleBytes.sublist(0, 4), [0x52, 0x49, 0x46, 0x46]);
    expect(laserIdleBytes.sublist(8, 12), [0x57, 0x41, 0x56, 0x45]);
  });
}
