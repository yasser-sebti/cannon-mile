import 'dart:async';
import 'dart:math' as math;

import 'package:cannon_mile/app/app_config.dart';
import 'package:cannon_mile/boot/boot_controller.dart';
import 'package:cannon_mile/boot/boot_overlay.dart';
import 'package:cannon_mile/game/components/tank/tank_bullet_level.dart';
import 'package:cannon_mile/game/components/tank/tank_bullet_spread_level.dart';
import 'package:cannon_mile/game/components/tank/tank_component.dart';
import 'package:cannon_mile/game/components/tank/tank_fire_rate_level.dart';
import 'package:cannon_mile/game/components/tank/tank_fire_sound_player.dart';
import 'package:cannon_mile/game/components/tank/tank_movement_mode.dart';
import 'package:cannon_mile/game/components/tank/tank_speed_level.dart';
import 'package:cannon_mile/game/cannon_mile_game.dart';
import 'package:cannon_mile/ui/overlays/bullet_level_toggle.dart';
import 'package:cannon_mile/ui/overlays/bullet_spread_toggle.dart';
import 'package:cannon_mile/ui/overlays/fire_rate_toggle.dart';
import 'package:cannon_mile/ui/overlays/movement_mode_toggle.dart';
import 'package:cannon_mile/ui/overlays/plane_spawn_toggle.dart';
import 'package:cannon_mile/ui/overlays/tank_speed_toggle.dart';
import 'package:cannon_mile/game/cannon_mile_world.dart';
import 'package:cannon_mile/ui/stage/game_shell.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<BootTask> _instantTasks() {
  return [BootTask(label: 'Ready', run: () async {})];
}

CannonMileGame _createGame() {
  return CannonMileGame(
    fireSoundPlayer: SilentTankFireSoundPlayer(random: math.Random(42)),
    planeSpawnRandom: math.Random(73),
  );
}

Future<void> _pumpBootSequence(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

Future<void> _awaitGameInitialization(
  WidgetTester tester,
  CannonMileGame game,
) async {
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
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

void main() {
  testWidgets('boot overlay finishes on the tank prototype', (tester) async {
    final game = _createGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameShell(
          game: game,
          bootTasks: _instantTasks(),
          bootTimings: BootTimings.instant,
        ),
      ),
    );

    expect(find.byKey(const Key('boot_overlay')), findsOneWidget);
    expect(find.byKey(const Key('orange_hat_boy_logo')), findsOneWidget);
    expect(find.byKey(movementModeToggleKey), findsNothing);
    expect(find.byKey(fireRateToggleKey), findsNothing);
    expect(find.byKey(bulletLevelToggleKey), findsNothing);
    expect(find.byKey(bulletSpreadToggleKey), findsNothing);
    expect(find.byKey(tankSpeedToggleKey), findsNothing);
    expect(find.byKey(planeSpawnToggleKey), findsNothing);

    await _pumpBootSequence(tester);
    await _awaitGameInitialization(tester, game);

    expect(find.byKey(const Key('boot_overlay')), findsNothing);
    expect(find.text('Coming Soon'), findsNothing);
    expect(find.byKey(movementModeToggleKey), findsOneWidget);
    expect(find.byKey(fireRateToggleKey), findsOneWidget);
    expect(find.byKey(bulletLevelToggleKey), findsOneWidget);
    expect(find.byKey(bulletSpreadToggleKey), findsOneWidget);
    expect(find.byKey(tankSpeedToggleKey), findsOneWidget);
    expect(find.byKey(planeSpawnToggleKey), findsOneWidget);
    expect(find.text('MODE: CONTINUOUS'), findsOneWidget);
    expect(find.text('FIRE RATE: 1/6'), findsOneWidget);
    expect(find.text('BULLET: 1/6'), findsOneWidget);
    expect(find.text('SPREAD: 1/5'), findsOneWidget);
    expect(find.text('TANK SPEED: 6/6'), findsOneWidget);
    expect(find.text('PLANES: OFF'), findsOneWidget);
    expect(game.world.children.whereType<TankComponent>(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('default boot waits for real preload and renderer warm-up', (
    tester,
  ) async {
    final game = _createGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameShell(game: game, bootTimings: BootTimings.instant),
      ),
    );

    expect(find.byKey(const Key('boot_overlay')), findsOneWidget);
    expect(game.loadingProgress.value.fraction, lessThan(1));

    await _awaitGameInitialization(tester, game);
    await _pumpBootSequence(tester);

    expect(game.loadingProgress.value.fraction, 1);
    expect(game.loadingProgress.value.label, 'Ready');
    expect(find.byKey(const Key('boot_overlay')), findsNothing);
    expect(find.byKey(movementModeToggleKey), findsOneWidget);
  });

  testWidgets('boot progress reflects the active ordered task', (tester) async {
    final gate = Completer<void>();
    final game = _createGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameShell(
          game: game,
          bootTasks: [BootTask(label: 'Checking core', run: () => gate.future)],
          bootTimings: BootTimings.instant,
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('boot_progress_percent')), findsOneWidget);
    expect(find.text('Checking core'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    gate.complete();
    await _pumpBootSequence(tester);
    await _awaitGameInitialization(tester, game);

    expect(find.byKey(const Key('boot_overlay')), findsNothing);
    expect(find.text('Coming Soon'), findsNothing);
  });

  testWidgets('lifecycle pauses and resumes the Flame engine', (tester) async {
    final game = _createGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameShell(
          game: game,
          bootTasks: _instantTasks(),
          bootTimings: BootTimings.instant,
        ),
      ),
    );
    await _pumpBootSequence(tester);
    await _awaitGameInitialization(tester, game);

    game.setTriggerHeld(true);
    game.world.tank.update(0);
    expect(game.triggerHeld, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(game.paused, isTrue);
    expect(game.triggerHeld, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(game.paused, isFalse);
  });

  testWidgets('the Flame core uses a typed world containing one tank', (
    tester,
  ) async {
    final game = _createGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameShell(
          game: game,
          bootTasks: _instantTasks(),
          bootTimings: BootTimings.instant,
        ),
      ),
    );
    await _pumpBootSequence(tester);
    await _awaitGameInitialization(tester, game);

    expect(game.world, isA<CannonMileWorld>());
    expect(game.world.children.whereType<TankComponent>(), hasLength(1));
  });

  testWidgets('mode button toggles authoritative state inside safe margin', (
    tester,
  ) async {
    final game = _createGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameShell(
          game: game,
          bootTasks: _instantTasks(),
          bootTimings: BootTimings.instant,
        ),
      ),
    );
    await _pumpBootSequence(tester);
    await _awaitGameInitialization(tester, game);

    final toggleFinder = find.byKey(movementModeToggleKey);
    final viewportSize = tester.getSize(find.byType(Scaffold));
    final scale = math.min(
      viewportSize.width / AppConfig.designWidth,
      viewportSize.height / AppConfig.designHeight,
    );
    final toggleRect = tester.getRect(toggleFinder);

    expect(toggleRect.top, closeTo(24 * scale, 0.1));
    expect(viewportSize.width - toggleRect.right, closeTo(24 * scale, 0.1));
    expect(game.movementMode, TankMovementMode.continuous);

    final pointerBeforeToggle = game.world.tank.pointerTarget;
    await tester.tap(toggleFinder);
    await tester.pump(const Duration(milliseconds: 61));
    expect(game.movementMode, TankMovementMode.bossFight);
    expect(game.world.tank.movementMode, TankMovementMode.bossFight);
    expect(game.world.tank.pointerTarget, pointerBeforeToggle);
    expect(find.text('MODE: BOSS FIGHT'), findsOneWidget);

    await tester.tap(toggleFinder);
    await tester.pump(const Duration(milliseconds: 61));
    expect(game.movementMode, TankMovementMode.continuous);
    expect(game.world.tank.movementMode, TankMovementMode.continuous);
    expect(find.text('MODE: CONTINUOUS'), findsOneWidget);
  });

  testWidgets('fire-rate button is safely placed, cycles, and never fires', (
    tester,
  ) async {
    final game = _createGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameShell(
          game: game,
          bootTasks: _instantTasks(),
          bootTimings: BootTimings.instant,
        ),
      ),
    );
    await _pumpBootSequence(tester);
    await _awaitGameInitialization(tester, game);
    game.pauseEngine();

    final fireFinder = find.byKey(fireRateToggleKey);
    final bulletFinder = find.byKey(bulletLevelToggleKey);
    final spreadFinder = find.byKey(bulletSpreadToggleKey);
    final speedFinder = find.byKey(tankSpeedToggleKey);
    final modeFinder = find.byKey(movementModeToggleKey);
    final planeFinder = find.byKey(planeSpawnToggleKey);
    final viewportSize = tester.getSize(find.byType(Scaffold));
    final scale = math.min(
      viewportSize.width / AppConfig.designWidth,
      viewportSize.height / AppConfig.designHeight,
    );
    final fireRect = tester.getRect(fireFinder);
    final bulletRect = tester.getRect(bulletFinder);
    final spreadRect = tester.getRect(spreadFinder);
    final speedRect = tester.getRect(speedFinder);
    final modeRect = tester.getRect(modeFinder);
    final planeRect = tester.getRect(planeFinder);

    expect(fireRect.top, closeTo(24 * scale, 0.1));
    expect(modeRect.left - fireRect.right, closeTo(12 * scale, 0.1));
    expect(spreadRect.left - bulletRect.right, closeTo(12 * scale, 0.1));
    expect(bulletRect.left - planeRect.right, closeTo(12 * scale, 0.1));
    expect(speedRect.left - spreadRect.right, closeTo(12 * scale, 0.1));
    expect(fireRect.left - speedRect.right, closeTo(12 * scale, 0.1));
    expect(fireRect.width, closeTo(190 * scale, 0.1));
    expect(fireRect.height, closeTo((44 + 4) * scale, 0.1));
    expect(game.fireRateLevel, TankFireRateLevel.level1);
    expect(game.world.tank.shotsFired, 0);

    final pointerBeforeToggle = game.world.tank.pointerTarget;
    final buttonMouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await buttonMouse.addPointer(location: fireRect.center);
    await buttonMouse.down(fireRect.center);
    await buttonMouse.up();
    await tester.pump(const Duration(milliseconds: 61));
    await buttonMouse.removePointer();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('FIRE RATE: 2/6'), findsOneWidget);
    expect(game.world.tank.pointerTarget, pointerBeforeToggle);
    expect(game.triggerHeld, isFalse);
    expect(game.world.tank.shotsFired, 0);

    for (var level = 3; level <= 6; level++) {
      await tester.tap(fireFinder);
      await tester.pump(const Duration(milliseconds: 61));
      expect(find.text('FIRE RATE: $level/6'), findsOneWidget);
      expect(game.fireRateLevel.level, level);
      expect(game.world.fireRateLevel, game.fireRateLevel);
      expect(game.world.tank.fireRateLevel, game.fireRateLevel);
    }

    await tester.tap(fireFinder);
    await tester.pump(const Duration(milliseconds: 61));
    expect(find.text('FIRE RATE: 1/6'), findsOneWidget);
    expect(game.fireRateLevel, TankFireRateLevel.level1);
    expect(game.triggerHeld, isFalse);
    expect(game.world.tank.shotsFired, 0);
  });

  testWidgets('plane button toggles spawning and never aims or fires', (
    tester,
  ) async {
    final game = _createGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameShell(
          game: game,
          bootTasks: _instantTasks(),
          bootTimings: BootTimings.instant,
        ),
      ),
    );
    await _pumpBootSequence(tester);
    await _awaitGameInitialization(tester, game);
    game.pauseEngine();

    final planeFinder = find.byKey(planeSpawnToggleKey);
    final pointerBeforeToggle = game.world.tank.pointerTarget;
    expect(game.planeSpawningEnabled, isFalse);
    expect(game.world.tank.shotsFired, 0);

    await tester.tap(planeFinder);
    await tester.pump(const Duration(milliseconds: 61));
    expect(game.planeSpawningEnabled, isTrue);
    expect(game.world.planeSpawningEnabled, isTrue);
    expect(find.text('PLANES: ON'), findsOneWidget);
    expect(game.world.tank.pointerTarget, pointerBeforeToggle);
    expect(game.world.tank.shotsFired, 0);
    expect(game.triggerHeld, isFalse);

    await tester.tap(planeFinder);
    await tester.pump(const Duration(milliseconds: 61));
    expect(game.planeSpawningEnabled, isFalse);
    expect(find.text('PLANES: OFF'), findsOneWidget);
    expect(game.world.tank.shotsFired, 0);
  });

  testWidgets('bullet button cycles six levels and wraps without firing', (
    tester,
  ) async {
    final game = _createGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameShell(
          game: game,
          bootTasks: _instantTasks(),
          bootTimings: BootTimings.instant,
        ),
      ),
    );
    await _pumpBootSequence(tester);
    await _awaitGameInitialization(tester, game);
    game.pauseEngine();

    final bulletFinder = find.byKey(bulletLevelToggleKey);
    expect(game.bulletLevel, TankBulletLevel.level1);
    expect(game.world.tank.shotsFired, 0);

    for (var level = 2; level <= 6; level++) {
      await tester.tap(bulletFinder);
      await tester.pump(const Duration(milliseconds: 61));
      expect(find.text('BULLET: $level/6'), findsOneWidget);
      expect(game.bulletLevel.level, level);
      expect(game.world.bulletLevel, game.bulletLevel);
      expect(game.world.tank.bulletLevel, game.bulletLevel);
    }

    await tester.tap(bulletFinder);
    await tester.pump(const Duration(milliseconds: 61));
    expect(find.text('BULLET: 1/6'), findsOneWidget);
    expect(game.bulletLevel, TankBulletLevel.level1);
    expect(game.triggerHeld, isFalse);
    expect(game.world.tank.shotsFired, 0);
  });

  testWidgets('spread button cycles five levels and wraps without firing', (
    tester,
  ) async {
    final game = _createGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameShell(
          game: game,
          bootTasks: _instantTasks(),
          bootTimings: BootTimings.instant,
        ),
      ),
    );
    await _pumpBootSequence(tester);
    await _awaitGameInitialization(tester, game);
    game.pauseEngine();

    final spreadFinder = find.byKey(bulletSpreadToggleKey);
    expect(game.bulletSpreadLevel, TankBulletSpreadLevel.level1);

    for (var level = 2; level <= 5; level++) {
      await tester.tap(spreadFinder);
      await tester.pump(const Duration(milliseconds: 61));
      expect(find.text('SPREAD: $level/5'), findsOneWidget);
      expect(game.bulletSpreadLevel.level, level);
      expect(game.world.tank.bulletSpreadLevel, game.bulletSpreadLevel);
    }
    await tester.tap(spreadFinder);
    await tester.pump(const Duration(milliseconds: 61));
    expect(game.bulletSpreadLevel, TankBulletSpreadLevel.level1);
    expect(game.triggerHeld, isFalse);
    expect(game.world.tank.shotsFired, 0);
  });

  testWidgets('tank-speed button cycles from level six and never fires', (
    tester,
  ) async {
    final game = _createGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameShell(
          game: game,
          bootTasks: _instantTasks(),
          bootTimings: BootTimings.instant,
        ),
      ),
    );
    await _pumpBootSequence(tester);
    await _awaitGameInitialization(tester, game);
    game.pauseEngine();

    final speedFinder = find.byKey(tankSpeedToggleKey);
    expect(game.speedLevel, TankSpeedLevel.level6);
    expect(game.world.tank.shotsFired, 0);

    for (var level = 1; level <= 6; level++) {
      await tester.tap(speedFinder);
      await tester.pump(const Duration(milliseconds: 61));
      expect(find.text('TANK SPEED: $level/6'), findsOneWidget);
      expect(game.speedLevel.level, level);
      expect(game.world.speedLevel, game.speedLevel);
      expect(game.world.tank.speedLevel, game.speedLevel);
    }

    expect(game.speedLevel, TankSpeedLevel.level6);
    expect(game.triggerHeld, isFalse);
    expect(game.world.tank.shotsFired, 0);
  });

  testWidgets(
    'primary mouse hold fires immediately and release stops repeats',
    (tester) async {
      final game = _createGame();
      await tester.pumpWidget(
        MaterialApp(
          home: GameShell(
            game: game,
            bootTasks: _instantTasks(),
            bootTimings: BootTimings.instant,
          ),
        ),
      );
      await _pumpBootSequence(tester);
      await _awaitGameInitialization(tester, game);
      game.pauseEngine();

      final tank = game.world.tank;
      final gameCenter = tester.getCenter(
        find.byType(GameWidget<CannonMileGame>),
      );
      final secondaryMouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await secondaryMouse.addPointer(location: gameCenter);
      await secondaryMouse.down(gameCenter);
      await tester.pump();
      expect(game.triggerHeld, isFalse);
      expect(tank.shotsFired, 0);
      await secondaryMouse.up();
      await secondaryMouse.removePointer();
      await tester.pump(const Duration(milliseconds: 50));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: gameCenter);
      await mouse.down(gameCenter);
      await tester.pump();

      expect(game.triggerHeld, isTrue);
      tank.update(0);
      expect(tank.shotsFired, 1);
      expect(tank.isMuzzleFlashVisible, isTrue);

      final pointerBeforeDrag = tank.pointerTarget;
      await mouse.moveTo(gameCenter + const Offset(80, -50));
      await tester.pump();
      tank.update(0.34);
      expect(tank.shotsFired, 2);
      expect(tank.pointerTarget, isNot(pointerBeforeDrag));

      await mouse.up();
      await tester.pump();
      expect(game.triggerHeld, isFalse);
      tank.update(1);
      expect(tank.shotsFired, 2);
      expect(tank.isMuzzleFlashVisible, isFalse);

      await mouse.down(gameCenter + const Offset(80, -50));
      await tester.pump();
      tank.update(0);
      expect(tank.shotsFired, 3);
      expect(game.triggerHeld, isTrue);
      await mouse.cancel();
      await tester.pump();
      expect(game.triggerHeld, isFalse);
      tank.update(1);
      expect(tank.shotsFired, 3);

      await mouse.removePointer();
      await tester.pump(const Duration(milliseconds: 50));

      final exitingMouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await exitingMouse.addPointer(location: gameCenter);
      await exitingMouse.down(gameCenter);
      await tester.pump();
      tank.update(0);
      expect(tank.shotsFired, 4);
      await exitingMouse.moveTo(const Offset(-10, -10));
      await tester.pump();
      expect(game.triggerHeld, isFalse);
      tank.update(1);
      expect(tank.shotsFired, 4);
      await exitingMouse.up();
      await exitingMouse.removePointer();
      await tester.pump(const Duration(milliseconds: 50));
    },
  );
}
