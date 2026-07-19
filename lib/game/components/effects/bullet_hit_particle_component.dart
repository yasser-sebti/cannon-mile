import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../tank/tank_track_morph_component.dart';

class BulletHitParticleComponent extends SpriteComponent {
  BulletHitParticleComponent({required List<Sprite> sprites})
    : assert(sprites.length == artworkCount),
      _sprites = sprites,
      _artworkSizes = [
        for (var index = 0; index < sprites.length; index++)
          sizeForSprite(sprites[index], index),
      ],
      super(
        sprite: sprites.first,
        size: Vector2.zero(),
        position: Vector2.all(parkingCoordinate),
        anchor: Anchor.center,
        paint: createTankSpritePaint(),
        priority: 4,
      );

  static const int artworkCount = 3;
  static const int poolCapacity = 256;
  static const double parkingCoordinate = -10000;
  static const double gravity = 1000;
  static const double maximumSimulationStep = 1 / 120;
  static const List<double> targetHeights = [16.5, 21, 14];
  static const List<String> assetPaths = [
    'effects/particle1.webp',
    'effects/particle2.webp',
    'effects/particle3.webp',
  ];
  static const List<Color> tintColors = [
    Color(0xFFFFD166),
    Color(0xFFFF9F1C),
    Color(0xFFFF6B00),
  ];
  static final List<Paint> _tintPaints = [
    for (final color in tintColors)
      createTankSpritePaint()
        ..colorFilter = ColorFilter.mode(color, BlendMode.modulate),
  ];

  final List<Sprite> _sprites;
  final List<Vector2> _artworkSizes;
  final Vector2 _velocity = Vector2.zero();
  bool _isActive = false;
  bool _isWarmup = false;
  int _artworkIndex = 0;
  double _age = 0;
  double _lifetime = 0;
  double _angularVelocity = 0;
  double _initialScale = 1;
  double _scaleProgress = 1;

  bool get isActive => _isActive;
  bool get isWarmup => _isWarmup;
  int get artworkIndex => _artworkIndex;
  double get age => _age;
  double get lifetime => _lifetime;
  double get angularVelocity => _angularVelocity;
  double get scaleProgress => _scaleProgress;
  Vector2 get velocity => _velocity.clone();
  Color get tintColor => tintColors[_artworkIndex];
  Paint get tintPaint => _tintPaints[_artworkIndex];

  static Vector2 sizeForSprite(Sprite sprite, int artworkIndex) {
    final height = targetHeights[artworkIndex];
    return Vector2(sprite.srcSize.x * height / sprite.srcSize.y, height);
  }

  void activate({
    required int artworkIndex,
    required double x,
    required double y,
    required double velocityX,
    required double velocityY,
    required double angularVelocity,
    required double lifetime,
    required double initialScale,
  }) {
    assert(artworkIndex >= 0 && artworkIndex < artworkCount);
    assert(lifetime > 0);
    _artworkIndex = artworkIndex;
    sprite = _sprites[artworkIndex];
    size.setFrom(_artworkSizes[artworkIndex]);
    position.setValues(x, y);
    _velocity.setValues(velocityX, velocityY);
    angle = 0;
    _angularVelocity = angularVelocity;
    _lifetime = lifetime;
    _initialScale = initialScale;
    _scaleProgress = 1;
    scale.setValues(initialScale, initialScale);
    _age = 0;
    _isWarmup = false;
    _isActive = true;
  }

  void activateForWarmup({
    required int artworkIndex,
    required double x,
    required double y,
  }) {
    activate(
      artworkIndex: artworkIndex,
      x: x,
      y: y,
      velocityX: 0,
      velocityY: 0,
      angularVelocity: 0,
      lifetime: 1,
      initialScale: 1,
    );
    _isWarmup = true;
  }

  void deactivate() {
    _isActive = false;
    _isWarmup = false;
    _age = 0;
    _lifetime = 0;
    _angularVelocity = 0;
    _initialScale = 1;
    _scaleProgress = 1;
    _velocity.setZero();
    scale.setValues(1, 1);
    position.setValues(parkingCoordinate, parkingCoordinate);
  }

  @override
  void update(double dt) {
    if (!_isActive || _isWarmup || dt <= 0) {
      return;
    }
    super.update(dt);
    var remainingTime = dt;
    while (_isActive && remainingTime > 0.0000001) {
      final step = math.min(remainingTime, maximumSimulationStep);
      _integrate(step);
      remainingTime -= step;
    }
  }

  void _integrate(double dt) {
    _age += dt;
    if (_age >= _lifetime) {
      deactivate();
      return;
    }
    _velocity.y += gravity * dt;
    position
      ..x += _velocity.x * dt
      ..y += _velocity.y * dt;
    angle += _angularVelocity * dt;
    final progress = (_age / _lifetime).clamp(0.0, 1.0);
    final easedProgress = progress * progress * (3 - 2 * progress);
    _scaleProgress = 1 - easedProgress;
    final visualScale = _initialScale * _scaleProgress;
    scale.setValues(visualScale, visualScale);
  }

  @override
  // SpriteComponent's default pass cannot select the cached tint per artwork.
  // ignore: must_call_super
  void render(Canvas canvas) {
    if (!_isActive || sprite == null) {
      return;
    }
    sprite!.render(
      canvas,
      size: size,
      overridePaint: _tintPaints[_artworkIndex],
    );
  }
}
