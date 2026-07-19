import 'dart:math' as math;

enum TankBulletSpreadLevel {
  level1(1),
  level2(2),
  level3(3),
  level4(4),
  level5(5);

  const TankBulletSpreadLevel(this.projectileCount);

  static const double angleStepDegrees = 10;
  static const double _stepRadians = angleStepDegrees * math.pi / 180;
  static const List<List<double>> _cachedAngleOffsets = [
    [0],
    [-_stepRadians / 2, _stepRadians / 2],
    [-_stepRadians, 0, _stepRadians],
    [
      -_stepRadians * 1.5,
      -_stepRadians / 2,
      _stepRadians / 2,
      _stepRadians * 1.5,
    ],
    [-_stepRadians * 2, -_stepRadians, 0, _stepRadians, _stepRadians * 2],
  ];

  final int projectileCount;

  int get level => index + 1;

  List<double> get angleOffsets => _cachedAngleOffsets[index];

  TankBulletSpreadLevel get next =>
      TankBulletSpreadLevel.values[(index + 1) %
          TankBulletSpreadLevel.values.length];
}
