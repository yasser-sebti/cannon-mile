import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../cannon_mile_game.dart';
import 'tank_bullet_component.dart';
import 'tank_bullet_level.dart';
import 'tank_bullet_shell_component.dart';
import 'tank_bullet_spread_level.dart';
import 'tank_fire_rate_level.dart';
import 'tank_movement_mode.dart';
import 'tank_motion.dart';
import 'tank_muzzle_flash_component.dart';
import 'tank_pointer_swipe_tracker.dart';
import 'tank_skin.dart';
import 'tank_speed_level.dart';
import 'tank_track_morph_component.dart';

class TankComponent extends PositionComponent
    with HasGameReference<CannonMileGame> {
  TankComponent({
    this.skin = TankSkin.defaultSkin,
    TankMovementMode initialMovementMode = TankMovementMode.continuous,
    TankFireRateLevel initialFireRateLevel = TankFireRateLevel.level1,
    TankBulletLevel initialBulletLevel = TankBulletLevel.level1,
    TankBulletSpreadLevel initialBulletSpreadLevel =
        TankBulletSpreadLevel.level1,
    TankSpeedLevel initialSpeedLevel = TankSpeedLevel.level6,
    math.Random? muzzleFlashRandom,
    math.Random? shellRandom,
  }) : _movementMode = initialMovementMode,
       _fireRateLevel = initialFireRateLevel,
       _bulletLevel = initialBulletLevel,
       _bulletSpreadLevel = initialBulletSpreadLevel,
       _speedLevel = initialSpeedLevel,
       _muzzleFlashRandom = muzzleFlashRandom ?? math.Random(),
       _shellRandom = shellRandom ?? math.Random(),
       super(
         size: Vector2(tankWidth, tankHeight),
         scale: Vector2.all(tankVisualScale),
         anchor: Anchor.bottomCenter,
       );

  static const double tankWidth = 264;
  static const double tankHeight = 250;
  static const double tankVisualScale = 0.70;
  static const double renderedTankWidth = tankWidth * tankVisualScale;
  static const double renderedTankHeight = tankHeight * tankVisualScale;
  static const double bulletDropSoundMinimumInterval = 0.18;
  static const double cannonPivotX = 132;
  static const double cannonPivotY = 112;
  static const double cannonArcHorizontalRadius = 18;
  static const double cannonArcVerticalDrop = 10;
  static final Vector2 _shellEjectionPort = Vector2(44, 76);

  static final Vector2 _trackSize = Vector2(264, 79);
  static final Vector2 _trackPosition = Vector2(132, 250);
  static final Vector2 _trackSourcePosition = Vector2(31, 19);
  static final Vector2 _baseSize = Vector2(248, 94);
  static final Vector2 _basePosition = Vector2(132, 182);
  static final Vector2 _cannonSize = Vector2(41, 117);
  static final Vector2 _cannonPosition = Vector2(cannonPivotX, cannonPivotY);
  static final List<Vector2> _wheelBaselines = [
    Vector2(52, 211),
    Vector2(132, 211),
    Vector2(212, 211),
  ];
  static const List<double> _wheelPhases = [
    0,
    math.pi * 2 / 3,
    math.pi * 4 / 3,
  ];

  final TankSkin skin;
  TankMovementMode _movementMode;
  TankFireRateLevel _fireRateLevel;
  TankBulletLevel _bulletLevel;
  TankBulletSpreadLevel _bulletSpreadLevel;
  TankSpeedLevel _speedLevel;
  final math.Random _muzzleFlashRandom;
  final math.Random _shellRandom;

  late final TankTrackMorphComponent _track;
  late final List<SpriteComponent> _roundWheels;
  late final SpriteComponent _cannon;
  late final TankMuzzleFlashComponent _muzzleFlash;
  late final List<Sprite> _bulletSprites;
  final List<TankBulletComponent> _bulletPool = [];
  late final List<Sprite> _bulletShellSprites;
  final List<TankBulletShellComponent> _bulletShellPool = [];
  late final _TankBulletShellRenderLayer _bulletShellRenderLayer;
  late final SpriteComponent _base;

  final Vector2 _pointerTarget = Vector2.zero();
  final TankPointerSwipeTracker _pointerSwipeTracker =
      TankPointerSwipeTracker();
  bool _hasPointerTarget = false;
  double _horizontalVelocity = 0;
  double _trackCyclePosition = 0;
  double _trackPlaybackDirection = 0;
  bool _isFastContinuousReverse = false;
  double _smoothedAnimationSpeed = 0;
  double _baseShakePhase = 0;
  double _wheelBouncePhase = 0;
  bool _triggerHeld = false;
  bool _rendererWarmupActive = false;
  final List<TankBulletComponent> _warmupBullets = [];
  final List<TankBulletShellComponent> _warmupShells = [];
  double _timeUntilNextShot = 0;
  double _bulletDropSoundCooldown = 0;
  int _shotsFired = 0;
  int _projectilesFired = 0;
  int _shellsEjected = 0;
  TankBulletComponent? _lastBullet;
  TankBulletShellComponent? _lastShell;
  final List<TankBulletComponent?> _lastShotBulletSlots = List.filled(5, null);
  int _lastShotBulletCount = 0;
  final Vector2 _transformScratch = Vector2.zero();
  final Vector2 _shotOrigin = Vector2.zero();
  final Vector2 _shellOrigin = Vector2.zero();
  final Vector2 _shellVelocity = Vector2.zero();

  double get horizontalVelocity => _horizontalVelocity;
  TankMovementMode get movementMode => _movementMode;
  TankFireRateLevel get fireRateLevel => _fireRateLevel;
  TankBulletLevel get bulletLevel => _bulletLevel;
  TankBulletSpreadLevel get bulletSpreadLevel => _bulletSpreadLevel;
  TankSpeedLevel get speedLevel => _speedLevel;
  bool get triggerHeld => _triggerHeld;
  int get shotsFired => _shotsFired;
  int get projectilesFired => _projectilesFired;
  TankBulletComponent? get lastBullet => _lastBullet;
  List<TankBulletComponent> get lastShotBullets => List.unmodifiable([
    for (var index = 0; index < _lastShotBulletCount; index++)
      _lastShotBulletSlots[index]!,
  ]);
  int get bulletPoolCapacity => _bulletPool.length;
  int get availableBulletCount =>
      _bulletPool.where((bullet) => !bullet.isActive).length;
  int get shellPoolCapacity => _bulletShellPool.length;
  int get availableShellCount =>
      _bulletShellPool.where((shell) => !shell.isActive).length;
  int get shellsEjected => _shellsEjected;
  TankBulletShellComponent? get lastShell => _lastShell;
  double get bulletDropSoundCooldown => _bulletDropSoundCooldown;
  Iterable<TankBulletShellComponent> get activeShells =>
      _bulletShellPool.where((shell) => shell.isActive && !shell.isWarmup);

  List<TankBulletComponent> get bulletPoolForCollision => _bulletPool;
  bool get isScreenMoving =>
      _horizontalVelocity.abs() >= TankMotionTuning.stationarySpeed;
  bool get isMoving =>
      _movementMode == TankMovementMode.continuous || isScreenMoving;
  double get cannonAngle => _cannon.angle;
  double get trackMorphProgress => _track.blend;
  double get smoothedAnimationSpeed => _smoothedAnimationSpeed;
  double get pointerSwipeVelocity => _pointerSwipeTracker.sampledVelocity;
  double get swipeEdgeBoost => _pointerSwipeTracker.activeBoost;
  bool get isMuzzleFlashVisible => _muzzleFlash.isVisible;
  double get muzzleFlashPhase => _muzzleFlash.phase;
  int get muzzleFlashFirstFrame => _muzzleFlash.firstFrameIndex;
  int? get muzzleFlashSecondFrame => _muzzleFlash.secondFrameIndex;
  double get muzzleFlashBlend => _muzzleFlash.blend;
  bool get isMuzzleFlashHorizontallyFlipped =>
      _muzzleFlash.isHorizontallyFlipped;

  @visibleForTesting
  static Vector2 get shellEjectionPort => _shellEjectionPort.clone();

  @visibleForTesting
  double get trackCyclePosition => _trackCyclePosition;

  @visibleForTesting
  double get trackPlaybackDirection => _trackPlaybackDirection;

  @visibleForTesting
  bool get isFastContinuousReverse => _isFastContinuousReverse;

  @visibleForTesting
  Vector2 get pointerTarget => _pointerTarget.clone();

  @visibleForTesting
  SpriteComponent get basePart => _base;

  @visibleForTesting
  SpriteComponent get cannonPart => _cannon;

  @visibleForTesting
  TankMuzzleFlashComponent get muzzleFlashPart => _muzzleFlash;

  @visibleForTesting
  TankTrackMorphComponent get trackPart => _track;

  @visibleForTesting
  List<SpriteComponent> get roundWheelParts => List.unmodifiable(_roundWheels);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await game.images.loadAll(skin.assetPaths);

    final trackSprites = [
      for (final asset in skin.trackAssets)
        Sprite(
          game.images.fromCache(asset),
          srcPosition: _trackSourcePosition.clone(),
          srcSize: _trackSize.clone(),
        ),
    ];
    final trackMorphCache = await TankTrackMorphComponent.bakeMorphFrames(
      sprites: trackSprites,
      size: _trackSize,
    );
    game.completeLoadingUnits(1, 'Baking track animation');
    _track = TankTrackMorphComponent(
      sprites: trackSprites,
      morphCache: trackMorphCache,
      size: _trackSize.clone(),
      position: _trackPosition.clone(),
      anchor: Anchor.bottomCenter,
      priority: 0,
    );

    final roundWheelSprite = Sprite(
      game.images.fromCache(skin.roundWheelAsset),
    );
    _roundWheels = [
      for (final baseline in _wheelBaselines)
        SpriteComponent(
          sprite: roundWheelSprite,
          size: Vector2.all(54),
          position: baseline.clone(),
          anchor: Anchor.center,
          paint: createTankSpritePaint(),
          priority: 1,
        ),
    ];

    final cannonSprite = Sprite(game.images.fromCache(skin.cannonAsset));
    _cannon = SpriteComponent(
      sprite: cannonSprite,
      size: _cannonSize.clone(),
      position: _cannonPosition.clone(),
      anchor: Anchor.bottomCenter,
      paint: createTankSpritePaint(),
      priority: 2,
    );
    final muzzleSprites = [
      for (final asset in skin.muzzleFlashAssets)
        Sprite(game.images.fromCache(asset)),
    ];
    final muzzleFrameCache = await TankMuzzleFlashComponent.bakeFrames(
      muzzleSprites,
    );
    game.completeLoadingUnits(1, 'Baking muzzle effects');
    _muzzleFlash = TankMuzzleFlashComponent(
      sprites: muzzleSprites,
      frameCache: muzzleFrameCache,
      position: Vector2(_cannonSize.x / 2, 0),
      anchor: Anchor.bottomCenter,
      random: _muzzleFlashRandom,
      priority: 1,
    );
    final sourceBulletSprites = [
      for (final asset in skin.bulletAssets)
        Sprite(game.images.fromCache(asset)),
    ];
    _bulletSprites = await TankBulletComponent.bakeLevelSprites(
      sourceBulletSprites,
    );
    game.completeLoadingUnits(1, 'Preparing projectile visuals');
    _bulletShellSprites = [
      for (final asset in skin.bulletShellAssets)
        Sprite(game.images.fromCache(asset)),
    ];
    _bulletShellRenderLayer = _TankBulletShellRenderLayer(
      tank: this,
      shells: _bulletShellPool,
      priority: 4,
    );
    _cannon.add(_muzzleFlash);
    _base = SpriteComponent(
      sprite: Sprite(game.images.fromCache(skin.baseAsset)),
      size: _baseSize.clone(),
      position: _basePosition.clone(),
      anchor: Anchor.bottomCenter,
      paint: createTankSpritePaint(),
      priority: 3,
    );

    await addAll([
      _track,
      _cannon,
      ..._roundWheels,
      _base,
      _bulletShellRenderLayer,
    ]);
  }

  Future<void> initializeProjectilePool() async {
    if (_bulletPool.isNotEmpty) {
      return;
    }
    _bulletPool.addAll(
      List.generate(
        TankBulletComponent.poolCapacity,
        (_) => TankBulletComponent(
          sprites: _bulletSprites,
          collisionProfiles: game.collisionMaskCache.projectileProfiles,
        ),
        growable: false,
      ),
    );
    await game.world.addAll(_bulletPool);
  }

  Future<void> initializeBulletShellPool() async {
    if (_bulletShellPool.isNotEmpty) {
      return;
    }
    _bulletShellPool.addAll(
      List.generate(
        TankBulletShellComponent.poolCapacity,
        (_) => TankBulletShellComponent(
          sprites: _bulletShellSprites,
          groundLineProvider: () => position.y,
          groundDriftVelocityProvider: () =>
              _movementMode == TankMovementMode.continuous
              ? -TankBulletShellComponent.continuousGroundDriftSpeed
              : 0,
          onFirstGroundImpact: _onBulletShellGroundImpact,
        ),
        growable: false,
      ),
    );
    await game.world.addAll(_bulletShellPool);
  }

  void beginRendererWarmup(Vector2 center, {required bool horizontalFlip}) {
    _rendererWarmupActive = true;
    _warmupBullets.clear();
    _warmupShells.clear();
    for (var index = 0; index < TankBulletLevel.values.length; index++) {
      final bullet = _bulletPool[index];
      bullet.activate(
        level: TankBulletLevel.values[index],
        tankScale: tankVisualScale,
        position: Vector2(center.x + index * 24, center.y),
        cannonAngle: 0,
      );
      _warmupBullets.add(bullet);
    }
    const warmupLevels = [
      TankBulletLevel.level1,
      TankBulletLevel.level3,
      TankBulletLevel.level5,
      TankBulletLevel.level6,
    ];
    for (var index = 0; index < warmupLevels.length; index++) {
      final shell = _bulletShellPool[index];
      shell.activateForWarmup(
        level: warmupLevels[index],
        position: Vector2(center.x + index * 14, center.y + 36),
        angle: -0.45 + index * 0.3,
      );
      _warmupShells.add(shell);
    }
    _track.phase = 0.5;
    _muzzleFlash.trigger(horizontalFlip: horizontalFlip);
  }

  void continueRendererWarmup({required bool horizontalFlip}) {
    _track.phase = 0.5;
    _muzzleFlash.trigger(horizontalFlip: horizontalFlip);
    for (final shell in _warmupShells) {
      shell.angle = -shell.angle;
    }
  }

  void endRendererWarmup() {
    _rendererWarmupActive = false;
    for (final bullet in _warmupBullets) {
      bullet.deactivate();
    }
    _warmupBullets.clear();
    for (final shell in _warmupShells) {
      shell.deactivate();
    }
    _warmupShells.clear();
    _track.phase = _trackCyclePosition;
    _muzzleFlash.finish();
  }

  void setPointerTarget(
    Vector2 target, {
    Duration? timestamp,
    bool measureSwipe = false,
  }) {
    _pointerTarget.setFrom(target);
    _hasPointerTarget = true;
    if (measureSwipe && timestamp != null) {
      _pointerSwipeTracker.addSample(target.x, timestamp);
    } else {
      _pointerSwipeTracker.resetSample(target.x, timestamp);
    }
  }

  void setMovementMode(TankMovementMode mode) {
    if (_movementMode == mode) {
      return;
    }
    _movementMode = mode;
    _isFastContinuousReverse = false;
    if (mode == TankMovementMode.continuous && !isScreenMoving) {
      _trackPlaybackDirection = 1;
    }
  }

  void setFireRateLevel(TankFireRateLevel level) {
    _fireRateLevel = level;
    _timeUntilNextShot = math.min(_timeUntilNextShot, 1 / level.shotsPerSecond);
  }

  void setBulletLevel(TankBulletLevel level) {
    _bulletLevel = level;
  }

  void setBulletSpreadLevel(TankBulletSpreadLevel level) {
    _bulletSpreadLevel = level;
  }

  void setSpeedLevel(TankSpeedLevel level) {
    _speedLevel = level;
  }

  void setTriggerHeld(bool held) {
    if (_triggerHeld == held) {
      return;
    }
    _triggerHeld = held;
    if (held) {
      _timeUntilNextShot = 0;
    }
  }

  void setInitialPointerAbove() {
    final pivot = absolutePositionOf(Vector2(cannonPivotX, cannonPivotY));
    setPointerTarget(Vector2(pivot.x, pivot.y - 300));
  }

  void clampToStage(double stageWidth) {
    final minimumX = TankMotionTuning.edgeMargin + renderedTankWidth / 2;
    final maximumX =
        stageWidth - TankMotionTuning.edgeMargin - renderedTankWidth / 2;
    position.x = position.x.clamp(minimumX, maximumX);
    if (position.x == minimumX && _horizontalVelocity < 0 ||
        position.x == maximumX && _horizontalVelocity > 0) {
      _horizontalVelocity = 0;
    }
  }

  @override
  void update(double dt) {
    if (dt > 0 && _bulletDropSoundCooldown > 0) {
      _bulletDropSoundCooldown = math.max(0, _bulletDropSoundCooldown - dt);
    }
    _pointerSwipeTracker.advance(dt);
    _updateMovement(dt);
    _updateAim();
    _updateShooting(dt);
    _updateAnimations(dt);
    super.update(dt);
  }

  void _onBulletShellGroundImpact() {
    if (_bulletDropSoundCooldown > 0 || _rendererWarmupActive) {
      return;
    }
    game.fireSounds.playBulletDrop();
    _bulletDropSoundCooldown = bulletDropSoundMinimumInterval;
  }

  void _updateShooting(double dt) {
    const schedulerEpsilon = 0.0000001;
    if (dt < 0) {
      return;
    }
    if (dt == 0) {
      if (_triggerHeld && _timeUntilNextShot <= 0) {
        _fireShot();
      }
      return;
    }

    var remainingTime = dt;
    while (remainingTime > schedulerEpsilon) {
      if (!_triggerHeld) {
        _muzzleFlash.advance(remainingTime);
        return;
      }

      final timeToShot = math.max(0.0, _timeUntilNextShot);
      if (timeToShot > remainingTime + schedulerEpsilon) {
        _muzzleFlash.advance(remainingTime);
        _timeUntilNextShot -= remainingTime;
        return;
      }

      final eventTime = math.min(timeToShot, remainingTime);
      _muzzleFlash.advance(eventTime);
      remainingTime -= eventTime;
      _fireShot();
      if (remainingTime <= schedulerEpsilon) {
        return;
      }
    }
  }

  void _fireShot() {
    _shotsFired++;
    game.fireSounds.playForBulletLevel(_bulletLevel);
    _muzzleFlash.trigger();
    _ejectBulletShell();
    _cannonPointToWorld(_muzzleFlash.position, _shotOrigin);
    final angleOffsets = _bulletSpreadLevel.angleOffsets;
    _lastShotBulletCount = angleOffsets.length;
    for (var index = 0; index < angleOffsets.length; index++) {
      final bullet = _acquireBullet();
      bullet.activate(
        level: _bulletLevel,
        tankScale: tankVisualScale,
        position: _shotOrigin,
        cannonAngle: _cannon.angle + angleOffsets[index],
      );
      _lastShotBulletSlots[index] = bullet;
    }
    _projectilesFired += _lastShotBulletCount;
    _lastBullet = _lastShotBulletSlots[(_lastShotBulletCount - 1) ~/ 2];
    _timeUntilNextShot = 1 / _fireRateLevel.shotsPerSecond;
  }

  TankBulletComponent _acquireBullet() {
    for (final bullet in _bulletPool) {
      if (!bullet.isActive) {
        return bullet;
      }
    }
    var oldest = _bulletPool.first;
    for (var index = 1; index < _bulletPool.length; index++) {
      final candidate = _bulletPool[index];
      if (candidate.age > oldest.age) {
        oldest = candidate;
      }
    }
    return oldest;
  }

  void _ejectBulletShell() {
    final shell = _acquireBulletShell();
    final cannonAngle = _cannon.angle;
    final ejectionSpeed = _randomBetween(
      TankBulletShellComponent.minimumEjectionSpeed,
      TankBulletShellComponent.maximumEjectionSpeed,
    );
    final upwardLift = _randomBetween(
      TankBulletShellComponent.minimumUpwardLift,
      TankBulletShellComponent.maximumUpwardLift,
    );
    final verticalVelocity = math.min(
      TankBulletShellComponent.maximumInitialVerticalVelocity,
      math.sin(cannonAngle) * ejectionSpeed - upwardLift,
    );
    final angularMagnitude = _randomBetween(
      TankBulletShellComponent.minimumAngularSpeed,
      TankBulletShellComponent.maximumAngularSpeed,
    );
    final angularVelocity = _shellRandom.nextBool()
        ? angularMagnitude
        : -angularMagnitude;
    _cannonPointToWorld(_shellEjectionPort, _shellOrigin);
    _shellVelocity.setValues(
      _horizontalVelocity + math.cos(cannonAngle) * ejectionSpeed,
      verticalVelocity,
    );
    shell.activate(
      level: _bulletLevel,
      position: _shellOrigin,
      velocity: _shellVelocity,
      angularVelocity: angularVelocity,
      initialAngle: cannonAngle,
    );
    _lastShell = shell;
    _shellsEjected++;
  }

  TankBulletShellComponent _acquireBulletShell() {
    for (final shell in _bulletShellPool) {
      if (!shell.isActive) {
        return shell;
      }
    }
    var oldest = _bulletShellPool.first;
    for (var index = 1; index < _bulletShellPool.length; index++) {
      final candidate = _bulletShellPool[index];
      if (candidate.age > oldest.age) {
        oldest = candidate;
      }
    }
    return oldest;
  }

  void _cannonPointToWorld(Vector2 cannonPoint, Vector2 output) {
    _cannon.transform.localToGlobal(cannonPoint, output: _transformScratch);
    transform.localToGlobal(_transformScratch, output: output);
  }

  double _randomBetween(double minimum, double maximum) {
    return minimum + _shellRandom.nextDouble() * (maximum - minimum);
  }

  void _updateMovement(double dt) {
    if (!_hasPointerTarget || dt <= 0) {
      return;
    }

    var remainingTime = dt;
    while (remainingTime > 0.0000001) {
      final step = math.min(
        remainingTime,
        TankMotionTuning.maximumSimulationStep,
      );
      _integrateMovement(step);
      remainingTime -= step;
    }
  }

  void _integrateMovement(double dt) {
    final minimumX = TankMotionTuning.edgeMargin + renderedTankWidth / 2;
    final maximumX =
        game.size.x - TankMotionTuning.edgeMargin - renderedTankWidth / 2;
    final pointerX = _pointerTarget.x;
    final targetX = pointerX.clamp(minimumX, maximumX);
    final viewportEdgeProgress = viewportEdgeBoostForPointer(
      pointerX: pointerX,
      minimumTankX: minimumX,
      maximumTankX: maximumX,
      stageWidth: game.size.x,
    );
    final currentSpeedFraction =
        (_horizontalVelocity.abs() / _speedLevel.maximumSpeed).clamp(0.0, 1.0);
    final reachesViewportEdge = pointerX <= 0 || pointerX >= game.size.x;
    final offset = targetX - position.x;
    final speedGatedBoost =
        viewportEdgeProgress * maximumEdgeBoostForSpeed(currentSpeedFraction);
    final swipeBoost =
        viewportEdgeProgress *
        _pointerSwipeTracker.boostForDirection(offset.sign);
    final safeMaximumSpeedBoost = math.max(speedGatedBoost, swipeBoost);
    if (reachesViewportEdge &&
        offset.abs() <= TankMotionTuning.arrivalTolerance &&
        _horizontalVelocity.abs() < TankMotionTuning.stationarySpeed) {
      position.x = targetX;
      _horizontalVelocity = 0;
      if (_movementMode == TankMovementMode.continuous) {
        _trackPlaybackDirection = 1;
      }
      return;
    }
    final desiredVelocity = desiredTankVelocity(
      offset,
      viewportEdgeProgress: viewportEdgeProgress,
      maximumSpeedBoost: safeMaximumSpeedBoost,
      maximumSpeed: _speedLevel.maximumSpeed,
    );
    if (_movementMode == TankMovementMode.bossFight) {
      if (desiredVelocity != 0) {
        _trackPlaybackDirection = desiredVelocity.sign;
      } else if (_horizontalVelocity != 0) {
        _trackPlaybackDirection = _horizontalVelocity.sign;
      }
    }
    _horizontalVelocity = tankVelocityAfterStep(
      _horizontalVelocity,
      desiredVelocity,
      dt,
    );

    var nextX = position.x + _horizontalVelocity * dt;
    final crossesTarget = offset != 0 && (targetX - nextX).sign != offset.sign;
    if (crossesTarget) {
      nextX = targetX;
      _horizontalVelocity = 0;
    }

    final clampedX = nextX.clamp(minimumX, maximumX);
    position.x = clampedX;
    if (clampedX != nextX) {
      _horizontalVelocity = 0;
    } else if (reachesViewportEdge &&
        desiredVelocity.abs() <= TankMotionTuning.arrivalSpeed &&
        _horizontalVelocity.abs() < TankMotionTuning.stationarySpeed) {
      position.x = targetX;
      _horizontalVelocity = 0;
    } else if (desiredVelocity.abs() <= TankMotionTuning.arrivalSpeed &&
        _horizontalVelocity.abs() < TankMotionTuning.stationarySpeed) {
      _horizontalVelocity = 0;
    }
    if (_movementMode == TankMovementMode.continuous && !isScreenMoving) {
      _trackPlaybackDirection = 1;
    }
  }

  void _updateAim() {
    if (!_hasPointerTarget) {
      return;
    }
    final localTarget = absoluteToLocal(_pointerTarget);
    final angle = cannonAngleForTarget(
      horizontalOffset: localTarget.x - cannonPivotX,
      verticalOffset: localTarget.y - cannonPivotY,
      previousAngle: _cannon.angle,
    );
    final cannonX = cannonPivotX + math.sin(angle) * cannonArcHorizontalRadius;
    final cannonY =
        cannonPivotY + (1 - math.cos(angle)) * cannonArcVerticalDrop;
    _cannon
      ..angle = angle
      ..position.setValues(cannonX, cannonY);
  }

  void _updateAnimations(double dt) {
    if (dt <= 0) {
      return;
    }

    final speedFraction = isScreenMoving
        ? (_horizontalVelocity.abs() / _speedLevel.maximumSpeed).clamp(0.0, 1.0)
        : 0.0;
    final isContinuous = _movementMode == TankMovementMode.continuous;
    final animationTarget = isContinuous
        ? math.max(
                TankMotionTuning.continuousTravelSpeedFraction,
                speedFraction,
              ) *
              TankMotionTuning.continuousAnimationMultiplier
        : speedFraction;
    _updateSmoothedAnimationSpeed(animationTarget, dt);
    final normalizedAnimationSpeed = _smoothedAnimationSpeed.clamp(0.0, 1.0);
    final animationOverdrive = math.max(1.0, _smoothedAnimationSpeed);
    if (isContinuous) {
      _updateContinuousTrackDirection(speedFraction);
    }
    final trackCadenceMultiplier = isContinuous
        ? continuousTrackCadenceMultiplier(speedFraction) *
              continuousReverseTrackCadenceMultiplier(
                isBackingUp: _horizontalVelocity < 0,
                isFastReverse: _isFastContinuousReverse,
              )
        : 1.0;
    _updateTrackMorph(
      normalizedAnimationSpeed,
      animationOverdrive * trackCadenceMultiplier,
      dt,
      settleOnFrame: !isContinuous && !isScreenMoving,
    );
    if (_rendererWarmupActive) {
      _track.phase = 0.5;
    }

    if (_smoothedAnimationSpeed == 0) {
      _base.angle = 0;
      _baseShakePhase = 0;
      _wheelBouncePhase = 0;
      for (var index = 0; index < _roundWheels.length; index++) {
        _roundWheels[index].position.setFrom(_wheelBaselines[index]);
      }
      return;
    }

    final baseCadenceMultiplier =
        animationOverdrive *
        (isContinuous ? continuousBaseCadenceMultiplier(speedFraction) : 1.0);
    _baseShakePhase =
        (_baseShakePhase +
            dt *
                math.pi *
                2 *
                TankMotionTuning.baseShakeFrequency *
                baseCadenceMultiplier) %
        (math.pi * 2);
    _base.angle =
        math.sin(_baseShakePhase) *
        TankMotionTuning.baseShakeDegrees *
        math.pi /
        180 *
        _smoothedAnimationSpeed;

    final wheelFrequency =
        wheelBounceFrequencyForSpeed(normalizedAnimationSpeed) *
        animationOverdrive;
    _wheelBouncePhase =
        (_wheelBouncePhase + dt * math.pi * 2 * wheelFrequency) % (math.pi * 2);
    final wheelAmplitude =
        wheelBounceAmplitudeForSpeed(normalizedAnimationSpeed) *
        animationOverdrive;
    for (var index = 0; index < _roundWheels.length; index++) {
      final baseline = _wheelBaselines[index];
      _roundWheels[index].position
        ..x = baseline.x
        ..y =
            baseline.y +
            math.sin(_wheelBouncePhase + _wheelPhases[index]) * wheelAmplitude;
    }
  }

  void _updateContinuousTrackDirection(double speedFraction) {
    if (_horizontalVelocity >= 0) {
      _isFastContinuousReverse = false;
    } else if (_isFastContinuousReverse) {
      _isFastContinuousReverse =
          speedFraction >=
          TankMotionTuning.continuousFastReverseExitSpeedFraction;
    } else {
      _isFastContinuousReverse =
          speedFraction >=
          TankMotionTuning.continuousFastReverseEnterSpeedFraction;
    }
    _trackPlaybackDirection = _isFastContinuousReverse ? -1 : 1;
  }

  void _updateSmoothedAnimationSpeed(double target, double dt) {
    final response = target > _smoothedAnimationSpeed
        ? TankMotionTuning.animationSpeedRiseResponse
        : TankMotionTuning.animationSpeedFallResponse;
    final interpolation = 1 - math.exp(-response * dt);
    _smoothedAnimationSpeed +=
        (target - _smoothedAnimationSpeed) * interpolation;
    if (target == 0 &&
        _smoothedAnimationSpeed < TankMotionTuning.animationSettleThreshold) {
      _smoothedAnimationSpeed = 0;
    }
  }

  void _updateTrackMorph(
    double animationIntensity,
    double animationMultiplier,
    double dt, {
    required bool settleOnFrame,
  }) {
    final frameCount = _track.sprites.length.toDouble();
    if (settleOnFrame) {
      final targetFrame = _trackCyclePosition.roundToDouble();
      _trackCyclePosition = moveTowards(
        _trackCyclePosition,
        targetFrame,
        TankMotionTuning.bossTrackSettleFramesPerSecond * dt,
      );
    } else if (animationIntensity > 0 && _trackPlaybackDirection != 0) {
      _trackCyclePosition +=
          _trackPlaybackDirection *
          trackAnimationSpeedFraction(animationIntensity) *
          TankMotionTuning.trackMorphFramesPerSecond *
          animationMultiplier *
          dt;
    }
    _trackCyclePosition %= frameCount;
    if (_trackCyclePosition < 0) {
      _trackCyclePosition += frameCount;
    }

    _track.phase = _trackCyclePosition;
  }

  @override
  void onRemove() {
    for (final sprite in _bulletSprites) {
      sprite.image.dispose();
    }
    super.onRemove();
  }
}

class _TankBulletShellRenderLayer extends Component {
  _TankBulletShellRenderLayer({
    required this.tank,
    required this.shells,
    required super.priority,
  });

  final TankComponent tank;
  final List<TankBulletShellComponent> shells;
  final Vector2 _localPosition = Vector2.zero();

  @override
  void render(Canvas canvas) {
    for (final shell in shells) {
      if (!shell.isActive) {
        continue;
      }
      tank.parentToLocal(shell.position, output: _localPosition);
      shell.renderFromTank(
        canvas,
        localPosition: _localPosition,
        tankScale: TankComponent.tankVisualScale,
      );
    }
  }
}
