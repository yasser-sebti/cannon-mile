import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../enemies/enemy_plane_component.dart';
import '../tank/tank_track_morph_component.dart';

class BulletHitFrameCache {
  const BulletHitFrameCache({
    required this.frames,
    required this.renderSize,
    required this.anchor,
  });

  final List<Sprite> frames;
  final Vector2 renderSize;
  final Anchor anchor;

  void dispose() {
    for (final frame in frames) {
      frame.image.dispose();
    }
  }
}

class BulletHitEffectComponent extends SpriteComponent {
  BulletHitEffectComponent({required this.frameCache})
    : assert(frameCache.frames.length == frameCount),
      super(
        sprite: frameCache.frames.first,
        size: Vector2.zero(),
        position: Vector2.all(parkingCoordinate),
        anchor: frameCache.anchor,
        angle: math.pi,
        paint: createTankSpritePaint(),
        priority: 3,
      );

  static const int frameCount = 10;
  static const int poolCapacity = 12;
  static const double duration = 0.070;
  static const double frameDuration = duration / frameCount;
  static const double minimumVisualScale = 0.24;
  static const double maximumVisualScale = 0.32;
  static const double glowSigma = 5;
  static const double glowAlpha = 0.65;
  static const double glowPadding = 15;
  static const double authoredWidth = 60;
  static const double authoredHeight = 125;
  static const double parkingCoordinate = -10000;
  static const List<String> assetPaths = [
    'effects/bullethit1.webp',
    'effects/bullethit2.webp',
    'effects/bullethit3.webp',
    'effects/bullethit4.webp',
    'effects/bullethit5.webp',
    'effects/bullethit6.webp',
    'effects/bullethit7.webp',
    'effects/bullethit8.webp',
    'effects/bullethit9.webp',
    'effects/bullethit10.webp',
  ];

  final BulletHitFrameCache frameCache;
  final Vector2 _attachmentOffset = Vector2.zero();
  EnemyPlaneComponent? _attachedPlane;
  bool _isActive = false;
  bool _isWarmup = false;
  double _age = 0;
  double _visualScale = minimumVisualScale;
  int _frameIndex = 0;

  bool get isActive => _isActive;
  bool get isWarmup => _isWarmup;
  bool get usesRuntimeGlow => false;
  bool get hasPrebakedGlow => true;
  double get age => _age;
  double get visualScale => _visualScale;
  int get frameIndex => _frameIndex;
  int get cachedFrameCount => frameCache.frames.length;
  EnemyPlaneComponent? get attachedPlane => _attachedPlane;

  static Future<BulletHitFrameCache> bakeGlowingFrames(
    List<Sprite> sourceSprites,
  ) async {
    assert(sourceSprites.length == frameCount);
    final imageWidth = (authoredWidth + glowPadding * 2).ceil();
    final imageHeight = (authoredHeight + glowPadding * 2).ceil();
    final rootX = imageWidth / 2;
    final rootY = glowPadding + authoredHeight;
    final renderPosition = Vector2(rootX, rootY);
    final glowPaint = createTankSpritePaint()
      ..colorFilter = const ui.ColorFilter.mode(
        ui.Color.fromRGBO(255, 132, 0, glowAlpha),
        ui.BlendMode.srcATop,
      )
      ..blendMode = ui.BlendMode.plus
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, glowSigma);
    final crispPaint = createTankSpritePaint();
    final frames = <Sprite>[];

    for (final source in sourceSprites) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      source.render(
        canvas,
        position: renderPosition,
        size: source.srcSize,
        anchor: Anchor.bottomCenter,
        overridePaint: glowPaint,
      );
      source.render(
        canvas,
        position: renderPosition,
        size: source.srcSize,
        anchor: Anchor.bottomCenter,
        overridePaint: crispPaint,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(imageWidth, imageHeight);
      picture.dispose();
      frames.add(Sprite(image));
    }
    return BulletHitFrameCache(
      frames: List.unmodifiable(frames),
      renderSize: Vector2(imageWidth.toDouble(), imageHeight.toDouble()),
      anchor: Anchor(0.5, rootY / imageHeight),
    );
  }

  void activate({
    required double x,
    required double y,
    required double visualScale,
    EnemyPlaneComponent? attachedPlane,
  }) {
    assert(
      visualScale >= minimumVisualScale && visualScale <= maximumVisualScale,
    );
    position.setValues(x, y);
    _visualScale = visualScale;
    size.setValues(
      frameCache.renderSize.x * visualScale,
      frameCache.renderSize.y * visualScale,
    );
    _attachedPlane = attachedPlane;
    if (attachedPlane == null) {
      _attachmentOffset.setZero();
    } else {
      _attachmentOffset.setValues(
        x - attachedPlane.position.x,
        y - attachedPlane.position.y,
      );
    }
    angle = math.pi;
    _age = 0;
    _frameIndex = 0;
    _isWarmup = false;
    _isActive = true;
    sprite = frameCache.frames.first;
  }

  void activateForWarmup({
    required double x,
    required double y,
    required int frameIndex,
    double visualScale = maximumVisualScale,
  }) {
    activate(x: x, y: y, visualScale: visualScale);
    _isWarmup = true;
    _frameIndex = frameIndex.clamp(0, frameCount - 1);
    sprite = frameCache.frames[_frameIndex];
  }

  void deactivate() {
    _isActive = false;
    _isWarmup = false;
    _attachedPlane = null;
    _attachmentOffset.setZero();
    _age = 0;
    _visualScale = minimumVisualScale;
    _frameIndex = 0;
    position.setValues(parkingCoordinate, parkingCoordinate);
  }

  @override
  void update(double dt) {
    if (!_isActive || _isWarmup || dt <= 0) {
      return;
    }
    super.update(dt);
    final plane = _attachedPlane;
    if (plane != null) {
      if (plane.isActive) {
        position.setValues(
          plane.position.x + _attachmentOffset.x,
          plane.position.y + _attachmentOffset.y,
        );
      } else {
        _attachedPlane = null;
      }
    }

    _age += dt;
    if (_age >= duration) {
      deactivate();
      return;
    }
    final nextFrame = (_age / frameDuration).floor().clamp(0, frameCount - 1);
    if (nextFrame != _frameIndex) {
      _frameIndex = nextFrame;
      sprite = frameCache.frames[nextFrame];
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (_isActive) {
      super.render(canvas);
    }
  }
}
