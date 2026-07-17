import 'dart:math' as math;

import 'package:cannon_mile/game/cannon_mile_game.dart';
import 'package:cannon_mile/game/components/tank/tank_component.dart';
import 'package:cannon_mile/game/components/tank/tank_motion.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<CannonMileGame> _loadGame(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  final game = CannonMileGame();
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
  await tester.pump();
  game.pauseEngine();
  return game;
}

Future<({double position, double velocity})> _simulateAtFrameRate(
  WidgetTester tester,
  int framesPerSecond,
) async {
  final game = await _loadGame(tester);
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

void main() {
  testWidgets('tank layers use filtered fixed composition and render order', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;

    expect(tank.size, Vector2(264, 250));
    expect(tank.anchor, Anchor.bottomCenter);
    expect(tank.position.x, closeTo(960, 0.0001));
    expect(tank.position.y, closeTo(1000, 0.0001));

    expect(tank.trackPart.size, Vector2(264, 79));
    expect(tank.trackPart.position, Vector2(132, 250));
    expect(tank.trackPart.anchor, Anchor.bottomCenter);
    expect(tank.trackPart.priority, 0);
    expect(tank.trackPart.firstSprite.srcPosition, Vector2(31, 19));
    expect(tank.trackPart.firstSprite.srcSize, Vector2(264, 79));
    expect(tank.trackPart.secondSprite.srcPosition, Vector2(31, 19));
    expect(tank.trackPart.secondSprite.srcSize, Vector2(264, 79));

    expect(tank.roundWheelParts, hasLength(3));
    expect(tank.roundWheelParts.map((wheel) => wheel.position.x), [
      52,
      132,
      212,
    ]);
    expect(tank.roundWheelParts.every((wheel) => wheel.priority == 1), isTrue);

    expect(tank.cannonPart.position, Vector2(132, 118));
    expect(tank.cannonPart.anchor, Anchor.bottomCenter);
    expect(tank.cannonPart.priority, 2);
    expect(tank.basePart.position, Vector2(132, 182));
    expect(tank.basePart.anchor, Anchor.bottomCenter);
    expect(tank.basePart.priority, 3);

    final spritePaints = [
      tank.trackPart.firstPaint,
      tank.trackPart.secondPaint,
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

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('movement drives smooth anchored and directional animation', (
    tester,
  ) async {
    final game = await _loadGame(tester);
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
    tank.update(0.05);
    expect(tank.horizontalVelocity, lessThan(0));
    expect(tank.trackCyclePosition, lessThan(cycleBeforeReversal));
    expect(tank.trackMorphProgress, inInclusiveRange(0, 1));

    tank.setPointerTarget(Vector2(tank.position.x, 500));
    tank.update(1);
    expect(tank.isMoving, isFalse);
    expect(tank.trackMorphProgress, 0);
    expect(tank.smoothedAnimationSpeed, 0);
    expect(tank.basePart.angle, 0);
    expect(tank.roundWheelParts.map((wheel) => wheel.position.y), [
      211,
      211,
      211,
    ]);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('tank never overshoots its target or leaves stage bounds', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final tank = game.world.tank;

    final nearbyTarget = tank.position.x + TankMotionTuning.deadZone + 100;
    tank.setPointerTarget(Vector2(nearbyTarget, 500));
    for (var step = 0; step < 480; step++) {
      tank.update(1 / 120);
      expect(tank.position.x, lessThanOrEqualTo(nearbyTarget));
    }
    expect(nearbyTarget - tank.position.x, lessThanOrEqualTo(30));
    expect(tank.horizontalVelocity, 0);

    final minimumX = TankMotionTuning.edgeMargin + TankComponent.tankWidth / 2;
    final maximumX =
        game.size.x - TankMotionTuning.edgeMargin - TankComponent.tankWidth / 2;
    tank.setPointerTarget(Vector2(-10000, 500));
    for (var step = 0; step < 480; step++) {
      tank.update(1 / 120);
      expect(tank.position.x, inInclusiveRange(minimumX, maximumX));
    }
    expect(tank.horizontalVelocity, 0);

    tank.setPointerTarget(Vector2(10000, 500));
    for (var step = 0; step < 480; step++) {
      tank.update(1 / 120);
      expect(tank.position.x, inInclusiveRange(minimumX, maximumX));
    }
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
}
