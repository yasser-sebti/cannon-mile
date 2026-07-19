class TankSkin {
  const TankSkin({
    required this.baseAsset,
    required this.cannonAsset,
    required this.roundWheelAsset,
    required this.trackAssets,
    required this.muzzleFlashAssets,
    required this.bulletAssets,
    required this.bulletShellAssets,
  });

  static const defaultSkin = TankSkin(
    baseAsset: 'tank skins/default-skin/base-tank.webp',
    cannonAsset: 'tank skins/default-skin/tank-canon.webp',
    roundWheelAsset: 'tank skins/default-skin/wheel-rounded.webp',
    trackAssets: [
      'tank skins/default-skin/wheel1.webp',
      'tank skins/default-skin/wheel2.webp',
      'tank skins/default-skin/wheel3.webp',
      'tank skins/default-skin/wheel4.webp',
    ],
    muzzleFlashAssets: [
      'effects/fire1.webp',
      'effects/fire2_1.webp',
      'effects/fire3_1.webp',
      'effects/fire4_1.webp',
    ],
    bulletAssets: [
      'effects/bullet1.webp',
      'effects/bullet2.webp',
      'effects/bullet3.webp',
      'effects/bullet4.webp',
      'effects/bullet5.webp',
    ],
    bulletShellAssets: [
      'effects/bulletshell1.webp',
      'effects/bulletshell2.webp',
      'effects/bulletshell3.webp',
      'effects/bulletshell4.webp',
    ],
  );

  final String baseAsset;
  final String cannonAsset;
  final String roundWheelAsset;
  final List<String> trackAssets;
  final List<String> muzzleFlashAssets;
  final List<String> bulletAssets;
  final List<String> bulletShellAssets;

  List<String> get assetPaths => [
    baseAsset,
    cannonAsset,
    roundWheelAsset,
    ...trackAssets,
    ...muzzleFlashAssets,
    ...bulletAssets,
    ...bulletShellAssets,
  ];
}
