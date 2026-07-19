import 'dart:math' as math;

import 'package:cannon_mile/game/components/tank/tank_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('desiredTankVelocity', () {
    test('tapers continuously into the dead zone', () {
      expect(desiredTankVelocity(0), 0);
      expect(desiredTankVelocity(TankMotionTuning.deadZone), 0);
      expect(desiredTankVelocity(-TankMotionTuning.deadZone), 0);
      expect(
        desiredTankVelocity(TankMotionTuning.deadZone + 1),
        closeTo(tankArrivalRate, 0.0001),
      );
      expect(
        desiredTankVelocity(-TankMotionTuning.deadZone - 1),
        closeTo(-tankArrivalRate, 0.0001),
      );
    });

    test('uses a 0.30 second finite arrival taper from cruise speed', () {
      final transitionDistance =
          TankMotionTuning.minimumMovementSpeed / tankArrivalRate;

      expect(
        desiredTankVelocity(TankMotionTuning.deadZone + transitionDistance),
        closeTo(TankMotionTuning.minimumMovementSpeed, 0.0001),
      );
      expect(
        math.log(
              TankMotionTuning.minimumMovementSpeed /
                  TankMotionTuning.arrivalSpeed,
            ) /
            tankArrivalRate,
        closeTo(TankMotionTuning.arrivalDuration, 0.0001),
      );
    });

    test('uses a gentle curved ramp in both directions', () {
      final halfwayDistance =
          (TankMotionTuning.deadZone + TankMotionTuning.fullSpeedDistance) / 2;
      final expectedHalfSpeed =
          TankMotionTuning.maxSpeed *
          0.5 *
          (TankMotionTuning.distanceCurveLinearWeight +
              (1 - TankMotionTuning.distanceCurveLinearWeight) * 0.5);

      expect(
        desiredTankVelocity(halfwayDistance),
        closeTo(expectedHalfSpeed, 0.0001),
      );
      expect(
        desiredTankVelocity(-halfwayDistance),
        closeTo(-expectedHalfSpeed, 0.0001),
      );
    });

    test('keeps modest aim offsets in the slow movement range', () {
      expect(desiredTankVelocity(200), lessThan(175));
      expect(desiredTankVelocity(450), lessThan(600));
      expect(
        desiredTankVelocity(600),
        lessThan(TankMotionTuning.maxSpeed * 0.85),
      );
    });

    test('uses maximum boost before a short smooth viewport-edge arrival', () {
      expect(
        desiredTankVelocity(350, viewportEdgeProgress: 1, maximumSpeedBoost: 1),
        TankMotionTuning.maxSpeed,
      );
      expect(
        desiredTankVelocity(150, viewportEdgeProgress: 1, maximumSpeedBoost: 1),
        TankMotionTuning.maxSpeed,
      );
      expect(
        desiredTankVelocity(100, viewportEdgeProgress: 1, maximumSpeedBoost: 1),
        TankMotionTuning.maxSpeed,
      );
      expect(
        desiredTankVelocity(50, viewportEdgeProgress: 1, maximumSpeedBoost: 1),
        closeTo(50 * tankArrivalRate, 0.0001),
      );
      expect(
        desiredTankVelocity(10, viewportEdgeProgress: 1, maximumSpeedBoost: 1),
        closeTo(10 * tankArrivalRate, 0.0001),
      );
      expect(desiredTankVelocity(0, viewportEdgeProgress: 1), 0);
    });

    test('enters viewport-edge boost without a velocity discontinuity', () {
      const minimumTankX = 156.0;
      const maximumTankX = 1764.0;
      const stageWidth = 1920.0;
      final beforeBoundary = desiredTankVelocity(200);
      final justPastBoundaryBoost = viewportEdgeBoostForPointer(
        pointerX: maximumTankX + 1,
        minimumTankX: minimumTankX,
        maximumTankX: maximumTankX,
        stageWidth: stageWidth,
      );
      final justPastBoundary = desiredTankVelocity(
        200,
        viewportEdgeProgress: justPastBoundaryBoost,
      );

      expect(
        viewportEdgeBoostForPointer(
          pointerX: maximumTankX,
          minimumTankX: minimumTankX,
          maximumTankX: maximumTankX,
          stageWidth: stageWidth,
        ),
        0,
      );
      expect(justPastBoundaryBoost, inExclusiveRange(0, 0.001));
      expect(justPastBoundary, greaterThan(beforeBoundary));
      expect(justPastBoundary - beforeBoundary, lessThan(1));
      expect(
        viewportEdgeBoostForPointer(
          pointerX: stageWidth,
          minimumTankX: minimumTankX,
          maximumTankX: maximumTankX,
          stageWidth: stageWidth,
        ),
        1,
      );
    });

    test('keeps edge turbo locked until the tank is already moving safely', () {
      final slowEdgeSpeed = desiredTankVelocity(
        150,
        viewportEdgeProgress: 1,
        maximumSpeedBoost: maximumEdgeBoostForSpeed(0.39),
      );
      final transitionEdgeSpeed = desiredTankVelocity(
        150,
        viewportEdgeProgress: 1,
        maximumSpeedBoost: maximumEdgeBoostForSpeed(0.50),
      );
      final fastEdgeSpeed = desiredTankVelocity(
        150,
        viewportEdgeProgress: 1,
        maximumSpeedBoost: maximumEdgeBoostForSpeed(0.60),
      );

      expect(maximumEdgeBoostForSpeed(0.39), 0);
      expect(maximumEdgeBoostForSpeed(0.50), closeTo(0.5, 0.0001));
      expect(maximumEdgeBoostForSpeed(0.60), 1);
      expect(slowEdgeSpeed, lessThan(150));
      expect(
        transitionEdgeSpeed,
        inExclusiveRange(slowEdgeSpeed, fastEdgeSpeed),
      );
      expect(fastEdgeSpeed, TankMotionTuning.maxSpeed);
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
      expect(
        desiredTankVelocity(
          TankMotionTuning.fullSpeedDistance * 3,
          maximumSpeed: 600,
        ),
        600,
      );
    });
  });

  test('viewport edge boost is symmetric and smoothly eased', () {
    const minimumTankX = 156.0;
    const maximumTankX = 1764.0;
    const stageWidth = 1920.0;

    double boost(double pointerX) => viewportEdgeBoostForPointer(
      pointerX: pointerX,
      minimumTankX: minimumTankX,
      maximumTankX: maximumTankX,
      stageWidth: stageWidth,
    );

    expect(boost(minimumTankX), 0);
    expect(boost(maximumTankX), 0);
    expect(boost(minimumTankX / 2), closeTo(0.5, 0.0001));
    expect(boost((maximumTankX + stageWidth) / 2), closeTo(0.5, 0.0001));
    expect(boost(0), 1);
    expect(boost(stageWidth), 1);
    expect(boost(-100), 1);
    expect(boost(stageWidth + 100), 1);
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

  test('track animation strongly boosts low movement speeds', () {
    expect(trackAnimationSpeedFraction(0), 0);
    expect(trackAnimationSpeedFraction(0.01), closeTo(0.1, 0.0001));
    expect(trackAnimationSpeedFraction(0.25), closeTo(0.5, 0.0001));
    expect(
      trackAnimationSpeedFraction(TankMotionTuning.highSpeedTrackTaperStart),
      closeTo(math.sqrt(TankMotionTuning.highSpeedTrackTaperStart), 0.0001),
    );
    expect(
      trackAnimationSpeedFraction(1),
      TankMotionTuning.maximumTrackCadenceMultiplier,
    );
    var previousCadence = 0.0;
    for (var step = 0; step <= 100; step++) {
      final cadence = trackAnimationSpeedFraction(step / 100);
      expect(cadence, greaterThanOrEqualTo(previousCadence - 0.0001));
      previousCadence = cadence;
    }
  });

  test('continuous animation uses a restrained persistent travel boost', () {
    const multiplier = TankMotionTuning.continuousAnimationMultiplier;
    const travelFloor = TankMotionTuning.continuousTravelSpeedFraction;

    expect(multiplier, 1.15);
    expect(travelFloor, 0.42);
    expect(travelFloor * multiplier, closeTo(0.483, 0.0001));
    expect(
      TankMotionTuning.trackMorphFramesPerSecond *
          trackAnimationSpeedFraction(1) *
          multiplier,
      closeTo(62.928, 0.0001),
    );
    expect(
      TankMotionTuning.baseShakeDegrees * multiplier,
      closeTo(2.0125, 0.0001),
    );
    expect(
      TankMotionTuning.wheelBounceDistance * multiplier,
      closeTo(1.725, 0.0001),
    );
    expect(
      TankMotionTuning.maximumWheelBounceFrequency * multiplier,
      closeTo(9.2, 0.0001),
    );
  });

  test('continuous idle base cadence ramps smoothly back to full speed', () {
    const travelFloor = TankMotionTuning.continuousTravelSpeedFraction;

    expect(TankMotionTuning.continuousIdleBaseCadenceMultiplier, 0.85);
    expect(continuousBaseCadenceMultiplier(0), 0.85);
    expect(
      continuousBaseCadenceMultiplier(travelFloor / 2),
      closeTo(0.925, 0.0001),
    );
    expect(continuousBaseCadenceMultiplier(travelFloor), 1);
    expect(continuousBaseCadenceMultiplier(1), 1);
  });

  test('continuous idle track cadence keeps a visible forward crawl', () {
    const travelFloor = TankMotionTuning.continuousTravelSpeedFraction;

    expect(TankMotionTuning.continuousIdleTrackCadenceMultiplier, 0.38);
    expect(continuousTrackCadenceMultiplier(0), 0.38);
    expect(
      continuousTrackCadenceMultiplier(travelFloor / 2),
      closeTo(0.69, 0.0001),
    );
    expect(continuousTrackCadenceMultiplier(travelFloor), 1);
    expect(continuousTrackCadenceMultiplier(1), 1);
  });

  test('continuous reverse cadence separates slow and fast backing', () {
    expect(
      TankMotionTuning.continuousFastReverseEnterSpeedFraction,
      greaterThan(TankMotionTuning.continuousFastReverseExitSpeedFraction),
    );
    expect(
      continuousReverseTrackCadenceMultiplier(
        isBackingUp: false,
        isFastReverse: false,
      ),
      1,
    );
    expect(
      continuousReverseTrackCadenceMultiplier(
        isBackingUp: true,
        isFastReverse: false,
      ),
      0.9,
    );
    expect(
      continuousReverseTrackCadenceMultiplier(
        isBackingUp: true,
        isFastReverse: true,
      ),
      1.25,
    );
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
