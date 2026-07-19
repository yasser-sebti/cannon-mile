import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import 'tank_track_morph_component.dart';

enum TankLaserParticleKind { colorDodge, graphic }

class TankLaserParticleComponent extends PositionComponent {
  TankLaserParticleComponent({required this.sprites})
    : assert(sprites.length == TankLaserParticleKind.values.length),
      super(
        position: Vector2.all(parkingCoordinate),
        anchor: Anchor.center,
        priority: 16,
      );

  static const List<String> assetPaths = [
    'effects/laser-beam-effect-color-dodge.webp',
    'effects/laser-beam-effect.webp',
  ];
  static const int poolCapacity = 192;
  static const int fadeSteps = 24;
  static const double parkingCoordinate = -10000;
  static const double maximumSimulationStep = 1 / 120;

  static final List<List<Paint>> _paints = List.unmodifiable([
    _buildPaints(BlendMode.colorDodge, 0.82),
    _buildPaints(BlendMode.plus, 0.92),
  ]);

  final List<Sprite> sprites;
  final Vector2 _velocity = Vector2.zero();
  bool _isActive = false;
  bool _isWarmup = false;
  TankLaserParticleKind _kind = TankLaserParticleKind.graphic;
  double _age = 0;
  double _lifetime = 0;
  double _lateralOffset = 0;
  double _distanceFromMuzzle = 0;
  double _travelDistance = 0;
  double _travelSpeed = 0;
  int _fadeIndex = 0;

  bool get isActive => _isActive;
  bool get isWarmup => _isWarmup;
  bool get usesMotionPhysics => false;
  TankLaserParticleKind get kind => _kind;
  double get age => _age;
  double get lifetime => _lifetime;
  double get lateralOffset => _lateralOffset;
  double get distanceFromMuzzle => _distanceFromMuzzle;
  Vector2 get velocity => _velocity.clone();

  void activate({
    required TankLaserParticleKind kind,
    required double lateralOffset,
    required double distanceFromMuzzle,
    required double travelSpeed,
    required double travelDistance,
    required double height,
  }) {
    assert(travelSpeed > 0);
    assert(travelDistance > distanceFromMuzzle);
    final sprite = sprites[kind.index];
    _kind = kind;
    _lateralOffset = lateralOffset;
    _distanceFromMuzzle = distanceFromMuzzle;
    _travelDistance = travelDistance;
    _travelSpeed = travelSpeed;
    _velocity.setValues(0, -travelSpeed);
    size.setValues(height * sprite.srcSize.x / sprite.srcSize.y, height);
    angle = 0;
    _lifetime = (travelDistance - distanceFromMuzzle) / travelSpeed;
    _age = 0;
    _fadeIndex = 0;
    _isWarmup = false;
    _isActive = true;
    _syncToBeam();
  }

  void activateForWarmup({
    required TankLaserParticleKind kind,
    required double lateralOffset,
    required double distanceFromMuzzle,
  }) {
    activate(
      kind: kind,
      lateralOffset: lateralOffset,
      distanceFromMuzzle: distanceFromMuzzle,
      travelSpeed: 1,
      travelDistance: distanceFromMuzzle + 1,
      height: kind == TankLaserParticleKind.colorDodge ? 58 : 46,
    );
    _isWarmup = true;
  }

  void deactivate() {
    _isActive = false;
    _isWarmup = false;
    _velocity.setZero();
    _age = 0;
    _lifetime = 0;
    _lateralOffset = 0;
    _distanceFromMuzzle = 0;
    _travelDistance = 0;
    _travelSpeed = 0;
    _fadeIndex = 0;
    angle = 0;
    size.setZero();
    position.setValues(parkingCoordinate, parkingCoordinate);
  }

  @override
  void update(double dt) {
    if (!_isActive || _isWarmup || dt <= 0) {
      return;
    }
    var remaining = dt;
    while (_isActive && remaining > 0.0000001) {
      final step = math.min(remaining, maximumSimulationStep);
      _integrate(step);
      remaining -= step;
    }
  }

  void _integrate(double dt) {
    _age += dt;
    _distanceFromMuzzle += _travelSpeed * dt;
    if (_age >= _lifetime || _distanceFromMuzzle >= _travelDistance) {
      deactivate();
      return;
    }
    _syncToBeam();

    final progress = (_age / _lifetime).clamp(0.0, 1.0);
    final fadeProgress = progress * progress * (3 - 2 * progress);
    _fadeIndex = (fadeProgress * (fadeSteps - 1)).round().clamp(
      0,
      fadeSteps - 1,
    );
  }

  void _syncToBeam() {
    final beam = parent;
    if (beam is! PositionComponent) {
      return;
    }
    position.setValues(
      beam.size.x / 2 + _lateralOffset,
      beam.size.y - _distanceFromMuzzle,
    );
  }

  @override
  void render(Canvas canvas) {
    if (!_isActive) {
      return;
    }
    sprites[_kind.index].render(
      canvas,
      size: size,
      overridePaint: _paints[_kind.index][_fadeIndex],
    );
  }

  static List<Paint> _buildPaints(BlendMode blendMode, double maximumAlpha) {
    return List.unmodifiable([
      for (var index = 0; index < fadeSteps; index++)
        createTankSpritePaint(filterQuality: FilterQuality.medium)
          ..blendMode = blendMode
          ..color = Color.fromARGB(
            (255 * maximumAlpha * (1 - index / (fadeSteps - 1))).round(),
            255,
            255,
            255,
          ),
    ]);
  }
}
