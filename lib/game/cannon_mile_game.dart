import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../app/app_config.dart';
import 'cannon_mile_world.dart';

class CannonMileGame extends FlameGame<CannonMileWorld> {
  CannonMileGame() : super(world: CannonMileWorld());

  final Completer<void> _initializationCompleter = Completer<void>();

  Future<void> get initialized => _initializationCompleter.future;

  @override
  Future<void> onLoad() async {
    try {
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
