import 'dart:async';

import 'package:flame/components.dart';

import 'components/tank/tank_component.dart';
import 'components/tank/tank_motion.dart';

/// The root for Cannon Mile gameplay components.
///
/// The player tank lives here. Future enemies, projectiles, terrain, and
/// gameplay systems should also be attached here instead of being placed in
/// the Flutter shell.
class CannonMileWorld extends World {
  late final TankComponent tank;

  final Completer<void> _readyCompleter = Completer<void>();
  Vector2 _stageSize = Vector2(1920, 1080);
  Vector2? _pendingPointerTarget;
  bool _tankCreated = false;

  Future<void> get ready => _readyCompleter.future;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    tank = TankComponent();
    _tankCreated = true;
    tank.position = Vector2(
      _stageSize.x / 2,
      _stageSize.y - TankMotionTuning.groundInset,
    );
    add(tank);
    unawaited(_completeTankLoading());
  }

  Future<void> _completeTankLoading() async {
    try {
      await tank.loaded;
      final pendingTarget = _pendingPointerTarget;
      if (pendingTarget == null) {
        tank.setInitialPointerAbove();
      } else {
        tank.setPointerTarget(pendingTarget);
      }
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    } catch (error, stackTrace) {
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.completeError(error, stackTrace);
      }
      rethrow;
    }
  }

  void setPointerTarget(Vector2 target) {
    _pendingPointerTarget = target.clone();
    if (_tankCreated && tank.isLoaded) {
      tank.setPointerTarget(target);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _stageSize = size.clone();
    if (!_tankCreated) {
      return;
    }

    tank.position.y = size.y - TankMotionTuning.groundInset;
    tank.clampToStage(size.x);
    if (_pendingPointerTarget == null && tank.isLoaded) {
      tank.setInitialPointerAbove();
    }
  }
}
