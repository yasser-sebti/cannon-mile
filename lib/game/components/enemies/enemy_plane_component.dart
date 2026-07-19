import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../cannon_mile_game.dart';
import '../tank/tank_component.dart';
import '../tank/tank_track_morph_component.dart';

class EnemyPlaneComponent extends SpriteComponent
    with HasGameReference<CannonMileGame> {
  EnemyPlaneComponent({required Sprite sprite})
    : super(
        sprite: sprite,
        size: sizeForSprite(sprite),
        position: Vector2.zero(),
        anchor: Anchor.center,
        paint: createTankSpritePaint(),
        priority: -10,
      );

  static const String assetPath = 'enemy/planes/scout-jet-default.webp';
  static const double safeTopGap = 120;
  static const double maximumAltitudeFraction = 0.45;
  static const double spawnPadding = 36;
  static const double despawnPadding = 72;
  static const int maximumHealth = 6;
  static const double hitFlashDuration = 0.100;
  static const double minimumHitOverlayStrength = 0.48;
  static const double hitOverlayStrengthPerExtraDamage = 0.04;
  static const double maximumHitOverlayStrength = 0.65;
  static const int hitOverlayPaintCount = 16;

  static final List<Paint> _hitOverlayPaints = List<Paint>.generate(
    hitOverlayPaintCount,
    (index) {
      final strength =
          maximumHitOverlayStrength * index / (hitOverlayPaintCount - 1);
      return createTankSpritePaint()
        ..colorFilter = ColorFilter.mode(
          Color.fromRGBO(255, 0, 0, strength),
          BlendMode.srcIn,
        );
    },
    growable: false,
  );

  final Vector2 _previousPosition = Vector2.zero();
  bool _isActive = false;
  bool _movesRight = true;
  double _speed = 0;
  int _altitudeLane = 0;
  double _altitudeOffset = 0;
  int _currentHealth = maximumHealth;
  double _hitFlashRemaining = 0;
  double _hitOverlayPeakStrength = 0;
  double _missileDropRemaining = double.infinity;
  bool _missileDropRequested = false;

  bool get isActive => _isActive;
  bool get movesRight => _movesRight;
  double get speed => _speed;
  int get altitudeLane => _altitudeLane;
  double get altitudeOffset => _altitudeOffset;
  int get maxHealth => maximumHealth;
  int get currentHealth => _currentHealth;
  bool get isHitFlashing => _isActive && _hitFlashRemaining > 0;
  double get hitFlashRemaining => _hitFlashRemaining;
  double get hitOverlayPeakStrength => _hitOverlayPeakStrength;
  double get missileDropRemaining => _missileDropRemaining;
  bool get missileDropRequested => _missileDropRequested;
  double get hitOverlayStrength {
    if (!isHitFlashing) {
      return 0;
    }
    final remainingProgress = (_hitFlashRemaining / hitFlashDuration).clamp(
      0.0,
      1.0,
    );
    final easedProgress =
        remainingProgress * remainingProgress * (3 - 2 * remainingProgress);
    return _hitOverlayPeakStrength * easedProgress;
  }

  int get cachedHitOverlayPaintCount => _hitOverlayPaints.length;
  Vector2 get previousPosition => _previousPosition.clone();
  double get previousX => _previousPosition.x;
  double get previousY => _previousPosition.y;

  double get horizontalVelocity => movesRight ? speed : -speed;

  static Vector2 sizeForSprite(Sprite sprite) {
    final width = TankComponent.renderedTankWidth;
    return Vector2(width, width * sprite.srcSize.y / sprite.srcSize.x);
  }

  void activate({
    required bool movesRight,
    required double speed,
    required int altitudeLane,
    double altitudeOffset = 0,
    double missileDropDelay = 0.7,
    required Vector2 position,
  }) {
    assert(speed > 0);
    assert(missileDropDelay > 0);
    _movesRight = movesRight;
    _speed = speed;
    _altitudeLane = altitudeLane;
    _altitudeOffset = altitudeOffset;
    this.position.setFrom(position);
    _previousPosition.setFrom(position);
    _currentHealth = maximumHealth;
    _hitFlashRemaining = 0;
    _hitOverlayPeakStrength = 0;
    _missileDropRemaining = missileDropDelay;
    _missileDropRequested = false;
    _isActive = true;
  }

  bool consumeMissileDropRequest() {
    if (!_isActive || !_missileDropRequested) {
      return false;
    }
    _missileDropRequested = false;
    return true;
  }

  void scheduleNextMissileDrop(double delay) {
    assert(delay > 0);
    _missileDropRemaining = delay;
    _missileDropRequested = false;
  }

  bool takeDamage(int damage) {
    if (!_isActive || damage <= 0) {
      return false;
    }
    _currentHealth = math.max(0, _currentHealth - damage);
    final damageStrength = math.min(
      maximumHitOverlayStrength,
      minimumHitOverlayStrength +
          math.max(0, damage - 1) * hitOverlayStrengthPerExtraDamage,
    );
    _hitOverlayPeakStrength = math.max(hitOverlayStrength, damageStrength);
    _hitFlashRemaining = hitFlashDuration;
    return _currentHealth == 0;
  }

  void deactivate() {
    _isActive = false;
    _speed = 0;
    _altitudeOffset = 0;
    _hitFlashRemaining = 0;
    _hitOverlayPeakStrength = 0;
    _missileDropRemaining = double.infinity;
    _missileDropRequested = false;
    position.setValues(-10000, -10000);
    _previousPosition.setValues(-10000, -10000);
  }

  @override
  void update(double dt) {
    if (!_isActive || dt <= 0) {
      return;
    }
    super.update(dt);
    _previousPosition.setFrom(position);
    position.x += horizontalVelocity * dt;
    _hitFlashRemaining = math.max(0, _hitFlashRemaining - dt);
    if (!_missileDropRequested) {
      _missileDropRemaining -= dt;
      if (_missileDropRemaining <= 0) {
        _missileDropRemaining = 0;
        _missileDropRequested = true;
      }
    }
    final halfWidth = size.x / 2;
    final hasLeftStage = movesRight
        ? position.x - halfWidth > game.size.x + despawnPadding
        : position.x + halfWidth < -despawnPadding;
    if (hasLeftStage) {
      deactivate();
    }
  }

  @override
  // The sprite is drawn directly so the cached red overlay can be composited.
  // ignore: must_call_super
  void render(Canvas canvas) {
    if (!_isActive) {
      return;
    }
    if (movesRight) {
      _renderPlane(canvas);
      return;
    }
    canvas.save();
    canvas
      ..translate(size.x, 0)
      ..scale(-1, 1);
    _renderPlane(canvas);
    canvas.restore();
  }

  void _renderPlane(Canvas canvas) {
    sprite!.render(canvas, size: size, overridePaint: paint);
    final overlayStrength = hitOverlayStrength;
    if (overlayStrength <= 0) {
      return;
    }
    final paintIndex =
        (overlayStrength /
                maximumHitOverlayStrength *
                (hitOverlayPaintCount - 1))
            .round()
            .clamp(1, hitOverlayPaintCount - 1);
    sprite!.render(
      canvas,
      size: size,
      overridePaint: _hitOverlayPaints[paintIndex],
    );
  }
}
