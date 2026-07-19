import 'package:cannon_mile/game/components/tank/tank_bullet_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bullet levels map to the five supplied sprites in upgrade order', () {
    expect(TankBulletLevel.values.map((level) => level.artworkIndex), [
      0,
      1,
      2,
      3,
      4,
      4,
    ]);
    expect(TankBulletLevel.values.map((level) => level.renderScale), [
      1.0,
      0.96,
      0.89,
      0.87,
      0.70,
      0.82,
    ]);
    expect(TankBulletLevel.values.map((level) => level.brightness), [
      0.74,
      0.77,
      0.80,
      0.83,
      1.0,
      1.0,
    ]);
    expect(TankBulletLevel.values.map((level) => level.shellArtworkIndex), [
      0,
      0,
      1,
      1,
      2,
      3,
    ]);
    expect(TankBulletLevel.values.map((level) => level.level), [
      1,
      2,
      3,
      4,
      5,
      6,
    ]);
  });

  test('next advances and wraps the six-level placeholder control', () {
    expect(TankBulletLevel.level1.next, TankBulletLevel.level2);
    expect(TankBulletLevel.level5.next, TankBulletLevel.level6);
    expect(TankBulletLevel.level6.next, TankBulletLevel.level1);
  });
}
