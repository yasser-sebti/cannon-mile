import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

class TankMuzzleSmokeComponent extends PositionComponent {
  TankMuzzleSmokeComponent({required super.position, super.priority})
    : super(
        size: Vector2(smokeWidth, smokeHeight),
        anchor: Anchor.bottomCenter,
      );

  static const double smokeWidth = 26;
  static const double smokeHeight = 82;
  static const double totalDuration = 2.4;
  static const double sustainedFireDelay = 0.5;
  static const double heatRetentionDuration = 5.0;
  static const double growthDuration = 0.34;
  static const double fadeDelay = 0.55;
  static const double maximumLean = 0.36;
  static const double continuousMaximumLean = 0.52;
  static const double continuousWindLean = -0.46;
  static const double bottomSegmentMass = 2.4;
  static const double topSegmentMass = 0.45;
  static const double maximumTrailOffset = 44;
  static const int fadeSteps = 32;
  static const int pathSegments = 12;
  static final List<Paint> _gradientPaints = List<Paint>.unmodifiable([
    for (var index = 0; index < fadeSteps; index++)
      _gradientPaint(1 - index / (fadeSteps - 1)),
  ]);

  final Path _plumePath = Path();
  final Float64List _trailOffsets = Float64List(pathSegments + 1);
  final Float64List _trailVelocities = Float64List(pathSegments + 1);
  double _elapsed = totalDuration;
  double _wavePhase = 0;
  double _lean = 0;
  double _motionIntensity = 0;
  double _fadeProgress = 1;
  double _growthProgress = 0;
  bool _continuousMode = false;

  bool get isVisible => _elapsed < totalDuration;
  bool get isSustained => false;
  bool get usesRuntimeBlur => false;
  double get elapsed => _elapsed;
  double get wavePhase => _wavePhase;
  double get lean => _lean;
  double get motionIntensity => _motionIntensity;
  double get fadeProgress => _fadeProgress;
  double get growthProgress => _growthProgress;
  double get anchorOffset => _trailOffsets.first;
  double get trailTipOffset => _trailOffsets.last;
  Paint get currentGradientPaint {
    final index = (_fadeProgress * (fadeSteps - 1)).round().clamp(
      0,
      fadeSteps - 1,
    );
    return _gradientPaints[index];
  }

  static Paint _gradientPaint(double opacity) {
    return Paint()
      ..isAntiAlias = true
      ..shader = Gradient.linear(
        const Offset(smokeWidth / 2, smokeHeight),
        const Offset(smokeWidth / 2, 0),
        [
          const Color(0xFFCDD2D5).withValues(alpha: 0.26 * opacity),
          const Color(0xFFB7BEC2).withValues(alpha: 0.20 * opacity),
          const Color(0xFFA8B0B5).withValues(alpha: 0.08 * opacity),
          const Color(0x00A8B0B5),
        ],
        const [0, 0.32, 0.72, 1],
      );
  }

  void trigger() {
    _elapsed = 0;
    _fadeProgress = 0;
    _growthProgress = 0;
    scale.setValues(1, 0.12);
    _resetTrail();
  }

  void activateForWarmup() {
    _elapsed = 0.8;
    _fadeProgress = 0.08;
    _growthProgress = 1;
    scale.setValues(1, 1);
  }

  void cancel() {
    _elapsed = totalDuration;
    _fadeProgress = 1;
    _growthProgress = 0;
    scale.setValues(1, 1);
    _resetTrail();
  }

  void setMotion({
    required double horizontalVelocity,
    required double cannonAngle,
    required double cannonAngularVelocity,
    required double dt,
    double anchorHorizontalDelta = 0,
    bool continuousMode = false,
  }) {
    // The tank keeps this component as a sibling below the cannon and moves its
    // anchor to the rotated muzzle. Zero rotation keeps the plume world-up.
    angle = 0;
    _continuousMode = continuousMode;
    if (dt <= 0) {
      return;
    }
    final velocityInfluence = (-horizontalVelocity / 720).clamp(-1.0, 1.0);
    final rotationInfluence = (-cannonAngularVelocity / 7).clamp(-1.0, 1.0);
    var targetLean =
        velocityInfluence * 0.25 +
        rotationInfluence * 0.16 +
        (continuousMode ? continuousWindLean : 0);
    if (continuousMode) {
      // Continuous travel represents the map moving from right to left. Keep
      // a persistent leftward apparent wind even while the tank is screen-idle.
      targetLean = math.min(targetLean, continuousWindLean * 0.55);
    }
    final leanLimit = continuousMode ? continuousMaximumLean : maximumLean;
    targetLean = targetLean.clamp(-leanLimit, leanLimit);
    final targetMotionIntensity = math.max(
      continuousMode ? 0.5 : velocityInfluence.abs(),
      math.max(velocityInfluence.abs(), rotationInfluence.abs()),
    );
    final response = 1 - math.exp(-8 * dt);
    _lean += (targetLean - _lean) * response;
    _motionIntensity += (targetMotionIntensity - _motionIntensity) * response;
    _wavePhase =
        (_wavePhase + dt * math.pi * 2 * (1.25 + _motionIntensity * 2.1)) %
        (math.pi * 2);
    _applyAnchorPull(anchorHorizontalDelta);
    _advanceTrail(dt);
  }

  @override
  void update(double dt) {
    if (!isVisible || dt <= 0) {
      return;
    }
    _elapsed += dt;
    if (_elapsed >= totalDuration) {
      cancel();
      return;
    }
    final linearGrowth = (_elapsed / growthDuration).clamp(0.0, 1.0);
    _growthProgress = linearGrowth * linearGrowth * (3 - 2 * linearGrowth);
    scale.setValues(1, 0.12 + _growthProgress * 0.88);

    final linearFade = ((_elapsed - fadeDelay) / (totalDuration - fadeDelay))
        .clamp(0.0, 1.0);
    _fadeProgress = linearFade * linearFade * (3 - 2 * linearFade);
  }

  @override
  void render(Canvas canvas) {
    if (!isVisible) {
      return;
    }
    _buildWavyPlume();
    canvas.drawPath(_plumePath, currentGradientPaint);
  }

  void _buildWavyPlume() {
    _plumePath.reset();
    for (var index = 0; index <= pathSegments; index++) {
      final rise = index / pathSegments;
      final y = smokeHeight * (1 - rise);
      final centerX = smokeWidth / 2 + _trailOffsets[index];
      final halfWidth = 3.2 + rise * 3.8;
      if (index == 0) {
        _plumePath.moveTo(centerX - halfWidth, y);
      } else {
        _plumePath.lineTo(centerX - halfWidth, y);
      }
    }
    for (var index = pathSegments; index >= 0; index--) {
      final rise = index / pathSegments;
      final y = smokeHeight * (1 - rise);
      final centerX = smokeWidth / 2 + _trailOffsets[index];
      final halfWidth = 3.2 + rise * 3.8;
      _plumePath.lineTo(centerX + halfWidth, y);
    }
    _plumePath.close();
  }

  void _advanceTrail(double dt) {
    var remaining = dt.clamp(0.0, 0.05);
    while (remaining > 0) {
      final step = math.min(remaining, 1 / 120);
      _trailOffsets[0] = 0;
      _trailVelocities[0] = 0;
      for (var index = 1; index <= pathSegments; index++) {
        final rise = index / pathSegments;
        final previousRise = (index - 1) / pathSegments;
        final bendAtSegment =
            _lean * smokeHeight * math.pow(rise, 1.32).toDouble();
        final bendAtPrevious =
            _lean * smokeHeight * math.pow(previousRise, 1.32).toDouble();
        final windStep = bendAtSegment - bendAtPrevious;
        final waveAmplitude =
            (0.45 + rise * 2.15) * (0.68 + _motionIntensity * 0.9);
        final wave =
            math.sin(_wavePhase - rise * math.pi * 2.65) * waveAmplitude;
        final target = _trailOffsets[index - 1] + windStep + wave * 0.34;

        // The anchored base is heavy and tightly constrained. Mass and spring
        // tension fall toward the free tip, letting successive upper segments
        // preserve old bends while the cannon pulls their anchor underneath.
        final mass =
            bottomSegmentMass + (topSegmentMass - bottomSegmentMass) * rise;
        final continuousResponse = _continuousMode ? 2.1 : 1.0;
        final stiffness = (122 - rise * 108) * continuousResponse;
        final damping =
            (13 - rise * 7.5) *
            (_continuousMode ? math.sqrt(continuousResponse) : 1);
        final acceleration =
            ((target - _trailOffsets[index]) * stiffness -
                _trailVelocities[index] * damping) /
            mass;
        _trailVelocities[index] += acceleration * step;
        _trailOffsets[index] += _trailVelocities[index] * step;
        final constrainedOffset = _trailOffsets[index].clamp(
          -maximumTrailOffset,
          maximumTrailOffset,
        );
        if (constrainedOffset != _trailOffsets[index]) {
          _trailOffsets[index] = constrainedOffset;
          _trailVelocities[index] *= 0.45;
        }
      }
      remaining -= step;
    }
  }

  void _applyAnchorPull(double horizontalDelta) {
    if (!horizontalDelta.isFinite || horizontalDelta == 0) {
      return;
    }
    final safeDelta = horizontalDelta.clamp(-18.0, 18.0);
    for (var index = 1; index <= pathSegments; index++) {
      final rise = index / pathSegments;
      // The tip retains much more of its world-space position for the frame;
      // the weighted lower sections follow the cannon much more immediately.
      // Finite plume tension limits retention during sustained maximum speed.
      final retention = math.pow(rise, 1.55).toDouble();
      _trailOffsets[index] =
          (_trailOffsets[index] - safeDelta * retention * 0.42).clamp(
            -maximumTrailOffset,
            maximumTrailOffset,
          );
    }
  }

  void _resetTrail() {
    _trailOffsets.fillRange(0, _trailOffsets.length, 0);
    _trailVelocities.fillRange(0, _trailVelocities.length, 0);
  }
}
