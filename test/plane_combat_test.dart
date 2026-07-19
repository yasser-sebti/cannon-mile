import 'dart:math' as math;

import 'package:cannon_mile/game/cannon_mile_game.dart';
import 'package:cannon_mile/game/components/effects/bullet_hit_effect_component.dart';
import 'package:cannon_mile/game/components/effects/bullet_hit_particle_component.dart';
import 'package:cannon_mile/game/components/effects/ground_hit_effect_component.dart';
import 'package:cannon_mile/game/components/effects/ground_hit_smoke_component.dart';
import 'package:cannon_mile/game/components/effects/plane_explosion_component.dart';
import 'package:cannon_mile/game/components/effects/plane_smoke_component.dart';
import 'package:cannon_mile/game/components/effects/plane_smoke_particle_component.dart';
import 'package:cannon_mile/game/components/enemies/enemy_plane_component.dart';
import 'package:cannon_mile/game/components/enemies/enemy_plane_missile_component.dart';
import 'package:cannon_mile/game/components/enemies/enemy_plane_spawn.dart';
import 'package:cannon_mile/game/components/enemies/plane_collision_mask_cache.dart';
import 'package:cannon_mile/game/components/tank/tank_bullet_component.dart';
import 'package:cannon_mile/game/components/tank/tank_bullet_level.dart';
import 'package:cannon_mile/game/components/tank/tank_bullet_shell_component.dart';
import 'package:cannon_mile/game/components/tank/tank_component.dart';
import 'package:cannon_mile/game/components/tank/tank_fire_sound_player.dart';
import 'package:cannon_mile/game/components/tank/tank_movement_mode.dart';
import 'package:cannon_mile/game/components/tank/tank_laser_component.dart';
import 'package:cannon_mile/game/components/tank/tank_weapon_mode.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<CannonMileGame> _loadCombatGame(
  WidgetTester tester, {
  int impactSeed = 83,
}) async {
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  final game = CannonMileGame(
    fireSoundPlayer: SilentTankFireSoundPlayer(random: math.Random(7)),
    impactRandom: math.Random(impactSeed),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: GameWidget<CannonMileGame>(game: game)),
    ),
  );
  var initialized = false;
  Object? initializationError;
  StackTrace? initializationStackTrace;
  game.initialized.then(
    (_) => initialized = true,
    onError: (Object error, StackTrace stackTrace) {
      initializationError = error;
      initializationStackTrace = stackTrace;
    },
  );
  for (var index = 0; index < 120 && !initialized; index++) {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (initializationError != null) {
      Error.throwWithStackTrace(
        initializationError!,
        initializationStackTrace!,
      );
    }
  }
  expect(initialized, isTrue, reason: 'Combat assets did not finish loading.');
  await tester.pump();
  game.pauseEngine();
  return game;
}

EnemyPlaneComponent _activatePlane(
  CannonMileGame game, {
  double speed = 280,
  bool movesRight = true,
  double x = 960,
  double y = 300,
}) {
  final plane = game.world.children.whereType<EnemyPlaneComponent>().firstWhere(
    (candidate) => !candidate.isActive,
  );
  plane.activate(
    movesRight: movesRight,
    speed: speed,
    altitudeLane: 0,
    position: Vector2(x, y),
  );
  return plane;
}

TankBulletComponent _activateBulletAtCollisionCenter(
  CannonMileGame game, {
  required TankBulletLevel level,
  required Vector2 collisionCenter,
  required double cannonAngle,
}) {
  final bullet = game.world.tank.bulletPoolForCollision.firstWhere(
    (candidate) => !candidate.isActive,
  );
  bullet.activate(
    level: level,
    tankScale: TankComponent.tankVisualScale,
    position: Vector2.zero(),
    cannonAngle: cannonAngle,
  );
  final profile = bullet.collisionProfile;
  final pixelScale = bullet.collisionPixelScale;
  final cosine = math.cos(cannonAngle);
  final sine = math.sin(cannonAngle);
  final profileCenterX =
      (cosine * profile.centerX - sine * profile.centerY) * pixelScale;
  final profileCenterY =
      (sine * profile.centerX + cosine * profile.centerY) * pixelScale;
  bullet.activate(
    level: level,
    tankScale: TankComponent.tankVisualScale,
    position: Vector2(
      collisionCenter.x - profileCenterX,
      collisionCenter.y - profileCenterY,
    ),
    cannonAngle: cannonAngle,
  );
  return bullet;
}

TankBulletComponent _fireCollisionBullet(
  CannonMileGame game,
  EnemyPlaneComponent plane,
  TankBulletLevel level, {
  double cannonAngle = 0,
  double approachDistance = 100,
}) {
  final directionX = math.sin(cannonAngle);
  final directionY = -math.cos(cannonAngle);
  return _activateBulletAtCollisionCenter(
    game,
    level: level,
    collisionCenter: Vector2(
      plane.position.x - directionX * approachDistance,
      plane.position.y - directionY * approachDistance,
    ),
    cannonAngle: cannonAngle,
  );
}

Vector2 _planeSourcePixelToWorld(
  EnemyPlaneComponent plane,
  SpriteAlphaMask mask,
  double sourceX,
  double sourceY,
) {
  final normalizedSourceX = sourceX / mask.width;
  final normalizedWorldX = plane.movesRight
      ? normalizedSourceX
      : 1 - normalizedSourceX;
  return Vector2(
    plane.position.x + (normalizedWorldX - 0.5) * plane.size.x,
    plane.position.y + (sourceY / mask.height - 0.5) * plane.size.y,
  );
}

void main() {
  test('bullet levels expose six-step damage', () {
    expect(TankBulletLevel.values.map((level) => level.damage), [
      1,
      2,
      3,
      4,
      5,
      6,
    ]);
  });

  testWidgets('collision masks use visible-alpha thresholds', (tester) async {
    final game = await _loadCombatGame(tester);
    final cache = game.collisionMaskCache;

    expect(
      cache.planeMask.alphaThreshold,
      PlaneCollisionMaskCache.planeAlphaThreshold,
    );
    expect(PlaneCollisionMaskCache.planeAlphaThreshold, 64);
    expect(PlaneCollisionMaskCache.projectileAlphaThreshold, 128);
    expect(cache.planeMask.isSolid(356, 0), isFalse);
    expect(cache.planeMask.isSolid(30, 0), isTrue);
    expect(cache.projectileProfiles, hasLength(6));
    for (final profile in cache.projectileProfiles) {
      expect(profile.alphaThreshold, 128);
      expect(profile.boundaryPointCount, greaterThan(0));
      expect(profile.boundingRadius, greaterThan(0));
    }

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a swept hit damages and softly flashes a moving plane', (
    tester,
  ) async {
    final game = await _loadCombatGame(tester);
    final plane = _activatePlane(game);
    final bullet = _fireCollisionBullet(game, plane, TankBulletLevel.level1);
    final previousBulletPosition = bullet.position.clone();

    game.update(0.1);

    expect(bullet.previousPosition, previousBulletPosition);
    expect(bullet.isActive, isFalse);
    expect(plane.maxHealth, 6);
    expect(plane.currentHealth, EnemyPlaneComponent.maximumHealth - 1);
    expect(plane.isHitFlashing, isTrue);
    expect(plane.hitOverlayStrength, closeTo(0.48, 0.0001));
    expect(plane.cachedHitOverlayPaintCount, 16);
    expect(game.bulletHits, 1);
    expect(game.planesDestroyed, 0);
    expect(game.bulletHitEffects, hasLength(1));
    expect(game.bulletHitParticles.length, inInclusiveRange(12, 16));
    expect(game.lastBulletHitParticleCount, game.bulletHitParticles.length);
    final sounds = game.fireSounds as SilentTankFireSoundPlayer;
    expect(sounds.metalHitPlayCount, 1);

    final effect = game.bulletHitEffects.single;
    expect(effect.frameIndex, 0);
    expect(effect.angle, math.pi);
    expect(effect.hasPrebakedGlow, isTrue);
    expect(effect.usesRuntimeGlow, isFalse);
    expect(effect.cachedFrameCount, BulletHitEffectComponent.frameCount);
    expect(
      effect.visualScale,
      inInclusiveRange(
        BulletHitEffectComponent.minimumVisualScale,
        BulletHitEffectComponent.maximumVisualScale,
      ),
    );
    expect(effect.attachedPlane, same(plane));
    final effectX = effect.position.x;
    final planeX = plane.position.x;
    game.update(BulletHitEffectComponent.frameDuration + 0.0001);
    expect(effect.frameIndex, 1);
    expect(
      effect.position.x - effectX,
      closeTo(plane.position.x - planeX, 0.0001),
    );
    game.update(EnemyPlaneComponent.hitFlashDuration);
    expect(plane.isHitFlashing, isFalse);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a lethal level-six hit removes the plane immediately', (
    tester,
  ) async {
    final game = await _loadCombatGame(tester);
    final plane = _activatePlane(game, movesRight: false);
    _fireCollisionBullet(game, plane, TankBulletLevel.level6);

    game.update(0.1);

    expect(plane.currentHealth, 0);
    expect(plane.isActive, isFalse);
    expect(game.world.planes, isEmpty);
    expect(game.planesDestroyed, 1);
    final sounds = game.fireSounds as SilentTankFireSoundPlayer;
    expect(sounds.explosionPlayCount, 0);
    expect(sounds.metalHitPlayCount, 1);
    expect(game.planeExplosions, hasLength(1));
    final explosion = game.planeExplosions.single;
    expect(explosion.frameIndex, 0);
    expect(explosion.fadeProgress, 0);
    expect(explosion.hasPrebakedGlow, isTrue);
    expect(explosion.usesRuntimeBlur, isFalse);
    expect(explosion.cachedFrameCount, 6);
    expect(PlaneExplosionComponent.glowSigma, 18);
    expect(PlaneExplosionComponent.glowPadding, 42);
    expect(PlaneExplosionComponent.coreGlowSigma, 7);
    expect(PlaneExplosionComponent.duration, closeTo(0.228, 0.0001));
    expect(explosion.position.x, closeTo(932, 0.0001));
    expect(explosion.position.y, closeTo(300, 0.0001));
    final initialExplosionWidth = explosion.size.x;
    explosion.update(PlaneExplosionComponent.frameDuration / 2);
    expect(explosion.size.x, greaterThan(initialExplosionWidth));
    explosion.update(PlaneExplosionComponent.duration * 0.60);
    expect(explosion.fadeProgress, greaterThan(0));
    explosion.update(PlaneExplosionComponent.duration);
    expect(explosion.isActive, isFalse);
    expect(game.world.availablePlaneExplosionCount, 12);
    expect(game.planeSmokeEffects, hasLength(1));
    final smoke = game.planeSmokeEffects.single;
    expect(smoke.priority, lessThan(explosion.priority));
    expect(PlaneSmokeComponent.activationDelay, 0);
    expect(smoke.isDelayComplete, isTrue);
    expect(smoke.isVisible, isTrue);
    expect(smoke.frameIndex, 0);
    final smokeStartY = smoke.position.y;
    smoke.update(PlaneSmokeComponent.frameDuration);
    expect(smoke.frameIndex, 1);
    expect(smoke.position.y, lessThan(smokeStartY));
    smoke.update(PlaneSmokeComponent.duration);
    expect(smoke.isActive, isFalse);
    expect(game.world.availablePlaneSmokeCount, 12);

    final smokeParticles = game.planeSmokeParticles.toList(growable: false);
    expect(smokeParticles.length, inInclusiveRange(14, 18));
    expect(game.lastPlaneSmokeParticleCount, smokeParticles.length);
    final burstParticles = smokeParticles
        .where((particle) => particle.type == PlaneSmokeParticleType.burst)
        .toList(growable: false);
    final lingeringParticles = smokeParticles
        .where((particle) => particle.type == PlaneSmokeParticleType.lingering)
        .toList(growable: false);
    expect(burstParticles.length, inInclusiveRange(7, 9));
    expect(lingeringParticles.length, inInclusiveRange(7, 9));
    expect(burstParticles.first.inheritedWorldVelocity, 0);
    expect(
      lingeringParticles.first.inheritedWorldVelocity,
      -TankBulletShellComponent.continuousGroundDriftSpeed,
    );
    game.setMovementMode(TankMovementMode.bossFight);
    expect(lingeringParticles.first.inheritedWorldVelocity, 0);
    game.setMovementMode(TankMovementMode.continuous);
    const allSmokeArtwork = {0, 1, 2, 3, 4, 5, 6};
    expect(
      burstParticles.map((particle) => particle.artworkIndex).toSet(),
      allSmokeArtwork,
    );
    expect(
      lingeringParticles.map((particle) => particle.artworkIndex).toSet(),
      allSmokeArtwork,
    );
    expect(
      lingeringParticles.first.velocity.x,
      lessThan(lingeringParticles.last.velocity.x),
    );
    for (final particle in smokeParticles) {
      expect(particle.priority, lessThan(explosion.priority));
      expect(
        particle.size.y,
        PlaneSmokeParticleComponent.targetHeights[particle.artworkIndex],
      );
      if (particle.type == PlaneSmokeParticleType.burst) {
        expect(particle.velocity.y, inInclusiveRange(-180, -60));
        expect(particle.activationDelay, inInclusiveRange(0.015, 0.060));
        expect(particle.lifetime, inInclusiveRange(0.65, 1.05));
      } else {
        expect(particle.velocity.y, inInclusiveRange(-86, -48));
        expect(particle.activationDelay, inInclusiveRange(0.12, 0.30));
        expect(particle.lifetime, inInclusiveRange(1.35, 2.0));
      }
      final startY = particle.position.y;
      particle.update(particle.activationDelay + 0.05);
      expect(particle.position.y, lessThan(startY));
      particle.update(particle.isLingering ? 2.1 : 1.1);
      expect(particle.isActive, isFalse);
    }
    expect(game.world.availablePlaneSmokeParticleCount, 256);
    final effect = game.bulletHitEffects.single;
    expect(effect.attachedPlane, isNull);
    final impactPosition = effect.position.clone();
    game.update(BulletHitEffectComponent.frameDuration);
    expect(effect.position, impactPosition);
    plane.activate(
      movesRight: true,
      speed: 280,
      altitudeLane: 1,
      position: Vector2(900, 320),
    );
    expect(plane.currentHealth, EnemyPlaneComponent.maximumHealth);
    expect(plane.isHitFlashing, isFalse);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('fast glowing impact and dense particles finish through pools', (
    tester,
  ) async {
    final game = await _loadCombatGame(tester, impactSeed: 19);
    final plane = _activatePlane(game, speed: 700);
    _fireCollisionBullet(game, plane, TankBulletLevel.level2);
    game.update(0.1);

    final effect = game.bulletHitEffects.single;
    expect(BulletHitEffectComponent.duration, 0.070);
    expect(BulletHitEffectComponent.glowSigma, 5);
    expect(BulletHitEffectComponent.glowAlpha, 0.65);
    expect(effect.hasPrebakedGlow, isTrue);
    expect(
      effect.size.x,
      closeTo(effect.frameCache.renderSize.x * effect.visualScale, 0.0001),
    );
    expect(
      effect.size.y,
      closeTo(effect.frameCache.renderSize.y * effect.visualScale, 0.0001),
    );
    for (var frame = 1; frame < BulletHitEffectComponent.frameCount; frame++) {
      effect.update(BulletHitEffectComponent.frameDuration + 0.000001);
      expect(effect.frameIndex, frame);
    }
    effect.update(BulletHitEffectComponent.frameDuration);
    expect(effect.isActive, isFalse);
    expect(game.world.availableBulletHitCount, 12);

    final particles = game.bulletHitParticles.toList(growable: false);
    expect(particles.length, inInclusiveRange(12, 16));
    expect(particles.map((particle) => particle.artworkIndex).toSet(), {
      0,
      1,
      2,
    });
    for (final particle in particles) {
      expect(
        particle.tintColor,
        BulletHitParticleComponent.tintColors[particle.artworkIndex],
      );
      expect(
        particle.size.y,
        BulletHitParticleComponent.targetHeights[particle.artworkIndex],
      );
      expect(particle.velocity.x, inInclusiveRange(-30, 450));
      expect(particle.velocity.y, inInclusiveRange(80, 220));
      expect(particle.angularVelocity, inInclusiveRange(-10, 10));
      expect(particle.lifetime, inInclusiveRange(0.22, 0.38));
      expect(particle.tintPaint.colorFilter, isNotNull);
      final originalY = particle.position.y;
      particle.update(0.05);
      expect(particle.position.y, greaterThan(originalY));
      expect(particle.scaleProgress, lessThan(1));
    }
    for (final particle in particles) {
      particle.update(0.40);
      expect(particle.isActive, isFalse);
    }
    expect(game.world.availableBulletHitParticleCount, 256);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('transparent plane corners miss during a bounds overlap', (
    tester,
  ) async {
    final game = await _loadCombatGame(tester);
    final plane = _activatePlane(game, speed: 0.001);
    final mask = game.collisionMaskCache.planeMask;
    final startCenter = _planeSourcePixelToWorld(plane, mask, 70, 5);
    final bullet = _activateBulletAtCollisionCenter(
      game,
      level: TankBulletLevel.level1,
      collisionCenter: startCenter,
      cannonAngle: math.pi / 2,
    );

    game.update(0.01);

    expect(bullet.isActive, isTrue);
    expect(game.bulletHits, 0);
    expect(plane.currentHealth, plane.maxHealth);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('first impact resolves to an opaque pixel on mirrored planes', (
    tester,
  ) async {
    for (final movesRight in [true, false]) {
      final game = await _loadCombatGame(
        tester,
        impactSeed: movesRight ? 7 : 8,
      );
      final plane = _activatePlane(game, speed: 0.001, movesRight: movesRight);
      final mask = game.collisionMaskCache.planeMask;
      final startSourceX = movesRight ? -20.0 : mask.width + 20.0;
      final startCenter = _planeSourcePixelToWorld(
        plane,
        mask,
        startSourceX,
        50,
      );
      _activateBulletAtCollisionCenter(
        game,
        level: TankBulletLevel.level1,
        collisionCenter: startCenter,
        cannonAngle: math.pi / 2,
      );

      game.update(0.04);

      expect(game.bulletHits, 1);
      var normalizedX =
          (game.lastResolvedHitX - plane.position.x) / plane.size.x + 0.5;
      if (!movesRight) {
        normalizedX = 1 - normalizedX;
      }
      final sourceX = (normalizedX * mask.width).floor();
      final sourceY =
          (((game.lastResolvedHitY - plane.position.y) / plane.size.y + 0.5) *
                  mask.height)
              .floor();
      expect(mask.isSolid(sourceX, sourceY), isTrue);
      final effect = game.bulletHitEffects.single;
      expect(effect.position.x, closeTo(game.lastResolvedHitX, 0.0001));
      expect(effect.position.y, closeTo(game.lastResolvedHitY, 0.0001));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('angled projectile cores use the same pixel sweep', (
    tester,
  ) async {
    final game = await _loadCombatGame(tester);
    final plane = _activatePlane(game, speed: 280);
    _fireCollisionBullet(
      game,
      plane,
      TankBulletLevel.level2,
      cannonAngle: math.pi / 4,
    );

    game.update(0.1);

    expect(game.bulletHits, 1);
    expect(plane.currentHealth, 4);
    expect(game.lastResolvedHitX.isFinite, isTrue);
    expect(game.lastResolvedHitY.isFinite, isTrue);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('plane red overlay scales with damage and fades smoothly', (
    tester,
  ) async {
    final game = await _loadCombatGame(tester);
    final plane = _activatePlane(game, speed: 0.001);

    plane.takeDamage(1);
    expect(plane.hitOverlayPeakStrength, closeTo(0.48, 0.0001));
    expect(plane.hitOverlayStrength, closeTo(0.48, 0.0001));
    plane.update(0.05);
    expect(plane.hitOverlayStrength, closeTo(0.24, 0.0001));
    plane.takeDamage(4);
    expect(plane.hitOverlayStrength, closeTo(0.60, 0.0001));
    plane.takeDamage(1);
    expect(plane.hitOverlayPeakStrength, closeTo(0.60, 0.0001));
    plane.update(EnemyPlaneComponent.hitFlashDuration);
    expect(plane.hitOverlayStrength, 0);

    plane.activate(
      movesRight: true,
      speed: 0.001,
      altitudeLane: 0,
      position: Vector2(960, 300),
    );
    plane.takeDamage(5);
    expect(plane.hitOverlayStrength, closeTo(0.64, 0.0001));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'plane missiles curve into pooled ground effects without damage',
    (tester) async {
      final game = await _loadCombatGame(tester);
      final plane = game.world.children
          .whereType<EnemyPlaneComponent>()
          .firstWhere((candidate) => !candidate.isActive);
      plane.activate(
        movesRight: true,
        speed: 400,
        altitudeLane: 0,
        missileDropDelay: 0.01,
        position: Vector2(700, 260),
      );

      game.update(0.02);

      expect(game.planeMissiles, hasLength(1));
      final missile = game.planeMissiles.single;
      expect(missile, isA<EnemyPlaneMissileComponent>());
      expect(missile.velocity.x, greaterThan(0));
      expect(missile.velocity.y, greaterThan(0));
      expect(game.groundHits, 0);

      for (var frame = 0; frame < 240 && game.groundHits == 0; frame++) {
        game.update(1 / 120);
      }

      expect(game.groundHits, 1);
      final sounds = game.fireSounds as SilentTankFireSoundPlayer;
      expect(sounds.explosionPlayCount, 1);
      expect(sounds.lastExplosionSoundIndex, inInclusiveRange(0, 2));
      expect(game.groundHitEffects, hasLength(1));
      expect(game.groundHitSmokeEffects, hasLength(1));
      final groundHit = game.groundHitEffects.single;
      final groundSmoke = game.groundHitSmokeEffects.single;
      expect(groundHit, isA<GroundHitEffectComponent>());
      expect(groundSmoke, isA<GroundHitSmokeComponent>());
      expect(groundHit.priority, greaterThan(game.world.tank.priority));
      expect(groundSmoke.priority, greaterThan(game.world.tank.priority));
      expect(GroundHitEffectComponent.artworkScale, 1);
      expect(groundHit.visualScale, inInclusiveRange(0.30, 0.52));
      expect(groundSmoke.visualScale, groundHit.visualScale);
      expect(groundSmoke.isVisible, isFalse);
      expect(groundHit.hasPrebakedGlow, isTrue);
      expect(groundHit.usesRuntimeBlur, isFalse);
      expect(groundHit.cachedFrameCount, GroundHitEffectComponent.frameCount);
      expect(GroundHitEffectComponent.glowSigma, 14);
      expect(GroundHitEffectComponent.glowPadding, 34);
      expect(
        groundHit.position.y,
        closeTo(
          game.world.tank.position.y +
              GroundHitEffectComponent.glowPadding * groundHit.visualScale,
          0.0001,
        ),
      );
      final hitStartX = groundHit.position.x;
      final smokeStartX = groundSmoke.position.x;

      game.update(0.05);

      expect(groundHit.position.x, lessThan(hitStartX));
      expect(groundSmoke.position.x, lessThan(smokeStartX));
      expect(groundSmoke.isVisible, isFalse);
      game.update(0.06);
      expect(groundSmoke.isVisible, isTrue);
      expect(groundSmoke.frameIndex, 0);

      groundHit.update(GroundHitEffectComponent.duration);
      groundSmoke.update(GroundHitSmokeComponent.duration);
      expect(groundHit.isActive, isFalse);
      expect(groundSmoke.isActive, isFalse);

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('one bullet destroys a plane missile with a small explosion', (
    tester,
  ) async {
    final game = await _loadCombatGame(tester);
    final missile = game.world.children
        .whereType<EnemyPlaneMissileComponent>()
        .firstWhere((candidate) => !candidate.isActive);
    missile.activate(x: 960, y: 300, velocityX: 0, velocityY: 100);
    final bullet = _activateBulletAtCollisionCenter(
      game,
      level: TankBulletLevel.level1,
      collisionCenter: Vector2(960, 400),
      cannonAngle: 0,
    );

    expect(missile.maxHealth, 1);
    expect(missile.currentHealth, 1);
    game.update(0.1);

    expect(bullet.isActive, isFalse);
    expect(missile.currentHealth, 0);
    expect(missile.isActive, isFalse);
    expect(game.planeMissiles, isEmpty);
    expect(game.planeMissilesDestroyed, 1);
    expect(game.bulletHits, 1);
    expect(game.groundHits, 0);
    final sounds = game.fireSounds as SilentTankFireSoundPlayer;
    expect(sounds.metalHitPlayCount, 1);
    expect(game.planeExplosions, hasLength(1));
    final explosion = game.planeExplosions.single;
    expect(explosion.visualScale, PlaneExplosionComponent.missileVisualScale);
    expect(PlaneExplosionComponent.missileVisualScale, 0.48);
    expect(explosion.hasPrebakedGlow, isTrue);
    expect(game.planeSmokeEffects, hasLength(1));
    final smoke = game.planeSmokeEffects.single;
    expect(smoke.visualScale, PlaneSmokeComponent.missileVisualScale);
    expect(smoke.priority, lessThan(explosion.priority));
    final smokeParticles = game.planeSmokeParticles.toList(growable: false);
    expect(smokeParticles.length, inInclusiveRange(14, 18));
    expect(game.lastPlaneSmokeParticleCount, smokeParticles.length);
    expect(
      smokeParticles
          .where((particle) => particle.isLingering)
          .every(
            (particle) =>
                particle.inheritedWorldVelocity ==
                -TankBulletShellComponent.continuousGroundDriftSpeed,
          ),
      isTrue,
    );
    expect(
      smokeParticles.every(
        (particle) =>
            particle.scale.x <=
            PlaneSmokeParticleComponent.missileVisualScale * 1.15,
      ),
      isTrue,
    );

    explosion.update(PlaneExplosionComponent.duration);
    expect(explosion.isActive, isFalse);
    expect(game.world.availablePlaneExplosionCount, 12);

    missile.activate(x: 960, y: 300, velocityX: 0, velocityY: 100);
    expect(missile.currentHealth, 1);
    expect(EnemyPlaneMissileComponent.gravity, 860);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('destroyed planes queue an immediate traffic replacement', (
    tester,
  ) async {
    final game = await _loadCombatGame(tester);
    game.setPlaneSpawningEnabled(true);
    final plane = _activatePlane(game, speed: 280);
    _fireCollisionBullet(
      game,
      plane,
      TankBulletLevel.level6,
      approachDistance: 0,
    );

    game.update(0.001);

    expect(plane.isActive, isFalse);
    expect(
      game.world.timeUntilNextPlane,
      lessThanOrEqualTo(EnemyPlaneSpawnTuning.immediateReplacementDelay),
    );
    final spawnedBeforeReplacement = game.world.planesSpawned;
    game.update(EnemyPlaneSpawnTuning.immediateReplacementDelay + 0.01);
    expect(game.world.planesSpawned, greaterThan(spawnedBeforeReplacement));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('charged laser pierces planes and missiles without shot audio', (
    tester,
  ) async {
    final game = await _loadCombatGame(tester);
    final firstPlane = _activatePlane(game, speed: 0.001, y: 300);
    final secondPlane = _activatePlane(game, speed: 0.001, y: 500);
    final missile = game.world.children
        .whereType<EnemyPlaneMissileComponent>()
        .firstWhere((candidate) => !candidate.isActive);
    missile.activate(x: 960, y: 650, velocityX: 0, velocityY: 1);
    final sounds = game.fireSounds as SilentTankFireSoundPlayer;

    game.setWeaponMode(TankWeaponMode.laser);
    game.world.tank.setPointerTarget(Vector2(960, 0));
    game.setTriggerHeld(true);
    game.update(0.10);

    expect(game.isLaserDamageActive, isTrue);
    expect(firstPlane.isActive, isFalse);
    expect(secondPlane.isActive, isFalse);
    expect(missile.isActive, isFalse);
    expect(game.laserHits, 3);
    expect(game.laserTargetsDestroyed, 3);
    expect(game.laser!.lastFrameHitCount, 3);
    expect(game.planesDestroyed, 2);
    expect(game.planeMissilesDestroyed, 1);
    expect(game.planeExplosions, hasLength(3));
    expect(game.bulletHits, 0);
    expect(sounds.metalHitPlayCount, 0);
    expect(sounds.playCount, 0);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('laser glow alone does not damage the visible plane silhouette', (
    tester,
  ) async {
    final game = await _loadCombatGame(tester);
    final mask = game.collisionMaskCache.planeMask;
    var leftBoundarySourceX = mask.width.toDouble();
    for (var index = 0; index < mask.boundaryPointCount; index++) {
      leftBoundarySourceX = math.min(
        leftBoundarySourceX,
        mask.boundaryXs[index],
      );
    }
    final plane = _activatePlane(game, speed: 0.001);
    final leftBoundaryOffset =
        (leftBoundarySourceX / mask.width - 0.5) * plane.size.x;
    const visualGapFromCenter = 30.0;
    plane.activate(
      movesRight: true,
      speed: 0.001,
      altitudeLane: 0,
      position: Vector2(960 + visualGapFromCenter - leftBoundaryOffset, 300),
    );

    game.setWeaponMode(TankWeaponMode.laser);
    game.world.tank.setPointerTarget(Vector2(960, 0));
    game.setTriggerHeld(true);
    game.update(TankLaserComponent.powerUpDuration + 0.01);

    expect(game.laserPower, 1);
    expect(
      visualGapFromCenter,
      greaterThan(TankLaserComponent.maximumCoreWidth / 2),
    );
    expect(
      visualGapFromCenter,
      lessThan(TankLaserComponent.maximumGlowWidth / 2),
    );
    expect(plane.isActive, isTrue);
    expect(game.laserTargetsDestroyed, 0);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('relative sweep catches fast shots at 30, 60, and 120 FPS', (
    tester,
  ) async {
    for (final framesPerSecond in [30, 60, 120]) {
      final game = await _loadCombatGame(tester, impactSeed: framesPerSecond);
      final plane = _activatePlane(game, speed: 700);
      _fireCollisionBullet(game, plane, TankBulletLevel.level1);
      for (var frame = 0; frame < 20 && game.bulletHits == 0; frame++) {
        game.update(1 / framesPerSecond);
      }
      expect(game.bulletHits, 1, reason: 'Missed at $framesPerSecond FPS');
      expect(plane.currentHealth, 5);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    await tester.binding.setSurfaceSize(null);
  });
}
