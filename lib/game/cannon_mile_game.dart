import 'dart:async';
import 'dart:math' as math;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../app/app_config.dart';
import 'cannon_mile_world.dart';
import 'components/effects/bullet_hit_effect_component.dart';
import 'components/effects/bullet_hit_particle_component.dart';
import 'components/effects/ground_hit_effect_component.dart';
import 'components/effects/ground_hit_smoke_component.dart';
import 'components/effects/plane_explosion_component.dart';
import 'components/effects/plane_smoke_component.dart';
import 'components/effects/plane_smoke_particle_component.dart';
import 'components/enemies/plane_collision_mask_cache.dart';
import 'components/enemies/enemy_plane_missile_component.dart';
import 'components/tank/tank_bullet_level.dart';
import 'components/tank/tank_bullet_shell_component.dart';
import 'components/tank/tank_bullet_spread_level.dart';
import 'components/tank/tank_fire_rate_level.dart';
import 'components/tank/tank_fire_sound_player.dart';
import 'components/tank/tank_movement_mode.dart';
import 'components/tank/tank_skin.dart';
import 'components/tank/tank_speed_level.dart';
import 'components/enemies/enemy_plane_component.dart';
import 'game_loading_progress.dart';

class CannonMileGame extends FlameGame<CannonMileWorld>
    with MouseMovementDetector, TapCallbacks, DragCallbacks {
  CannonMileGame({
    TankMovementMode initialMovementMode = TankMovementMode.continuous,
    TankFireRateLevel initialFireRateLevel = TankFireRateLevel.level1,
    TankBulletLevel initialBulletLevel = TankBulletLevel.level1,
    TankBulletSpreadLevel initialBulletSpreadLevel =
        TankBulletSpreadLevel.level1,
    TankSpeedLevel initialSpeedLevel = TankSpeedLevel.level6,
    bool initialPlaneSpawningEnabled = false,
    AssetBundle? assetBundle,
    TankFireSoundPlayer? fireSoundPlayer,
    math.Random? muzzleFlashRandom,
    math.Random? shellRandom,
    math.Random? planeSpawnRandom,
    math.Random? impactRandom,
  }) : super(
         world: CannonMileWorld(
           initialMovementMode: initialMovementMode,
           initialFireRateLevel: initialFireRateLevel,
           initialBulletLevel: initialBulletLevel,
           initialBulletSpreadLevel: initialBulletSpreadLevel,
           initialSpeedLevel: initialSpeedLevel,
           initialPlaneSpawningEnabled: initialPlaneSpawningEnabled,
           muzzleFlashRandom: muzzleFlashRandom,
           shellRandom: shellRandom,
           planeSpawnRandom: planeSpawnRandom,
           impactRandom: impactRandom,
         ),
       ) {
    images = Images(prefix: 'assets/', bundle: assetBundle);
    fireSounds = fireSoundPlayer ?? createTankFireSoundPlayer();
  }

  late final TankFireSoundPlayer fireSounds;
  late final PlaneCollisionMaskCache collisionMaskCache;
  static final List<String> preloadImageAssets = List.unmodifiable([
    ...TankSkin.defaultSkin.assetPaths,
    ...BulletHitEffectComponent.assetPaths,
    ...BulletHitParticleComponent.assetPaths,
    ...PlaneExplosionComponent.assetPaths,
    ...PlaneSmokeComponent.assetPaths,
    ...PlaneSmokeParticleComponent.assetPaths,
    ...GroundHitEffectComponent.assetPaths,
    ...GroundHitSmokeComponent.assetPaths,
    EnemyPlaneComponent.assetPath,
  ]);
  static int get loadingUnitCount => preloadImageAssets.length + 20;

  late final ValueNotifier<GameLoadingProgress> loadingProgress =
      ValueNotifier<GameLoadingProgress>(
        GameLoadingProgress(
          completed: 0,
          total: loadingUnitCount,
          label: 'Preparing',
        ),
      );
  final Completer<void> _initializationCompleter = Completer<void>();
  final Stopwatch _pointerClock = Stopwatch()..start();
  Future<void>? _initializedFuture;
  int _completedLoadingUnits = 0;

  Future<void> get initialized => _initializedFuture ??= _awaitInitialization();
  TankMovementMode get movementMode => world.movementMode;
  TankFireRateLevel get fireRateLevel => world.fireRateLevel;
  TankBulletLevel get bulletLevel => world.bulletLevel;
  TankBulletSpreadLevel get bulletSpreadLevel => world.bulletSpreadLevel;
  TankSpeedLevel get speedLevel => world.speedLevel;
  bool get planeSpawningEnabled => world.planeSpawningEnabled;
  bool get triggerHeld => world.triggerHeld;
  double get pointerSwipeVelocity => world.pointerSwipeVelocity;
  double get swipeEdgeBoost => world.swipeEdgeBoost;
  Iterable<TankBulletShellComponent> get shells => world.shells;
  int get bulletHits => world.bulletHits;
  int get planesDestroyed => world.planesDestroyed;
  int get planeMissilesDropped => world.planeMissilesDropped;
  int get groundHits => world.groundHits;
  double get lastResolvedHitX => world.lastResolvedHitX;
  double get lastResolvedHitY => world.lastResolvedHitY;
  int get lastBulletHitParticleCount => world.lastBulletHitParticleCount;
  int get lastPlaneSmokeParticleCount => world.lastPlaneSmokeParticleCount;
  Iterable<BulletHitEffectComponent> get bulletHitEffects =>
      world.bulletHitEffects;
  Iterable<BulletHitParticleComponent> get bulletHitParticles =>
      world.bulletHitParticles;
  Iterable<PlaneExplosionComponent> get planeExplosions =>
      world.planeExplosions;
  Iterable<PlaneSmokeComponent> get planeSmokeEffects =>
      world.planeSmokeEffects;
  Iterable<PlaneSmokeParticleComponent> get planeSmokeParticles =>
      world.planeSmokeParticles;
  Iterable<EnemyPlaneMissileComponent> get planeMissiles => world.planeMissiles;
  Iterable<GroundHitEffectComponent> get groundHitEffects =>
      world.groundHitEffects;
  Iterable<GroundHitSmokeComponent> get groundHitSmokeEffects =>
      world.groundHitSmokeEffects;

  void setMovementMode(TankMovementMode mode) {
    world.setMovementMode(mode);
  }

  void setFireRateLevel(TankFireRateLevel level) {
    world.setFireRateLevel(level);
  }

  void cycleFireRateLevel() {
    setFireRateLevel(fireRateLevel.next);
  }

  void setBulletLevel(TankBulletLevel level) {
    world.setBulletLevel(level);
  }

  void cycleBulletLevel() {
    setBulletLevel(bulletLevel.next);
  }

  void setBulletSpreadLevel(TankBulletSpreadLevel level) {
    world.setBulletSpreadLevel(level);
  }

  void cycleBulletSpreadLevel() {
    setBulletSpreadLevel(bulletSpreadLevel.next);
  }

  void setSpeedLevel(TankSpeedLevel level) {
    world.setSpeedLevel(level);
  }

  void cycleSpeedLevel() {
    setSpeedLevel(speedLevel.next);
  }

  void setPlaneSpawningEnabled(bool enabled) {
    world.setPlaneSpawningEnabled(enabled);
  }

  void togglePlaneSpawning() {
    setPlaneSpawningEnabled(!planeSpawningEnabled);
  }

  void setTriggerHeld(bool held) {
    world.setTriggerHeld(held);
  }

  Future<void> _awaitInitialization() async {
    await _initializationCompleter.future;
    await world.ready;
    await world.warmUpRenderer(
      onFrameReady: (frame) => completeLoadingUnits(
        1,
        frame == 1 ? 'Warming effects' : 'Warming renderer',
      ),
    );
    loadingProgress.value = GameLoadingProgress(
      completed: loadingUnitCount,
      total: loadingUnitCount,
      label: 'Ready',
    );
  }

  void completeLoadingUnits(int count, String label) {
    _completedLoadingUnits = math.min(
      loadingUnitCount,
      _completedLoadingUnits + count,
    );
    loadingProgress.value = GameLoadingProgress(
      completed: _completedLoadingUnits,
      total: loadingUnitCount,
      label: label,
    );
  }

  Future<void> _preloadGameplayAssets() async {
    for (final asset in preloadImageAssets) {
      await images.load(asset);
      final label = asset.startsWith('effects/')
          ? 'Loading effects'
          : asset.startsWith('enemy/')
          ? 'Loading aircraft'
          : 'Loading tank graphics';
      completeLoadingUnits(1, label);
    }
    collisionMaskCache = await PlaneCollisionMaskCache.build(
      planeImage: images.fromCache(EnemyPlaneComponent.assetPath),
      projectileImages: [
        for (final asset in TankSkin.defaultSkin.bulletAssets)
          images.fromCache(asset),
      ],
      projectileArtworkIndices: [
        for (final level in TankBulletLevel.values) level.artworkIndex,
      ],
    );
    completeLoadingUnits(1, 'Preparing collision masks');
    await fireSounds.load();
    completeLoadingUnits(4, 'Loading combat audio');
  }

  @override
  void onMouseMove(PointerHoverInfo info) {
    _setPointerTarget(
      info.eventPosition.widget,
      timestamp: info.raw.timeStamp,
      measureSwipe: true,
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    _setPointerTarget(event.canvasPosition);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _setPointerTarget(event.canvasPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _setPointerTarget(
      event.canvasEndPosition,
      timestamp: event.timestamp,
      measureSwipe: true,
    );
  }

  void _setPointerTarget(
    Vector2 canvasPosition, {
    Duration? timestamp,
    bool measureSwipe = false,
  }) {
    final worldPosition = camera.globalToLocal(canvasPosition);
    final effectiveTimestamp = measureSwipe && timestamp == Duration.zero
        ? _pointerClock.elapsed
        : timestamp;
    world.setPointerTarget(
      worldPosition,
      timestamp: effectiveTimestamp,
      measureSwipe: measureSwipe,
    );
  }

  @override
  Future<void> onLoad() async {
    try {
      camera.viewfinder
        ..anchor = Anchor.topLeft
        ..position = Vector2.zero();
      await _preloadGameplayAssets();
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
  void onRemove() {
    unawaited(fireSounds.dispose());
    loadingProgress.dispose();
    super.onRemove();
  }

  @override
  Color backgroundColor() => AppConfig.backgroundColor;
}
