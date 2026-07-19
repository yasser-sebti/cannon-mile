import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../cannon_mile_game.dart';
import '../enemies/plane_collision_mask_cache.dart';
import 'tank_bullet_level.dart';
import 'tank_track_morph_component.dart';

class TankBulletComponent extends SpriteComponent
    with HasGameReference<CannonMileGame> {
  TankBulletComponent({
    required List<Sprite> sprites,
    required List<ProjectileCollisionProfile> collisionProfiles,
  }) : assert(sprites.length == TankBulletLevel.values.length),
       assert(collisionProfiles.length == TankBulletLevel.values.length),
       _sprites = sprites,
       _collisionProfiles = collisionProfiles,
       _collisionProfile = collisionProfiles.first,
       super(
         sprite: sprites.first,
         size: Vector2.zero(),
         position: Vector2(-10000, -10000),
         anchor: Anchor.bottomCenter,
         paint: createTankSpritePaint(filterQuality: FilterQuality.medium),
         priority: 2,
       );

  static const double speed = 1440;
  static const double maximumLifetime = 2.5;
  static const int poolCapacity = 96;

  final List<Sprite> _sprites;
  final List<ProjectileCollisionProfile> _collisionProfiles;
  ProjectileCollisionProfile _collisionProfile;
  final Vector2 direction = Vector2.zero();
  final Vector2 _previousPosition = Vector2(-10000, -10000);
  TankBulletLevel _level = TankBulletLevel.level1;
  double _tankScale = 1;
  double _angleCosine = 1;
  double _angleSine = 0;
  bool _isActive = false;
  double _age = 0;

  TankBulletLevel get level => _level;
  double get tankScale => _tankScale;
  bool get isActive => _isActive;
  double get age => _age;
  int get damage => _level.damage;
  ProjectileCollisionProfile get collisionProfile => _collisionProfile;
  double get collisionPixelScale => size.x / _collisionProfile.sourceWidth;
  double get collisionRadius =>
      _collisionProfile.boundingRadius * collisionPixelScale;
  Vector2 get previousPosition => _previousPosition.clone();
  double get previousX => _previousPosition.x;
  double get previousY => _previousPosition.y;
  double get angleCosine => _angleCosine;
  double get angleSine => _angleSine;
  double get collisionCenterX =>
      position.x +
      (_angleCosine * _collisionProfile.centerX -
              _angleSine * _collisionProfile.centerY) *
          collisionPixelScale;
  double get collisionCenterY =>
      position.y +
      (_angleSine * _collisionProfile.centerX +
              _angleCosine * _collisionProfile.centerY) *
          collisionPixelScale;
  double get previousCollisionCenterX =>
      _previousPosition.x +
      (_angleCosine * _collisionProfile.centerX -
              _angleSine * _collisionProfile.centerY) *
          collisionPixelScale;
  double get previousCollisionCenterY =>
      _previousPosition.y +
      (_angleSine * _collisionProfile.centerX +
              _angleCosine * _collisionProfile.centerY) *
          collisionPixelScale;

  static Future<List<Sprite>> bakeLevelSprites(
    List<Sprite> sourceSprites,
  ) async {
    final bakedSprites = <Sprite>[];
    for (final level in TankBulletLevel.values) {
      final source = sourceSprites[level.artworkIndex];
      final width = source.srcSize.x.ceil();
      final height = source.srcSize.y.ceil();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = createTankSpritePaint(filterQuality: FilterQuality.medium);
      if (level.brightness < 1) {
        final brightness = level.brightness;
        paint.colorFilter = ColorFilter.matrix([
          brightness,
          0,
          0,
          0,
          0,
          0,
          brightness,
          0,
          0,
          0,
          0,
          0,
          brightness,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      }
      source.render(
        canvas,
        size: Vector2(width.toDouble(), height.toDouble()),
        overridePaint: paint,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      picture.dispose();
      bakedSprites.add(Sprite(image));
    }
    return List.unmodifiable(bakedSprites);
  }

  void activate({
    required TankBulletLevel level,
    required double tankScale,
    required Vector2 position,
    required double cannonAngle,
  }) {
    assert(tankScale > 0);
    _level = level;
    _collisionProfile = _collisionProfiles[level.index];
    _tankScale = tankScale;
    sprite = _sprites[level.index];
    final sizeScale = level.renderScale * tankScale;
    size.setValues(
      sprite!.srcSize.x * sizeScale,
      sprite!.srcSize.y * sizeScale,
    );
    this.position.setFrom(position);
    _previousPosition.setFrom(position);
    angle = cannonAngle;
    _angleCosine = math.cos(cannonAngle);
    _angleSine = math.sin(cannonAngle);
    direction.setValues(math.sin(cannonAngle), -math.cos(cannonAngle));
    _age = 0;
    _isActive = true;
  }

  void deactivate() {
    _isActive = false;
    _age = 0;
    position.setValues(-10000, -10000);
  }

  @override
  void update(double dt) {
    if (!_isActive || dt <= 0) {
      return;
    }
    super.update(dt);
    _previousPosition.setFrom(position);
    _age += dt;
    position.addScaled(direction, speed * dt);
    final boundsMargin = math.max(size.x, size.y);
    final isOutsideStage =
        isMounted &&
        (position.x < -boundsMargin ||
            position.x > game.size.x + boundsMargin ||
            position.y < -boundsMargin ||
            position.y > game.size.y + boundsMargin);
    if (_age >= maximumLifetime || isOutsideStage) {
      deactivate();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_isActive) {
      super.render(canvas);
    }
  }
}
