import 'dart:math' as math;

import 'tank_motion.dart';

class TankPointerSwipeTracker {
  double _lastPointerX = 0;
  Duration? _lastTimestamp;
  double _sampledVelocity = 0;
  double _activeBoost = 0;
  double _boostDirection = 0;

  double get sampledVelocity => _sampledVelocity;
  double get activeBoost => _activeBoost;
  double get boostDirection => _boostDirection;

  void resetSample(double pointerX, [Duration? timestamp]) {
    _lastPointerX = pointerX;
    _lastTimestamp = timestamp;
    _sampledVelocity = 0;
    _activeBoost = 0;
    _boostDirection = 0;
  }

  void addSample(double pointerX, Duration timestamp) {
    final previousTimestamp = _lastTimestamp;
    if (previousTimestamp == null) {
      resetSample(pointerX, timestamp);
      return;
    }

    final elapsed = (timestamp - previousTimestamp).inMicroseconds / 1000000;
    final deltaX = pointerX - _lastPointerX;
    _lastPointerX = pointerX;
    _lastTimestamp = timestamp;

    if (elapsed <= 0 || elapsed > TankMotionTuning.maximumSwipeSampleGap) {
      _sampledVelocity = 0;
      return;
    }

    _sampledVelocity = deltaX / elapsed;
    final boost = swipeEdgeBoostForVelocity(_sampledVelocity);
    if (boost <= 0 || _sampledVelocity == 0) {
      return;
    }

    final direction = _sampledVelocity.sign;
    if (_boostDirection != direction) {
      _activeBoost = 0;
    }
    _boostDirection = direction;
    _activeBoost = math.max(_activeBoost, boost);
  }

  void advance(double dt) {
    if (dt <= 0 || _activeBoost <= 0) {
      return;
    }
    final decayPerSecond =
        TankMotionTuning.maximumSwipeEdgeBoost /
        TankMotionTuning.swipeBoostDecayDuration;
    _activeBoost = math.max(0, _activeBoost - decayPerSecond * dt);
    if (_activeBoost == 0) {
      _boostDirection = 0;
      _sampledVelocity = 0;
    }
  }

  double boostForDirection(double direction) {
    if (direction == 0 || direction.sign != _boostDirection) {
      return 0;
    }
    return _activeBoost;
  }
}
