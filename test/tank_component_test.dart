import 'dart:math' as math;

import 'package:cannon_mile/game/cannon_mile_game.dart';
import 'package:cannon_mile/game/game_loading_progress.dart';
import 'package:cannon_mile/game/components/enemies/enemy_plane_component.dart';
import 'package:cannon_mile/game/components/enemies/enemy_plane_spawn.dart';
import 'package:cannon_mile/game/components/tank/tank_bullet_component.dart';
import 'package:cannon_mile/game/components/tank/tank_bullet_level.dart';
import 'package:cannon_mile/game/components/tank/tank_bullet_shell_component.dart';
import 'package:cannon_mile/game/components/tank/tank_bullet_spread_level.dart';
import 'package:cannon_mile/game/components/tank/tank_component.dart';
import 'package:cannon_mile/game/components/tank/tank_fire_rate_level.dart';
import 'package:cannon_mile/game/components/tank/tank_fire_sound_player.dart';
import 'package:cannon_mile/game/components/tank/tank_movement_mode.dart';
import 'package:cannon_mile/game/components/tank/tank_motion.dart';
import 'package:cannon_mile/game/components/tank/tank_muzzle_flash_component.dart';
import 'package:cannon_mile/game/components/tank/tank_speed_level.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<CannonMileGame> _loadGame(
  WidgetTester tester, {
  TankMovementMode initialMovementMode = TankMovementMode.continuous,
  math.Random? muzzleFlashRandom,
  math.Random? shellRandom,
  math.Random? planeSpawnRandom,
  List<GameLoadingProgress>? progressLog,
}) async {
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  final game = CannonMileGame(
    initialMovementMode: initialMovementMode,
    fireSoundPlayer: SilentTankFireSoundPlayer(random: math.Random(42)),
    muzzleFlashRandom: muzzleFlashRandom,
    shellRandom: shellRandom,
    planeSpawnRandom: planeSpawnRandom,
  );
  void recordProgress() => progressLog?.add(game.loadingProgress.value);
  if (progressLog != null) {
    progressLog.add(game.loadingProgress.value);
    game.loadingProgress.addListener(recordProgress);
  }
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
  for (var i = 0; i < 100 && !initialized; i++) {
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
  expect(initialized, isTrue, reason: 'The tank did not finish loading.');
  if (progressLog != null) {
    game.loadingProgress.removeListener(recordProgress);
  }
  await tester.pump();
  game.pauseEngine();
  return game;
}

Future<({double position, double velocity})> _simulateAtFrameRate(
  WidgetTester tester,
  int framesPerSecond,
) async {
  final game = await _loadGame(
    tester,
    initialMovementMode: TankMovementMode.bossFight,
  );
  final tank = game.world.tank;
  tank.setPointerTarget(Vector2(1900, 500));
  final frameCount = framesPerSecond ~/ 2;
  for (var frame = 0; frame < frameCount; frame++) {
    tank.update(1 / framesPerSecond);
  }
  final result = (position: tank.position.x, velocity: tank.horizontalVelocity);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  return result;
}

Future<({Vector2 position, Vector2 velocity, double angle})>
_simulateShellAtFrameRate(WidgetTester tester, int framesPerSecond) async {
  final game = await _loadGame(
    tester,
    initialMovementMode: TankMovementMode.bossFight,
    shellRandom: math.Random(27),
  );
  final tank = game.world.tank;
  tank.setTriggerHeld(true);
  tank.update(0);
  tank.setTriggerHeld(false);
  final shell = tank.lastShell!;
  for (var frame = 0; frame < framesPerSecond ~/ 2; frame++) {
    shell.update(1 / framesPerSecond);
  }
  final result = (
    position: shell.position.clone(),
    velocity: shell.velocity,
    angle: shell.angle,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  return result;
}

void main() {
  testWidgets('tank layers use filtered fixed composition and render order', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;

    expect(tank.size, Vector2(264, 250));
    expect(tank.scale, Vector2.all(TankComponent.tankVisualScale));
    expect(TankComponent.tankVisualScale, 0.70);
    expect(TankComponent.renderedTankWidth, closeTo(184.8, 0.0001));
    expect(TankComponent.renderedTankHeight, closeTo(175, 0.0001));
    expect(tank.anchor, Anchor.bottomCenter);
    expect(tank.position.x, closeTo(960, 0.0001));
    expect(tank.position.y, closeTo(1000, 0.0001));

    expect(tank.trackPart.size, Vector2(264, 79));
    expect(tank.trackPart.position, Vector2(132, 250));
    expect(tank.trackPart.anchor, Anchor.bottomCenter);
    expect(tank.trackPart.priority, 0);
    expect(tank.trackPart.sprites, hasLength(4));
    for (final sprite in tank.trackPart.sprites) {
      expect(sprite.srcPosition, Vector2(31, 19));
      expect(sprite.srcSize, Vector2(264, 79));
    }
    tank.trackPart.phase = 0.5;
    expect(tank.trackPart.firstFrameIndex, 0);
    expect(tank.trackPart.secondFrameIndex, 1);
    tank.trackPart.phase = 1.5;
    expect(tank.trackPart.firstFrameIndex, 1);
    expect(tank.trackPart.secondFrameIndex, 2);
    tank.trackPart.phase = 2.5;
    expect(tank.trackPart.firstFrameIndex, 2);
    expect(tank.trackPart.secondFrameIndex, 3);
    tank.trackPart.phase = -0.5;
    expect(tank.trackPart.firstFrameIndex, 3);
    expect(tank.trackPart.secondFrameIndex, 0);
    tank.trackPart.phase = 0;

    expect(tank.roundWheelParts, hasLength(3));
    expect(tank.roundWheelParts.map((wheel) => wheel.position.x), [
      52,
      132,
      212,
    ]);
    expect(tank.roundWheelParts.every((wheel) => wheel.priority == 1), isTrue);

    expect(tank.cannonPart.position, Vector2(132, 112));
    expect(tank.cannonPart.anchor, Anchor.bottomCenter);
    expect(tank.cannonPart.priority, 2);
    expect(tank.muzzleFlashPart.parent, same(tank.cannonPart));
    expect(tank.muzzleFlashPart.position, Vector2(20.5, 0));
    expect(
      tank.muzzleFlashPart.size,
      Vector2(
        TankMuzzleFlashComponent.effectWidth,
        TankMuzzleFlashComponent.effectHeight,
      ),
    );
    expect(
      tank.muzzleFlashPart.size * TankComponent.tankVisualScale,
      Vector2(
            TankMuzzleFlashComponent.effectWidth,
            TankMuzzleFlashComponent.effectHeight,
          ) *
          TankComponent.tankVisualScale,
    );
    expect(tank.muzzleFlashPart.anchor, Anchor.bottomCenter);
    expect(tank.muzzleFlashPart.priority, 1);
    expect(tank.muzzleFlashPart.sprites, hasLength(4));
    expect(tank.muzzleFlashPart.sprites.map((sprite) => sprite.srcSize), [
      Vector2(46, 84),
      Vector2(98, 147),
      Vector2(102, 198),
      Vector2(78, 96),
    ]);
    expect(List.generate(4, tank.muzzleFlashPart.renderedSizeForFrame), [
      Vector2(46, 84) * TankMuzzleFlashComponent.renderScale,
      Vector2(98, 147) * TankMuzzleFlashComponent.renderScale,
      Vector2(102, 198) * TankMuzzleFlashComponent.renderScale,
      Vector2(78, 96) * TankMuzzleFlashComponent.renderScale,
    ]);
    expect(tank.isMuzzleFlashVisible, isFalse);
    expect(tank.basePart.position, Vector2(132, 182));
    expect(tank.basePart.anchor, Anchor.bottomCenter);
    expect(tank.basePart.priority, 3);

    final spritePaints = [
      tank.trackPart.firstPaint,
      tank.trackPart.secondPaint,
      tank.trackPart.cachedPaint,
      ...tank.roundWheelParts.map((wheel) => wheel.paint),
      tank.cannonPart.paint,
      tank.basePart.paint,
    ];
    expect(
      spritePaints.every(
        (paint) =>
            paint.filterQuality == FilterQuality.high && paint.isAntiAlias,
      ),
      isTrue,
    );
    expect(
      tank.muzzleFlashPart.cachedPaint.filterQuality,
      FilterQuality.medium,
    );
    expect(tank.muzzleFlashPart.cachedPaint.isAntiAlias, isTrue);
    expect(tank.muzzleFlashPart.cachedPaint.maskFilter, isNull);
    expect(tank.muzzleFlashPart.usesRuntimeBlur, isFalse);
    expect(tank.muzzleFlashPart.renderCacheFrameCount, 16);
    expect(tank.trackPart.cachedMorphFrameCount, 64);
    expect(TankMuzzleFlashComponent.gaussianBlurSigma, 3.0);
    expect(TankMuzzleFlashComponent.gaussianGlowAlpha, 0.30);
    expect(TankMuzzleFlashComponent.trailOffsets, [-3, -8, -13]);
    expect(TankMuzzleFlashComponent.trailAlphas, [0.22, 0.12, 0.06]);
    expect(TankMuzzleFlashComponent.trailLengthScales, [1.18, 1.45, 1.72]);
    expect(TankMuzzleFlashComponent.trailWidthScales, [0.94, 0.86, 0.78]);
    expect(tank.bulletPoolCapacity, TankBulletComponent.poolCapacity);
    expect(tank.availableBulletCount, TankBulletComponent.poolCapacity);
    expect(game.world.planePoolCapacity, 20);
    expect(game.world.availablePlaneCount, 20);
    expect(tank.shellPoolCapacity, TankBulletShellComponent.poolCapacity);
    expect(tank.availableShellCount, TankBulletShellComponent.poolCapacity);
    expect(game.world.shells, isEmpty);
    expect(
      game.world.children.whereType<EnemyPlaneComponent>(),
      hasLength(EnemyPlaneSpawnTuning.poolCapacity),
    );

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('muzzle flash inherits cannon aim and its arched mount', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;
    final pivot = tank.absolutePositionOf(
      Vector2(TankComponent.cannonPivotX, TankComponent.cannonPivotY),
    );

    tank.setPointerTarget(Vector2(pivot.x + 500, pivot.y));
    tank.update(0);

    expect(tank.cannonPart.angle, closeTo(math.pi / 2, 0.0001));
    expect(tank.muzzleFlashPart.parent, same(tank.cannonPart));
    expect(
      tank.muzzleFlashPart.absolutePosition,
      tank.cannonPart.absolutePositionOf(tank.muzzleFlashPart.position),
    );

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('one shot plays an extremely fast four-frame muzzle sequence', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;

    tank.setTriggerHeld(true);
    tank.update(0);
    tank.setTriggerHeld(false);

    expect(tank.shotsFired, 1);
    expect(game.fireSounds.playCount, 1);
    expect(tank.triggerHeld, isFalse);
    expect(tank.isMuzzleFlashVisible, isTrue);
    expect(tank.muzzleFlashPhase, 0);
    expect(tank.muzzleFlashFirstFrame, 0);
    expect(tank.muzzleFlashSecondFrame, 1);
    expect(tank.muzzleFlashBlend, 0);
    expect(tank.muzzleFlashPart.trailStrength, 1);

    tank.update(0.0075);
    expect(tank.muzzleFlashFirstFrame, 0);
    expect(tank.muzzleFlashSecondFrame, 1);
    expect(tank.muzzleFlashBlend, closeTo(0.5, 0.0001));
    expect(tank.muzzleFlashPart.trailStrength, closeTo(0.875, 0.0001));

    tank.update(0.008);
    expect(tank.muzzleFlashFirstFrame, 1);
    expect(tank.muzzleFlashSecondFrame, 2);
    expect(tank.muzzleFlashBlend, greaterThanOrEqualTo(0));

    tank.update(0.015);
    expect(tank.muzzleFlashFirstFrame, 2);
    expect(tank.muzzleFlashSecondFrame, 3);

    tank.update(0.015);
    expect(tank.muzzleFlashFirstFrame, 3);
    expect(tank.muzzleFlashSecondFrame, isNull);

    tank.update(0.0145);
    expect(tank.isMuzzleFlashVisible, isFalse);
    expect(tank.muzzleFlashPhase, 1);
    expect(tank.muzzleFlashBlend, 1);
    expect(tank.muzzleFlashPart.trailStrength, 0);
    expect(tank.shotsFired, 1);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('each muzzle flash independently chooses a mirrored pose', (
    tester,
  ) async {
    final game = await _loadGame(tester, muzzleFlashRandom: math.Random(17));
    final tank = game.world.tank;
    final expectedRandom = math.Random(17);
    final observedOrientations = <bool>{};

    for (var shot = 0; shot < 24; shot++) {
      tank.setTriggerHeld(true);
      tank.update(0);
      tank.setTriggerHeld(false);

      final expectedFlip = expectedRandom.nextBool();
      expect(tank.isMuzzleFlashHorizontallyFlipped, expectedFlip);
      expect(tank.muzzleFlashPart.isHorizontallyFlipped, expectedFlip);
      observedOrientations.add(expectedFlip);
    }

    expect(observedOrientations, {false, true});
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('each trigger uses its bullet-level sound at a varied speed', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;
    final sounds = game.fireSounds as SilentTankFireSoundPlayer;
    game.setBulletSpreadLevel(TankBulletSpreadLevel.level5);

    for (var shot = 0; shot < 24; shot++) {
      game.setBulletLevel(
        TankBulletLevel.values[shot % TankBulletLevel.values.length],
      );
      tank.setTriggerHeld(true);
      tank.update(0);
      tank.setTriggerHeld(false);
    }

    expect(tank.shotsFired, 24);
    expect(tank.projectilesFired, 24 * 5);
    expect(sounds.playCount, 24);
    expect(
      sounds.playedSoundIndices,
      List.generate(24, (index) => index % TankBulletLevel.values.length),
    );
    expect(sounds.lastSoundIndex, TankBulletLevel.level6.index);
    expect(
      sounds.playedPlaybackRates,
      everyElement(
        inInclusiveRange(
          TankFireSoundPlayer.minimumPlaybackRate,
          TankFireSoundPlayer.maximumPlaybackRate,
        ),
      ),
    );
    expect(sounds.playedPlaybackRates.toSet(), hasLength(greaterThan(1)));
    expect(
      PooledTankFireSoundPlayer.playbackVolume,
      closeTo(0.15925, 0.000001),
    );

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('shots preserve source canvases and reduce higher bullet sizes', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;
    final sourceSizes = [
      Vector2(74, 79),
      Vector2(79, 85),
      Vector2(84, 95),
      Vector2(86, 101),
      Vector2(142, 157),
      Vector2(142, 157),
    ];

    for (final level in TankBulletLevel.values) {
      game.setBulletLevel(level);
      final muzzlePosition = tank.muzzleFlashPart.absolutePosition.clone();
      tank.setTriggerHeld(true);
      tank.update(0);
      tank.setTriggerHeld(false);
      final bullet = tank.lastBullet;
      game.update(0);

      expect(bullet, isNotNull);
      expect(bullet!.level, level);
      expect(bullet.tankScale, TankComponent.tankVisualScale);
      final expectedSize =
          sourceSizes[level.index] *
          level.renderScale *
          TankComponent.tankVisualScale;
      expect(bullet.size.x, closeTo(expectedSize.x, 0.00001));
      expect(bullet.size.y, closeTo(expectedSize.y, 0.00001));
      expect(bullet.sprite!.srcSize, sourceSizes[level.index]);
      expect(bullet.anchor, Anchor.bottomCenter);
      expect(bullet.position, muzzlePosition);
      expect(bullet.priority, 2);
      expect(bullet.paint.filterQuality, FilterQuality.medium);
      expect(bullet.paint.isAntiAlias, isTrue);
      expect(bullet.paint.color.a, 1);
      expect(bullet.paint.colorFilter, isNull);
      expect(game.bulletLevel, level);
      expect(game.world.bulletLevel, level);
      expect(tank.bulletLevel, level);
      expect(game.world.bullets, contains(bullet));
    }

    final pivot = tank.absolutePositionOf(
      Vector2(TankComponent.cannonPivotX, TankComponent.cannonPivotY),
    );
    tank.setPointerTarget(Vector2(pivot.x + 500, pivot.y));
    tank.update(0);
    tank.setTriggerHeld(true);
    tank.update(0);
    tank.setTriggerHeld(false);
    final horizontalBullet = tank.lastBullet!;
    final start = horizontalBullet.position.clone();

    expect(horizontalBullet.angle, closeTo(math.pi / 2, 0.0001));
    expect(horizontalBullet.direction.x, closeTo(1, 0.0001));
    expect(horizontalBullet.direction.y, closeTo(0, 0.0001));
    horizontalBullet.update(0.1);
    expect(
      horizontalBullet.position.x,
      closeTo(start.x + TankBulletComponent.speed * 0.1, 0.0001),
    );
    expect(horizontalBullet.position.y, closeTo(start.y, 0.0001));
    horizontalBullet.update(TankBulletComponent.maximumLifetime);
    game.update(0);
    expect(game.world.bullets, isNot(contains(horizontalBullet)));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'continuous slow backing stays forward and fast backing reverses faster',
    (tester) async {
      final game = await _loadGame(tester);
      final tank = game.world.tank;

      for (var frame = 0; frame < 120; frame++) {
        tank.update(1 / 120);
      }
      final idleCycleBefore = tank.trackCyclePosition;
      tank.update(1 / 240);
      var idleDelta = tank.trackCyclePosition - idleCycleBefore;
      if (idleDelta < 0) {
        idleDelta += 4;
      }
      expect(idleDelta, greaterThan(0));

      tank.setPointerTarget(Vector2(tank.position.x - 250, 300));
      for (var frame = 0; frame < 24; frame++) {
        tank.update(1 / 120);
      }
      expect(tank.horizontalVelocity, lessThan(0));
      expect(
        tank.horizontalVelocity.abs(),
        lessThan(
          TankMotionTuning.maxSpeed *
              TankMotionTuning.continuousFastReverseEnterSpeedFraction,
        ),
      );
      expect(tank.isFastContinuousReverse, isFalse);
      expect(tank.trackPlaybackDirection, 1);
      final slowCycleBefore = tank.trackCyclePosition;
      tank.update(1 / 1000);
      var slowDelta = tank.trackCyclePosition - slowCycleBefore;
      if (slowDelta < 0) {
        slowDelta += 4;
      }
      expect(slowDelta, greaterThan(0));

      tank.setPointerTarget(Vector2(-10000, 300));
      for (
        var frame = 0;
        frame < 120 && !tank.isFastContinuousReverse;
        frame++
      ) {
        tank.update(1 / 120);
      }
      expect(tank.isFastContinuousReverse, isTrue);
      expect(tank.trackPlaybackDirection, -1);
      expect(
        tank.horizontalVelocity.abs(),
        greaterThanOrEqualTo(
          TankMotionTuning.maxSpeed *
              TankMotionTuning.continuousFastReverseEnterSpeedFraction,
        ),
      );
      final fastCycleBefore = tank.trackCyclePosition;
      tank.update(1 / 1000);
      var fastDelta = tank.trackCyclePosition - fastCycleBefore;
      if (fastDelta > 2) {
        fastDelta -= 4;
      }
      expect(fastDelta, lessThan(0));

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('static velocity and spread upgrades create shot patterns', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;

    expect(TankBulletComponent.speed, 1440);
    for (final level in TankBulletSpreadLevel.values) {
      game.setBulletSpreadLevel(level);
      final projectilesBefore = tank.projectilesFired;
      tank.setTriggerHeld(true);
      tank.update(0);
      tank.setTriggerHeld(false);
      game.update(0);
      final bullets = tank.lastShotBullets;

      expect(bullets, hasLength(level.projectileCount));
      expect(tank.projectilesFired - projectilesBefore, level.projectileCount);
      expect(game.bulletSpreadLevel, level);
      expect(game.world.bulletSpreadLevel, level);
      expect(tank.bulletSpreadLevel, level);
      for (var index = 0; index < bullets.length; index++) {
        expect(
          bullets[index].angle,
          closeTo(level.angleOffsets[index], 0.0001),
        );
        expect(game.world.bullets, contains(bullets[index]));
      }
    }

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'tank speed levels preserve level one and cap the reduced maximum',
    (tester) async {
      final game = await _loadGame(
        tester,
        initialMovementMode: TankMovementMode.bossFight,
      );
      final tank = game.world.tank;

      expect(game.speedLevel, TankSpeedLevel.level6);
      expect(game.world.speedLevel, TankSpeedLevel.level6);
      expect(tank.speedLevel, TankSpeedLevel.level6);

      game.setSpeedLevel(TankSpeedLevel.level1);
      tank.setPointerTarget(Vector2(10000, 500));
      for (var frame = 0; frame < 30; frame++) {
        tank.update(1 / 120);
      }
      expect(tank.horizontalVelocity, closeTo(600, 0.0001));
      expect(game.world.speedLevel, TankSpeedLevel.level1);
      expect(tank.speedLevel, TankSpeedLevel.level1);

      game.setSpeedLevel(TankSpeedLevel.level6);
      for (var frame = 0; frame < 30; frame++) {
        tank.update(1 / 120);
      }
      expect(tank.horizontalVelocity, closeTo(720, 0.0001));
      expect(tank.speedLevel.maximumSpeed, TankMotionTuning.maxSpeed);

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'plane spawning uses tank-sized filtered sprites and safe altitude',
    (tester) async {
      final game = await _loadGame(tester, planeSpawnRandom: math.Random(23));
      final world = game.world;

      expect(world.planeSpawningEnabled, isFalse);
      expect(world.planesSpawned, 0);
      expect(world.planes, isEmpty);

      game.setPlaneSpawningEnabled(true);
      expect(world.planeSpawningEnabled, isTrue);
      expect(world.timeUntilNextPlane.isFinite, isTrue);
      expect(world.pendingPlaneCount, inInclusiveRange(1, 3));

      world.update(world.timeUntilNextPlane + 0.0001);
      game.update(0);
      expect(world.planesSpawned, 1);
      expect(world.planes, hasLength(1));

      final plane = world.planes.single;
      expect(plane.sprite!.srcSize, Vector2(357, 108));
      expect(plane.size.x, closeTo(TankComponent.renderedTankWidth, 0.0001));
      expect(
        plane.size.x,
        lessThanOrEqualTo(TankComponent.renderedTankWidth + 0.0001),
      );
      expect(
        plane.position.y - plane.size.y / 2,
        greaterThanOrEqualTo(EnemyPlaneComponent.safeTopGap),
      );
      expect(plane.position.x, anyOf(lessThan(0), greaterThan(game.size.x)));
      expect(plane.paint.filterQuality, FilterQuality.high);
      expect(plane.paint.isAntiAlias, isTrue);
      expect(
        plane.altitudeOffset.abs(),
        EnemyPlaneSpawnTuning.oppositeDirectionAltitudeOffset,
      );
      expect(world.planePoolCapacity, EnemyPlaneSpawnTuning.poolCapacity);
      expect(world.availablePlaneCount, world.planePoolCapacity - 1);

      game.setPlaneSpawningEnabled(false);
      final spawnedBeforeWait = world.planesSpawned;
      world.update(20);
      expect(world.planeSpawningEnabled, isFalse);
      expect(world.planesSpawned, spawnedBeforeWait);
      expect(world.timeUntilNextPlane, double.infinity);
      plane.update(20);
      expect(world.planes, isEmpty);
      expect(world.availablePlaneCount, world.planePoolCapacity);

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('held fire cadence is deterministic at 30, 60, and 120 FPS', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;
    const duration = 2.4;

    for (final level in TankFireRateLevel.values) {
      final expectedShots = 1 + (duration * level.shotsPerSecond).floor();
      for (final framesPerSecond in [30, 60, 120]) {
        final before = tank.shotsFired;
        game.setFireRateLevel(level);
        tank.setTriggerHeld(true);
        for (
          var frame = 0;
          frame < (duration * framesPerSecond).round();
          frame++
        ) {
          tank.update(1 / framesPerSecond);
        }
        tank.setTriggerHeld(false);

        expect(
          tank.shotsFired - before,
          expectedShots,
          reason: '${level.name} at $framesPerSecond FPS',
        );
        expect(game.fireRateLevel, level);
        expect(game.world.fireRateLevel, level);
        expect(tank.fireRateLevel, level);
      }
    }

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('cannon keeps following while the primary mouse is held', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1200, 300));
    await mouse.moveTo(const Offset(1200, 300));
    await tester.pump();
    tank.update(1 / 60);
    expect(tank.cannonAngle, greaterThan(0));

    await mouse.down(const Offset(1200, 300));
    await mouse.moveTo(const Offset(600, 300));
    await tester.pump();
    tank.update(1 / 60);
    expect(tank.cannonAngle, lessThan(0));

    await mouse.up();
    await mouse.removePointer();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('cannon mount follows an upside-down U aiming arch', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;
    final centerPivot = tank.absolutePositionOf(
      Vector2(TankComponent.cannonPivotX, TankComponent.cannonPivotY),
    );

    tank.setPointerTarget(Vector2(centerPivot.x + 500, centerPivot.y));
    tank.update(0);
    expect(tank.cannonAngle, closeTo(math.pi / 2, 0.0001));
    expect(
      tank.cannonPart.position,
      Vector2(
        TankComponent.cannonPivotX + TankComponent.cannonArcHorizontalRadius,
        TankComponent.cannonPivotY + TankComponent.cannonArcVerticalDrop,
      ),
    );

    tank.setPointerTarget(Vector2(centerPivot.x - 500, centerPivot.y));
    tank.update(0);
    expect(tank.cannonAngle, closeTo(-math.pi / 2, 0.0001));
    expect(
      tank.cannonPart.position,
      Vector2(
        TankComponent.cannonPivotX - TankComponent.cannonArcHorizontalRadius,
        TankComponent.cannonPivotY + TankComponent.cannonArcVerticalDrop,
      ),
    );

    tank.setPointerTarget(Vector2(centerPivot.x, centerPivot.y - 500));
    tank.update(0);
    expect(tank.cannonAngle, closeTo(0, 0.0001));
    expect(
      tank.cannonPart.position,
      Vector2(TankComponent.cannonPivotX, TankComponent.cannonPivotY),
    );

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('continuous mode keeps travel animation and horizontal control', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;
    final initialX = tank.position.x;
    var maximumBaseAngle = 0.0;
    var maximumWheelOffset = 0.0;

    for (var frame = 0; frame < 120; frame++) {
      tank.update(1 / 120);
      maximumBaseAngle = math.max(maximumBaseAngle, tank.basePart.angle.abs());
      for (final wheel in tank.roundWheelParts) {
        maximumWheelOffset = math.max(
          maximumWheelOffset,
          (wheel.position.y - 211).abs(),
        );
      }
    }

    expect(game.movementMode, TankMovementMode.continuous);
    expect(game.world.movementMode, TankMovementMode.continuous);
    expect(tank.movementMode, TankMovementMode.continuous);
    expect(tank.position.x, initialX);
    expect(tank.horizontalVelocity, 0);
    expect(tank.isScreenMoving, isFalse);
    expect(tank.isMoving, isTrue);
    expect(
      tank.smoothedAnimationSpeed,
      closeTo(
        TankMotionTuning.continuousTravelSpeedFraction *
            TankMotionTuning.continuousAnimationMultiplier,
        0.0001,
      ),
    );
    expect(tank.trackPlaybackDirection, 1);
    expect(tank.trackCyclePosition, isNot(0));
    final idleCycleBefore = tank.trackCyclePosition;
    const idleStep = 1 / 240;
    tank.update(idleStep);
    var idleCycleDelta = tank.trackCyclePosition - idleCycleBefore;
    if (idleCycleDelta < 0) {
      idleCycleDelta += 4;
    }
    expect(
      idleCycleDelta,
      closeTo(
        trackAnimationSpeedFraction(tank.smoothedAnimationSpeed) *
            TankMotionTuning.trackMorphFramesPerSecond *
            TankMotionTuning.continuousIdleTrackCadenceMultiplier *
            idleStep,
        0.0001,
      ),
    );
    expect(
      maximumBaseAngle,
      greaterThan(
        TankMotionTuning.baseShakeDegrees *
            TankMotionTuning.continuousTravelSpeedFraction *
            TankMotionTuning.continuousAnimationMultiplier *
            math.pi /
            180 *
            0.98,
      ),
    );
    expect(
      maximumWheelOffset,
      greaterThan(
        TankMotionTuning.wheelBounceDistance *
            TankMotionTuning.continuousTravelSpeedFraction *
            TankMotionTuning.continuousAnimationMultiplier *
            0.98,
      ),
    );

    tank.setPointerTarget(Vector2(1900, 300));
    for (var frame = 0; frame < 30; frame++) {
      tank.update(1 / 120);
    }
    expect(tank.position.x, greaterThan(initialX));
    expect(tank.horizontalVelocity, greaterThan(0));
    expect(tank.isScreenMoving, isTrue);
    expect(
      tank.smoothedAnimationSpeed,
      greaterThan(
        TankMotionTuning.continuousTravelSpeedFraction *
            TankMotionTuning.continuousAnimationMultiplier,
      ),
    );
    expect(tank.cannonAngle, greaterThan(0));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'mode switching preserves movement and resumes in either direction',
    (tester) async {
      final game = await _loadGame(tester);
      final tank = game.world.tank;

      tank.setPointerTarget(Vector2(1900, 500));
      for (var frame = 0; frame < 30; frame++) {
        tank.update(1 / 120);
      }
      final movingX = tank.position.x;
      expect(movingX, greaterThan(960));

      final velocityBeforeBoss = tank.horizontalVelocity;
      final phaseBeforeBoss = tank.trackCyclePosition;
      game.setMovementMode(TankMovementMode.bossFight);
      expect(tank.position.x, movingX);
      expect(tank.horizontalVelocity, velocityBeforeBoss);
      expect(tank.trackCyclePosition, phaseBeforeBoss);

      for (var frame = 0; frame < 30; frame++) {
        tank.update(1 / 120);
      }
      final bossX = tank.position.x;
      final velocityBeforeContinuous = tank.horizontalVelocity;
      final phaseBeforeContinuous = tank.trackCyclePosition;
      game.setMovementMode(TankMovementMode.continuous);
      expect(tank.position.x, bossX);
      expect(tank.horizontalVelocity, velocityBeforeContinuous);
      expect(tank.trackCyclePosition, phaseBeforeContinuous);

      tank.setPointerTarget(Vector2(0, 500));
      for (var frame = 0; frame < 120; frame++) {
        tank.update(1 / 120);
      }
      expect(tank.position.x, lessThan(bossX));
      expect(tank.trackPlaybackDirection, -1);

      game.setMovementMode(TankMovementMode.bossFight);
      for (var frame = 0; frame < 30; frame++) {
        tank.update(1 / 120);
      }
      expect(tank.position.x, lessThan(bossX));

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('movement drives smooth anchored and directional animation', (
    tester,
  ) async {
    final game = await _loadGame(
      tester,
      initialMovementMode: TankMovementMode.bossFight,
    );
    final tank = game.world.tank;
    final wheelX = tank.roundWheelParts
        .map((wheel) => wheel.position.x)
        .toList();

    expect(tank.isMoving, isFalse);
    expect(tank.trackMorphProgress, 0);
    expect(tank.smoothedAnimationSpeed, 0);
    expect(tank.basePart.angle, 0);
    expect(tank.roundWheelParts.map((wheel) => wheel.position.y), [
      211,
      211,
      211,
    ]);

    tank.setPointerTarget(Vector2(1900, 500));
    tank.update(0.05);

    expect(tank.horizontalVelocity, closeTo(240, 0.0001));
    expect(tank.isMoving, isTrue);
    expect(tank.smoothedAnimationSpeed, inExclusiveRange(0, 0.2));
    expect(
      tank.trackCyclePosition,
      closeTo(
        trackAnimationSpeedFraction(tank.smoothedAnimationSpeed) *
            TankMotionTuning.trackMorphFramesPerSecond *
            0.05,
        0.0001,
      ),
    );
    expect(tank.trackMorphProgress, inExclusiveRange(0, 1));
    expect(tank.basePart.angle, isNot(0));
    expect(tank.cannonAngle, inInclusiveRange(-math.pi / 2, math.pi / 2));
    expect(tank.roundWheelParts.map((wheel) => wheel.position.x), wheelX);
    expect(
      tank.roundWheelParts.any((wheel) => wheel.position.y != 211),
      isTrue,
    );

    final cycleBeforeReversal = tank.trackCyclePosition;
    tank.setPointerTarget(Vector2(0, 500));
    tank.update(0.01);
    expect(tank.horizontalVelocity, greaterThan(0));
    expect(tank.trackPlaybackDirection, -1);
    expect(tank.trackCyclePosition, lessThan(cycleBeforeReversal));
    expect(tank.trackMorphProgress, inInclusiveRange(0, 1));

    tank.setPointerTarget(Vector2(tank.position.x, 500));
    for (var frame = 0; frame < 120; frame++) {
      tank.update(1 / 120);
    }
    expect(tank.isMoving, isFalse);
    expect(tank.smoothedAnimationSpeed, 0);
    expect(tank.basePart.angle, 0);
    expect(tank.roundWheelParts.map((wheel) => wheel.position.y), [
      211,
      211,
      211,
    ]);

    final settledCycle = tank.trackCyclePosition;
    expect(settledCycle, closeTo(settledCycle.roundToDouble(), 0.0001));
    expect(tank.trackMorphProgress, 0);
    tank.update(1 / 60);
    expect(tank.trackCyclePosition, closeTo(settledCycle, 0.0001));
    expect(tank.trackMorphProgress, 0);

    tank.setPointerTarget(Vector2(1900, 500));
    tank.update(0.01);
    expect(tank.trackPlaybackDirection, 1);
    expect(tank.trackCyclePosition, isNot(settledCycle));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a slow tank reaches the viewport edge without turbo spiking', (
    tester,
  ) async {
    final game = await _loadGame(
      tester,
      initialMovementMode: TankMovementMode.bossFight,
    );
    final tank = game.world.tank;
    final maximumX =
        game.size.x -
        TankMotionTuning.edgeMargin -
        TankComponent.renderedTankWidth / 2;
    tank.position.x = maximumX - 150;
    tank.setPointerTarget(Vector2(game.size.x, 500));

    var maximumObservedSpeed = 0.0;
    for (var frame = 0; frame < 720; frame++) {
      tank.update(1 / 120);
      maximumObservedSpeed = math.max(
        maximumObservedSpeed,
        tank.horizontalVelocity.abs(),
      );
    }

    expect(
      maximumObservedSpeed,
      lessThanOrEqualTo(TankMotionTuning.minimumMovementSpeed + 0.0001),
    );
    expect(tank.position.x, closeTo(maximumX, 0.0001));
    expect(tank.horizontalVelocity, 0);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('tank never overshoots its target or leaves stage bounds', (
    tester,
  ) async {
    final game = await _loadGame(
      tester,
      initialMovementMode: TankMovementMode.bossFight,
    );
    final tank = game.world.tank;

    final nearbyTarget = tank.position.x + TankMotionTuning.deadZone + 100;
    tank.setPointerTarget(Vector2(nearbyTarget, 500));
    for (var step = 0; step < 720; step++) {
      tank.update(1 / 120);
      expect(tank.position.x, lessThanOrEqualTo(nearbyTarget));
    }
    expect(nearbyTarget - tank.position.x, lessThanOrEqualTo(30));
    expect(tank.horizontalVelocity, 0);

    final minimumX =
        TankMotionTuning.edgeMargin + TankComponent.renderedTankWidth / 2;
    final maximumX =
        game.size.x -
        TankMotionTuning.edgeMargin -
        TankComponent.renderedTankWidth / 2;
    tank.setPointerTarget(Vector2(-10000, 500));
    var reachedMaximumEdgeBoost = false;
    var sawSmoothEdgeBraking = false;
    for (var step = 0; step < 900; step++) {
      tank.update(1 / 120);
      final speed = tank.horizontalVelocity.abs();
      if (speed >= TankMotionTuning.maxSpeed - 0.0001) {
        reachedMaximumEdgeBoost = true;
      } else if (reachedMaximumEdgeBoost &&
          speed > TankMotionTuning.stationarySpeed &&
          speed < TankMotionTuning.maxSpeed * 0.9) {
        sawSmoothEdgeBraking = true;
      }
      expect(tank.position.x, inInclusiveRange(minimumX, maximumX));
    }
    expect(reachedMaximumEdgeBoost, isTrue);
    expect(sawSmoothEdgeBraking, isTrue);
    expect(tank.position.x, closeTo(minimumX, 0.0001));
    expect(tank.horizontalVelocity, 0);

    tank.setPointerTarget(Vector2(10000, 500));
    for (var step = 0; step < 900; step++) {
      tank.update(1 / 120);
      expect(tank.position.x, inInclusiveRange(minimumX, maximumX));
    }
    expect(tank.position.x, closeTo(maximumX, 0.0001));
    expect(tank.horizontalVelocity, 0);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('movement is stable at 30, 60, and 120 FPS', (tester) async {
    final at30 = await _simulateAtFrameRate(tester, 30);
    final at60 = await _simulateAtFrameRate(tester, 60);
    final at120 = await _simulateAtFrameRate(tester, 120);

    expect(at30.position, closeTo(at120.position, 0.01));
    expect(at60.position, closeTo(at120.position, 0.01));
    expect(at30.velocity, closeTo(at120.velocity, 0.01));
    expect(at60.velocity, closeTo(at120.velocity, 0.01));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a fast edge swipe unlocks a moderate temporary dodge', (
    tester,
  ) async {
    final game = await _loadGame(
      tester,
      initialMovementMode: TankMovementMode.bossFight,
    );
    final tank = game.world.tank;
    tank.position.x = 1700;
    tank.setPointerTarget(Vector2(1700, 500), timestamp: Duration.zero);
    tank.setPointerTarget(
      Vector2(game.size.x, 500),
      timestamp: const Duration(milliseconds: 50),
      measureSwipe: true,
    );

    expect(tank.pointerSwipeVelocity, greaterThan(2400));
    expect(tank.swipeEdgeBoost, TankMotionTuning.maximumSwipeEdgeBoost);
    tank.update(0.05);

    expect(tank.horizontalVelocity, greaterThan(80));
    expect(tank.horizontalVelocity, lessThan(tank.speedLevel.maximumSpeed));
    expect(tank.swipeEdgeBoost, inExclusiveRange(0, 0.7));
    expect(game.pointerSwipeVelocity, tank.pointerSwipeVelocity);
    expect(game.swipeEdgeBoost, tank.swipeEdgeBoost);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('shots eject one tiny shell with level-matched artwork', (
    tester,
  ) async {
    final game = await _loadGame(tester, shellRandom: math.Random(11));
    final tank = game.world.tank;
    const sourceSizes = [
      (11.0, 28.0),
      (13.0, 41.0),
      (13.0, 50.0),
      (13.0, 53.0),
    ];
    game.setBulletSpreadLevel(TankBulletSpreadLevel.level5);

    for (final level in TankBulletLevel.values) {
      final projectilesBefore = tank.projectilesFired;
      final shellsBefore = tank.shellsEjected;
      game.setBulletLevel(level);
      tank.setTriggerHeld(true);
      tank.update(0);
      tank.setTriggerHeld(false);

      final shell = tank.lastShell!;
      final sourceSize = sourceSizes[level.shellArtworkIndex];
      final targetHeight =
          TankBulletShellComponent.targetHeights[level.shellArtworkIndex];
      expect(tank.projectilesFired - projectilesBefore, 5);
      expect(tank.shellsEjected - shellsBefore, 1);
      expect(shell.level, level);
      expect(shell.artworkIndex, level.shellArtworkIndex);
      expect(shell.sprite!.srcSize, Vector2(sourceSize.$1, sourceSize.$2));
      expect(shell.size.y, targetHeight);
      expect(
        shell.size.x,
        closeTo(sourceSize.$1 * targetHeight / sourceSize.$2, 0.0001),
      );
      expect(shell.priority, 1);
      expect(shell.anchor, Anchor.center);
      expect(shell.paint.filterQuality, FilterQuality.high);
      expect(shell.paint.isAntiAlias, isTrue);
      expect(shell.isMounted, isTrue);
      expect(game.world.shells, contains(shell));
      shell.deactivate();
    }

    expect(tank.shellsEjected, TankBulletLevel.values.length);
    expect(game.world.shells, isEmpty);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('shell ejection follows cannon-local right and tank velocity', (
    tester,
  ) async {
    final game = await _loadGame(
      tester,
      initialMovementMode: TankMovementMode.bossFight,
      shellRandom: math.Random(19),
    );
    final tank = game.world.tank;
    tank.setPointerTarget(Vector2(1900, 500));
    tank.update(0.1);
    final inheritedVelocity = tank.horizontalVelocity;
    expect(inheritedVelocity, greaterThan(0));

    final pivot = tank.absolutePositionOf(
      Vector2(TankComponent.cannonPivotX, TankComponent.cannonPivotY),
    );
    tank.setPointerTarget(Vector2(pivot.x, pivot.y - 500));
    tank.update(0);
    var expectedOrigin = tank.cannonPart.absolutePositionOf(
      TankComponent.shellEjectionPort,
    );
    tank.setTriggerHeld(true);
    tank.update(0);
    tank.setTriggerHeld(false);
    var shell = tank.lastShell!;
    expect(shell.position.x, closeTo(expectedOrigin.x, 0.0001));
    expect(shell.position.y, closeTo(expectedOrigin.y, 0.0001));
    expect(
      shell.velocity.x - inheritedVelocity,
      inInclusiveRange(
        TankBulletShellComponent.minimumEjectionSpeed,
        TankBulletShellComponent.maximumEjectionSpeed,
      ),
    );
    expect(
      shell.velocity.y,
      lessThanOrEqualTo(
        TankBulletShellComponent.maximumInitialVerticalVelocity,
      ),
    );
    shell.deactivate();

    tank.setPointerTarget(Vector2(pivot.x + 500, pivot.y));
    tank.update(0);
    expect(tank.cannonAngle, closeTo(math.pi / 2, 0.0001));
    expectedOrigin = tank.cannonPart.absolutePositionOf(
      TankComponent.shellEjectionPort,
    );
    tank.setTriggerHeld(true);
    tank.update(0);
    tank.setTriggerHeld(false);
    shell = tank.lastShell!;
    expect(shell.angle, closeTo(math.pi / 2, 0.0001));
    expect(shell.position.x, closeTo(expectedOrigin.x, 0.0001));
    expect(shell.position.y, closeTo(expectedOrigin.y, 0.0001));
    expect(shell.velocity.x, closeTo(inheritedVelocity, 0.0001));
    shell.deactivate();

    tank.setPointerTarget(Vector2(pivot.x - 500, pivot.y));
    tank.update(0);
    expect(tank.cannonAngle, closeTo(-math.pi / 2, 0.0001));
    expectedOrigin = tank.cannonPart.absolutePositionOf(
      TankComponent.shellEjectionPort,
    );
    tank.setTriggerHeld(true);
    tank.update(0);
    tank.setTriggerHeld(false);
    shell = tank.lastShell!;
    expect(shell.angle, closeTo(-math.pi / 2, 0.0001));
    expect(shell.position.x, closeTo(expectedOrigin.x, 0.0001));
    expect(shell.position.y, closeTo(expectedOrigin.y, 0.0001));
    expect(shell.velocity.x, closeTo(inheritedVelocity, 0.0001));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('shell bounces twice on the exact ground edge then fades', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;
    final sounds = game.fireSounds as SilentTankFireSoundPlayer;
    final shell = tank.activeShells.isEmpty
        ? game.world.children.whereType<TankBulletShellComponent>().first
        : tank.activeShells.first;
    shell.activate(
      level: TankBulletLevel.level6,
      position: Vector2(tank.position.x, tank.position.y - 80),
      velocity: Vector2(90, -180),
      angularVelocity: 12,
      initialAngle: 0.4,
    );

    var previousBounceCount = 0;
    double? firstBounceX;
    for (var step = 0; step < 600 && !shell.isGrounded; step++) {
      shell.update(1 / 120);
      if (shell.bounceCount > previousBounceCount) {
        expect(shell.visibleBottom, closeTo(tank.position.y, 0.0001));
        expect(shell.velocity.y, lessThan(0));
        previousBounceCount = shell.bounceCount;
        if (shell.bounceCount == 1) {
          firstBounceX = shell.position.x;
        } else if (shell.bounceCount == 2) {
          expect(shell.position.x, lessThan(firstBounceX!));
        }
      }
    }

    expect(shell.bounceCount, TankBulletShellComponent.maximumBounceCount);
    expect(shell.isGrounded, isTrue);
    expect(shell.hasTriggeredGroundImpact, isTrue);
    expect(sounds.bulletDropPlayCount, 1);
    final otherShells = game.world.children
        .whereType<TankBulletShellComponent>()
        .where((candidate) => !candidate.isActive)
        .take(2)
        .toList(growable: false);
    for (final candidate in otherShells) {
      candidate.activate(
        level: TankBulletLevel.level1,
        position: Vector2(tank.position.x, tank.position.y - 2),
        velocity: Vector2(0, 100),
        angularVelocity: 0,
        initialAngle: 0,
      );
      candidate.update(1 / 120);
      break;
    }
    expect(sounds.bulletDropPlayCount, 1);
    tank.update(TankComponent.bulletDropSoundMinimumInterval);
    final nextShell = otherShells.last;
    nextShell.activate(
      level: TankBulletLevel.level1,
      position: Vector2(tank.position.x, tank.position.y - 2),
      velocity: Vector2(0, 100),
      angularVelocity: 0,
      initialAngle: 0,
    );
    nextShell.update(1 / 120);
    expect(sounds.bulletDropPlayCount, 2);
    for (final candidate in otherShells) {
      candidate.deactivate();
    }
    expect(shell.visibleBottom, closeTo(tank.position.y, 0.0001));
    expect(shell.fadeProgress, 0);

    shell.update(
      TankBulletShellComponent.fadeDelay +
          TankBulletShellComponent.fadeDuration / 2,
    );
    expect(shell.isActive, isTrue);
    expect(shell.fadeProgress, closeTo(0.5, 0.03));
    expect(shell.paint.color.a, closeTo(0.5, 0.03));
    shell.update(TankBulletShellComponent.fadeDuration);
    expect(shell.isActive, isFalse);
    expect(game.world.shells, isEmpty);
    expect(tank.availableShellCount, TankBulletShellComponent.poolCapacity);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('shells eject right before Continuous wind carries them left', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;
    final shell = game.world.children
        .whereType<TankBulletShellComponent>()
        .first;
    shell.activate(
      level: TankBulletLevel.level1,
      position: Vector2(tank.position.x, tank.position.y - 150),
      velocity: Vector2(180, 100),
      angularVelocity: 0,
      initialAngle: 0,
    );

    expect(shell.travelDriftFraction, 0);
    final airborneX = shell.position.x;
    shell.update(1 / 120);
    expect(shell.isGrounded, isFalse);
    expect(shell.position.x, greaterThan(airborneX));

    for (var step = 0; step < 600 && !shell.isGrounded; step++) {
      shell.update(1 / 120);
    }
    expect(shell.isGrounded, isTrue);
    expect(shell.travelDriftFraction, greaterThan(0));
    expect(
      shell.groundDriftVelocity,
      -TankBulletShellComponent.continuousGroundDriftSpeed,
    );

    final continuousX = shell.position.x;
    final groundedDriftFraction = shell.travelDriftFraction;
    shell.update(0.05);
    expect(shell.position.x, lessThan(continuousX - 9));
    expect(shell.travelDriftFraction, greaterThan(groundedDriftFraction));
    expect(shell.travelDriftFraction, lessThanOrEqualTo(1));
    expect(shell.fadeProgress, 0);

    game.setMovementMode(TankMovementMode.bossFight);
    final bossDriftFraction = shell.travelDriftFraction;
    expect(shell.groundDriftVelocity, 0);
    shell.update(0.05);
    expect(shell.travelDriftFraction, lessThan(bossDriftFraction));
    expect(shell.fadeProgress, 0);
    shell.update(0.20);
    expect(shell.fadeProgress, closeTo(0.5, 0.03));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'shell ground tracking follows tank resize and lifetime is safe',
    (tester) async {
      final game = await _loadGame(tester);
      final tank = game.world.tank;
      final shell = game.world.children
          .whereType<TankBulletShellComponent>()
          .first;
      final originalGround = shell.groundLine;
      tank.position.y -= 120;
      expect(shell.groundLine, originalGround - 120);

      shell.activate(
        level: TankBulletLevel.level1,
        position: Vector2(tank.position.x, tank.position.y - 10000),
        velocity: Vector2.zero(),
        angularVelocity: 0,
        initialAngle: 0,
      );
      shell.update(TankBulletShellComponent.maximumLifetime);
      expect(shell.isActive, isFalse);
      expect(
        shell.position,
        Vector2.all(TankBulletShellComponent.parkingCoordinate),
      );

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('shell trajectories are stable at 30, 60, and 120 FPS', (
    tester,
  ) async {
    final at30 = await _simulateShellAtFrameRate(tester, 30);
    final at60 = await _simulateShellAtFrameRate(tester, 60);
    final at120 = await _simulateShellAtFrameRate(tester, 120);

    for (final result in [at30, at60]) {
      expect(result.position.x, closeTo(at120.position.x, 0.01));
      expect(result.position.y, closeTo(at120.position.y, 0.01));
      expect(result.velocity.x, closeTo(at120.velocity.x, 0.01));
      expect(result.velocity.y, closeTo(at120.velocity.y, 0.01));
      expect(result.angle, closeTo(at120.angle, 0.01));
    }
  });

  testWidgets('shell pool recycles its oldest active component', (
    tester,
  ) async {
    final game = await _loadGame(tester, shellRandom: math.Random(31));
    final tank = game.world.tank;

    for (var shot = 0; shot < TankBulletShellComponent.poolCapacity; shot++) {
      tank.setTriggerHeld(true);
      tank.update(0);
      tank.setTriggerHeld(false);
    }
    final firstShell = game.world.children
        .whereType<TankBulletShellComponent>()
        .first;
    expect(tank.availableShellCount, 0);
    expect(game.world.shells, hasLength(TankBulletShellComponent.poolCapacity));

    tank.setTriggerHeld(true);
    tank.update(0);
    tank.setTriggerHeld(false);
    expect(tank.lastShell, same(firstShell));
    expect(tank.shellsEjected, TankBulletShellComponent.poolCapacity + 1);
    expect(
      game.world.children.whereType<TankBulletShellComponent>(),
      hasLength(TankBulletShellComponent.poolCapacity),
    );

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('projectile pool reuses inactive bullets without removal', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;
    expect(tank.bulletPoolCapacity, TankBulletComponent.poolCapacity);
    expect(tank.availableBulletCount, TankBulletComponent.poolCapacity);

    tank.setTriggerHeld(true);
    tank.update(0);
    tank.setTriggerHeld(false);
    final firstBullet = tank.lastBullet!;
    expect(firstBullet.isActive, isTrue);
    expect(firstBullet.isMounted, isTrue);
    firstBullet.deactivate();
    final parkedPosition = firstBullet.position.clone();
    firstBullet.update(1);
    expect(firstBullet.position, parkedPosition);

    tank.setTriggerHeld(true);
    tank.update(0);
    tank.setTriggerHeld(false);
    expect(tank.lastBullet, same(firstBullet));
    expect(firstBullet.isActive, isTrue);
    expect(firstBullet.isMounted, isTrue);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('game initialization finishes every real preload unit', (
    tester,
  ) async {
    final progressLog = <GameLoadingProgress>[];
    final game = await _loadGame(tester, progressLog: progressLog);
    final progress = game.loadingProgress.value;

    expect(CannonMileGame.preloadImageAssets, hasLength(68));
    expect(CannonMileGame.preloadImageAssets.toSet(), hasLength(68));
    expect(CannonMileGame.loadingUnitCount, 88);
    expect(progress.completed, progress.total);
    expect(progress.fraction, 1);
    expect(progress.label, 'Ready');
    expect(game.world.availablePlaneCount, 20);
    expect(game.world.availableBulletHitCount, 12);
    expect(game.world.availableBulletHitParticleCount, 256);
    expect(game.world.availablePlaneExplosionCount, 12);
    expect(game.world.availablePlaneSmokeCount, 12);
    expect(game.world.availablePlaneSmokeParticleCount, 256);
    expect(game.world.availablePlaneMissileCount, 64);
    expect(game.world.availableGroundHitCount, 32);
    expect(game.world.availableGroundHitSmokeCount, 40);
    expect(game.world.tank.availableBulletCount, 96);
    expect(game.world.tank.availableShellCount, 24);
    expect(game.world.shells, isEmpty);
    expect(game.world.tank.isMuzzleFlashVisible, isFalse);
    expect(
      progressLog.map((progress) => progress.completed),
      orderedEquals(
        [...progressLog.map((progress) => progress.completed)]..sort(),
      ),
    );
    expect(
      progressLog.map((progress) => progress.label),
      containsAll([
        'Loading tank graphics',
        'Loading effects',
        'Loading aircraft',
        'Loading combat audio',
        'Preparing collision masks',
        'Baking hit-effect glow',
        'Baking explosion glow',
        'Baking ground-hit glow',
        'Baking track animation',
        'Baking muzzle effects',
        'Preparing projectile visuals',
        'Preparing aircraft pool',
        'Preparing hit-effect pools',
        'Preparing explosion pool',
        'Preparing smoke pools',
        'Preparing aircraft attack effects',
        'Preparing projectile pool',
        'Preparing shell pool',
        'Warming effects',
        'Warming renderer',
        'Ready',
      ]),
    );

    await tester.binding.setSurfaceSize(null);
  });
}
