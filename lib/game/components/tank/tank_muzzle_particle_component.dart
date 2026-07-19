import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

class TankMuzzleParticlePalette {
  TankMuzzleParticlePalette._(this.colors, this.visibleBounds)
    : flippedVisibleBounds = List.unmodifiable([
        for (final bounds in visibleBounds)
          Rect.fromLTRB(-bounds.right, bounds.top, -bounds.left, bounds.bottom),
      ]),
      corePaints = _buildPaints(colors, 1),
      glowPaints = _buildPaints(colors, 0.28);

  static const int fadeSteps = 24;
  static const List<Color> fallbackColors = [
    Color(0xFFFFF4C2),
    Color(0xFFFFD34E),
    Color(0xFFFF9418),
    Color(0xFFFF5A0A),
  ];

  final List<Color> colors;
  final List<Rect> visibleBounds;
  final List<Rect> flippedVisibleBounds;
  final List<List<Paint>> corePaints;
  final List<List<Paint>> glowPaints;

  Rect firstFrameVisibleBounds({required bool horizontalFlip}) =>
      horizontalFlip ? flippedVisibleBounds.first : visibleBounds.first;

  static Future<TankMuzzleParticlePalette> fromSprites(
    List<Sprite> sprites, {
    required double renderScale,
  }) async {
    final sampledColors = <Color>[];
    final visibleBounds = <Rect>[];
    for (final sprite in sprites) {
      final visual = await _sampleVisibleVisual(sprite, renderScale);
      sampledColors.add(visual.color);
      visibleBounds.add(visual.bounds);
    }
    return TankMuzzleParticlePalette._(
      List.unmodifiable(sampledColors),
      List.unmodifiable(visibleBounds),
    );
  }

  static Future<({Color color, Rect bounds})> _sampleVisibleVisual(
    Sprite sprite,
    double renderScale,
  ) async {
    final bytes = await sprite.image.toByteData(
      format: ImageByteFormat.rawRgba,
    );
    if (bytes == null) {
      return (
        color: fallbackColors.first,
        bounds: Rect.fromLTWH(
          -sprite.srcSize.x * renderScale / 2,
          -sprite.srcSize.y * renderScale,
          sprite.srcSize.x * renderScale,
          sprite.srcSize.y * renderScale,
        ),
      );
    }

    final imageWidth = sprite.image.width;
    final startX = sprite.srcPosition.x.floor().clamp(0, imageWidth - 1);
    final startY = sprite.srcPosition.y.floor().clamp(
      0,
      sprite.image.height - 1,
    );
    final endX = (sprite.srcPosition.x + sprite.srcSize.x).ceil().clamp(
      startX + 1,
      imageWidth,
    );
    final endY = (sprite.srcPosition.y + sprite.srcSize.y).ceil().clamp(
      startY + 1,
      sprite.image.height,
    );
    var redTotal = 0.0;
    var greenTotal = 0.0;
    var blueTotal = 0.0;
    var totalWeight = 0.0;
    var minimumVisibleX = endX;
    var minimumVisibleY = endY;
    var maximumVisibleX = startX - 1;
    var maximumVisibleY = startY - 1;

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final offset = (y * imageWidth + x) * 4;
        final red = bytes.getUint8(offset);
        final green = bytes.getUint8(offset + 1);
        final blue = bytes.getUint8(offset + 2);
        final alpha = bytes.getUint8(offset + 3);
        final peak = math.max(red, math.max(green, blue));
        if (alpha >= 48) {
          minimumVisibleX = math.min(minimumVisibleX, x);
          minimumVisibleY = math.min(minimumVisibleY, y);
          maximumVisibleX = math.max(maximumVisibleX, x);
          maximumVisibleY = math.max(maximumVisibleY, y);
        }
        if (alpha < 48 || peak < 72) {
          continue;
        }
        final brightness = peak / 255;
        final weight = alpha / 255 * (0.35 + brightness * brightness);
        redTotal += red * weight;
        greenTotal += green * weight;
        blueTotal += blue * weight;
        totalWeight += weight;
      }
    }

    final color = totalWeight == 0
        ? fallbackColors.first
        : _brightenedColor(
            redTotal / totalWeight,
            greenTotal / totalWeight,
            blueTotal / totalWeight,
          );
    final hasVisiblePixels = maximumVisibleX >= minimumVisibleX;
    final sourceWidth = sprite.srcSize.x;
    final sourceHeight = sprite.srcSize.y;
    final relativeLeft = hasVisiblePixels
        ? minimumVisibleX - startX.toDouble()
        : 0.0;
    final relativeTop = hasVisiblePixels
        ? minimumVisibleY - startY.toDouble()
        : 0.0;
    final relativeRight = hasVisiblePixels
        ? maximumVisibleX - startX + 1.0
        : sourceWidth;
    final relativeBottom = hasVisiblePixels
        ? maximumVisibleY - startY + 1.0
        : sourceHeight;
    return (
      color: color,
      bounds: Rect.fromLTRB(
        (relativeLeft - sourceWidth / 2) * renderScale,
        (relativeTop - sourceHeight) * renderScale,
        (relativeRight - sourceWidth / 2) * renderScale,
        (relativeBottom - sourceHeight) * renderScale,
      ),
    );
  }

  static Color _brightenedColor(double red, double green, double blue) {
    final peak = math.max(red, math.max(green, blue));
    final brightnessBoost = peak < 215 ? 215 / peak : 1.0;
    return Color.fromARGB(
      255,
      (red * brightnessBoost).clamp(0, 255).round(),
      (green * brightnessBoost).clamp(0, 255).round(),
      (blue * brightnessBoost).clamp(0, 255).round(),
    );
  }

  static List<List<Paint>> _buildPaints(
    List<Color> colors,
    double maximumAlpha,
  ) {
    return List<List<Paint>>.unmodifiable([
      for (final color in colors)
        List<Paint>.unmodifiable([
          for (var step = 0; step < fadeSteps; step++)
            Paint()
              ..isAntiAlias = true
              ..blendMode = BlendMode.plus
              ..color = color.withValues(
                alpha: maximumAlpha * (1 - step / (fadeSteps - 1)),
              ),
        ]),
    ]);
  }
}

class TankMuzzleParticleComponent extends PositionComponent {
  TankMuzzleParticleComponent({required this.palette})
    : super(
        position: Vector2.all(parkingCoordinate),
        size: Vector2(particleWidth, particleHeight),
        anchor: Anchor.center,
        priority: 3,
      );

  static const int poolCapacity = 48;
  static const int minimumParticlesPerShot = 4;
  static const int maximumParticlesPerShot = 4;
  static const double particleWidth = 7;
  static const double particleHeight = 10;
  static const double gravity = 320;
  static const double airResistance = 7.5;
  static const double maximumSimulationStep = 1 / 120;
  static const double parkingCoordinate = -10000;
  static final RRect _glowShape = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, particleWidth, particleHeight),
    const Radius.circular(3.5),
  );
  static final RRect _coreShape = RRect.fromRectAndRadius(
    const Rect.fromLTWH(2, 1, 3, 8),
    const Radius.circular(1.5),
  );

  final TankMuzzleParticlePalette palette;
  final Vector2 _velocity = Vector2.zero();
  bool _isActive = false;
  bool _isWarmup = false;
  int _colorIndex = 0;
  int _fadeIndex = 0;
  double _age = 0;
  double _lifetime = 0;
  double _initialScale = 1;
  double _scaleProgress = 1;

  bool get isActive => _isActive;
  bool get isWarmup => _isWarmup;
  int get colorIndex => _colorIndex;
  Color get color => palette.colors[_colorIndex];
  double get age => _age;
  double get lifetime => _lifetime;
  double get scaleProgress => _scaleProgress;
  Vector2 get velocity => _velocity.clone();

  void activate({
    required int colorIndex,
    required double x,
    required double y,
    required double velocityX,
    required double velocityY,
    required double lifetime,
    required double initialScale,
  }) {
    assert(colorIndex >= 0 && colorIndex < palette.colors.length);
    assert(lifetime > 0);
    _colorIndex = colorIndex;
    position.setValues(x, y);
    _velocity.setValues(velocityX, velocityY);
    angle = math.atan2(velocityY, velocityX) + math.pi / 2;
    _lifetime = lifetime;
    _initialScale = initialScale;
    _scaleProgress = 1;
    _fadeIndex = 0;
    _age = 0;
    scale.setValues(initialScale, initialScale);
    _isWarmup = false;
    _isActive = true;
  }

  void activateForWarmup({
    required int colorIndex,
    required double x,
    required double y,
  }) {
    activate(
      colorIndex: colorIndex,
      x: x,
      y: y,
      velocityX: 0,
      velocityY: -1,
      lifetime: 1,
      initialScale: 1,
    );
    _isWarmup = true;
  }

  void deactivate() {
    _isActive = false;
    _isWarmup = false;
    _velocity.setZero();
    _age = 0;
    _lifetime = 0;
    _initialScale = 1;
    _scaleProgress = 1;
    _fadeIndex = 0;
    angle = 0;
    scale.setValues(1, 1);
    position.setValues(parkingCoordinate, parkingCoordinate);
  }

  @override
  void update(double dt) {
    if (!_isActive || _isWarmup || dt <= 0) {
      return;
    }
    var remainingTime = dt;
    while (_isActive && remainingTime > 0.0000001) {
      final step = math.min(remainingTime, maximumSimulationStep);
      _integrate(step);
      remainingTime -= step;
    }
  }

  void _integrate(double dt) {
    _age += dt;
    if (_age >= _lifetime) {
      deactivate();
      return;
    }
    final drag = math.exp(-airResistance * dt);
    _velocity
      ..x *= drag
      ..y = _velocity.y * drag + gravity * dt;
    position.addScaled(_velocity, dt);
    angle = math.atan2(_velocity.y, _velocity.x) + math.pi / 2;

    final progress = (_age / _lifetime).clamp(0.0, 1.0);
    final easedProgress = progress * progress * (3 - 2 * progress);
    _scaleProgress = 1 - easedProgress;
    final visualScale = _initialScale * _scaleProgress;
    scale.setValues(visualScale, visualScale);
    _fadeIndex = (easedProgress * (TankMuzzleParticlePalette.fadeSteps - 1))
        .round()
        .clamp(0, TankMuzzleParticlePalette.fadeSteps - 1);
  }

  @override
  void render(Canvas canvas) {
    if (!_isActive) {
      return;
    }
    canvas
      ..drawRRect(_glowShape, palette.glowPaints[_colorIndex][_fadeIndex])
      ..drawRRect(_coreShape, palette.corePaints[_colorIndex][_fadeIndex]);
  }
}
