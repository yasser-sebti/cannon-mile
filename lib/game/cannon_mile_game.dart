import 'dart:async';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../app/app_config.dart';
import 'cannon_mile_world.dart';

class CannonMileGame extends FlameGame<CannonMileWorld>
    with MouseMovementDetector {
  CannonMileGame() : super(world: CannonMileWorld()) {
    images = Images(prefix: 'assets/');
  }

  final Completer<void> _initializationCompleter = Completer<void>();
  Future<void>? _initializedFuture;

  Future<void> get initialized => _initializedFuture ??= _awaitInitialization();

  Future<void> _awaitInitialization() async {
    await _initializationCompleter.future;
    await world.ready;
  }

  @override
  void onMouseMove(PointerHoverInfo info) {
    final worldPosition = camera.globalToLocal(info.eventPosition.widget);
    world.setPointerTarget(worldPosition);
  }

  @override
  Future<void> onLoad() async {
    try {
      camera.viewfinder
        ..anchor = Anchor.topLeft
        ..position = Vector2.zero();
      await super.onLoad();
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
    } catch (error, stackTrace) {
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.completeError(error, stackTrace);
      }
      rethrow;
    }
  }

  @override
  Color backgroundColor() => AppConfig.backgroundColor;
}
