import 'dart:math' as math;

import 'package:cannon_mile/game/components/tank/tank_bullet_spread_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'spread upgrades create centered symmetric one-to-five shot patterns',
    () {
      expect(
        TankBulletSpreadLevel.values.map((level) => level.projectileCount),
        [1, 2, 3, 4, 5],
      );
      expect(TankBulletSpreadLevel.level1.angleOffsets, [0]);
      expect(
        TankBulletSpreadLevel.level2.angleOffsets,
        [-5, 5].map((degrees) => degrees * math.pi / 180),
      );
      expect(
        TankBulletSpreadLevel.level5.angleOffsets,
        [-20, -10, 0, 10, 20].map((degrees) => degrees * math.pi / 180),
      );
    },
  );

  test('spread levels advance and wrap', () {
    expect(TankBulletSpreadLevel.level1.next, TankBulletSpreadLevel.level2);
    expect(TankBulletSpreadLevel.level5.next, TankBulletSpreadLevel.level1);
  });
}
