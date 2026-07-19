import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../tank/tank_track_morph_component.dart';

class PlaneSmokeComponent extends SpriteComponent {
  PlaneSmokeComponent({required List<Sprite> sprites})
    : assert(sprites.length == frameCount),
      _sprites = sprites,
      _frameWidths = [
        for (final sprite in sprites) sprite.srcSize.x * artworkScale,
      ],
      _frameHeights = [
        for (final sprite in sprites) sprite.srcSize.y * artworkScale,
      ],
      super(
        sprite: sprites.first,
        size: Vector2.zero(),
        position: Vector2.all(parkingCoordinate),
        anchor: Anchor.center,
        paint: createTankSpritePaint(),
        priority: 5,
      );

  static const int frameCount = 6;
  static const int poolCapacity = 12;
  static const double activationDelay = 0;
  static const double frameDuration = 0.060;
  static const double duration = frameDuration * frameCount;
  static const double fadeStartProgress = 0.42;
  static const double artworkScale = 0.48;
  static const double horizontalDrag = 3.5;
  static const double upwardDriftSpeed = 22;
  static const double finalSizeMultiplier = 0.88;
  static const double parkingCoordinate = -10000;
  static const List<String> assetPaths = [
    'effects/smoke1.webp',
    'effects/smoke2.webp',
    'effects/smoke3.webp',
    'effects/smoke4.webp',
    'effects/smoke5.webp',
    'effects/smoke6.webp',
  ];
  static final List<Color> _fadeColors = [
    for (var index = 0; index <= 64; index++)
      Color.fromARGB(((1 - index / 64) * 255).round(), 255, 255, 255),
  ];

  final List<Sprite> _sprites;
  final List<double> _frameWidths;
  final List<double> _frameHeights;
  bool _isActive = false;
  bool _isWarmup = false;
  double _age = 0;
  double _horizontalVelocity = 0;
  double _fadeProgress = 0;
  double _sizeProgress = 0;
  int _frameIndex = 0;

  bool get isActive => _isActive;
  bool get isWarmup => _isWarmup;
  bool get isDelayComplete => true;
  bool get isVisible => _isActive;
  double get age => _age;
  double get horizontalVelocity => _horizontalVelocity;
  double get fadeProgress => _fadeProgress;
  double get sizeProgress => _sizeProgress;
  int get frameIndex => _frameIndex;

  void activate({
    required double x,
    required double y,
    required double horizontalVelocity,
  }) {
    position.setValues(x, y);
    _horizontalVelocity = horizontalVelocity;
    _age = 0;
    _fadeProgress = 0;
    _sizeProgress = 0;
    _frameIndex = 0;
    _isWarmup = false;
    _isActive = true;
    sprite = _sprites.first;
    size.setValues(_frameWidths.first, _frameHeights.first);
    paint.color = const Color(0xFFFFFFFF);
  }

  void activateForWarmup({
    required double x,
    required double y,
    required int frameIndex,
  }) {
    activate(x: x, y: y, horizontalVelocity: 0);
    _isWarmup = true;
    _age = 0;
    _frameIndex = frameIndex.clamp(0, frameCount - 1);
    sprite = _sprites[_frameIndex];
    size.setValues(_frameWidths[_frameIndex], _frameHeights[_frameIndex]);
  }

  void deactivate() {
    _isActive = false;
    _isWarmup = false;
    _age = 0;
    _horizontalVelocity = 0;
    _fadeProgress = 0;
    _sizeProgress = 0;
    _frameIndex = 0;
    position.setValues(parkingCoordinate, parkingCoordinate);
    paint.color = const Color(0xFFFFFFFF);
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

    _horizontalVelocity *= math.exp(-horizontalDrag * dt);
    position
      ..x += _horizontalVelocity * dt
      ..y -= upwardDriftSpeed * dt;

    final animationProgress = (_age / duration).clamp(0.0, 1.0);
    final exactFrame = _age / frameDuration;
    final nextFrameIndex = exactFrame.floor().clamp(0, frameCount - 1);
    if (nextFrameIndex != _frameIndex) {
      _frameIndex = nextFrameIndex;
      sprite = _sprites[_frameIndex];
    }
    final frameProgress = exactFrame - exactFrame.floor();
    _sizeProgress = frameProgress * frameProgress * (3 - 2 * frameProgress);
    final followingFrame = (_frameIndex + 1).clamp(0, frameCount - 1);
    var targetWidth = _frameWidths[followingFrame];
    var targetHeight = _frameHeights[followingFrame];
    if (_frameIndex == frameCount - 1) {
      targetWidth *= finalSizeMultiplier;
      targetHeight *= finalSizeMultiplier;
    }
    size.setValues(
      _frameWidths[_frameIndex] +
          (targetWidth - _frameWidths[_frameIndex]) * _sizeProgress,
      _frameHeights[_frameIndex] +
          (targetHeight - _frameHeights[_frameIndex]) * _sizeProgress,
    );

    final linearFade =
        ((animationProgress - fadeStartProgress) / (1 - fadeStartProgress))
            .clamp(0.0, 1.0);
    _fadeProgress = linearFade * linearFade * (3 - 2 * linearFade);
    final fadeColorIndex = (_fadeProgress * 64).round().clamp(0, 64);
    paint.color = _fadeColors[fadeColorIndex];
  }

  @override
  void render(Canvas canvas) {
    if (isVisible) {
      super.render(canvas);
    }
  }
}
