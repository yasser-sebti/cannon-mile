import 'package:cannon_mile/game/components/tank/tank_speed_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'speed levels keep level one and rise evenly to the reduced maximum',
    () {
      expect(TankSpeedLevel.values.map((level) => level.maximumSpeedFraction), [
        600 / 720,
        624 / 720,
        648 / 720,
        672 / 720,
        696 / 720,
        1.0,
      ]);
      expect(TankSpeedLevel.values.map((level) => level.maximumSpeed), [
        600,
        624,
        648,
        672,
        696,
        720,
      ]);
      expect(TankSpeedLevel.values.map((level) => level.level), [
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
    },
  );

  test('next advances and wraps level six to level one', () {
    expect(TankSpeedLevel.level1.next, TankSpeedLevel.level2);
    expect(TankSpeedLevel.level5.next, TankSpeedLevel.level6);
    expect(TankSpeedLevel.level6.next, TankSpeedLevel.level1);
  });
}
