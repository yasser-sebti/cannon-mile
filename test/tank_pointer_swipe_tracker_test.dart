import 'package:cannon_mile/game/components/tank/tank_motion.dart';
import 'package:cannon_mile/game/components/tank/tank_pointer_swipe_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('swipe boost has smooth moderate thresholds and a hard cap', () {
    expect(swipeEdgeBoostForVelocity(899), 0);
    expect(swipeEdgeBoostForVelocity(900), 0);
    expect(
      swipeEdgeBoostForVelocity(1650),
      closeTo(TankMotionTuning.maximumSwipeEdgeBoost / 2, 0.0001),
    );
    expect(
      swipeEdgeBoostForVelocity(2400),
      TankMotionTuning.maximumSwipeEdgeBoost,
    );
    expect(
      swipeEdgeBoostForVelocity(-5000),
      TankMotionTuning.maximumSwipeEdgeBoost,
    );
  });

  test('tracker uses timestamped signed samples and rejects stale input', () {
    final tracker = TankPointerSwipeTracker();
    tracker.resetSample(100, Duration.zero);
    tracker.addSample(340, const Duration(milliseconds: 100));

    expect(tracker.sampledVelocity, closeTo(2400, 0.0001));
    expect(tracker.activeBoost, TankMotionTuning.maximumSwipeEdgeBoost);
    expect(tracker.boostForDirection(1), tracker.activeBoost);
    expect(tracker.boostForDirection(-1), 0);

    final stale = TankPointerSwipeTracker();
    stale.resetSample(100, Duration.zero);
    stale.addSample(500, const Duration(milliseconds: 121));
    expect(stale.sampledVelocity, 0);
    expect(stale.activeBoost, 0);
  });

  test('a direction switch replaces the old boost without leaking', () {
    final tracker = TankPointerSwipeTracker();
    tracker.resetSample(0, Duration.zero);
    tracker.addSample(240, const Duration(milliseconds: 100));
    expect(tracker.boostForDirection(1), 0.7);

    tracker.addSample(0, const Duration(milliseconds: 200));
    expect(tracker.sampledVelocity, closeTo(-2400, 0.0001));
    expect(tracker.boostForDirection(1), 0);
    expect(tracker.boostForDirection(-1), 0.7);
  });

  test('boost decay is frame-rate independent over 0.30 seconds', () {
    for (final framesPerSecond in [30, 60, 120]) {
      final tracker = TankPointerSwipeTracker();
      tracker.resetSample(0, Duration.zero);
      tracker.addSample(240, const Duration(milliseconds: 100));
      final frames =
          (TankMotionTuning.swipeBoostDecayDuration * framesPerSecond).round();
      for (var frame = 0; frame < frames; frame++) {
        tracker.advance(1 / framesPerSecond);
      }
      expect(
        tracker.activeBoost,
        closeTo(0, 0.0001),
        reason: '$framesPerSecond FPS',
      );
    }
  });

  test('resetting a pointer sample cannot manufacture a swipe', () {
    final tracker = TankPointerSwipeTracker();
    tracker.resetSample(0, Duration.zero);
    tracker.addSample(240, const Duration(milliseconds: 100));
    tracker.resetSample(1000, const Duration(milliseconds: 110));

    expect(tracker.sampledVelocity, 0);
    expect(tracker.activeBoost, 0);
  });
}
