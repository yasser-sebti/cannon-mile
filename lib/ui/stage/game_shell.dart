import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/platform_bootstrap.dart';
import '../../boot/boot_controller.dart';
import '../../boot/boot_overlay.dart';
import '../../game/cannon_mile_game.dart';
import '../../game/components/tank/tank_movement_mode.dart';
import '../overlays/bullet_level_toggle.dart';
import '../overlays/bullet_spread_toggle.dart';
import '../overlays/fire_rate_toggle.dart';
import '../overlays/movement_mode_toggle.dart';
import '../overlays/plane_spawn_toggle.dart';
import '../overlays/tank_speed_toggle.dart';
import '../overlays/weapon_mode_toggle.dart';
import 'virtual_stage.dart';

class GameShell extends StatefulWidget {
  const GameShell({
    this.game,
    this.assetBundle,
    this.bootTasks,
    this.bootTimings = BootTimings.production,
    super.key,
  });

  final CannonMileGame? game;
  final AssetBundle? assetBundle;
  final List<BootTask>? bootTasks;
  final BootTimings bootTimings;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> with WidgetsBindingObserver {
  late final CannonMileGame _game;
  bool _showBootOverlay = true;
  bool _gameMounted = false;
  int? _firingPointer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = widget.game ?? CannonMileGame(assetBundle: widget.assetBundle);
  }

  void _toggleMovementMode() {
    final nextMode = _game.movementMode == TankMovementMode.continuous
        ? TankMovementMode.bossFight
        : TankMovementMode.continuous;
    _game.setMovementMode(nextMode);
    setState(() {});
  }

  void _cycleFireRate() {
    _game.cycleFireRateLevel();
    setState(() {});
  }

  void _cycleBulletLevel() {
    _game.cycleBulletLevel();
    setState(() {});
  }

  void _cycleBulletSpreadLevel() {
    _game.cycleBulletSpreadLevel();
    setState(() {});
  }

  void _cycleTankSpeedLevel() {
    _game.cycleSpeedLevel();
    setState(() {});
  }

  void _togglePlaneSpawning() {
    _game.togglePlaneSpawning();
    setState(() {});
  }

  void _toggleWeaponMode() {
    _releaseFirePointer();
    _game.toggleWeaponMode();
    setState(() {});
  }

  void _handleGamePointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons & kPrimaryMouseButton == 0) {
      return;
    }
    _firingPointer = event.pointer;
    _game.setTriggerHeld(true);
  }

  void _handleGamePointerUp(PointerUpEvent event) {
    _releaseFirePointer(pointer: event.pointer);
  }

  void _handleGamePointerCancel(PointerCancelEvent event) {
    _releaseFirePointer(pointer: event.pointer);
  }

  void _releaseFirePointer({int? pointer}) {
    if (pointer != null && pointer != _firingPointer) {
      return;
    }
    _firingPointer = null;
    _game.setTriggerHeld(false);
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
        _releaseFirePointer();
        _game.pauseEngine();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _releaseFirePointer();
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
                  if (_gameMounted)
                    MouseRegion(
                      onExit: (_) => _releaseFirePointer(),
                      child: Listener(
                        onPointerDown: _handleGamePointerDown,
                        onPointerUp: _handleGamePointerUp,
                        onPointerCancel: _handleGamePointerCancel,
                        child: GameWidget<CannonMileGame>(
                          game: _game,
                          autofocus: true,
                          loadingBuilder: (_) => const SizedBox.expand(),
                          errorBuilder: (context, error) {
                            debugPrint('Game initialization failed: $error');
                            return const ColoredBox(
                              color: AppConfig.backgroundColor,
                            );
                          },
                        ),
                      ),
                    ),
                  if (!_showBootOverlay)
                    Positioned.fill(
                      child: SafeArea(
                        minimum: const EdgeInsets.all(24),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PlaneSpawnToggle(
                                isEnabled: _game.planeSpawningEnabled,
                                onToggle: _togglePlaneSpawning,
                              ),
                              const SizedBox(width: 12),
                              WeaponModeToggle(
                                mode: _game.weaponMode,
                                onToggle: _toggleWeaponMode,
                              ),
                              const SizedBox(width: 12),
                              BulletLevelToggle(
                                level: _game.bulletLevel,
                                onToggle: _cycleBulletLevel,
                              ),
                              const SizedBox(width: 12),
                              BulletSpreadToggle(
                                level: _game.bulletSpreadLevel,
                                onToggle: _cycleBulletSpreadLevel,
                              ),
                              const SizedBox(width: 12),
                              TankSpeedToggle(
                                level: _game.speedLevel,
                                onToggle: _cycleTankSpeedLevel,
                              ),
                              const SizedBox(width: 12),
                              FireRateToggle(
                                level: _game.fireRateLevel,
                                onToggle: _cycleFireRate,
                              ),
                              const SizedBox(width: 12),
                              MovementModeToggle(
                                mode: _game.movementMode,
                                onToggle: _toggleMovementMode,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_showBootOverlay)
            BootOverlay(
              game: _game,
              tasks: widget.bootTasks,
              timings: widget.bootTimings,
              onLoadingStarted: () {
                if (mounted && !_gameMounted) {
                  setState(() {
                    _gameMounted = true;
                  });
                }
              },
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
