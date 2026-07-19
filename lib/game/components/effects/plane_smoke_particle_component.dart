import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../tank/tank_track_morph_component.dart';

enum PlaneSmokeParticleType { burst, lingering }

class PlaneSmokeParticleComponent extends SpriteComponent {
  PlaneSmokeParticleComponent({
    required List<Sprite> sprites,
    required this.worldVelocityProvider,
  }) : assert(sprites.length == artworkCount),
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

  static const int artworkCount = 7;
  static const int poolCapacity = 256;
  static const double gravity = 180;
  static const double lingeringGravity = 12;
  static const double airResistance = 1.2;
  static const double lingeringAirResistance = 0.45;
  static const double angularResistance = 0.8;
  static const double lingeringAngularResistance = 0.55;
  static const double maximumSimulationStep = 1 / 120;
  static const double fadeStartProgress = 0.35;
  static const double lingeringFadeStartProgress = 0.55;
  static const double missileVisualScale = 0.62;
  static const double parkingCoordinate = -10000;
  static const List<double> targetHeights = [16, 18, 17, 10, 17, 9, 10];
  static const List<String> assetPaths = [
    'effects/smoke-particle1.webp',
    'effects/smoke-particle2.webp',
    'effects/smoke-particle3.webp',
    'effects/smoke-particle4.webp',
    'effects/smoke-particle5.webp',
    'effects/smoke-particle6.webp',
    'effects/smoke-particle7.webp',
  ];
  static final List<Color> _fadeColors = [
    for (var index = 0; index <= 64; index++)
      Color.fromARGB(((1 - index / 64) * 255).round(), 255, 255, 255),
  ];

  final List<Sprite> _sprites;
  final List<Vector2> _artworkSizes;
  final double Function() worldVelocityProvider;
  final Vector2 _velocity = Vector2.zero();
  bool _isActive = false;
  bool _isWarmup = false;
  PlaneSmokeParticleType _type = PlaneSmokeParticleType.burst;
  int _artworkIndex = 0;
  double _age = 0;
  double _activationDelay = 0;
  double _lifetime = 0;
  double _angularVelocity = 0;
  double _initialScale = 1;
  double _scaleProgress = 0;
  double _fadeProgress = 0;

  bool get isActive => _isActive;
  bool get isWarmup => _isWarmup;
  bool get isVisible => _isActive && _age >= _activationDelay;
  PlaneSmokeParticleType get type => _type;
  bool get isLingering => _type == PlaneSmokeParticleType.lingering;
  int get artworkIndex => _artworkIndex;
  double get age => _age;
  double get activationDelay => _activationDelay;
  double get lifetime => _lifetime;
  double get angularVelocity => _angularVelocity;
  double get scaleProgress => _scaleProgress;
  double get fadeProgress => _fadeProgress;
  Vector2 get velocity => _velocity.clone();
  double get inheritedWorldVelocity =>
      isLingering ? worldVelocityProvider() : 0;

  static Vector2 sizeForSprite(Sprite sprite, int artworkIndex) {
    final height = targetHeights[artworkIndex];
    return Vector2(sprite.srcSize.x * height / sprite.srcSize.y, height);
  }

  void activate({
    required PlaneSmokeParticleType type,
    required int artworkIndex,
    required double x,
    required double y,
    required double velocityX,
    required double velocityY,
    required double angularVelocity,
    required double activationDelay,
    required double lifetime,
    required double initialScale,
  }) {
    assert(artworkIndex >= 0 && artworkIndex < artworkCount);
    assert(activationDelay >= 0);
    assert(lifetime > 0);
    _type = type;
    _artworkIndex = artworkIndex;
    sprite = _sprites[artworkIndex];
    size.setFrom(_artworkSizes[artworkIndex]);
    position.setValues(x, y);
    _velocity.setValues(velocityX, velocityY);
    angle = 0;
    _angularVelocity = angularVelocity;
    _activationDelay = activationDelay;
    _lifetime = lifetime;
    _initialScale = initialScale;
    _scaleProgress = 0.65;
    _fadeProgress = 0;
    scale.setValues(
      initialScale * _scaleProgress,
      initialScale * _scaleProgress,
    );
    _age = 0;
    _isWarmup = false;
    _isActive = true;
    paint.color = const Color(0xFFFFFFFF);
  }

  void activateForWarmup({
    required int artworkIndex,
    required double x,
    required double y,
  }) {
    activate(
      type: PlaneSmokeParticleType.burst,
      artworkIndex: artworkIndex,
      x: x,
      y: y,
      velocityX: 0,
      velocityY: 0,
      angularVelocity: 0,
      activationDelay: 0,
      lifetime: 1,
      initialScale: 1,
    );
    _isWarmup = true;
    _scaleProgress = 1;
    scale.setValues(1, 1);
  }

  void deactivate() {
    _isActive = false;
    _isWarmup = false;
    _type = PlaneSmokeParticleType.burst;
    _age = 0;
    _activationDelay = 0;
    _lifetime = 0;
    _angularVelocity = 0;
    _initialScale = 1;
    _scaleProgress = 0;
    _fadeProgress = 0;
    _velocity.setZero();
    scale.setValues(1, 1);
    position.setValues(parkingCoordinate, parkingCoordinate);
    paint.color = const Color(0xFFFFFFFF);
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
    if (_age < _activationDelay) {
      return;
    }
    final lifeAge = _age - _activationDelay;
    if (lifeAge >= _lifetime) {
      deactivate();
      return;
    }

    final activeAirResistance = isLingering
        ? lingeringAirResistance
        : airResistance;
    final activeGravity = isLingering ? lingeringGravity : gravity;
    final activeAngularResistance = isLingering
        ? lingeringAngularResistance
        : angularResistance;
    _velocity
      ..x *= math.exp(-activeAirResistance * dt)
      ..y =
          _velocity.y * math.exp(-activeAirResistance * dt) +
          activeGravity * dt;
    _angularVelocity *= math.exp(-activeAngularResistance * dt);
    position
      ..x += (_velocity.x + inheritedWorldVelocity) * dt
      ..y += _velocity.y * dt;
    angle += _angularVelocity * dt;

    final progress = (lifeAge / _lifetime).clamp(0.0, 1.0);
    final growthEndProgress = isLingering ? 0.30 : 0.22;
    final peakScale = isLingering ? 1.20 : 1.10;
    if (progress < growthEndProgress) {
      final growth = progress / growthEndProgress;
      final easedGrowth = growth * growth * (3 - 2 * growth);
      _scaleProgress = 0.65 + (peakScale - 0.65) * easedGrowth;
    } else {
      final decay = ((progress - growthEndProgress) / (1 - growthEndProgress))
          .clamp(0.0, 1.0);
      final easedDecay = decay * decay * (3 - 2 * decay);
      _scaleProgress = peakScale * (1 - easedDecay);
    }
    final visualScale = _initialScale * _scaleProgress;
    scale.setValues(visualScale, visualScale);

    final activeFadeStartProgress = isLingering
        ? lingeringFadeStartProgress
        : fadeStartProgress;
    final linearFade =
        ((progress - activeFadeStartProgress) / (1 - activeFadeStartProgress))
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
