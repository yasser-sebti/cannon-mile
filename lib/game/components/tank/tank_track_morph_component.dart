import 'dart:ui';

import 'package:flame/components.dart';

Paint createTankSpritePaint() {
  return Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high;
}

class TankTrackMorphComponent extends PositionComponent {
  TankTrackMorphComponent({
    required this.firstSprite,
    required this.secondSprite,
    required super.size,
    required super.position,
    required super.anchor,
    super.priority,
  });

  final Sprite firstSprite;
  final Sprite secondSprite;

  final Paint firstPaint = createTankSpritePaint();
  final Paint secondPaint = createTankSpritePaint();
  final Paint _layerPaint = Paint();

  double _blend = 0;

  double get blend => _blend;

  set blend(double value) {
    _blend = value.clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    if (_blend <= 0) {
      firstPaint
        ..color = const Color(0xFFFFFFFF)
        ..blendMode = BlendMode.srcOver;
      firstSprite.render(canvas, size: size, overridePaint: firstPaint);
      return;
    }

    if (_blend >= 1) {
      secondPaint
        ..color = const Color(0xFFFFFFFF)
        ..blendMode = BlendMode.srcOver;
      secondSprite.render(canvas, size: size, overridePaint: secondPaint);
      return;
    }

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.x, size.y), _layerPaint);
    firstPaint
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - _blend)
      ..blendMode = BlendMode.srcOver;
    secondPaint
      ..color = const Color(0xFFFFFFFF).withValues(alpha: _blend)
      ..blendMode = BlendMode.plus;
    firstSprite.render(canvas, size: size, overridePaint: firstPaint);
    secondSprite.render(canvas, size: size, overridePaint: secondPaint);
    canvas.restore();
  }
}
