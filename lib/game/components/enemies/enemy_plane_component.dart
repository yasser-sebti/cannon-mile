import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../cannon_mile_game.dart';
import '../tank/tank_track_morph_component.dart';
import 'enemy_plane_visual_template.dart';

class EnemyPlaneComponent extends SpriteComponent
    with HasGameReference<CannonMileGame> {
  EnemyPlaneComponent({required EnemyPlaneVisualTemplate template})
    : _template = template,
      _fanSprites = template.fanSprites,
      _fanSize = template.fanSize,
      _fanPosition = template.fanPosition,
      super(
        sprite: template.bodySprite,
        size: template.size,
        position: Vector2.zero(),
        anchor: Anchor.center,
        paint: createTankSpritePaint(),
        priority: -10,
      );

  static const String assetPath = 'enemy/planes/scout-jet-default.webp';
  static const String fanAssetPath = 'enemy/planes/fan-animation.webp';
  static const int fanFrameCount = EnemyPlaneVisualTemplate.fanFrameCount;
  static const double fanFrameWidth = EnemyPlaneVisualTemplate.fanFrameWidth;
  static const double fanFrameGap = EnemyPlaneVisualTemplate.fanFrameGap;
  static const double fanFrameStride = EnemyPlaneVisualTemplate.fanFrameStride;
  static const double fanFramesPerSecond = 90;
  static const double fanSheetHeight = EnemyPlaneVisualTemplate.fanSheetHeight;
  static const double fanVisualScale = EnemyPlaneVisualTemplate.fanVisualScale;
  static const double fanMountInsetSourcePixels =
      EnemyPlaneVisualTemplate.fanMountInsetSourcePixels;
  static const double fanMountDownSourcePixels =
      EnemyPlaneVisualTemplate.fanMountDownSourcePixels;
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
  static final Paint _fanPaint = createTankSpritePaint();

  final EnemyPlaneVisualTemplate _template;
  final List<Sprite> _fanSprites;
  final Vector2 _fanSize;
  final Vector2 _fanPosition;
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
  double _fanPhase = 0;
  int _fanFrameIndex = 0;

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
  int get fanFrameIndex => _fanFrameIndex;
  double get fanPhase => _fanPhase;
  EnemyPlaneVisualTemplate get visualTemplate => _template;
  double get visualGroupScale => _template.groupScale;
  Vector2 get fanSize => _fanSize.clone();
  Vector2 get fanPosition => _fanPosition.clone();
  List<Sprite> get fanSprites => _fanSprites;
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

  static Vector2 sizeForSprite(
    Sprite sprite, {
    double groupScale = EnemyPlaneVisualTemplate.defaultGroupScale,
  }) {
    return EnemyPlaneVisualTemplate.bodySizeForSprite(
      sprite,
      groupScale: groupScale,
    );
  }

  static double fanFrameSourceX(int index) {
    assert(index >= 0 && index < fanFrameCount);
    return EnemyPlaneVisualTemplate.fanFrameSourceX(index);
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
    _fanPhase = 0;
    _fanFrameIndex = 0;
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
    _fanPhase = (_fanPhase + dt * fanFramesPerSecond) % fanFrameCount;
    _fanFrameIndex = _fanPhase.floor();
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
    _fanSprites[_fanFrameIndex].render(
      canvas,
      position: _fanPosition,
      size: _fanSize,
      anchor: Anchor.center,
      overridePaint: _fanPaint,
    );
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
