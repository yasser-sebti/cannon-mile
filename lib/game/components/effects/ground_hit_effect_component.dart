import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../tank/tank_track_morph_component.dart';

class GroundHitFrameCache {
  const GroundHitFrameCache({required this.frames});

  final List<Sprite> frames;

  void dispose() {
    for (final frame in frames) {
      frame.image.dispose();
    }
  }
}

class GroundHitEffectComponent extends SpriteComponent {
  GroundHitEffectComponent({
    required this.frameCache,
    required this.groundVelocityProvider,
  }) : assert(frameCache.frames.length == frameCount),
       _frameWidths = [
         for (final sprite in frameCache.frames)
           sprite.srcSize.x * artworkScale,
       ],
       _frameHeights = [
         for (final sprite in frameCache.frames)
           sprite.srcSize.y * artworkScale,
       ],
       super(
         sprite: frameCache.frames.first,
         size: Vector2.zero(),
         position: Vector2.all(parkingCoordinate),
         anchor: Anchor.bottomCenter,
         paint: createTankSpritePaint(),
         priority: 20,
       );

  static const int frameCount = 10;
  static const int poolCapacity = 32;
  static const double frameDuration = 0.035;
  static const double duration = frameDuration * frameCount;
  static const double fadeStartProgress = 0.52;
  static const double artworkScale = 1;
  static const double minimumVisualScale = 0.30;
  static const double maximumVisualScale = 0.52;
  static const double minimumConsecutiveScaleDifference = 0.055;
  static const double glowSigma = 14;
  static const double glowAlpha = 0.76;
  static const double glowPadding = 34;
  static const double coreGlowSigma = 5;
  static const double coreGlowAlpha = 0.88;
  static const double finalSizeMultiplier = 0.82;
  static const double parkingCoordinate = -10000;
  static const List<String> assetPaths = [
    'effects/ground-hit1.webp',
    'effects/ground-hit2.webp',
    'effects/ground-hit3.webp',
    'effects/ground-hit4.webp',
    'effects/ground-hit5.webp',
    'effects/ground-hit6.webp',
    'effects/ground-hit7.webp',
    'effects/ground-hit8.webp',
    'effects/ground-hit9.webp',
    'effects/ground-hit10.webp',
  ];
  static final List<ui.Color> _fadeColors = [
    for (var index = 0; index <= 64; index++)
      ui.Color.fromARGB(((1 - index / 64) * 255).round(), 255, 255, 255),
  ];

  final GroundHitFrameCache frameCache;
  final List<double> _frameWidths;
  final List<double> _frameHeights;
  final double Function() groundVelocityProvider;
  bool _isActive = false;
  bool _isWarmup = false;
  double _age = 0;
  double _fadeProgress = 0;
  double _visualScale = 1;
  int _frameIndex = 0;

  bool get isActive => _isActive;
  bool get isWarmup => _isWarmup;
  bool get hasPrebakedGlow => true;
  bool get usesRuntimeBlur => false;
  double get age => _age;
  double get fadeProgress => _fadeProgress;
  double get visualScale => _visualScale;
  int get frameIndex => _frameIndex;
  int get cachedFrameCount => frameCache.frames.length;

  static Future<GroundHitFrameCache> bakeGlowingFrames(
    List<Sprite> sourceSprites,
  ) async {
    assert(sourceSprites.length == frameCount);
    final bakedFrames = <Sprite>[];
    final outerGlowPaint = createTankSpritePaint()
      ..color = const ui.Color.fromRGBO(255, 255, 255, glowAlpha)
      ..blendMode = ui.BlendMode.plus
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, glowSigma);
    final coreGlowPaint = createTankSpritePaint()
      ..color = const ui.Color.fromRGBO(255, 255, 255, coreGlowAlpha)
      ..blendMode = ui.BlendMode.plus
      ..maskFilter = const ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        coreGlowSigma,
      );
    final crispPaint = createTankSpritePaint();

    for (final source in sourceSprites) {
      final imageWidth = (source.srcSize.x + glowPadding * 2).ceil();
      final imageHeight = (source.srcSize.y + glowPadding * 2).ceil();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final renderPosition = Vector2(glowPadding, glowPadding);
      source.render(
        canvas,
        position: renderPosition,
        size: source.srcSize,
        overridePaint: outerGlowPaint,
      );
      source.render(
        canvas,
        position: renderPosition,
        size: source.srcSize,
        overridePaint: coreGlowPaint,
      );
      source.render(
        canvas,
        position: renderPosition,
        size: source.srcSize,
        overridePaint: crispPaint,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(imageWidth, imageHeight);
      picture.dispose();
      bakedFrames.add(Sprite(image));
    }
    return GroundHitFrameCache(frames: List.unmodifiable(bakedFrames));
  }

  void activate({
    required double x,
    required double y,
    required double visualScale,
  }) {
    assert(
      visualScale >= minimumVisualScale && visualScale <= maximumVisualScale,
    );
    position.setValues(x, y + glowPadding * visualScale);
    _age = 0;
    _fadeProgress = 0;
    _frameIndex = 0;
    _visualScale = visualScale;
    _isWarmup = false;
    _isActive = true;
    sprite = frameCache.frames.first;
    size.setValues(
      _frameWidths.first * visualScale,
      _frameHeights.first * visualScale,
    );
    paint.color = const ui.Color(0xFFFFFFFF);
  }

  void activateForWarmup({
    required double x,
    required double y,
    required int frameIndex,
  }) {
    activate(x: x, y: y, visualScale: 0.39);
    _isWarmup = true;
    _frameIndex = frameIndex.clamp(0, frameCount - 1);
    sprite = frameCache.frames[_frameIndex];
    size.setValues(
      _frameWidths[_frameIndex] * _visualScale,
      _frameHeights[_frameIndex] * _visualScale,
    );
  }

  void deactivate() {
    _isActive = false;
    _isWarmup = false;
    _age = 0;
    _fadeProgress = 0;
    _visualScale = 1;
    _frameIndex = 0;
    position.setValues(parkingCoordinate, parkingCoordinate);
    paint.color = const ui.Color(0xFFFFFFFF);
  }

  @override
  void update(double dt) {
    if (!_isActive || _isWarmup || dt <= 0) {
      return;
    }
    super.update(dt);
    _age += dt;
    if (_age >= duration) {
      deactivate();
      return;
    }
    position.x += groundVelocityProvider() * dt;

    final animationProgress = (_age / duration).clamp(0.0, 1.0);
    final exactFrame = _age / frameDuration;
    final nextFrameIndex = exactFrame.floor().clamp(0, frameCount - 1);
    if (nextFrameIndex != _frameIndex) {
      _frameIndex = nextFrameIndex;
      sprite = frameCache.frames[_frameIndex];
    }
    final frameProgress = exactFrame - exactFrame.floor();
    final easedFrameProgress =
        frameProgress * frameProgress * (3 - 2 * frameProgress);
    final followingFrame = (_frameIndex + 1).clamp(0, frameCount - 1);
    var targetWidth = _frameWidths[followingFrame];
    var targetHeight = _frameHeights[followingFrame];
    if (_frameIndex == frameCount - 1) {
      targetWidth *= finalSizeMultiplier;
      targetHeight *= finalSizeMultiplier;
    }
    size.setValues(
      (_frameWidths[_frameIndex] +
              (targetWidth - _frameWidths[_frameIndex]) * easedFrameProgress) *
          _visualScale,
      (_frameHeights[_frameIndex] +
              (targetHeight - _frameHeights[_frameIndex]) *
                  easedFrameProgress) *
          _visualScale,
    );

    final linearFade =
        ((animationProgress - fadeStartProgress) / (1 - fadeStartProgress))
            .clamp(0.0, 1.0);
    _fadeProgress = linearFade * linearFade * (3 - 2 * linearFade);
    paint.color = _fadeColors[(_fadeProgress * 64).round().clamp(0, 64)];
  }

  @override
  void render(ui.Canvas canvas) {
    if (_isActive) {
      super.render(canvas);
    }
  }
}
