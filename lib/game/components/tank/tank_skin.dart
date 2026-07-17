class TankSkin {
  const TankSkin({
    required this.baseAsset,
    required this.cannonAsset,
    required this.roundWheelAsset,
    required this.firstTrackAsset,
    required this.secondTrackAsset,
  });

  static const defaultSkin = TankSkin(
    baseAsset: 'tank skins/default-skin/base-tank.webp',
    cannonAsset: 'tank skins/default-skin/tank-canon.webp',
    roundWheelAsset: 'tank skins/default-skin/wheel-rounded.webp',
    firstTrackAsset: 'tank skins/default-skin/wheel1.webp',
    secondTrackAsset: 'tank skins/default-skin/wheel2.webp',
  );

  final String baseAsset;
  final String cannonAsset;
  final String roundWheelAsset;
  final String firstTrackAsset;
  final String secondTrackAsset;

  List<String> get assetPaths => [
    baseAsset,
    cannonAsset,
    roundWheelAsset,
    firstTrackAsset,
    secondTrackAsset,
  ];
}
