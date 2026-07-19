import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import 'tank_bullet_level.dart';
import 'tank_track_morph_component.dart';

class TankBulletShellComponent extends SpriteComponent {
  TankBulletShellComponent({
    required List<Sprite> sprites,
    required this.groundLineProvider,
    required this.groundDriftVelocityProvider,
    required this.onFirstGroundImpact,
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
         priority: 1,
       );

  static const int artworkCount = 4;
  static const int poolCapacity = 24;
  static const double parkingCoordinate = -10000;
  static const double gravity = 1100;
  static const double minimumEjectionSpeed = 170;
  static const double maximumEjectionSpeed = 230;
  static const double minimumUpwardLift = 180;
  static const double maximumUpwardLift = 230;
  static const double maximumInitialVerticalVelocity = -80;
  static const double minimumAngularSpeed = 9;
  static const double maximumAngularSpeed = 15;
  static const double horizontalAirResistance = 0.18;
  static const double angularAirResistance = 0.08;
  static const double maximumSimulationStep = 1 / 120;
  static const double bounceRestitution = 0.32;
  static const double impactHorizontalRetention = 0.72;
  static const double impactAngularRetention = 0.68;
  static const int maximumBounceCount = 2;
  static const double minimumBounceSpeed = 35;
  static const double groundFriction = 600;
  static const double groundAngularFriction = 24;
  static const double continuousGroundDriftSpeed = 300;
  static const double windStartClearance = 120;
  static const double windFullClearance = 20;
  static const double preImpactWindFraction = 0.70;
  static const double firstBounceWindFraction = 0.82;
  static const double secondBounceWindFraction = 0.94;
  static const double driftRampResponse = 10;
  static const double fadeDelay = 0.10;
  static const double fadeDuration = 0.40;
  static const double maximumLifetime = 2.5;
  static const List<double> targetHeights = [9.0, 10.5, 12.0, 13.5];
  static final List<Color> _fadeColors = [
    for (var index = 0; index <= 64; index++)
      Color.fromARGB(((1 - index / 64) * 255).round(), 255, 255, 255),
  ];

  final List<Sprite> _sprites;
  final List<Vector2> _artworkSizes;
  final double Function() groundLineProvider;
  final double Function() groundDriftVelocityProvider;
  final void Function() onFirstGroundImpact;
  final Vector2 _velocity = Vector2.zero();
  final Vector2 _tankLayerSize = Vector2.zero();
  TankBulletLevel _level = TankBulletLevel.level1;
  bool _isActive = false;
  bool _isWarmup = false;
  bool _isGrounded = false;
  bool _hasTriggeredGroundImpact = false;
  double _age = 0;
  double _angularVelocity = 0;
  double _groundedElapsed = 0;
  double _fadeProgress = 0;
  double _travelDriftFraction = 0;
  int _bounceCount = 0;

  TankBulletLevel get level => _level;
  int get artworkIndex => _level.shellArtworkIndex;
  bool get isActive => _isActive;
  bool get isGrounded => _isGrounded;
  bool get isWarmup => _isWarmup;
  bool get hasTriggeredGroundImpact => _hasTriggeredGroundImpact;
  double get age => _age;
  double get angularVelocity => _angularVelocity;
  double get fadeProgress => _fadeProgress;
  double get travelDriftFraction => _travelDriftFraction;
  int get bounceCount => _bounceCount;
  Vector2 get velocity => _velocity.clone();
  double get groundLine => groundLineProvider();
  double get groundDriftVelocity => groundDriftVelocityProvider();
  double get projectedBottomExtent =>
      math.sin(angle).abs() * size.x / 2 + math.cos(angle).abs() * size.y / 2;
  double get visibleBottom => position.y + projectedBottomExtent;

  static Vector2 sizeForSprite(Sprite sprite, int artworkIndex) {
    final height = targetHeights[artworkIndex];
    return Vector2(sprite.srcSize.x * height / sprite.srcSize.y, height);
  }

  /// Shell physics remain in world space, but their artwork is drawn by the
  /// tank's interleaved shell layer so the chassis can correctly occlude it.
  // SpriteComponent's normal world pass is intentionally suppressed here.
  @override
  // ignore: must_call_super
  void render(Canvas canvas) {}

  void renderFromTank(
    Canvas canvas, {
    required Vector2 localPosition,
    required double tankScale,
  }) {
    if (!_isActive || sprite == null) {
      return;
    }

    canvas.save();
    canvas.translate(localPosition.x, localPosition.y);
    canvas.rotate(angle);
    _tankLayerSize.setValues(size.x / tankScale, size.y / tankScale);
    sprite!.render(
      canvas,
      size: _tankLayerSize,
      anchor: Anchor.center,
      overridePaint: paint,
    );
    canvas.restore();
  }

  void activate({
    required TankBulletLevel level,
    required Vector2 position,
    required Vector2 velocity,
    required double angularVelocity,
    required double initialAngle,
  }) {
    _level = level;
    sprite = _sprites[artworkIndex];
    size.setFrom(_artworkSizes[artworkIndex]);
    this.position.setFrom(position);
    _velocity.setFrom(velocity);
    angle = initialAngle;
    _angularVelocity = angularVelocity;
    _age = 0;
    _groundedElapsed = 0;
    _fadeProgress = 0;
    _travelDriftFraction = 0;
    _bounceCount = 0;
    _isGrounded = false;
    _hasTriggeredGroundImpact = false;
    _isWarmup = false;
    _isActive = true;
    paint.color = const Color(0xFFFFFFFF);
  }

  void activateForWarmup({
    required TankBulletLevel level,
    required Vector2 position,
    required double angle,
  }) {
    activate(
      level: level,
      position: position,
      velocity: Vector2.zero(),
      angularVelocity: 0,
      initialAngle: angle,
    );
    _isWarmup = true;
  }

  void deactivate() {
    _isActive = false;
    _isWarmup = false;
    _isGrounded = false;
    _hasTriggeredGroundImpact = false;
    _age = 0;
    _angularVelocity = 0;
    _groundedElapsed = 0;
    _fadeProgress = 0;
    _travelDriftFraction = 0;
    _bounceCount = 0;
    _velocity.setZero();
    position.setValues(parkingCoordinate, parkingCoordinate);
    paint.color = const Color(0xFFFFFFFF);
  }

  @override
  void update(double dt) {
    if (!_isActive || _isWarmup || dt <= 0) {
      return;
    }
    super.update(dt);
    if (_age + dt >= maximumLifetime) {
      deactivate();
      return;
    }

    var remainingTime = dt;
    while (_isActive && remainingTime > 0.0000001) {
      final step = math.min(remainingTime, maximumSimulationStep);
      _integrate(step);
      remainingTime -= step;
    }
  }

  void _integrate(double dt) {
    _age += dt;
    if (_age >= maximumLifetime) {
      deactivate();
      return;
    }

    _updateTravelDrift(dt);

    if (_isGrounded) {
      _integrateGrounded(dt);
    } else {
      _integrateAirborne(dt);
    }
  }

  void _integrateAirborne(double dt) {
    _velocity
      ..x *= math.exp(-horizontalAirResistance * dt)
      ..y += gravity * dt;
    _angularVelocity *= math.exp(-angularAirResistance * dt);
    final bounceDriftVelocity = groundDriftVelocity * _travelDriftFraction;
    final airborneHorizontalVelocity = _bounceCount == 0
        ? _velocity.x + bounceDriftVelocity
        : _velocityWithDrift(
            physicalVelocity: _velocity.x,
            driftVelocity: bounceDriftVelocity,
            minimumDriftFraction: _bounceCount == 1 ? 0.50 : 0.75,
          );
    position
      ..x += airborneHorizontalVelocity * dt
      ..y += _velocity.y * dt;
    angle += _angularVelocity * dt;

    final ground = groundLine;
    if (visibleBottom < ground) {
      return;
    }

    position.y = ground - projectedBottomExtent;
    if (_velocity.y <= 0) {
      return;
    }
    if (!_hasTriggeredGroundImpact) {
      _hasTriggeredGroundImpact = true;
      onFirstGroundImpact();
    }
    if (_bounceCount < maximumBounceCount &&
        _velocity.y >= minimumBounceSpeed) {
      _bounceCount++;
      _velocity
        ..x *= impactHorizontalRetention
        ..y = -_velocity.y * bounceRestitution;
      _angularVelocity *= impactAngularRetention;
      return;
    }

    _isGrounded = true;
    _velocity
      ..x *= impactHorizontalRetention
      ..y = 0;
    _angularVelocity *= impactAngularRetention;
  }

  void _integrateGrounded(double dt) {
    _velocity.x = _moveTowardsZero(_velocity.x, groundFriction * dt);
    _angularVelocity = _moveTowardsZero(
      _angularVelocity,
      groundAngularFriction * dt,
    );
    final driftVelocity = groundDriftVelocity * _travelDriftFraction;
    final effectiveHorizontalVelocity = _velocityWithDrift(
      physicalVelocity: _velocity.x,
      driftVelocity: driftVelocity,
      minimumDriftFraction: 1,
    );
    position.x += effectiveHorizontalVelocity * dt;
    angle += _angularVelocity * dt;
    position.y = groundLine - projectedBottomExtent;

    _groundedElapsed += dt;
    if (_groundedElapsed <= fadeDelay) {
      return;
    }
    _fadeProgress = ((_groundedElapsed - fadeDelay) / fadeDuration).clamp(
      0.0,
      1.0,
    );
    final fadeColorIndex = (_fadeProgress * 64).round().clamp(0, 64);
    paint.color = _fadeColors[fadeColorIndex];
    if (_fadeProgress >= 1) {
      deactivate();
    }
  }

  double _moveTowardsZero(double value, double amount) {
    if (value > 0) {
      return math.max(0, value - amount);
    }
    return math.min(0, value + amount);
  }

  void _updateTravelDrift(double dt) {
    final targetFraction = _targetTravelDriftFraction();
    if (_travelDriftFraction == targetFraction) {
      return;
    }
    final responseBlend = 1 - math.exp(-driftRampResponse * dt);
    _travelDriftFraction +=
        (targetFraction - _travelDriftFraction) * responseBlend;
    if ((targetFraction - _travelDriftFraction).abs() < 0.0001) {
      _travelDriftFraction = targetFraction;
    }
  }

  double _targetTravelDriftFraction() {
    if (groundDriftVelocity == 0) {
      return 0;
    }
    if (_isGrounded) {
      return 1;
    }
    if (_bounceCount >= maximumBounceCount) {
      return secondBounceWindFraction;
    }
    if (_bounceCount == 1) {
      return firstBounceWindFraction;
    }

    final clearance = math.max(0.0, groundLine - visibleBottom);
    final proximity =
        ((windStartClearance - clearance) /
                (windStartClearance - windFullClearance))
            .clamp(0.0, 1.0);
    final easedProximity = proximity * proximity * (3 - 2 * proximity);
    return preImpactWindFraction * easedProximity;
  }

  double _velocityWithDrift({
    required double physicalVelocity,
    required double driftVelocity,
    required double minimumDriftFraction,
  }) {
    var effectiveVelocity = physicalVelocity + driftVelocity;
    if (driftVelocity < 0) {
      effectiveVelocity = math.min(
        effectiveVelocity,
        driftVelocity * minimumDriftFraction,
      );
    } else if (driftVelocity > 0) {
      effectiveVelocity = math.max(
        effectiveVelocity,
        driftVelocity * minimumDriftFraction,
      );
    }
    return effectiveVelocity;
  }
}
