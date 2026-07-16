import 'dart:async';

import 'package:cannon_mile/boot/boot_controller.dart';
import 'package:cannon_mile/boot/boot_overlay.dart';
import 'package:cannon_mile/game/cannon_mile_game.dart';
import 'package:cannon_mile/game/cannon_mile_world.dart';
import 'package:cannon_mile/ui/stage/game_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<BootTask> _instantTasks() {
  return [BootTask(label: 'Ready', run: () async {})];
}

Future<void> _pumpBootSequence(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

void main() {
  testWidgets('boot overlay finishes on the empty game placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameShell(
          bootTasks: _instantTasks(),
          bootTimings: BootTimings.instant,
        ),
      ),
    );

    expect(find.byKey(const Key('boot_overlay')), findsOneWidget);
    expect(find.byKey(const Key('orange_hat_boy_logo')), findsOneWidget);

    await _pumpBootSequence(tester);

    expect(find.byKey(const Key('boot_overlay')), findsNothing);
    expect(find.text('Coming Soon'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('boot progress reflects the active ordered task', (tester) async {
    final gate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: GameShell(
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

    expect(find.byKey(const Key('boot_overlay')), findsNothing);
    expect(find.text('Coming Soon'), findsOneWidget);
  });

  testWidgets('lifecycle pauses and resumes the Flame engine', (tester) async {
    final game = CannonMileGame();
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

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(game.paused, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(game.paused, isFalse);
  });

  testWidgets('the Flame core uses an empty typed world', (tester) async {
    final game = CannonMileGame();
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

    expect(game.world, isA<CannonMileWorld>());
    expect(game.world.children, isEmpty);
  });
}
