import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/platform_bootstrap.dart';
import '../../boot/boot_controller.dart';
import '../../boot/boot_overlay.dart';
import '../../game/cannon_mile_game.dart';
import '../overlays/coming_soon_overlay.dart';
import 'virtual_stage.dart';

class GameShell extends StatefulWidget {
  const GameShell({
    this.game,
    this.bootTasks,
    this.bootTimings = BootTimings.production,
    super.key,
  });

  final CannonMileGame? game;
  final List<BootTask>? bootTasks;
  final BootTimings bootTimings;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> with WidgetsBindingObserver {
  late final CannonMileGame _game;
  bool _showBootOverlay = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = widget.game ?? CannonMileGame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _game.resumeEngine();
        unawaited(restoreImmersiveGameUi());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _game.pauseEngine();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: VirtualStage(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GameWidget<CannonMileGame>(
                    game: _game,
                    autofocus: true,
                    loadingBuilder: (_) => const SizedBox.expand(),
                    errorBuilder: (context, error) {
                      debugPrint('Game initialization failed: $error');
                      return const ColoredBox(color: AppConfig.backgroundColor);
                    },
                  ),
                  const ComingSoonOverlay(),
                ],
              ),
            ),
          ),
          if (_showBootOverlay)
            BootOverlay(
              game: _game,
              tasks: widget.bootTasks,
              timings: widget.bootTimings,
              onFinished: () {
                if (mounted) {
                  setState(() {
                    _showBootOverlay = false;
                  });
                }
              },
            ),
        ],
      ),
    );
  }
}
