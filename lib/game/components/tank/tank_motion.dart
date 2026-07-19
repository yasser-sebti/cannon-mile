import 'dart:math' as math;

abstract final class TankMotionTuning {
  static const double edgeMargin = 24;
  static const double groundInset = 80;
  static const double deadZone = 24;
  static const double fullSpeedDistance = 700;
  static const double distanceCurveLinearWeight = 0.3;
  static const double arrivalTolerance = 1;
  static const double arrivalSpeed = 3;
  static const double arrivalDuration = 0.30;
  static const double minimumMovementSpeed = 80;
  static const double maxSpeed = 720;
  static const double acceleration = 4800;
  static const double braking = 6500;
  static const double stationarySpeed = 5;
  static const double maximumSimulationStep = 1 / 120;
  static const double edgeBoostGateStartSpeedFraction = 0.40;
  static const double edgeBoostGateFullSpeedFraction = 0.60;
  static const double swipeBoostStartSpeed = 900;
  static const double swipeBoostFullSpeed = 2400;
  static const double maximumSwipeEdgeBoost = 0.70;
  static const double swipeBoostDecayDuration = 0.30;
  static const double maximumSwipeSampleGap = 0.12;

  static const double trackMorphFramesPerSecond = 72;
  static const double highSpeedTrackTaperStart = 0.50;
  static const double maximumTrackCadenceMultiplier = 0.76;
  static const double continuousAnimationMultiplier = 1.15;
  static const double continuousTravelSpeedFraction = 0.42;
  static const double continuousIdleBaseCadenceMultiplier = 0.85;
  static const double continuousIdleTrackCadenceMultiplier = 0.38;
  static const double continuousFastReverseEnterSpeedFraction = 0.55;
  static const double continuousFastReverseExitSpeedFraction = 0.45;
  static const double continuousSlowReverseTrackCadenceMultiplier = 0.90;
  static const double continuousFastReverseTrackCadenceMultiplier = 1.25;
  static const double bossTrackSettleFramesPerSecond = 12;
  static const double animationSpeedRiseResponse = 14;
  static const double animationSpeedFallResponse = 18;
  static const double animationSettleThreshold = 0.001;
  static const double baseShakeDegrees = 1.75;
  static const double baseShakeFrequency = 3;
  static const double wheelBounceDistance = 1.5;
  static const double minimumWheelBounceFrequency = 2;
  static const double maximumWheelBounceFrequency = 8;
}

double get tankArrivalRate =>
    math.log(
      TankMotionTuning.minimumMovementSpeed / TankMotionTuning.arrivalSpeed,
    ) /
    TankMotionTuning.arrivalDuration;

double trackAnimationSpeedFraction(double movementSpeedFraction) {
  final normalizedSpeed = movementSpeedFraction.clamp(0.0, 1.0);
  final boostedSpeed = math.sqrt(normalizedSpeed);
  if (normalizedSpeed <= TankMotionTuning.highSpeedTrackTaperStart) {
    return boostedSpeed;
  }

  final highSpeedProgress =
      ((normalizedSpeed - TankMotionTuning.highSpeedTrackTaperStart) /
              (1 - TankMotionTuning.highSpeedTrackTaperStart))
          .clamp(0.0, 1.0);
  final easedHighSpeedProgress =
      highSpeedProgress * highSpeedProgress * (3 - 2 * highSpeedProgress);
  final taperStartCadence = math.sqrt(
    TankMotionTuning.highSpeedTrackTaperStart,
  );
  return taperStartCadence +
      (TankMotionTuning.maximumTrackCadenceMultiplier - taperStartCadence) *
          easedHighSpeedProgress;
}

double continuousBaseCadenceMultiplier(double movementSpeedFraction) {
  final movingBlend =
      (movementSpeedFraction / TankMotionTuning.continuousTravelSpeedFraction)
          .clamp(0.0, 1.0);
  return TankMotionTuning.continuousIdleBaseCadenceMultiplier +
      (1 - TankMotionTuning.continuousIdleBaseCadenceMultiplier) * movingBlend;
}

double continuousTrackCadenceMultiplier(double movementSpeedFraction) {
  final movingBlend =
      (movementSpeedFraction / TankMotionTuning.continuousTravelSpeedFraction)
          .clamp(0.0, 1.0);
  return TankMotionTuning.continuousIdleTrackCadenceMultiplier +
      (1 - TankMotionTuning.continuousIdleTrackCadenceMultiplier) * movingBlend;
}

double continuousReverseTrackCadenceMultiplier({
  required bool isBackingUp,
  required bool isFastReverse,
}) {
  if (!isBackingUp) {
    return 1;
  }
  return isFastReverse
      ? TankMotionTuning.continuousFastReverseTrackCadenceMultiplier
      : TankMotionTuning.continuousSlowReverseTrackCadenceMultiplier;
}

double viewportEdgeBoostForPointer({
  required double pointerX,
  required double minimumTankX,
  required double maximumTankX,
  required double stageWidth,
}) {
  double rawProgress;
  if (pointerX < minimumTankX) {
    rawProgress = minimumTankX <= 0
        ? 1
        : (minimumTankX - pointerX) / minimumTankX;
  } else if (pointerX > maximumTankX) {
    final rightBandWidth = stageWidth - maximumTankX;
    rawProgress = rightBandWidth <= 0
        ? 1
        : (pointerX - maximumTankX) / rightBandWidth;
  } else {
    return 0;
  }

  final progress = rawProgress.clamp(0.0, 1.0);
  return progress * progress * (3 - 2 * progress);
}

double maximumEdgeBoostForSpeed(double speedFraction) {
  final progress =
      ((speedFraction - TankMotionTuning.edgeBoostGateStartSpeedFraction) /
              (TankMotionTuning.edgeBoostGateFullSpeedFraction -
                  TankMotionTuning.edgeBoostGateStartSpeedFraction))
          .clamp(0.0, 1.0);
  return progress * progress * (3 - 2 * progress);
}

double swipeEdgeBoostForVelocity(double pointerVelocity) {
  final progress =
      ((pointerVelocity.abs() - TankMotionTuning.swipeBoostStartSpeed) /
              (TankMotionTuning.swipeBoostFullSpeed -
                  TankMotionTuning.swipeBoostStartSpeed))
          .clamp(0.0, 1.0);
  final eased = progress * progress * (3 - 2 * progress);
  return eased * TankMotionTuning.maximumSwipeEdgeBoost;
}

double desiredTankVelocity(
  double horizontalOffset, {
  double viewportEdgeProgress = 0,
  double maximumSpeedBoost = 0,
  double maximumSpeed = TankMotionTuning.maxSpeed,
}) {
  final edgeProgress = viewportEdgeProgress.clamp(0.0, 1.0);
  final speedBoost = maximumSpeedBoost.clamp(0.0, 1.0);
  final distance = horizontalOffset.abs();
  final deadZone = TankMotionTuning.deadZone * (1 - edgeProgress);
  if (distance <= deadZone) {
    return 0;
  }

  final usableDistance = TankMotionTuning.fullSpeedDistance - deadZone;
  final linearFraction = ((distance - deadZone) / usableDistance).clamp(
    0.0,
    1.0,
  );
  final speedFraction =
      linearFraction *
      (TankMotionTuning.distanceCurveLinearWeight +
          (1 - TankMotionTuning.distanceCurveLinearWeight) * linearFraction);
  final normalCruiseSpeed = math.max(
    TankMotionTuning.minimumMovementSpeed,
    maximumSpeed * speedFraction,
  );
  final cruiseSpeed =
      normalCruiseSpeed + (maximumSpeed - normalCruiseSpeed) * speedBoost;
  final arrivalSpeed = (distance - deadZone) * tankArrivalRate;
  final speed = math.min(cruiseSpeed, arrivalSpeed);
  return horizontalOffset.sign * speed;
}

double moveTowards(double current, double target, double maximumDelta) {
  final difference = target - current;
  if (difference.abs() <= maximumDelta) {
    return target;
  }
  return current + difference.sign * maximumDelta;
}

double tankVelocityAfterStep(double current, double desired, double dt) {
  if (dt <= 0 || current == desired) {
    return current;
  }

  final isReversing =
      current != 0 && desired != 0 && current.sign != desired.sign;
  if (isReversing) {
    final brakingTime = current.abs() / TankMotionTuning.braking;
    if (dt <= brakingTime) {
      return moveTowards(current, 0, TankMotionTuning.braking * dt);
    }
    return moveTowards(
      0,
      desired,
      TankMotionTuning.acceleration * (dt - brakingTime),
    );
  }

  final isBraking = desired.abs() < current.abs();
  final rate = isBraking
      ? TankMotionTuning.braking
      : TankMotionTuning.acceleration;
  return moveTowards(current, desired, rate * dt);
}

double wheelBounceFrequencyForSpeed(double speedFraction) {
  final normalizedSpeed = speedFraction.clamp(0.0, 1.0);
  return TankMotionTuning.minimumWheelBounceFrequency +
      (TankMotionTuning.maximumWheelBounceFrequency -
              TankMotionTuning.minimumWheelBounceFrequency) *
          normalizedSpeed;
}

double wheelBounceAmplitudeForSpeed(double speedFraction) {
  final normalizedSpeed = speedFraction.clamp(0.0, 1.0);
  final easedSpeed = 1 - math.pow(1 - normalizedSpeed, 3).toDouble();
  return TankMotionTuning.wheelBounceDistance * easedSpeed;
}

double cannonAngleForTarget({
  required double horizontalOffset,
  required double verticalOffset,
  required double previousAngle,
}) {
  if (verticalOffset >= 0 && horizontalOffset.abs() < 0.001) {
    return previousAngle.clamp(-math.pi / 2, math.pi / 2);
  }

  final angle = math.atan2(horizontalOffset, -verticalOffset);
  return angle.clamp(-math.pi / 2, math.pi / 2);
}
