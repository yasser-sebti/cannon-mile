import 'dart:async';

import 'package:flutter/foundation.dart';

typedef BootProgressCallback = void Function(BootProgress progress);

class BootTask {
  const BootTask({
    required this.label,
    required this.run,
    this.timeout = const Duration(seconds: 10),
  });

  final String label;
  final Future<void> Function() run;
  final Duration timeout;
}

class BootProgress {
  const BootProgress({
    required this.completed,
    required this.total,
    required this.label,
  });

  final int completed;
  final int total;
  final String label;

  double get fraction => total <= 0 ? 0 : (completed / total).clamp(0.0, 1.0);
}

class BootController {
  BootController({required this.tasks, this.onProgress});

  final List<BootTask> tasks;
  final BootProgressCallback? onProgress;

  Future<void>? _runFuture;

  Future<void> run() => _runFuture ??= _runTasks();

  Future<void> _runTasks() async {
    var completed = 0;
    _report(completed, 'Preparing');

    for (final task in tasks) {
      _report(completed, task.label);
      try {
        await task.run().timeout(task.timeout);
      } on TimeoutException catch (error) {
        debugPrint(
          'Boot task "${task.label}" timed out after '
          '${task.timeout.inMilliseconds}ms: $error',
        );
      } catch (error, stackTrace) {
        debugPrint('Boot task "${task.label}" failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      completed++;
      _report(completed, completed == tasks.length ? 'Ready' : task.label);
    }

    if (tasks.isEmpty) {
      _report(0, 'Ready');
    }
  }

  void _report(int completed, String label) {
    onProgress?.call(
      BootProgress(completed: completed, total: tasks.length, label: label),
    );
  }
}
