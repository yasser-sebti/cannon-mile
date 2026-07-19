import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

Paint createTankSpritePaint({
  FilterQuality filterQuality = FilterQuality.high,
}) {
  return Paint()
    ..isAntiAlias = true
    ..filterQuality = filterQuality;
}

class TankTrackMorphCache {
  TankTrackMorphCache({
    required this.transitionFrames,
    required this.samplesPerTransition,
  });

  final List<List<Sprite>> transitionFrames;
  final int samplesPerTransition;

  void dispose() {
    for (final transition in transitionFrames) {
      for (final sprite in transition) {
        sprite.image.dispose();
      }
    }
  }
}

class TankTrackMorphComponent extends PositionComponent {
  TankTrackMorphComponent({
    required List<Sprite> sprites,
    required this.morphCache,
    required super.size,
    required super.position,
    required super.anchor,
    super.priority,
  }) : assert(sprites.length >= 2),
       assert(morphCache.transitionFrames.length == sprites.length),
       sprites = List.unmodifiable(sprites);

  static const int samplesPerTransition = 16;

  final List<Sprite> sprites;
  final TankTrackMorphCache morphCache;
  final Paint firstPaint = createTankSpritePaint();
  final Paint secondPaint = createTankSpritePaint();
  final Paint cachedPaint = createTankSpritePaint();

  double _blend = 0;
  double _phase = 0;
  double _linearBlend = 0;
  int _firstFrameIndex = 0;
  int _secondFrameIndex = 1;

  double get blend => _blend;
  double get phase => _phase;
  int get firstFrameIndex => _firstFrameIndex;
  int get secondFrameIndex => _secondFrameIndex;
  int get cachedMorphFrameCount =>
      morphCache.transitionFrames.length * morphCache.samplesPerTransition;
  Sprite get firstSprite => sprites[_firstFrameIndex];
  Sprite get secondSprite => sprites[_secondFrameIndex];

  set phase(double value) {
    final frameCount = sprites.length.toDouble();
    _phase = value % frameCount;
    if (_phase < 0) {
      _phase += frameCount;
    }
    _firstFrameIndex = _phase.floor() % sprites.length;
    _secondFrameIndex = (_firstFrameIndex + 1) % sprites.length;
    _linearBlend = _phase - _phase.floorToDouble();
    _blend = (1 - math.cos(math.pi * _linearBlend)) / 2;
  }

  static Future<TankTrackMorphCache> bakeMorphFrames({
    required List<Sprite> sprites,
    required Vector2 size,
  }) async {
    assert(sprites.length >= 2);
    final imageWidth = size.x.ceil();
    final imageHeight = size.y.ceil();
    final transitions = <List<Sprite>>[];

    for (var firstIndex = 0; firstIndex < sprites.length; firstIndex++) {
      final secondIndex = (firstIndex + 1) % sprites.length;
      final frames = <Sprite>[];
      for (var sample = 0; sample < samplesPerTransition; sample++) {
        final linearBlend = sample / (samplesPerTransition - 1);
        final easedBlend = (1 - math.cos(math.pi * linearBlend)) / 2;
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        final layerPaint = Paint();
        final firstPaint = createTankSpritePaint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - easedBlend)
          ..blendMode = BlendMode.srcOver;
        final secondPaint = createTankSpritePaint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: easedBlend)
          ..blendMode = BlendMode.plus;
        canvas.saveLayer(Rect.fromLTWH(0, 0, size.x, size.y), layerPaint);
        sprites[firstIndex].render(
          canvas,
          size: size,
          overridePaint: firstPaint,
        );
        sprites[secondIndex].render(
          canvas,
          size: size,
          overridePaint: secondPaint,
        );
        canvas.restore();
        final picture = recorder.endRecording();
        final image = await picture.toImage(imageWidth, imageHeight);
        picture.dispose();
        frames.add(Sprite(image));
      }
      transitions.add(List.unmodifiable(frames));
    }

    return TankTrackMorphCache(
      transitionFrames: List.unmodifiable(transitions),
      samplesPerTransition: samplesPerTransition,
    );
  }

  @override
  void render(Canvas canvas) {
    final sampleIndex = (_linearBlend * (samplesPerTransition - 1)).round();
    morphCache.transitionFrames[_firstFrameIndex][sampleIndex].render(
      canvas,
      size: size,
      overridePaint: cachedPaint,
    );
  }

  @override
  void onRemove() {
    morphCache.dispose();
    super.onRemove();
  }
}
