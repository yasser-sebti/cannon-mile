import 'package:flame/components.dart';

import '../tank/tank_component.dart';

/// Immutable shared visual composition for one aircraft design.
///
/// Change [defaultGroupScale], or construct a copy with [withGroupScale], to
/// resize the body, fan, mount offsets, collision bounds, and spawn footprint
/// as one unit without retuning individual coordinates.
class EnemyPlaneVisualTemplate {
  EnemyPlaneVisualTemplate({
    required this.bodySprite,
    required List<Sprite> fanSprites,
    this.groupScale = defaultGroupScale,
  }) : assert(fanSprites.length == fanFrameCount),
       assert(groupScale > 0),
       fanSprites = List.unmodifiable(fanSprites);

  static const double defaultGroupScale = 1;
  static const int fanFrameCount = 10;
  static const double fanFrameWidth = 34.963;
  static const double fanFrameGap = 6.4157;
  static const double fanFrameStride = fanFrameWidth + fanFrameGap;
  static const double fanSheetHeight = 78;
  static const double fanVisualScale = 1.29;
  static const double fanMountInsetSourcePixels = -9.5;
  static const double fanMountDownSourcePixels = 16.25;

  final Sprite bodySprite;
  final List<Sprite> fanSprites;
  final double groupScale;

  Vector2 get size => bodySizeForSprite(bodySprite, groupScale: groupScale);

  double get sourceToWorldScale => size.x / bodySprite.srcSize.x;

  Vector2 get fanSize {
    final scale = sourceToWorldScale;
    return Vector2(
      fanFrameWidth * scale * fanVisualScale,
      fanSheetHeight * scale * fanVisualScale,
    );
  }

  Vector2 get fanPosition {
    final bodySize = size;
    final scale = bodySize.x / bodySprite.srcSize.x;
    return Vector2(
      bodySize.x - fanMountInsetSourcePixels * scale,
      bodySize.y / 2 + fanMountDownSourcePixels * scale,
    );
  }

  EnemyPlaneVisualTemplate withGroupScale(double scale) {
    return EnemyPlaneVisualTemplate(
      bodySprite: bodySprite,
      fanSprites: fanSprites,
      groupScale: scale,
    );
  }

  static Vector2 bodySizeForSprite(
    Sprite sprite, {
    double groupScale = defaultGroupScale,
  }) {
    assert(groupScale > 0);
    final width = TankComponent.renderedTankWidth * groupScale;
    return Vector2(width, width * sprite.srcSize.y / sprite.srcSize.x);
  }

  static double fanFrameSourceX(int index) {
    assert(index >= 0 && index < fanFrameCount);
    return index * fanFrameStride;
  }
}
