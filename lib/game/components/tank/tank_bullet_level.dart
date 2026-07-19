enum TankBulletLevel {
  level1(0, 1.0),
  level2(1, 0.96),
  level3(2, 0.89),
  level4(3, 0.87),
  level5(4, 0.70),
  level6(4, 0.82);

  const TankBulletLevel(this.artworkIndex, this.renderScale);

  /// Level six temporarily reuses bullet5 until bullet6.webp is supplied.
  final int artworkIndex;
  final double renderScale;

  int get shellArtworkIndex => switch (this) {
    TankBulletLevel.level1 || TankBulletLevel.level2 => 0,
    TankBulletLevel.level3 || TankBulletLevel.level4 => 1,
    TankBulletLevel.level5 => 2,
    TankBulletLevel.level6 => 3,
  };

  double get brightness => switch (this) {
    TankBulletLevel.level1 => 0.74,
    TankBulletLevel.level2 => 0.77,
    TankBulletLevel.level3 => 0.80,
    TankBulletLevel.level4 => 0.83,
    TankBulletLevel.level5 || TankBulletLevel.level6 => 1,
  };

  int get level => index + 1;

  int get damage => level;

  TankBulletLevel get next =>
      TankBulletLevel.values[(index + 1) % TankBulletLevel.values.length];
}
