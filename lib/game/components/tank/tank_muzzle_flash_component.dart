import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import 'tank_track_morph_component.dart';

class TankMuzzleFlashFrameCache {
  TankMuzzleFlashFrameCache({
    required this.frames,
    required this.renderSize,
    required this.bottomPadding,
  });

  final List<Sprite> frames;
  final Vector2 renderSize;
  final double bottomPadding;

  void dispose() {
    for (final frame in frames) {
      frame.image.dispose();
    }
  }
}

class TankMuzzleFlashComponent extends PositionComponent {
  TankMuzzleFlashComponent({
    required List<Sprite> sprites,
    required this.frameCache,
    required super.position,
    required super.anchor,
    math.Random? random,
    super.priority,
  }) : assert(sprites.length == frameCount),
       assert(frameCache.frames.length == cachedFrameCount),
       sprites = List.unmodifiable(sprites),
       _random = random ?? math.Random(),
       super(size: Vector2(effectWidth, effectHeight)) {
    _cachedRenderPosition.setValues(
      effectWidth / 2,
      effectHeight + frameCache.bottomPadding,
    );
  }

  static const int frameCount = 4;
  static const int cachedFrameCount = 16;
  static const double renderScale = 0.78;
  static const double effectWidth = 102 * renderScale;
  static const double effectHeight = 198 * renderScale;
  static const double transitionDuration = 0.015;
  static const double totalDuration = transitionDuration * frameCount;
  static const double gaussianBlurSigma = 3.0;
  static const double gaussianGlowAlpha = 0.30;
  static const List<double> trailOffsets = [-3, -8, -13];
  static const List<double> trailAlphas = [0.22, 0.12, 0.06];
  static const List<double> trailLengthScales = [1.18, 1.45, 1.72];
  static const List<double> trailWidthScales = [0.94, 0.86, 0.78];

  final List<Sprite> sprites;
  final TankMuzzleFlashFrameCache frameCache;
  final math.Random _random;
  final ui.Paint cachedPaint = createTankSpritePaint(
    filterQuality: ui.FilterQuality.medium,
  );
  final Vector2 _cachedRenderPosition = Vector2.zero();
  late final List<Vector2> _renderedFrameSizes = [
    for (final sprite in sprites) sprite.srcSize * renderScale,
  ];

  double _elapsed = totalDuration;
  bool _isHorizontallyFlipped = false;

  bool get isVisible => _elapsed < totalDuration;
  bool get isHorizontallyFlipped => _isHorizontallyFlipped;
  bool get usesRuntimeBlur => false;
  int get renderCacheFrameCount => frameCache.frames.length;
  double get phase => (_elapsed / totalDuration).clamp(0.0, 1.0);
  double get trailStrength => isVisible ? 1 - phase : 0;

  int get firstFrameIndex {
    if (!isVisible) {
      return frameCount - 1;
    }
    return math.min((_elapsed / transitionDuration).floor(), frameCount - 1);
  }

  int? get secondFrameIndex {
    final first = firstFrameIndex;
    return isVisible && first < frameCount - 1 ? first + 1 : null;
  }

  double get blend {
    if (!isVisible) {
      return 1;
    }
    final linearBlend = (_elapsed % transitionDuration) / transitionDuration;
    return (1 - math.cos(math.pi * linearBlend)) / 2;
  }

  Vector2 renderedSizeForFrame(int index) => _renderedFrameSizes[index].clone();

  static Future<TankMuzzleFlashFrameCache> bakeFrames(
    List<Sprite> sprites,
  ) async {
    assert(sprites.length == frameCount);
    final padding = (gaussianBlurSigma * 3).ceilToDouble();
    final imageWidth = (effectWidth + padding * 2).ceil();
    final imageHeight = (effectHeight + padding * 2).ceil();
    final contentOffsetX = (imageWidth - effectWidth) / 2;
    final contentOffsetY = padding;
    final bottomPadding = imageHeight - contentOffsetY - effectHeight;
    final frameSizes = [
      for (final sprite in sprites) sprite.srcSize * renderScale,
    ];
    final renderPosition = Vector2(
      contentOffsetX + effectWidth / 2,
      contentOffsetY + effectHeight,
    );
    final trailPositions = [
      for (final offset in trailOffsets)
        Vector2(renderPosition.x, renderPosition.y + offset),
    ];
    final bakedFrames = <Sprite>[];

    for (var sample = 0; sample < cachedFrameCount; sample++) {
      final elapsed =
          (totalDuration - 0.0000001) * sample / (cachedFrameCount - 1);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final firstIndex = math.min(
        (elapsed / transitionDuration).floor(),
        frameCount - 1,
      );
      final secondIndex = firstIndex < frameCount - 1 ? firstIndex + 1 : null;
      final linearBlend = (elapsed % transitionDuration) / transitionDuration;
      final easedBlend = (1 - math.cos(math.pi * linearBlend)) / 2;
      final firstAlpha = 1 - easedBlend;
      final timelinePhase = elapsed / totalDuration;
      final trailStrength = math.sqrt(1 - timelinePhase);
      final dominantIndex = secondIndex != null && easedBlend >= 0.5
          ? secondIndex
          : firstIndex;

      if (firstAlpha > 0) {
        _renderBakedSprite(
          canvas,
          sprites[firstIndex],
          renderPosition,
          frameSizes[firstIndex],
          _bakePaint(
            alpha: firstAlpha * gaussianGlowAlpha,
            blendMode: ui.BlendMode.plus,
            blurSigma: gaussianBlurSigma,
          ),
        );
      }
      if (secondIndex != null && easedBlend > 0) {
        _renderBakedSprite(
          canvas,
          sprites[secondIndex],
          renderPosition,
          frameSizes[secondIndex],
          _bakePaint(
            alpha: easedBlend * gaussianGlowAlpha,
            blendMode: ui.BlendMode.plus,
            blurSigma: gaussianBlurSigma,
          ),
        );
      }

      for (var index = 0; index < trailOffsets.length; index++) {
        final sourceSize = frameSizes[dominantIndex];
        _renderBakedSprite(
          canvas,
          sprites[dominantIndex],
          trailPositions[index],
          Vector2(
            sourceSize.x * trailWidthScales[index],
            sourceSize.y * trailLengthScales[index],
          ),
          _bakePaint(
            alpha: trailAlphas[index] * trailStrength,
            blendMode: ui.BlendMode.plus,
          ),
        );
      }

      canvas.saveLayer(
        ui.Rect.fromLTWH(
          contentOffsetX,
          contentOffsetY,
          effectWidth,
          effectHeight,
        ),
        ui.Paint(),
      );
      if (firstAlpha > 0) {
        _renderBakedSprite(
          canvas,
          sprites[firstIndex],
          renderPosition,
          frameSizes[firstIndex],
          _bakePaint(alpha: firstAlpha),
        );
      }
      if (secondIndex != null && easedBlend > 0) {
        _renderBakedSprite(
          canvas,
          sprites[secondIndex],
          renderPosition,
          frameSizes[secondIndex],
          _bakePaint(alpha: easedBlend, blendMode: ui.BlendMode.plus),
        );
      }
      canvas.restore();

      final picture = recorder.endRecording();
      final image = await picture.toImage(imageWidth, imageHeight);
      picture.dispose();
      bakedFrames.add(Sprite(image));
    }

    return TankMuzzleFlashFrameCache(
      frames: List.unmodifiable(bakedFrames),
      renderSize: Vector2(imageWidth.toDouble(), imageHeight.toDouble()),
      bottomPadding: bottomPadding,
    );
  }

  static ui.Paint _bakePaint({
    required double alpha,
    ui.BlendMode blendMode = ui.BlendMode.srcOver,
    double? blurSigma,
  }) {
    return createTankSpritePaint(filterQuality: ui.FilterQuality.medium)
      ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: alpha)
      ..blendMode = blendMode
      ..maskFilter = blurSigma == null
          ? null
          : ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma);
  }

  static void _renderBakedSprite(
    ui.Canvas canvas,
    Sprite sprite,
    Vector2 position,
    Vector2 size,
    ui.Paint paint,
  ) {
    sprite.render(
      canvas,
      position: position,
      size: size,
      anchor: Anchor.bottomCenter,
      overridePaint: paint,
    );
  }

  void trigger({bool? horizontalFlip}) {
    _isHorizontallyFlipped = horizontalFlip ?? _random.nextBool();
    _elapsed = 0;
  }

  void finish() {
    _elapsed = totalDuration;
  }

  void advance(double dt) {
    if (dt <= 0 || !isVisible) {
      return;
    }
    _elapsed = math.min(totalDuration, _elapsed + dt);
  }

  @override
  void update(double dt) {
    // The tank advances this timeline alongside its frame-rate-independent
    // fire scheduler so a shot begins at the correct point within a frame.
  }

  @override
  void render(ui.Canvas canvas) {
    if (!isVisible) {
      return;
    }

    canvas.save();
    if (_isHorizontallyFlipped) {
      canvas
        ..translate(size.x, 0)
        ..scale(-1, 1);
    }
    final cacheIndex = math.min(
      (phase * cachedFrameCount).floor(),
      cachedFrameCount - 1,
    );
    frameCache.frames[cacheIndex].render(
      canvas,
      position: _cachedRenderPosition,
      size: frameCache.renderSize,
      anchor: Anchor.bottomCenter,
      overridePaint: cachedPaint,
    );
    canvas.restore();
  }

  @override
  void onRemove() {
    frameCache.dispose();
    super.onRemove();
  }
}
