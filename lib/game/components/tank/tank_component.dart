import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../cannon_mile_game.dart';
import 'tank_motion.dart';
import 'tank_skin.dart';
import 'tank_track_morph_component.dart';

class TankComponent extends PositionComponent
    with HasGameReference<CannonMileGame> {
  TankComponent({this.skin = TankSkin.defaultSkin})
    : super(size: Vector2(tankWidth, tankHeight), anchor: Anchor.bottomCenter);

  static const double tankWidth = 264;
  static const double tankHeight = 250;
  static const double cannonPivotX = 132;
  static const double cannonPivotY = 118;

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

  late final TankTrackMorphComponent _track;
  late final List<SpriteComponent> _roundWheels;
  late final SpriteComponent _cannon;
  late final SpriteComponent _base;

  final Vector2 _pointerTarget = Vector2.zero();
  bool _hasPointerTarget = false;
  double _horizontalVelocity = 0;
  double _trackCyclePosition = 0;
  double _smoothedAnimationSpeed = 0;
  double _baseShakePhase = 0;
  double _wheelBouncePhase = 0;

  double get horizontalVelocity => _horizontalVelocity;
  bool get isMoving =>
      _horizontalVelocity.abs() >= TankMotionTuning.stationarySpeed;
  double get cannonAngle => _cannon.angle;
  double get trackMorphProgress => _track.blend;
  double get smoothedAnimationSpeed => _smoothedAnimationSpeed;

  @visibleForTesting
  double get trackCyclePosition => _trackCyclePosition;

  @visibleForTesting
  SpriteComponent get basePart => _base;

  @visibleForTesting
  SpriteComponent get cannonPart => _cannon;

  @visibleForTesting
  TankTrackMorphComponent get trackPart => _track;

  @visibleForTesting
  List<SpriteComponent> get roundWheelParts => List.unmodifiable(_roundWheels);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await game.images.loadAll(skin.assetPaths);

    final firstTrackSprite = Sprite(
      game.images.fromCache(skin.firstTrackAsset),
      srcPosition: _trackSourcePosition.clone(),
      srcSize: _trackSize.clone(),
    );
    final secondTrackSprite = Sprite(
      game.images.fromCache(skin.secondTrackAsset),
      srcPosition: _trackSourcePosition.clone(),
      srcSize: _trackSize.clone(),
    );
    _track = TankTrackMorphComponent(
      firstSprite: firstTrackSprite,
      secondSprite: secondTrackSprite,
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

    _cannon = SpriteComponent(
      sprite: Sprite(game.images.fromCache(skin.cannonAsset)),
      size: _cannonSize.clone(),
      position: _cannonPosition.clone(),
      anchor: Anchor.bottomCenter,
      paint: createTankSpritePaint(),
      priority: 2,
    );
    _base = SpriteComponent(
      sprite: Sprite(game.images.fromCache(skin.baseAsset)),
      size: _baseSize.clone(),
      position: _basePosition.clone(),
      anchor: Anchor.bottomCenter,
      paint: createTankSpritePaint(),
      priority: 3,
    );

    await addAll([_track, ..._roundWheels, _cannon, _base]);
  }

  void setPointerTarget(Vector2 target) {
    _pointerTarget.setFrom(target);
    _hasPointerTarget = true;
  }

  void setInitialPointerAbove() {
    final pivot = absolutePositionOf(Vector2(cannonPivotX, cannonPivotY));
    setPointerTarget(Vector2(pivot.x, pivot.y - 300));
  }

  void clampToStage(double stageWidth) {
    final minimumX = TankMotionTuning.edgeMargin + tankWidth / 2;
    final maximumX = stageWidth - TankMotionTuning.edgeMargin - tankWidth / 2;
    position.x = position.x.clamp(minimumX, maximumX);
    if (position.x == minimumX && _horizontalVelocity < 0 ||
        position.x == maximumX && _horizontalVelocity > 0) {
      _horizontalVelocity = 0;
    }
  }

  @override
  void update(double dt) {
    _updateMovement(dt);
    _updateAim();
    _updateAnimations(dt);
    super.update(dt);
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
    final minimumX = TankMotionTuning.edgeMargin + tankWidth / 2;
    final maximumX = game.size.x - TankMotionTuning.edgeMargin - tankWidth / 2;
    final targetX = _pointerTarget.x.clamp(minimumX, maximumX);
    final offset = targetX - position.x;
    final desiredVelocity = desiredTankVelocity(offset);
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
    } else if (offset.abs() <= TankMotionTuning.deadZone &&
        _horizontalVelocity.abs() < TankMotionTuning.stationarySpeed) {
      _horizontalVelocity = 0;
    }
  }

  void _updateAim() {
    if (!_hasPointerTarget) {
      return;
    }
    final localTarget = absoluteToLocal(_pointerTarget);
    _cannon.angle = cannonAngleForTarget(
      horizontalOffset: localTarget.x - cannonPivotX,
      verticalOffset: localTarget.y - cannonPivotY,
      previousAngle: _cannon.angle,
    );
  }

  void _updateAnimations(double dt) {
    if (dt <= 0) {
      return;
    }

    final speedFraction = isMoving
        ? (_horizontalVelocity.abs() / TankMotionTuning.maxSpeed).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    _updateSmoothedAnimationSpeed(speedFraction, dt);
    _updateTrackMorph(speedFraction, dt);

    if (_smoothedAnimationSpeed == 0) {
      _base.angle = 0;
      _baseShakePhase = 0;
      _wheelBouncePhase = 0;
      for (var index = 0; index < _roundWheels.length; index++) {
        _roundWheels[index].position.setFrom(_wheelBaselines[index]);
      }
      return;
    }

    _baseShakePhase =
        (_baseShakePhase +
            dt * math.pi * 2 * TankMotionTuning.baseShakeFrequency) %
        (math.pi * 2);
    _base.angle =
        math.sin(_baseShakePhase) *
        TankMotionTuning.baseShakeDegrees *
        math.pi /
        180 *
        _smoothedAnimationSpeed;

    final wheelFrequency = wheelBounceFrequencyForSpeed(
      _smoothedAnimationSpeed,
    );
    _wheelBouncePhase =
        (_wheelBouncePhase + dt * math.pi * 2 * wheelFrequency) % (math.pi * 2);
    final wheelAmplitude = wheelBounceAmplitudeForSpeed(
      _smoothedAnimationSpeed,
    );
    for (var index = 0; index < _roundWheels.length; index++) {
      final baseline = _wheelBaselines[index];
      _roundWheels[index].position
        ..x = baseline.x
        ..y =
            baseline.y +
            math.sin(_wheelBouncePhase + _wheelPhases[index]) * wheelAmplitude;
    }
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

  void _updateTrackMorph(double speedFraction, double dt) {
    if (isMoving) {
      _trackCyclePosition +=
          _horizontalVelocity.sign *
          speedFraction *
          TankMotionTuning.trackMorphCyclesPerSecond *
          2 *
          dt;
      _trackCyclePosition %= 2;
      if (_trackCyclePosition < 0) {
        _trackCyclePosition += 2;
      }
    } else {
      final resetTarget = _trackCyclePosition <= 1 ? 0.0 : 2.0;
      _trackCyclePosition = moveTowards(
        _trackCyclePosition,
        resetTarget,
        dt / TankMotionTuning.trackResetDuration,
      );
      if (_trackCyclePosition == 2) {
        _trackCyclePosition = 0;
      }
    }

    final linearBlend = _trackCyclePosition <= 1
        ? _trackCyclePosition
        : 2 - _trackCyclePosition;
    _track.blend = (1 - math.cos(math.pi * linearBlend)) / 2;
  }
}
