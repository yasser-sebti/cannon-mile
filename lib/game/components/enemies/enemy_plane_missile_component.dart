import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

class EnemyPlaneMissileComponent extends PositionComponent {
  EnemyPlaneMissileComponent({required this.groundLineProvider})
    : super(
        position: Vector2.all(parkingCoordinate),
        size: Vector2(missileWidth, missileHeight),
        anchor: Anchor.center,
        priority: 8,
      );

  static const int poolCapacity = 64;
  static const double missileWidth = 11;
  static const double missileHeight = 20;
  static const double gravity = 860;
  static const double airResistance = 0.10;
  static const double maximumSimulationStep = 1 / 120;
  static const double maximumLifetime = 4;
  static const double parkingCoordinate = -10000;
  static const int maximumHealth = 1;

  static final Path _trianglePath = Path()
    ..moveTo(missileWidth / 2, missileHeight)
    ..lineTo(0, 0)
    ..lineTo(missileWidth, 0)
    ..close();
  static final Paint _fillPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill
    ..color = const Color(0xFFFF8A00);
  static final Paint _outlinePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = const Color(0xFF42230A);

  final double Function() groundLineProvider;
  final Vector2 _velocity = Vector2.zero();
  final Vector2 _previousPosition = Vector2.all(parkingCoordinate);
  bool _isActive = false;
  bool _isWarmup = false;
  bool _impactPending = false;
  double _age = 0;
  double _impactX = 0;
  double _impactY = 0;
  double _previousAngle = 0;
  int _currentHealth = maximumHealth;

  bool get isActive => _isActive;
  bool get isWarmup => _isWarmup;
  bool get impactPending => _impactPending;
  double get age => _age;
  double get impactX => _impactX;
  double get impactY => _impactY;
  int get maxHealth => maximumHealth;
  int get currentHealth => _currentHealth;
  double get previousX => _previousPosition.x;
  double get previousY => _previousPosition.y;
  double get previousAngle => _previousAngle;
  Vector2 get velocity => _velocity.clone();
  double get velocityX => _velocity.x;
  double get velocityY => _velocity.y;
  double get groundLine => groundLineProvider();

  void activate({
    required double x,
    required double y,
    required double velocityX,
    required double velocityY,
  }) {
    position.setValues(x, y);
    _previousPosition.setValues(x, y);
    _velocity.setValues(velocityX, velocityY);
    angle = math.atan2(velocityY, velocityX) - math.pi / 2;
    _previousAngle = angle;
    _currentHealth = maximumHealth;
    _age = 0;
    _impactX = 0;
    _impactY = 0;
    _impactPending = false;
    _isWarmup = false;
    _isActive = true;
  }

  void activateForWarmup({required double x, required double y}) {
    activate(x: x, y: y, velocityX: 80, velocityY: 160);
    _isWarmup = true;
  }

  void clearPendingImpact() {
    _impactPending = false;
    _impactX = 0;
    _impactY = 0;
    position.setValues(parkingCoordinate, parkingCoordinate);
    _previousPosition.setValues(parkingCoordinate, parkingCoordinate);
  }

  bool takeDamage(int damage) {
    if (!_isActive || damage <= 0) {
      return false;
    }
    _currentHealth = math.max(0, _currentHealth - damage);
    return _currentHealth == 0;
  }

  void deactivate() {
    _isActive = false;
    _isWarmup = false;
    _impactPending = false;
    _age = 0;
    _impactX = 0;
    _impactY = 0;
    _velocity.setZero();
    angle = 0;
    _previousAngle = 0;
    position.setValues(parkingCoordinate, parkingCoordinate);
    _previousPosition.setValues(parkingCoordinate, parkingCoordinate);
  }

  @override
  void update(double dt) {
    if (!_isActive || _isWarmup || dt <= 0) {
      return;
    }
    super.update(dt);
    _previousPosition.setFrom(position);
    _previousAngle = angle;
    var remainingTime = dt;
    while (_isActive && remainingTime > 0.0000001) {
      final step = math.min(remainingTime, maximumSimulationStep);
      _integrate(step);
      remainingTime -= step;
    }
  }

  void _integrate(double dt) {
    _age += dt;
    if (_age >= maximumLifetime) {
      deactivate();
      return;
    }

    final drag = math.exp(-airResistance * dt);
    _velocity
      ..x *= drag
      ..y = _velocity.y * drag + gravity * dt;
    position.addScaled(_velocity, dt);
    angle = math.atan2(_velocity.y, _velocity.x) - math.pi / 2;

    final projectedBottomExtent =
        math.sin(angle).abs() * size.x / 2 + math.cos(angle).abs() * size.y / 2;
    final ground = groundLine;
    if (position.y + projectedBottomExtent >= ground) {
      position.y = ground - projectedBottomExtent;
      _impactX = position.x;
      _impactY = ground;
      _impactPending = true;
      _isActive = false;
      _velocity.setZero();
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_isActive) {
      return;
    }
    canvas
      ..drawPath(_trianglePath, _fillPaint)
      ..drawPath(_trianglePath, _outlinePaint);
  }
}
