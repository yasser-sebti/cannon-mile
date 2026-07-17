import 'dart:math' as math;

import 'package:cannon_mile/game/components/tank/tank_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('desiredTankVelocity', () {
    test('stops inside the dead zone', () {
      expect(desiredTankVelocity(0), 0);
      expect(desiredTankVelocity(TankMotionTuning.deadZone), 0);
      expect(desiredTankVelocity(-TankMotionTuning.deadZone), 0);
      expect(desiredTankVelocity(TankMotionTuning.deadZone + 1), 0);
    });

    test('scales linearly with distance in both directions', () {
      final halfwayDistance =
          (TankMotionTuning.deadZone + TankMotionTuning.fullSpeedDistance) / 2;

      expect(
        desiredTankVelocity(halfwayDistance),
        closeTo(TankMotionTuning.maxSpeed / 2, 0.0001),
      );
      expect(
        desiredTankVelocity(-halfwayDistance),
        closeTo(-TankMotionTuning.maxSpeed / 2, 0.0001),
      );
    });

    test('caps at maximum speed', () {
      expect(
        desiredTankVelocity(TankMotionTuning.fullSpeedDistance * 3),
        TankMotionTuning.maxSpeed,
      );
      expect(
        desiredTankVelocity(-TankMotionTuning.fullSpeedDistance * 3),
        -TankMotionTuning.maxSpeed,
      );
    });
  });

  test('moveTowards accelerates, brakes, and never overshoots its target', () {
    expect(moveTowards(0, 1200, 240), 240);
    expect(moveTowards(500, 0, 160), 340);
    expect(moveTowards(10, -10, 50), -10);
  });

  group('tankVelocityAfterStep', () {
    test('uses the responsive acceleration and braking rates', () {
      expect(tankVelocityAfterStep(0, 1200, 0.05), closeTo(240, 0.0001));
      expect(tankVelocityAfterStep(500, 0, 0.05), closeTo(175, 0.0001));
    });

    test('brakes to zero before accelerating through a reversal', () {
      final reversed = tankVelocityAfterStep(100, -1200, 0.05);

      expect(reversed, closeTo(-166.1538, 0.001));
    });
  });

  test('wheel bounce frequency and amplitude rise smoothly with speed', () {
    expect(wheelBounceFrequencyForSpeed(0), 2);
    expect(wheelBounceFrequencyForSpeed(0.5), 5);
    expect(wheelBounceFrequencyForSpeed(1), 8);

    expect(wheelBounceAmplitudeForSpeed(0), 0);
    expect(
      wheelBounceAmplitudeForSpeed(0.5),
      inExclusiveRange(0, TankMotionTuning.wheelBounceDistance),
    );
    expect(
      wheelBounceAmplitudeForSpeed(1),
      TankMotionTuning.wheelBounceDistance,
    );
  });

  group('cannonAngleForTarget', () {
    test('aims through the upper semicircle', () {
      expect(
        cannonAngleForTarget(
          horizontalOffset: 0,
          verticalOffset: -100,
          previousAngle: 0,
        ),
        closeTo(0, 0.0001),
      );
      expect(
        cannonAngleForTarget(
          horizontalOffset: 100,
          verticalOffset: 0,
          previousAngle: 0,
        ),
        closeTo(math.pi / 2, 0.0001),
      );
      expect(
        cannonAngleForTarget(
          horizontalOffset: -100,
          verticalOffset: 0,
          previousAngle: 0,
        ),
        closeTo(-math.pi / 2, 0.0001),
      );
    });

    test('clamps targets below the pivot to the nearest side', () {
      expect(
        cannonAngleForTarget(
          horizontalOffset: 100,
          verticalOffset: 100,
          previousAngle: 0,
        ),
        closeTo(math.pi / 2, 0.0001),
      );
      expect(
        cannonAngleForTarget(
          horizontalOffset: -100,
          verticalOffset: 100,
          previousAngle: 0,
        ),
        closeTo(-math.pi / 2, 0.0001),
      );
    });

    test('retains the previous side when the target is directly below', () {
      expect(
        cannonAngleForTarget(
          horizontalOffset: 0,
          verticalOffset: 100,
          previousAngle: -0.4,
        ),
        closeTo(-0.4, 0.0001),
      );
    });
  });
}
