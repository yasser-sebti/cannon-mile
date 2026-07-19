import 'dart:ui';

import 'package:flame/components.dart';

import '../tank/tank_track_morph_component.dart';
import 'ground_hit_effect_component.dart';

class GroundHitSmokeComponent extends SpriteComponent {
  GroundHitSmokeComponent({
    required List<Sprite> sprites,
    required this.groundVelocityProvider,
  }) : assert(sprites.length == frameCount),
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
         anchor: Anchor.bottomCenter,
         paint: createTankSpritePaint(),
         priority: 19,
       );

  static const int frameCount = 5;
  static const int poolCapacity = 40;
  static const double activationDelay = 0.10;
  static const double frameDuration = 0.115;
  static const double activeDuration = frameDuration * frameCount;
  static const double duration = activationDelay + activeDuration;
  static const double fadeStartProgress = 0.38;
  static const double artworkScale = 1;
  static const double minimumVisualScale =
      GroundHitEffectComponent.minimumVisualScale;
  static const double maximumVisualScale =
      GroundHitEffectComponent.maximumVisualScale;
  static const double upwardDriftSpeed = 8;
  static const double finalSizeMultiplier = 0.86;
  static const double parkingCoordinate = -10000;
  static const List<String> assetPaths = [
    'effects/ground-hit-smoke1.webp',
    'effects/ground-hit-smoke2.webp',
    'effects/ground-hit-smoke3.webp',
    'effects/ground-hit-smoke4.webp',
    'effects/ground-hit-smoke5.webp',
  ];
  static final List<Color> _fadeColors = [
    for (var index = 0; index <= 64; index++)
      Color.fromARGB(((1 - index / 64) * 255).round(), 255, 255, 255),
  ];

  final List<Sprite> _sprites;
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
  bool get isVisible => _isActive && _age >= activationDelay;
  double get age => _age;
  double get fadeProgress => _fadeProgress;
  double get visualScale => _visualScale;
  int get frameIndex => _frameIndex;

  void activate({
    required double x,
    required double y,
    required double visualScale,
  }) {
    assert(
      visualScale >= minimumVisualScale && visualScale <= maximumVisualScale,
    );
    position.setValues(x, y);
    _age = 0;
    _fadeProgress = 0;
    _frameIndex = 0;
    _visualScale = visualScale;
    _isWarmup = false;
    _isActive = true;
    sprite = _sprites.first;
    size.setValues(
      _frameWidths.first * visualScale,
      _frameHeights.first * visualScale,
    );
    paint.color = const Color(0xFFFFFFFF);
  }

  void activateForWarmup({
    required double x,
    required double y,
    required int frameIndex,
  }) {
    activate(x: x, y: y, visualScale: 0.39);
    _isWarmup = true;
    _age = activationDelay;
    _frameIndex = frameIndex.clamp(0, frameCount - 1);
    sprite = _sprites[_frameIndex];
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
    position.x += groundVelocityProvider() * dt;
    if (_age < activationDelay) {
      return;
    }

    final smokeAge = _age - activationDelay;
    position.y -= upwardDriftSpeed * dt;
    final animationProgress = (smokeAge / activeDuration).clamp(0.0, 1.0);
    final exactFrame = smokeAge / frameDuration;
    final nextFrameIndex = exactFrame.floor().clamp(0, frameCount - 1);
    if (nextFrameIndex != _frameIndex) {
      _frameIndex = nextFrameIndex;
      sprite = _sprites[_frameIndex];
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
  void render(Canvas canvas) {
    if (isVisible) {
      super.render(canvas);
    }
  }
}
