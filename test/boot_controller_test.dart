import 'dart:async';

import 'package:cannon_mile/app/app_config.dart';
import 'package:cannon_mile/boot/boot_controller.dart';
import 'package:cannon_mile/boot/boot_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production boot cadence matches the source launch sequence', () {
    expect(BootTimings.production.logoPop, AppConfig.logoPopDuration);
    expect(BootTimings.production.loadingDelay, AppConfig.loadingDelay);
    expect(
      BootTimings.production.progressSettle,
      AppConfig.progressSettleDuration,
    );
    expect(
      BootTimings.production.completedHold,
      AppConfig.completedHoldDuration,
    );
    expect(BootTimings.production.fadeOut, AppConfig.loadingFadeDuration);
  });

  test('BootProgress clamps its fraction', () {
    expect(const BootProgress(completed: -1, total: 4, label: '').fraction, 0);
    expect(const BootProgress(completed: 2, total: 4, label: '').fraction, 0.5);
    expect(const BootProgress(completed: 8, total: 4, label: '').fraction, 1);
    expect(const BootProgress(completed: 0, total: 0, label: '').fraction, 0);
  });

  test('BootController runs tasks in order and reports readiness', () async {
    final order = <String>[];
    final progress = <BootProgress>[];
    final controller = BootController(
      tasks: [
        BootTask(label: 'First', run: () async => order.add('first')),
        BootTask(label: 'Second', run: () async => order.add('second')),
      ],
      onProgress: progress.add,
    );

    await controller.run();

    expect(order, ['first', 'second']);
    expect(progress.first.label, 'Preparing');
    expect(progress.last.completed, 2);
    expect(progress.last.label, 'Ready');
    expect(progress.last.fraction, 1);
  });

  test('BootController deduplicates concurrent runs', () async {
    final gate = Completer<void>();
    var calls = 0;
    final controller = BootController(
      tasks: [
        BootTask(
          label: 'Once',
          run: () {
            calls++;
            return gate.future;
          },
        ),
      ],
    );

    final first = controller.run();
    final second = controller.run();

    expect(identical(first, second), isTrue);
    expect(calls, 1);
    gate.complete();
    await Future.wait([first, second]);
  });

  test('BootController continues after timeouts and errors', () async {
    final completed = <String>[];
    final never = Completer<void>();
    final controller = BootController(
      tasks: [
        BootTask(
          label: 'Timeout',
          timeout: Duration.zero,
          run: () => never.future,
        ),
        BootTask(
          label: 'Error',
          run: () async => throw StateError('expected test error'),
        ),
        BootTask(label: 'Final', run: () async => completed.add('final')),
      ],
    );

    await controller.run();

    expect(completed, ['final']);
  });
}
