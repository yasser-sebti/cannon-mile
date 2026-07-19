import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import 'tank_track_morph_component.dart';

class TankLaserVisualCache {
  TankLaserVisualCache({
    required this.beamFrames,
    required this.originCapFrames,
    required this.shineSprite,
  });

  static const int frameCount = 16;
  static const double imageWidth = 160;
  static const double stripHeight = 32;
  static const double originCapHeight = 30;

  final List<Sprite> beamFrames;
  final List<Sprite> originCapFrames;
  final Sprite shineSprite;

  static Future<TankLaserVisualCache> bake() async {
    final frames = <Sprite>[];
    final originCaps = <Sprite>[];
    for (var index = 0; index < frameCount; index++) {
      final phase = index / frameCount;
      final pulse = (math.sin(phase * math.pi * 2) + 1) / 2;
      final coreWidth = _lerp(28, 40, pulse);
      final energyWidth = _lerp(48, 64, pulse);
      final orangeWidth = _lerp(76, 96, pulse);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      const centerX = imageWidth / 2;
      final fullHeight = stripHeight * 5;
      final top = -stripHeight * 2;

      canvas.drawRect(
        ui.Rect.fromLTWH(
          centerX - orangeWidth / 2,
          top,
          orangeWidth,
          fullHeight,
        ),
        _bakePaint(
          color: const ui.Color(0xCCFF6A00),
          blurSigma: 18,
          blendMode: ui.BlendMode.plus,
        ),
      );
      canvas.drawRect(
        ui.Rect.fromLTWH(
          centerX - orangeWidth / 2,
          top,
          orangeWidth,
          fullHeight,
        ),
        _bakePaint(color: const ui.Color(0xFFFF7200)),
      );
      canvas.drawRect(
        ui.Rect.fromLTWH(
          centerX - energyWidth / 2,
          top,
          energyWidth,
          fullHeight,
        ),
        _bakePaint(
          color: const ui.Color(0xFFFFD21A),
          blendMode: ui.BlendMode.plus,
        ),
      );
      canvas.drawRect(
        ui.Rect.fromLTWH(centerX - coreWidth / 2, top, coreWidth, fullHeight),
        _bakePaint(
          color: ui.Color.lerp(
            const ui.Color(0xFFFFF5B8),
            const ui.Color(0xFFFFFFFF),
            0.78 + pulse * 0.22,
          )!,
          blendMode: ui.BlendMode.plus,
        ),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        imageWidth.ceil(),
        stripHeight.ceil(),
      );
      picture.dispose();
      frames.add(Sprite(image));

      // The beam begins with the lower half of a flattened ellipse. Its
      // horizontal layer widths exactly match the rectangular beam above it,
      // so every cached pulse state joins without a clipped-looking edge.
      final capRecorder = ui.PictureRecorder();
      final capCanvas = ui.Canvas(capRecorder);
      capCanvas.drawOval(
        ui.Rect.fromCenter(
          center: const ui.Offset(centerX, 0),
          width: orangeWidth,
          height: orangeWidth * 0.55,
        ),
        _bakePaint(
          color: const ui.Color(0xCCFF6A00),
          blurSigma: 18,
          blendMode: ui.BlendMode.plus,
        ),
      );
      capCanvas.drawOval(
        ui.Rect.fromCenter(
          center: const ui.Offset(centerX, 0),
          width: orangeWidth,
          height: orangeWidth * 0.50,
        ),
        _bakePaint(color: const ui.Color(0xFFFF7200)),
      );
      capCanvas.drawOval(
        ui.Rect.fromCenter(
          center: const ui.Offset(centerX, 0),
          width: energyWidth,
          height: energyWidth * 0.55,
        ),
        _bakePaint(
          color: const ui.Color(0xFFFFD21A),
          blendMode: ui.BlendMode.plus,
        ),
      );
      capCanvas.drawOval(
        ui.Rect.fromCenter(
          center: const ui.Offset(centerX, 0),
          width: coreWidth,
          height: coreWidth * 0.60,
        ),
        _bakePaint(
          color: ui.Color.lerp(
            const ui.Color(0xFFFFF5B8),
            const ui.Color(0xFFFFFFFF),
            0.78 + pulse * 0.22,
          )!,
          blendMode: ui.BlendMode.plus,
        ),
      );
      final capPicture = capRecorder.endRecording();
      final capImage = await capPicture.toImage(
        imageWidth.ceil(),
        originCapHeight.ceil(),
      );
      capPicture.dispose();
      originCaps.add(Sprite(capImage));
    }

    final shineRecorder = ui.PictureRecorder();
    final shineCanvas = ui.Canvas(shineRecorder);
    final shineGlowPaint = _bakePaint(
      color: const ui.Color(0xD9FFFFFF),
      blurSigma: 9,
      blendMode: ui.BlendMode.plus,
    );
    final shineCorePaint = _bakePaint(
      color: const ui.Color(0xFFFFFFFF),
      blendMode: ui.BlendMode.plus,
    );
    const shineRect = ui.Rect.fromLTWH(28, 12, 104, 16);
    shineCanvas
      ..drawOval(shineRect, shineGlowPaint)
      ..drawOval(const ui.Rect.fromLTWH(48, 17, 64, 6), shineCorePaint);
    final shinePicture = shineRecorder.endRecording();
    final shineImage = await shinePicture.toImage(160, 40);
    shinePicture.dispose();

    return TankLaserVisualCache(
      beamFrames: List.unmodifiable(frames),
      originCapFrames: List.unmodifiable(originCaps),
      shineSprite: Sprite(shineImage),
    );
  }

  static ui.Paint _bakePaint({
    required ui.Color color,
    ui.BlendMode blendMode = ui.BlendMode.srcOver,
    double? blurSigma,
  }) {
    return createTankSpritePaint(filterQuality: ui.FilterQuality.medium)
      ..color = color
      ..blendMode = blendMode
      ..maskFilter = blurSigma == null
          ? null
          : ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma);
  }

  static double _lerp(double from, double to, double progress) {
    return from + (to - from) * progress;
  }

  void dispose() {
    for (final frame in beamFrames) {
      frame.image.dispose();
    }
    for (final frame in originCapFrames) {
      frame.image.dispose();
    }
    shineSprite.image.dispose();
  }
}

class TankLaserComponent extends PositionComponent {
  TankLaserComponent({required this.visualCache})
    : assert(visualCache.beamFrames.length == TankLaserVisualCache.frameCount),
      assert(
        visualCache.originCapFrames.length == TankLaserVisualCache.frameCount,
      ),
      super(
        position: Vector2.all(parkingCoordinate),
        size: Vector2(TankLaserVisualCache.imageWidth, 0),
        anchor: Anchor.bottomCenter,
        priority: 15,
      );

  static const double parkingCoordinate = -10000;
  static const double powerUpDuration = 0;
  static const double powerDownDuration = 0.10;
  static const double damagePowerThreshold = 0.35;
  static const double pulseFrequency = 2.8;
  static const double shineFrequency = 13.0;
  static const double shakeFrequency = 44.0;
  static const double maximumShakeOffset = 4.6;
  static const double minimumCoreWidth = 28;
  static const double maximumCoreWidth = 40;
  static const double minimumGlowWidth = 105;
  static const double maximumGlowWidth = 135;
  static const int cachedPowerPaintCount = 33;

  final TankLaserVisualCache visualCache;
  final List<ui.Paint> _powerPaints = List<ui.Paint>.generate(
    cachedPowerPaintCount,
    (index) => createTankSpritePaint(filterQuality: ui.FilterQuality.medium)
      ..color = ui.Color.fromARGB(
        (255 * index / (cachedPowerPaintCount - 1)).round(),
        255,
        255,
        255,
      ),
    growable: false,
  );
  final Vector2 _beamRenderPosition = Vector2.zero();
  final Vector2 _beamRenderSize = Vector2.zero();
  final Vector2 _originCapPosition = Vector2.zero();
  final Vector2 _originCapSize = Vector2.zero();
  final Vector2 _shinePosition = Vector2.zero();
  final Vector2 _shineSize = Vector2.zero();
  final Vector2 _currentOrigin = Vector2.all(parkingCoordinate);
  final Vector2 _previousOrigin = Vector2.all(parkingCoordinate);
  final Vector2 _currentEndpoint = Vector2.all(parkingCoordinate);
  final Vector2 _previousEndpoint = Vector2.all(parkingCoordinate);

  bool _weaponEnabled = false;
  bool _triggerHeld = false;
  bool _warmupActive = false;
  bool _hasGeometry = false;
  double _linearPower = 0;
  double _power = 0;
  double _pulsePhase = 0;
  double _shinePhase = 0;
  double _shakePhase = 0;
  double _shakeOffset = 0;
  double _currentAngle = 0;
  double _previousAngle = 0;
  double _currentLength = 0;
  double _previousLength = 0;
  double _visualLength = 0;
  double _activeCoreWidth = 0;
  double _previousCoreWidth = 0;
  int _lastFrameHitCount = 0;
  int _lastFrameDestructionCount = 0;

  bool get weaponEnabled => _weaponEnabled;
  bool get triggerHeld => _triggerHeld;
  bool get isVisible => _warmupActive || _power > 0.0001;
  bool get isDamageActive =>
      !_warmupActive && _weaponEnabled && _power >= damagePowerThreshold;
  bool get usesRuntimeBlur => false;
  bool get hasPrebakedGlow => true;
  int get cachedFrameCount => visualCache.beamFrames.length;
  int get cachedOriginCapFrameCount => visualCache.originCapFrames.length;
  double get power => _power;
  double get pulsePhase => _pulsePhase;
  double get shinePhase => _shinePhase;
  double get shakePhase => _shakePhase;
  double get shakeOffset => _shakeOffset;
  double get currentAngle => _currentAngle;
  double get previousAngle => _previousAngle;
  double get currentLength => _currentLength;
  double get previousLength => _previousLength;
  double get visualLength => _visualLength;
  double get activeCoreWidth => _activeCoreWidth;
  double get previousCoreWidth => _previousCoreWidth;
  double get currentOriginX => _currentOrigin.x;
  double get currentOriginY => _currentOrigin.y;
  double get previousOriginX => _previousOrigin.x;
  double get previousOriginY => _previousOrigin.y;
  double get currentEndpointX => _currentEndpoint.x;
  double get currentEndpointY => _currentEndpoint.y;
  double get previousEndpointX => _previousEndpoint.x;
  double get previousEndpointY => _previousEndpoint.y;
  int get lastFrameHitCount => _lastFrameHitCount;
  int get lastFrameDestructionCount => _lastFrameDestructionCount;
  Vector2 get currentOrigin => _currentOrigin.clone();
  Vector2 get currentEndpoint => _currentEndpoint.clone();

  void setWeaponEnabled(bool enabled) {
    _weaponEnabled = enabled;
    if (!enabled) {
      _triggerHeld = false;
    }
  }

  void setTriggerHeld(bool held) {
    _triggerHeld = _weaponEnabled && held;
  }

  void setGeometry({
    required Vector2 origin,
    required double angle,
    required Vector2 stageSize,
  }) {
    if (_hasGeometry) {
      _previousOrigin.setFrom(_currentOrigin);
      _previousEndpoint.setFrom(_currentEndpoint);
      _previousAngle = _currentAngle;
      _previousLength = _currentLength;
    } else {
      _previousOrigin.setFrom(origin);
      _previousAngle = angle;
      _hasGeometry = true;
    }
    _currentOrigin.setFrom(origin);
    _currentAngle = angle;
    _currentLength = lengthToStageEdge(
      originX: origin.x,
      originY: origin.y,
      angle: angle,
      stageWidth: stageSize.x,
      stageHeight: stageSize.y,
    );
    _visualLength =
        _currentLength +
        math.sqrt(stageSize.x * stageSize.x + stageSize.y * stageSize.y) *
            0.55 +
        240;
    final directionX = math.sin(angle);
    final directionY = -math.cos(angle);
    _currentEndpoint.setValues(
      origin.x + directionX * _currentLength,
      origin.y + directionY * _currentLength,
    );
    if (_previousLength == 0) {
      _previousLength = _currentLength;
      _previousEndpoint.setFrom(_currentEndpoint);
    }
    position.setFrom(origin);
    this.angle = angle;
    size
      ..x = TankLaserVisualCache.imageWidth
      ..y = _visualLength;
  }

  void advance(double dt) {
    if (dt < 0) {
      return;
    }
    _previousCoreWidth = _activeCoreWidth;
    final wantsPower = _warmupActive || (_weaponEnabled && _triggerHeld);
    if (wantsPower) {
      // Activation is intentionally immediate: the beam snaps fully out of
      // the cannon on the first firing update, without a fade-in ramp.
      _linearPower = 1;
    } else {
      _linearPower = math.max(0, _linearPower - dt / powerDownDuration);
    }
    _power = _smoothstep(_linearPower);
    if (_power > 0 || _warmupActive) {
      _pulsePhase = (_pulsePhase + dt * pulseFrequency) % 1;
      _shinePhase = (_shinePhase + dt * shineFrequency) % 1;
      _shakePhase = (_shakePhase + dt * shakeFrequency) % 1;
    }
    final shakeRadians = _shakePhase * math.pi * 2;
    _shakeOffset =
        (math.sin(shakeRadians) * 0.72 +
            math.sin(shakeRadians * 1.91 + 0.8) * 0.28) *
        maximumShakeOffset *
        _power;
    final pulse = (math.sin(_pulsePhase * math.pi * 2) + 1) / 2;
    _activeCoreWidth =
        (minimumCoreWidth + (maximumCoreWidth - minimumCoreWidth) * pulse) *
        _power;
    if (_warmupActive) {
      _activeCoreWidth = maximumCoreWidth;
    }
  }

  void beginWarmup({required Vector2 origin, required Vector2 stageSize}) {
    _warmupActive = true;
    _linearPower = 1;
    _power = 1;
    _pulsePhase = 0.25;
    _shakePhase = 0.125;
    _activeCoreWidth = maximumCoreWidth;
    _previousCoreWidth = maximumCoreWidth;
    setGeometry(origin: origin, angle: 0, stageSize: stageSize);
  }

  void continueWarmup() {
    _pulsePhase = 0.75;
    _shinePhase = 0.5;
    _activeCoreWidth = minimumCoreWidth;
  }

  void endWarmup() {
    _warmupActive = false;
    _linearPower = 0;
    _power = 0;
    _shakeOffset = 0;
    _activeCoreWidth = 0;
    _previousCoreWidth = 0;
  }

  void resetFrameImpactCounts() {
    _lastFrameHitCount = 0;
    _lastFrameDestructionCount = 0;
  }

  void recordDestruction() {
    _lastFrameHitCount++;
    _lastFrameDestructionCount++;
  }

  static double lengthToStageEdge({
    required double originX,
    required double originY,
    required double angle,
    required double stageWidth,
    required double stageHeight,
  }) {
    const epsilon = 0.0000001;
    final directionX = math.sin(angle);
    final directionY = -math.cos(angle);
    var distance = double.infinity;
    if (directionY < -epsilon) {
      distance = math.min(distance, -originY / directionY);
    }
    if (directionX < -epsilon) {
      distance = math.min(distance, -originX / directionX);
    } else if (directionX > epsilon) {
      distance = math.min(distance, (stageWidth - originX) / directionX);
    }
    if (!distance.isFinite || distance < 0) {
      return 0;
    }
    return distance;
  }

  static double _smoothstep(double value) {
    final clamped = value.clamp(0.0, 1.0);
    return clamped * clamped * (3 - 2 * clamped);
  }

  @override
  void render(ui.Canvas canvas) {
    if (!isVisible || _visualLength <= 0) {
      return;
    }
    final powerIndex = (_power * (cachedPowerPaintCount - 1)).round().clamp(
      1,
      cachedPowerPaintCount - 1,
    );
    final paint = _powerPaints[powerIndex];
    final frameIndex = (_pulsePhase * TankLaserVisualCache.frameCount)
        .floor()
        .clamp(0, TankLaserVisualCache.frameCount - 1);
    final chargeScale = 0.45 + _power * 0.55;
    final renderWidth = TankLaserVisualCache.imageWidth * chargeScale;
    _beamRenderPosition.setValues(size.x / 2 + _shakeOffset, size.y);
    _beamRenderSize.setValues(renderWidth, size.y);
    visualCache.beamFrames[frameIndex].render(
      canvas,
      position: _beamRenderPosition,
      size: _beamRenderSize,
      anchor: Anchor.bottomCenter,
      overridePaint: paint,
    );

    _originCapPosition.setValues(size.x / 2 + _shakeOffset, size.y - 1);
    _originCapSize.setValues(
      renderWidth,
      TankLaserVisualCache.originCapHeight * chargeScale,
    );
    visualCache.originCapFrames[frameIndex].render(
      canvas,
      position: _originCapPosition,
      size: _originCapSize,
      anchor: Anchor.topCenter,
      overridePaint: paint,
    );

    _shinePosition.setValues(
      size.x / 2 + _shakeOffset,
      size.y * (1 - _shinePhase),
    );
    _shineSize.setValues(renderWidth * 0.94, 40 * chargeScale);
    visualCache.shineSprite.render(
      canvas,
      position: _shinePosition,
      size: _shineSize,
      anchor: Anchor.center,
      overridePaint: paint,
    );
  }

  @override
  void onRemove() {
    visualCache.dispose();
    super.onRemove();
  }
}
