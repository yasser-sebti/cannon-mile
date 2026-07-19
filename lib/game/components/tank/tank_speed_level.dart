import 'tank_motion.dart';

enum TankSpeedLevel {
  level1(600),
  level2(624),
  level3(648),
  level4(672),
  level5(696),
  level6(720);

  const TankSpeedLevel(this.maximumSpeed);

  final double maximumSpeed;

  double get maximumSpeedFraction => maximumSpeed / TankMotionTuning.maxSpeed;

  int get level => index + 1;

  TankSpeedLevel get next =>
      TankSpeedLevel.values[(index + 1) % TankSpeedLevel.values.length];
}
