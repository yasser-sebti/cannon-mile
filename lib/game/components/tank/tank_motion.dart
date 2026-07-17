import 'dart:math' as math;

abstract final class TankMotionTuning {
  static const double edgeMargin = 40;
  static const double groundInset = 80;
  static const double deadZone = 24;
  static const double fullSpeedDistance = 450;
  static const double maxSpeed = 1200;
  static const double acceleration = 4800;
  static const double braking = 6500;
  static const double stationarySpeed = 5;
  static const double maximumSimulationStep = 1 / 120;

  static const double trackMorphCyclesPerSecond = 5;
  static const double trackResetDuration = 0.12;
  static const double animationSpeedRiseResponse = 14;
  static const double animationSpeedFallResponse = 18;
  static const double animationSettleThreshold = 0.001;
  static const double baseShakeDegrees = 1.25;
  static const double baseShakeFrequency = 3;
  static const double wheelBounceDistance = 1.5;
  static const double minimumWheelBounceFrequency = 2;
  static const double maximumWheelBounceFrequency = 8;
}

double desiredTankVelocity(double horizontalOffset) {
  final distance = horizontalOffset.abs();
  if (distance <= TankMotionTuning.deadZone) {
    return 0;
  }

  final usableDistance =
      TankMotionTuning.fullSpeedDistance - TankMotionTuning.deadZone;
  final speedFraction =
      ((distance - TankMotionTuning.deadZone) / usableDistance).clamp(0.0, 1.0);
  final speed = TankMotionTuning.maxSpeed * speedFraction;
  if (speed < TankMotionTuning.stationarySpeed) {
    return 0;
  }
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
