import 'package:cannon_mile/game/components/tank/tank_fire_rate_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fire-rate levels progress evenly from the raised minimum', () {
    expect(TankFireRateLevel.values.map((level) => level.shotsPerSecond), [
      5.376,
      5.7808,
      6.1856,
      6.5904,
      6.9952,
      7.4,
    ]);
    final rates = TankFireRateLevel.values
        .map((level) => level.shotsPerSecond)
        .toList();
    for (var index = 1; index < rates.length; index++) {
      expect(rates[index] - rates[index - 1], closeTo(0.4048, 0.0001));
    }
    expect(TankFireRateLevel.values.map((level) => level.level), [
      1,
      2,
      3,
      4,
      5,
      6,
    ]);
  });

  test('next advances one level and wraps level six to level one', () {
    expect(TankFireRateLevel.level1.next, TankFireRateLevel.level2);
    expect(TankFireRateLevel.level5.next, TankFireRateLevel.level6);
    expect(TankFireRateLevel.level6.next, TankFireRateLevel.level1);
  });
}
