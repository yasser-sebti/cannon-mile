enum TankFireRateLevel {
  level1(5.376),
  level2(5.7808),
  level3(6.1856),
  level4(6.5904),
  level5(6.9952),
  level6(7.4);

  const TankFireRateLevel(this.shotsPerSecond);

  final double shotsPerSecond;

  int get level => index + 1;

  Duration get interval => Duration(
    microseconds: (Duration.microsecondsPerSecond / shotsPerSecond).round(),
  );

  TankFireRateLevel get next =>
      TankFireRateLevel.values[(index + 1) % TankFireRateLevel.values.length];
}
