import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/scheduler.dart';

import 'cannon_mile_game.dart';
import 'components/effects/bullet_hit_effect_component.dart';
import 'components/effects/bullet_hit_particle_component.dart';
import 'components/effects/ground_hit_effect_component.dart';
import 'components/effects/ground_hit_smoke_component.dart';
import 'components/effects/plane_explosion_component.dart';
import 'components/effects/plane_smoke_component.dart';
import 'components/effects/plane_smoke_particle_component.dart';
import 'components/enemies/enemy_plane_component.dart';
import 'components/enemies/enemy_plane_missile_component.dart';
import 'components/enemies/enemy_plane_spawn.dart';
import 'components/enemies/enemy_plane_visual_template.dart';
import 'components/tank/tank_component.dart';
import 'components/tank/tank_bullet_component.dart';
import 'components/tank/tank_bullet_level.dart';
import 'components/tank/tank_bullet_shell_component.dart';
import 'components/tank/tank_bullet_spread_level.dart';
import 'components/tank/tank_fire_rate_level.dart';
import 'components/tank/tank_laser_component.dart';
import 'components/tank/tank_laser_particle_component.dart';
import 'components/tank/tank_movement_mode.dart';
import 'components/tank/tank_muzzle_particle_component.dart';
import 'components/tank/tank_motion.dart';
import 'components/tank/tank_speed_level.dart';
import 'components/tank/tank_weapon_mode.dart';

/// The root for Cannon Mile gameplay components.
///
/// The player tank lives here. Future enemies, projectiles, terrain, and
/// gameplay systems should also be attached here instead of being placed in
/// the Flutter shell.
class CannonMileWorld extends World with HasGameReference<CannonMileGame> {
  CannonMileWorld({
    TankMovementMode initialMovementMode = TankMovementMode.continuous,
    TankFireRateLevel initialFireRateLevel = TankFireRateLevel.level1,
    TankBulletLevel initialBulletLevel = TankBulletLevel.level1,
    TankBulletSpreadLevel initialBulletSpreadLevel =
        TankBulletSpreadLevel.level1,
    TankSpeedLevel initialSpeedLevel = TankSpeedLevel.level6,
    TankWeaponMode initialWeaponMode = TankWeaponMode.bullets,
    bool initialPlaneSpawningEnabled = false,
    this.muzzleFlashRandom,
    this.muzzleParticleRandom,
    this.laserParticleRandom,
    this.shellRandom,
    math.Random? planeSpawnRandom,
    math.Random? impactRandom,
  }) : _movementMode = initialMovementMode,
       _fireRateLevel = initialFireRateLevel,
       _bulletLevel = initialBulletLevel,
       _bulletSpreadLevel = initialBulletSpreadLevel,
       _speedLevel = initialSpeedLevel,
       _weaponMode = initialWeaponMode,
       _planeSpawningEnabled = initialPlaneSpawningEnabled,
       _planeSpawnRandom = planeSpawnRandom ?? math.Random(),
       _impactRandom = impactRandom ?? math.Random();

  late final TankComponent tank;

  final Completer<void> _readyCompleter = Completer<void>();
  Vector2 _stageSize = Vector2(1920, 1080);
  Vector2? _pendingPointerTarget;
  bool _tankCreated = false;
  TankMovementMode _movementMode;
  TankFireRateLevel _fireRateLevel;
  TankBulletLevel _bulletLevel;
  TankBulletSpreadLevel _bulletSpreadLevel;
  TankSpeedLevel _speedLevel;
  TankWeaponMode _weaponMode;
  final math.Random? muzzleFlashRandom;
  final math.Random? muzzleParticleRandom;
  final math.Random? laserParticleRandom;
  final math.Random? shellRandom;
  final math.Random _planeSpawnRandom;
  final math.Random _impactRandom;
  bool _triggerHeld = false;
  bool _planeSpawningEnabled;
  bool _planeSpriteLoaded = false;
  bool _rendererWarmedUp = false;
  Future<void>? _rendererWarmupFuture;
  late final Sprite _planeSprite;
  late final List<Sprite> _planeFanSprites;
  late final EnemyPlaneVisualTemplate _planeVisualTemplate;
  late final Vector2 _planeSize;
  late final _PlaneCombatCollisionPass _planeCombatCollisionPass;
  late final _PlaneAttackPass _planeAttackPass;
  late final List<Sprite> _bulletHitSprites;
  late final BulletHitFrameCache _bulletHitFrameCache;
  late final List<Sprite> _bulletHitParticleSprites;
  late final List<Sprite> _planeExplosionSourceSprites;
  late final PlaneExplosionFrameCache _planeExplosionFrameCache;
  late final List<Sprite> _planeSmokeSprites;
  late final List<Sprite> _planeSmokeParticleSprites;
  late final List<Sprite> _groundHitSourceSprites;
  late final GroundHitFrameCache _groundHitFrameCache;
  late final List<Sprite> _groundHitSmokeSprites;
  final Queue<EnemyPlaneSpawnSpec> _pendingPlaneSpawns =
      Queue<EnemyPlaneSpawnSpec>();
  final List<EnemyPlaneComponent> _planePool = [];
  final List<BulletHitEffectComponent> _bulletHitPool = [];
  final List<BulletHitParticleComponent> _bulletHitParticlePool = [];
  final List<PlaneExplosionComponent> _planeExplosionPool = [];
  final List<PlaneSmokeComponent> _planeSmokePool = [];
  final List<PlaneSmokeParticleComponent> _planeSmokeParticlePool = [];
  final List<EnemyPlaneMissileComponent> _planeMissilePool = [];
  final List<GroundHitEffectComponent> _groundHitPool = [];
  final List<GroundHitSmokeComponent> _groundHitSmokePool = [];
  final List<int> _alternativePlaneLanes = [];
  final List<int> _candidatePlaneLanes = [];
  final ActiveEnemyPlaneTrafficBuffer _planeTrafficBuffer =
      ActiveEnemyPlaneTrafficBuffer(EnemyPlaneSpawnTuning.poolCapacity);
  double _timeUntilNextPlane = double.infinity;
  int _planesSpawned = 0;
  int _bulletHits = 0;
  int _planesDestroyed = 0;
  double _lastResolvedHitX = double.nan;
  double _lastResolvedHitY = double.nan;
  int _lastBulletHitParticleCount = 0;
  int _lastPlaneSmokeParticleCount = 0;
  int _planeMissilesDropped = 0;
  int _planeMissilesDestroyed = 0;
  int _groundHits = 0;
  int _laserHits = 0;
  int _laserTargetsDestroyed = 0;
  double _lastGroundHitVisualScale = double.nan;
  bool _rendererWarmupActive = false;

  Future<void> get ready => _readyCompleter.future;
  TankMovementMode get movementMode => _movementMode;
  TankFireRateLevel get fireRateLevel => _fireRateLevel;
  TankBulletLevel get bulletLevel => _bulletLevel;
  TankBulletSpreadLevel get bulletSpreadLevel => _bulletSpreadLevel;
  TankSpeedLevel get speedLevel => _speedLevel;
  TankWeaponMode get weaponMode => _weaponMode;
  TankLaserComponent? get laser =>
      _tankCreated && tank.isLoaded ? tank.laser : null;
  Iterable<TankLaserParticleComponent> get laserParticles =>
      _tankCreated && tank.isLoaded
      ? tank.activeLaserParticles
      : const <TankLaserParticleComponent>[];
  bool get triggerHeld => _triggerHeld;
  bool get planeSpawningEnabled => _planeSpawningEnabled;
  int get planesSpawned => _planesSpawned;
  int get bulletHits => _bulletHits;
  int get planesDestroyed => _planesDestroyed;
  double get lastResolvedHitX => _lastResolvedHitX;
  double get lastResolvedHitY => _lastResolvedHitY;
  int get lastBulletHitParticleCount => _lastBulletHitParticleCount;
  int get lastPlaneSmokeParticleCount => _lastPlaneSmokeParticleCount;
  int get planeMissilesDropped => _planeMissilesDropped;
  int get planeMissilesDestroyed => _planeMissilesDestroyed;
  int get groundHits => _groundHits;
  int get laserHits => _laserHits;
  int get laserTargetsDestroyed => _laserTargetsDestroyed;
  double get timeUntilNextPlane => _timeUntilNextPlane;
  int get pendingPlaneCount => _pendingPlaneSpawns.length;
  int get planePoolCapacity => _planePool.length;
  int get availablePlaneCount =>
      _planePool.where((plane) => !plane.isActive).length;
  int get bulletHitPoolCapacity => _bulletHitPool.length;
  int get availableBulletHitCount =>
      _bulletHitPool.where((effect) => !effect.isActive).length;
  int get bulletHitParticlePoolCapacity => _bulletHitParticlePool.length;
  int get availableBulletHitParticleCount =>
      _bulletHitParticlePool.where((particle) => !particle.isActive).length;
  int get planeExplosionPoolCapacity => _planeExplosionPool.length;
  int get availablePlaneExplosionCount =>
      _planeExplosionPool.where((explosion) => !explosion.isActive).length;
  int get planeSmokePoolCapacity => _planeSmokePool.length;
  int get availablePlaneSmokeCount =>
      _planeSmokePool.where((smoke) => !smoke.isActive).length;
  int get planeSmokeParticlePoolCapacity => _planeSmokeParticlePool.length;
  int get availablePlaneSmokeParticleCount =>
      _planeSmokeParticlePool.where((particle) => !particle.isActive).length;
  int get planeMissilePoolCapacity => _planeMissilePool.length;
  int get availablePlaneMissileCount => _planeMissilePool
      .where((missile) => !missile.isActive && !missile.impactPending)
      .length;
  int get groundHitPoolCapacity => _groundHitPool.length;
  int get availableGroundHitCount =>
      _groundHitPool.where((effect) => !effect.isActive).length;
  int get groundHitSmokePoolCapacity => _groundHitSmokePool.length;
  int get availableGroundHitSmokeCount =>
      _groundHitSmokePool.where((effect) => !effect.isActive).length;
  double get pointerSwipeVelocity =>
      _tankCreated ? tank.pointerSwipeVelocity : 0;
  double get swipeEdgeBoost => _tankCreated ? tank.swipeEdgeBoost : 0;
  Iterable<TankBulletComponent> get bullets => children
      .whereType<TankBulletComponent>()
      .where((bullet) => bullet.isActive);
  Iterable<EnemyPlaneComponent> get planes =>
      _planePool.where((plane) => plane.isActive);
  Iterable<BulletHitEffectComponent> get bulletHitEffects =>
      _bulletHitPool.where((effect) => effect.isActive && !effect.isWarmup);
  Iterable<BulletHitParticleComponent> get bulletHitParticles =>
      _bulletHitParticlePool.where(
        (particle) => particle.isActive && !particle.isWarmup,
      );
  Iterable<PlaneExplosionComponent> get planeExplosions => _planeExplosionPool
      .where((explosion) => explosion.isActive && !explosion.isWarmup);
  Iterable<PlaneSmokeComponent> get planeSmokeEffects =>
      _planeSmokePool.where((smoke) => smoke.isActive && !smoke.isWarmup);
  Iterable<PlaneSmokeParticleComponent> get planeSmokeParticles =>
      _planeSmokeParticlePool.where(
        (particle) => particle.isActive && !particle.isWarmup,
      );
  Iterable<EnemyPlaneMissileComponent> get planeMissiles => _planeMissilePool
      .where((missile) => missile.isActive && !missile.isWarmup);
  Iterable<GroundHitEffectComponent> get groundHitEffects =>
      _groundHitPool.where((effect) => effect.isActive && !effect.isWarmup);
  Iterable<GroundHitSmokeComponent> get groundHitSmokeEffects =>
      _groundHitSmokePool.where(
        (effect) => effect.isActive && !effect.isWarmup,
      );
  Iterable<TankBulletShellComponent> get shells =>
      _tankCreated ? tank.activeShells : const <TankBulletShellComponent>[];
  Iterable<TankMuzzleParticleComponent> get muzzleParticles => _tankCreated
      ? tank.activeMuzzleParticles
      : const <TankMuzzleParticleComponent>[];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _planeSprite = Sprite(game.images.fromCache(EnemyPlaneComponent.assetPath));
    final fanImage = game.images.fromCache(EnemyPlaneComponent.fanAssetPath);
    _planeFanSprites = [
      for (var index = 0; index < EnemyPlaneComponent.fanFrameCount; index++)
        Sprite(
          fanImage,
          srcPosition: Vector2(EnemyPlaneComponent.fanFrameSourceX(index), 0),
          srcSize: Vector2(
            EnemyPlaneComponent.fanFrameWidth,
            fanImage.height.toDouble(),
          ),
        ),
    ];
    _planeVisualTemplate = EnemyPlaneVisualTemplate(
      bodySprite: _planeSprite,
      fanSprites: _planeFanSprites,
    );
    _planeSize = _planeVisualTemplate.size;
    _bulletHitSprites = [
      for (final asset in BulletHitEffectComponent.assetPaths)
        Sprite(game.images.fromCache(asset)),
    ];
    _bulletHitFrameCache = await BulletHitEffectComponent.bakeGlowingFrames(
      _bulletHitSprites,
    );
    game.completeLoadingUnits(1, 'Baking hit-effect glow');
    _bulletHitParticleSprites = [
      for (final asset in BulletHitParticleComponent.assetPaths)
        Sprite(game.images.fromCache(asset)),
    ];
    _planeExplosionSourceSprites = [
      for (final asset in PlaneExplosionComponent.assetPaths)
        Sprite(game.images.fromCache(asset)),
    ];
    _planeExplosionFrameCache = await PlaneExplosionComponent.bakeGlowingFrames(
      _planeExplosionSourceSprites,
    );
    game.completeLoadingUnits(1, 'Baking explosion glow');
    _planeSmokeSprites = [
      for (final asset in PlaneSmokeComponent.assetPaths)
        Sprite(game.images.fromCache(asset)),
    ];
    _planeSmokeParticleSprites = [
      for (final asset in PlaneSmokeParticleComponent.assetPaths)
        Sprite(game.images.fromCache(asset)),
    ];
    _groundHitSourceSprites = [
      for (final asset in GroundHitEffectComponent.assetPaths)
        Sprite(game.images.fromCache(asset)),
    ];
    _groundHitFrameCache = await GroundHitEffectComponent.bakeGlowingFrames(
      _groundHitSourceSprites,
    );
    game.completeLoadingUnits(1, 'Baking ground-hit glow');
    _groundHitSmokeSprites = [
      for (final asset in GroundHitSmokeComponent.assetPaths)
        Sprite(game.images.fromCache(asset)),
    ];
    _planeSpriteLoaded = true;
    _planePool.addAll(
      List.generate(
        EnemyPlaneSpawnTuning.poolCapacity,
        (_) => EnemyPlaneComponent(template: _planeVisualTemplate),
        growable: false,
      ),
    );
    await addAll(_planePool);
    game.completeLoadingUnits(1, 'Preparing aircraft pool');
    _bulletHitPool.addAll(
      List.generate(
        BulletHitEffectComponent.poolCapacity,
        (_) => BulletHitEffectComponent(frameCache: _bulletHitFrameCache),
        growable: false,
      ),
    );
    _bulletHitParticlePool.addAll(
      List.generate(
        BulletHitParticleComponent.poolCapacity,
        (_) => BulletHitParticleComponent(sprites: _bulletHitParticleSprites),
        growable: false,
      ),
    );
    await addAll([..._bulletHitPool, ..._bulletHitParticlePool]);
    game.completeLoadingUnits(1, 'Preparing hit-effect pools');
    _planeExplosionPool.addAll(
      List.generate(
        PlaneExplosionComponent.poolCapacity,
        (_) => PlaneExplosionComponent(frameCache: _planeExplosionFrameCache),
        growable: false,
      ),
    );
    await addAll(_planeExplosionPool);
    game.completeLoadingUnits(1, 'Preparing explosion pool');
    _planeSmokePool.addAll(
      List.generate(
        PlaneSmokeComponent.poolCapacity,
        (_) => PlaneSmokeComponent(sprites: _planeSmokeSprites),
        growable: false,
      ),
    );
    _planeSmokeParticlePool.addAll(
      List.generate(
        PlaneSmokeParticleComponent.poolCapacity,
        (_) => PlaneSmokeParticleComponent(
          sprites: _planeSmokeParticleSprites,
          worldVelocityProvider: _groundEffectVelocity,
        ),
        growable: false,
      ),
    );
    await addAll([..._planeSmokePool, ..._planeSmokeParticlePool]);
    game.completeLoadingUnits(1, 'Preparing smoke pools');
    _planeMissilePool.addAll(
      List.generate(
        EnemyPlaneMissileComponent.poolCapacity,
        (_) => EnemyPlaneMissileComponent(groundLineProvider: _groundLine),
        growable: false,
      ),
    );
    _groundHitPool.addAll(
      List.generate(
        GroundHitEffectComponent.poolCapacity,
        (_) => GroundHitEffectComponent(
          frameCache: _groundHitFrameCache,
          groundVelocityProvider: _groundEffectVelocity,
        ),
        growable: false,
      ),
    );
    _groundHitSmokePool.addAll(
      List.generate(
        GroundHitSmokeComponent.poolCapacity,
        (_) => GroundHitSmokeComponent(
          sprites: _groundHitSmokeSprites,
          groundVelocityProvider: _groundEffectVelocity,
        ),
        growable: false,
      ),
    );
    await addAll([
      ..._planeMissilePool,
      ..._groundHitPool,
      ..._groundHitSmokePool,
    ]);
    game.completeLoadingUnits(1, 'Preparing aircraft attack effects');
    if (_planeSpawningEnabled) {
      _scheduleNextPlaneWave();
    }
    tank = TankComponent(
      initialMovementMode: _movementMode,
      initialFireRateLevel: _fireRateLevel,
      initialBulletLevel: _bulletLevel,
      initialBulletSpreadLevel: _bulletSpreadLevel,
      initialSpeedLevel: _speedLevel,
      initialWeaponMode: _weaponMode,
      muzzleFlashRandom: muzzleFlashRandom,
      muzzleParticleRandom: muzzleParticleRandom,
      laserParticleRandom: laserParticleRandom,
      shellRandom: shellRandom,
    );
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
      await tank.initializeProjectilePool();
      game.completeLoadingUnits(1, 'Preparing projectile pool');
      await tank.initializeMuzzleParticlePool();
      game.completeLoadingUnits(1, 'Preparing muzzle particle pool');
      await tank.initializeBulletShellPool();
      game.completeLoadingUnits(1, 'Preparing shell pool');
      await tank.initializeUltimateLaser();
      game.completeLoadingUnits(1, 'Preparing ultimate beam');
      await tank.initializeLaserParticlePool();
      game.completeLoadingUnits(1, 'Preparing laser particle pool');
      _planeCombatCollisionPass = _PlaneCombatCollisionPass(this);
      _planeAttackPass = _PlaneAttackPass(this);
      await addAll([_planeCombatCollisionPass, _planeAttackPass]);
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

  Future<void> warmUpRenderer({
    required void Function(int frame) onFrameReady,
  }) {
    if (_rendererWarmedUp) {
      return Future<void>.value();
    }
    return _rendererWarmupFuture ??= _runRendererWarmup(onFrameReady);
  }

  Future<void> _runRendererWarmup(void Function(int frame) onFrameReady) async {
    _rendererWarmupActive = true;
    final center = Vector2(_stageSize.x / 2, _stageSize.y / 3);
    final warmupPlanes = _planePool
        .where((plane) => !plane.isActive)
        .take(2)
        .toList(growable: false);
    if (warmupPlanes.length < 2) {
      throw StateError('The aircraft warm-up requires two free pooled planes.');
    }
    warmupPlanes[0].activate(
      movesRight: true,
      speed: EnemyPlaneSpawnTuning.minimumSpeed,
      altitudeLane: 0,
      position: center,
    );
    warmupPlanes[1].activate(
      movesRight: false,
      speed: EnemyPlaneSpawnTuning.maximumSpeed,
      altitudeLane: 1,
      position: Vector2(center.x, center.y + 80),
    );
    warmupPlanes[0].takeDamage(5);
    final warmupHitEffect = _bulletHitPool.firstWhere(
      (effect) => !effect.isActive,
    )..activateForWarmup(x: center.x, y: center.y, frameIndex: 4);
    final warmupExplosion = _planeExplosionPool.firstWhere(
      (explosion) => !explosion.isActive,
    )..activateForWarmup(x: center.x - 180, y: center.y, frameIndex: 3);
    final warmupSmoke = _planeSmokePool.firstWhere((smoke) => !smoke.isActive)
      ..activateForWarmup(x: center.x - 180, y: center.y, frameIndex: 2);
    final warmupParticles = <BulletHitParticleComponent>[];
    for (var index = 0; index < 16; index++) {
      final particle =
          _bulletHitParticlePool.firstWhere(
            (candidate) =>
                !candidate.isActive && !warmupParticles.contains(candidate),
          )..activateForWarmup(
            artworkIndex: index % BulletHitParticleComponent.artworkCount,
            x: center.x + 50 + index * 12,
            y: center.y + 40,
          );
      warmupParticles.add(particle);
    }
    final warmupSmokeParticles = <PlaneSmokeParticleComponent>[];
    for (
      var index = 0;
      index < PlaneSmokeParticleComponent.artworkCount;
      index++
    ) {
      final particle =
          _planeSmokeParticlePool.firstWhere(
            (candidate) =>
                !candidate.isActive &&
                !warmupSmokeParticles.contains(candidate),
          )..activateForWarmup(
            artworkIndex: index,
            x: center.x - 120 + index * 18,
            y: center.y + 90,
          );
      warmupSmokeParticles.add(particle);
    }
    final warmupMissile = _planeMissilePool.firstWhere(
      (missile) => !missile.isActive && !missile.impactPending,
    )..activateForWarmup(x: center.x + 220, y: center.y + 40);
    final groundY = _groundLine();
    final warmupGroundHit = _groundHitPool.firstWhere(
      (effect) => !effect.isActive,
    )..activateForWarmup(x: center.x + 220, y: groundY, frameIndex: 4);
    final warmupGroundSmoke = _groundHitSmokePool.firstWhere(
      (effect) => !effect.isActive,
    )..activateForWarmup(x: center.x + 220, y: groundY, frameIndex: 2);
    tank.beginRendererWarmup(center, horizontalFlip: false);
    game.completeLoadingUnits(1, 'Warming ultimate beam');
    final collisionWarmupBullet = tank.bulletPoolForCollision.first;
    final collisionProfile = collisionWarmupBullet.collisionProfile;
    final collisionScale = collisionWarmupBullet.collisionPixelScale;
    collisionWarmupBullet.activate(
      level: collisionWarmupBullet.level,
      tankScale: collisionWarmupBullet.tankScale,
      position: Vector2(
        center.x - collisionProfile.centerX * collisionScale,
        center.y - collisionProfile.centerY * collisionScale,
      ),
      cannonAngle: 0,
    );
    _findPixelAccurateHit(collisionWarmupBullet, warmupPlanes.first);

    try {
      await SchedulerBinding.instance.endOfFrame;
      onFrameReady(1);
      warmupPlanes[1].takeDamage(1);
      warmupHitEffect.activateForWarmup(
        x: center.x,
        y: center.y,
        frameIndex: 8,
      );
      warmupExplosion.activateForWarmup(
        x: center.x - 180,
        y: center.y,
        frameIndex: 5,
      );
      warmupSmoke.activateForWarmup(
        x: center.x - 180,
        y: center.y,
        frameIndex: 5,
      );
      warmupGroundHit.activateForWarmup(
        x: center.x + 220,
        y: groundY,
        frameIndex: 8,
      );
      warmupGroundSmoke.activateForWarmup(
        x: center.x + 220,
        y: groundY,
        frameIndex: 4,
      );
      tank.continueRendererWarmup(horizontalFlip: true);
      await SchedulerBinding.instance.endOfFrame;
      onFrameReady(2);
      _rendererWarmedUp = true;
    } finally {
      for (final plane in warmupPlanes) {
        plane.deactivate();
      }
      warmupHitEffect.deactivate();
      warmupExplosion.deactivate();
      warmupSmoke.deactivate();
      warmupMissile.deactivate();
      warmupGroundHit.deactivate();
      warmupGroundSmoke.deactivate();
      for (final particle in warmupParticles) {
        particle.deactivate();
      }
      for (final particle in warmupSmokeParticles) {
        particle.deactivate();
      }
      tank.endRendererWarmup();
      _rendererWarmupActive = false;
    }
  }

  void setPointerTarget(
    Vector2 target, {
    Duration? timestamp,
    bool measureSwipe = false,
  }) {
    _pendingPointerTarget = target.clone();
    if (_tankCreated && tank.isLoaded) {
      tank.setPointerTarget(
        target,
        timestamp: timestamp,
        measureSwipe: measureSwipe,
      );
    }
  }

  void setMovementMode(TankMovementMode mode) {
    _movementMode = mode;
    if (_tankCreated) {
      tank.setMovementMode(mode);
    }
  }

  void setWeaponMode(TankWeaponMode mode) {
    if (_weaponMode == mode) {
      return;
    }
    _weaponMode = mode;
    _triggerHeld = false;
    if (_tankCreated) {
      tank.setWeaponMode(mode);
    }
  }

  void setFireRateLevel(TankFireRateLevel level) {
    _fireRateLevel = level;
    if (_tankCreated) {
      tank.setFireRateLevel(level);
    }
  }

  void setTriggerHeld(bool held) {
    _triggerHeld = held;
    if (_tankCreated) {
      tank.setTriggerHeld(held);
    }
  }

  void setBulletLevel(TankBulletLevel level) {
    _bulletLevel = level;
    if (_tankCreated) {
      tank.setBulletLevel(level);
    }
  }

  void setBulletSpreadLevel(TankBulletSpreadLevel level) {
    _bulletSpreadLevel = level;
    if (_tankCreated) {
      tank.setBulletSpreadLevel(level);
    }
  }

  void setSpeedLevel(TankSpeedLevel level) {
    _speedLevel = level;
    if (_tankCreated) {
      tank.setSpeedLevel(level);
    }
  }

  void setPlaneSpawningEnabled(bool enabled) {
    if (_planeSpawningEnabled == enabled) {
      return;
    }
    _planeSpawningEnabled = enabled;
    if (!enabled) {
      _pendingPlaneSpawns.clear();
      _timeUntilNextPlane = double.infinity;
    } else if (_planeSpriteLoaded) {
      _scheduleNextPlaneWave();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_planeSpawningEnabled || !_planeSpriteLoaded || dt <= 0) {
      return;
    }

    var remainingTime = dt;
    while (remainingTime >= _timeUntilNextPlane) {
      remainingTime -= _timeUntilNextPlane;
      if (!_spawnNextPlane()) {
        return;
      }
    }
    _timeUntilNextPlane -= remainingTime;
  }

  void _updatePlaneMissileDrops() {
    for (var index = 0; index < _planePool.length; index++) {
      final plane = _planePool[index];
      if (!plane.consumeMissileDropRequest()) {
        continue;
      }
      _activatePlaneMissile(plane);
      plane.scheduleNextMissileDrop(
        _randomPlaneBetween(
          EnemyPlaneSpawnTuning.missileDelayMinimum,
          EnemyPlaneSpawnTuning.missileDelayMaximum,
        ),
      );
    }
  }

  void _resolvePlaneMissileImpacts() {
    for (var index = 0; index < _planeMissilePool.length; index++) {
      final missile = _planeMissilePool[index];
      if (!missile.impactPending) {
        continue;
      }
      final impactX = missile.impactX;
      final impactY = missile.impactY;
      missile.clearPendingImpact();
      final visualScale = _nextGroundHitVisualScale();
      _activateGroundHit(x: impactX, y: impactY, visualScale: visualScale);
      _activateGroundHitSmoke(x: impactX, y: impactY, visualScale: visualScale);
      game.fireSounds.playExplosion();
      _groundHits++;
    }
  }

  void _resolveBulletPlaneCollisions() {
    if (!_tankCreated || !tank.isLoaded) {
      return;
    }
    final bullets = tank.bulletPoolForCollision;
    for (var bulletIndex = 0; bulletIndex < bullets.length; bulletIndex++) {
      final bullet = bullets[bulletIndex];
      if (!bullet.isActive) {
        continue;
      }

      EnemyPlaneComponent? hitPlane;
      EnemyPlaneMissileComponent? hitMissile;
      var earliestHitTime = double.infinity;
      var hitX = 0.0;
      var hitY = 0.0;
      for (var planeIndex = 0; planeIndex < _planePool.length; planeIndex++) {
        final plane = _planePool[planeIndex];
        if (!plane.isActive) {
          continue;
        }
        if (_findPixelAccurateHit(bullet, plane) &&
            _candidateHitTime < earliestHitTime) {
          earliestHitTime = _candidateHitTime;
          hitX = _candidateHitX;
          hitY = _candidateHitY;
          hitPlane = plane;
          hitMissile = null;
        }
      }
      for (
        var missileIndex = 0;
        missileIndex < _planeMissilePool.length;
        missileIndex++
      ) {
        final missile = _planeMissilePool[missileIndex];
        if (!missile.isActive || missile.isWarmup) {
          continue;
        }
        if (_findPixelAccurateMissileHit(bullet, missile) &&
            _candidateHitTime < earliestHitTime) {
          earliestHitTime = _candidateHitTime;
          hitX = _candidateHitX;
          hitY = _candidateHitY;
          hitPlane = null;
          hitMissile = missile;
        }
      }
      if (hitPlane == null && hitMissile == null) {
        continue;
      }

      _lastResolvedHitX = hitX;
      _lastResolvedHitY = hitY;
      bullet.deactivate();
      if (hitMissile != null) {
        final destroyed = hitMissile.takeDamage(bullet.damage);
        game.fireSounds.playMetalHit();
        _bulletHits++;
        if (destroyed) {
          final missileX = hitMissile.position.x;
          final missileY = hitMissile.position.y;
          final missileVelocity = hitMissile.velocityX;
          _activatePlaneExplosion(
            x: missileX,
            y: missileY,
            visualScale: PlaneExplosionComponent.missileVisualScale,
          );
          _activatePlaneSmoke(
            x: missileX,
            y: missileY,
            planeVelocity: missileVelocity,
            visualScale: PlaneSmokeComponent.missileVisualScale,
          );
          _emitPlaneSmokeParticles(
            x: missileX,
            y: missileY,
            planeVelocity: missileVelocity,
            visualScale: PlaneSmokeParticleComponent.missileVisualScale,
          );
          hitMissile.deactivate();
          _planeMissilesDestroyed++;
        }
        continue;
      }

      final planeVelocity = hitPlane!.horizontalVelocity;
      final destroyed = hitPlane.takeDamage(bullet.damage);
      game.fireSounds.playMetalHit();
      _activateBulletHitEffect(
        x: hitX,
        y: hitY,
        attachedPlane: destroyed ? null : hitPlane,
      );
      _emitBulletHitParticles(x: hitX, y: hitY, planeVelocity: planeVelocity);
      _bulletHits++;
      if (destroyed) {
        _activatePlaneExplosion(x: hitPlane.position.x, y: hitPlane.position.y);
        _activatePlaneSmoke(
          x: hitPlane.position.x,
          y: hitPlane.position.y,
          planeVelocity: planeVelocity,
        );
        _emitPlaneSmokeParticles(
          x: hitPlane.position.x,
          y: hitPlane.position.y,
          planeVelocity: planeVelocity,
        );
        hitPlane.deactivate();
        _planesDestroyed++;
        if (_planeSpawningEnabled) {
          _queueImmediatePlaneReplacement();
        }
      }
    }
  }

  double _laserContactX = 0;
  double _laserContactY = 0;

  void _resolveLaserCollisions() {
    if (!_tankCreated || !tank.isLoaded) {
      return;
    }
    final laser = tank.laser;
    if (laser == null) {
      return;
    }
    laser.resetFrameImpactCounts();
    if (!laser.isDamageActive) {
      return;
    }

    for (var planeIndex = 0; planeIndex < _planePool.length; planeIndex++) {
      final plane = _planePool[planeIndex];
      if (!plane.isActive || !_laserHitsPlane(laser, plane)) {
        continue;
      }
      _lastResolvedHitX = _laserContactX;
      _lastResolvedHitY = _laserContactY;
      final planeVelocity = plane.horizontalVelocity;
      plane.takeDamage(plane.maxHealth);
      _activatePlaneExplosion(x: plane.position.x, y: plane.position.y);
      _activatePlaneSmoke(
        x: plane.position.x,
        y: plane.position.y,
        planeVelocity: planeVelocity,
      );
      _emitPlaneSmokeParticles(
        x: plane.position.x,
        y: plane.position.y,
        planeVelocity: planeVelocity,
      );
      plane.deactivate();
      _planesDestroyed++;
      _laserHits++;
      _laserTargetsDestroyed++;
      laser.recordDestruction();
      if (_planeSpawningEnabled) {
        _queueImmediatePlaneReplacement();
      }
    }

    for (
      var missileIndex = 0;
      missileIndex < _planeMissilePool.length;
      missileIndex++
    ) {
      final missile = _planeMissilePool[missileIndex];
      if (!missile.isActive ||
          missile.isWarmup ||
          !_laserHitsMissile(laser, missile)) {
        continue;
      }
      _lastResolvedHitX = _laserContactX;
      _lastResolvedHitY = _laserContactY;
      final missileX = missile.position.x;
      final missileY = missile.position.y;
      final missileVelocity = missile.velocityX;
      missile.takeDamage(missile.maxHealth);
      _activatePlaneExplosion(
        x: missileX,
        y: missileY,
        visualScale: PlaneExplosionComponent.missileVisualScale,
      );
      _activatePlaneSmoke(
        x: missileX,
        y: missileY,
        planeVelocity: missileVelocity,
        visualScale: PlaneSmokeComponent.missileVisualScale,
      );
      _emitPlaneSmokeParticles(
        x: missileX,
        y: missileY,
        planeVelocity: missileVelocity,
        visualScale: PlaneSmokeParticleComponent.missileVisualScale,
      );
      missile.deactivate();
      _planeMissilesDestroyed++;
      _laserHits++;
      _laserTargetsDestroyed++;
      laser.recordDestruction();
    }
  }

  int _laserSweepSampleCount(TankLaserComponent laser) {
    final angleDelta = math.atan2(
      math.sin(laser.currentAngle - laser.previousAngle),
      math.cos(laser.currentAngle - laser.previousAngle),
    );
    final originTravel = math.sqrt(
      math.pow(laser.currentOriginX - laser.previousOriginX, 2) +
          math.pow(laser.currentOriginY - laser.previousOriginY, 2),
    );
    final stageDiagonal = math.sqrt(
      _stageSize.x * _stageSize.x + _stageSize.y * _stageSize.y,
    );
    final outerTravel = originTravel + angleDelta.abs() * stageDiagonal;
    final widestCore = math.max(laser.previousCoreWidth, laser.activeCoreWidth);
    final spacing = math.max(2.0, widestCore * 0.30);
    return math.max(1, (outerTravel / spacing).ceil()).clamp(1, 64);
  }

  bool _laserHitsPlane(TankLaserComponent laser, EnemyPlaneComponent plane) {
    final sampleCount = _laserSweepSampleCount(laser);
    final angleDelta = math.atan2(
      math.sin(laser.currentAngle - laser.previousAngle),
      math.cos(laser.currentAngle - laser.previousAngle),
    );
    for (var sample = 0; sample <= sampleCount; sample++) {
      final progress = sample / sampleCount;
      final originX = _lerpDouble(
        laser.previousOriginX,
        laser.currentOriginX,
        progress,
      );
      final originY = _lerpDouble(
        laser.previousOriginY,
        laser.currentOriginY,
        progress,
      );
      final angle = laser.previousAngle + angleDelta * progress;
      final coreWidth = _lerpDouble(
        laser.previousCoreWidth,
        laser.activeCoreWidth,
        progress,
      );
      if (coreWidth <= 0) {
        continue;
      }
      final beamLength = TankLaserComponent.lengthToStageEdge(
        originX: originX,
        originY: originY,
        angle: angle,
        stageWidth: _stageSize.x,
        stageHeight: _stageSize.y,
      );
      final directionX = math.sin(angle);
      final directionY = -math.cos(angle);
      final endpointX = originX + directionX * beamLength;
      final endpointY = originY + directionY * beamLength;
      final planeX = _lerpDouble(plane.previousX, plane.position.x, progress);
      final planeY = _lerpDouble(plane.previousY, plane.position.y, progress);
      final halfCore = coreWidth / 2;
      if (!_beamBoundsOverlap(
        originX: originX,
        originY: originY,
        endpointX: endpointX,
        endpointY: endpointY,
        padding: halfCore,
        targetX: planeX,
        targetY: planeY,
        targetHalfWidth: plane.size.x / 2,
        targetHalfHeight: plane.size.y / 2,
      )) {
        continue;
      }

      final mask = game.collisionMaskCache.planeMask;
      var nearestProjection = double.infinity;
      var found = false;
      for (
        var pointIndex = 0;
        pointIndex < mask.boundaryPointCount;
        pointIndex++
      ) {
        var normalizedX = mask.boundaryXs[pointIndex] / mask.width;
        if (!plane.movesRight) {
          normalizedX = 1 - normalizedX;
        }
        final worldX = planeX + (normalizedX - 0.5) * plane.size.x;
        final worldY =
            planeY +
            (mask.boundaryYs[pointIndex] / mask.height - 0.5) * plane.size.y;
        final relativeX = worldX - originX;
        final relativeY = worldY - originY;
        final projection = relativeX * directionX + relativeY * directionY;
        if (projection < 0 || projection > beamLength) {
          continue;
        }
        final perpendicular = (relativeX * -directionY + relativeY * directionX)
            .abs();
        if (perpendicular > halfCore || projection >= nearestProjection) {
          continue;
        }
        nearestProjection = projection;
        _laserContactX = worldX;
        _laserContactY = worldY;
        found = true;
      }
      if (found) {
        return true;
      }
    }
    return false;
  }

  bool _laserHitsMissile(
    TankLaserComponent laser,
    EnemyPlaneMissileComponent missile,
  ) {
    final sampleCount = _laserSweepSampleCount(laser);
    final beamAngleDelta = math.atan2(
      math.sin(laser.currentAngle - laser.previousAngle),
      math.cos(laser.currentAngle - laser.previousAngle),
    );
    final missileAngleDelta = math.atan2(
      math.sin(missile.angle - missile.previousAngle),
      math.cos(missile.angle - missile.previousAngle),
    );
    for (var sample = 0; sample <= sampleCount; sample++) {
      final progress = sample / sampleCount;
      final originX = _lerpDouble(
        laser.previousOriginX,
        laser.currentOriginX,
        progress,
      );
      final originY = _lerpDouble(
        laser.previousOriginY,
        laser.currentOriginY,
        progress,
      );
      final beamAngle = laser.previousAngle + beamAngleDelta * progress;
      final halfCore =
          _lerpDouble(
            laser.previousCoreWidth,
            laser.activeCoreWidth,
            progress,
          ) /
          2;
      if (halfCore <= 0) {
        continue;
      }
      final beamLength = TankLaserComponent.lengthToStageEdge(
        originX: originX,
        originY: originY,
        angle: beamAngle,
        stageWidth: _stageSize.x,
        stageHeight: _stageSize.y,
      );
      final endpointX = originX + math.sin(beamAngle) * beamLength;
      final endpointY = originY - math.cos(beamAngle) * beamLength;
      final missileX = _lerpDouble(
        missile.previousX,
        missile.position.x,
        progress,
      );
      final missileY = _lerpDouble(
        missile.previousY,
        missile.position.y,
        progress,
      );
      if (!_beamBoundsOverlap(
        originX: originX,
        originY: originY,
        endpointX: endpointX,
        endpointY: endpointY,
        padding: halfCore,
        targetX: missileX,
        targetY: missileY,
        targetHalfWidth: EnemyPlaneMissileComponent.missileWidth,
        targetHalfHeight: EnemyPlaneMissileComponent.missileHeight,
      )) {
        continue;
      }
      final missileAngle = missile.previousAngle + missileAngleDelta * progress;
      final cosine = math.cos(missileAngle);
      final sine = math.sin(missileAngle);
      const halfWidth = EnemyPlaneMissileComponent.missileWidth / 2;
      const halfHeight = EnemyPlaneMissileComponent.missileHeight / 2;
      final firstX = missileX - sine * halfHeight;
      final firstY = missileY + cosine * halfHeight;
      final secondX = missileX - cosine * halfWidth + sine * halfHeight;
      final secondY = missileY - sine * halfWidth - cosine * halfHeight;
      final thirdX = missileX + cosine * halfWidth + sine * halfHeight;
      final thirdY = missileY + sine * halfWidth - cosine * halfHeight;
      if (_segmentsWithinDistance(
            originX,
            originY,
            endpointX,
            endpointY,
            firstX,
            firstY,
            secondX,
            secondY,
            halfCore,
          ) ||
          _segmentsWithinDistance(
            originX,
            originY,
            endpointX,
            endpointY,
            secondX,
            secondY,
            thirdX,
            thirdY,
            halfCore,
          ) ||
          _segmentsWithinDistance(
            originX,
            originY,
            endpointX,
            endpointY,
            thirdX,
            thirdY,
            firstX,
            firstY,
            halfCore,
          )) {
        _laserContactX = missileX;
        _laserContactY = missileY;
        return true;
      }
    }
    return false;
  }

  bool _beamBoundsOverlap({
    required double originX,
    required double originY,
    required double endpointX,
    required double endpointY,
    required double padding,
    required double targetX,
    required double targetY,
    required double targetHalfWidth,
    required double targetHalfHeight,
  }) {
    return math.min(originX, endpointX) - padding <=
            targetX + targetHalfWidth &&
        math.max(originX, endpointX) + padding >= targetX - targetHalfWidth &&
        math.min(originY, endpointY) - padding <= targetY + targetHalfHeight &&
        math.max(originY, endpointY) + padding >= targetY - targetHalfHeight;
  }

  bool _segmentsWithinDistance(
    double firstStartX,
    double firstStartY,
    double firstEndX,
    double firstEndY,
    double secondStartX,
    double secondStartY,
    double secondEndX,
    double secondEndY,
    double distance,
  ) {
    if (_segmentsIntersect(
      firstStartX,
      firstStartY,
      firstEndX,
      firstEndY,
      secondStartX,
      secondStartY,
      secondEndX,
      secondEndY,
    )) {
      return true;
    }
    final maximumDistanceSquared = distance * distance;
    return _pointSegmentDistanceSquared(
              firstStartX,
              firstStartY,
              secondStartX,
              secondStartY,
              secondEndX,
              secondEndY,
            ) <=
            maximumDistanceSquared ||
        _pointSegmentDistanceSquared(
              firstEndX,
              firstEndY,
              secondStartX,
              secondStartY,
              secondEndX,
              secondEndY,
            ) <=
            maximumDistanceSquared ||
        _pointSegmentDistanceSquared(
              secondStartX,
              secondStartY,
              firstStartX,
              firstStartY,
              firstEndX,
              firstEndY,
            ) <=
            maximumDistanceSquared ||
        _pointSegmentDistanceSquared(
              secondEndX,
              secondEndY,
              firstStartX,
              firstStartY,
              firstEndX,
              firstEndY,
            ) <=
            maximumDistanceSquared;
  }

  bool _segmentsIntersect(
    double firstStartX,
    double firstStartY,
    double firstEndX,
    double firstEndY,
    double secondStartX,
    double secondStartY,
    double secondEndX,
    double secondEndY,
  ) {
    final firstDeltaX = firstEndX - firstStartX;
    final firstDeltaY = firstEndY - firstStartY;
    final secondDeltaX = secondEndX - secondStartX;
    final secondDeltaY = secondEndY - secondStartY;
    final denominator = firstDeltaX * secondDeltaY - firstDeltaY * secondDeltaX;
    if (denominator.abs() < 0.0000001) {
      return false;
    }
    final offsetX = secondStartX - firstStartX;
    final offsetY = secondStartY - firstStartY;
    final firstProgress =
        (offsetX * secondDeltaY - offsetY * secondDeltaX) / denominator;
    final secondProgress =
        (offsetX * firstDeltaY - offsetY * firstDeltaX) / denominator;
    return firstProgress >= 0 &&
        firstProgress <= 1 &&
        secondProgress >= 0 &&
        secondProgress <= 1;
  }

  double _pointSegmentDistanceSquared(
    double pointX,
    double pointY,
    double startX,
    double startY,
    double endX,
    double endY,
  ) {
    final deltaX = endX - startX;
    final deltaY = endY - startY;
    final lengthSquared = deltaX * deltaX + deltaY * deltaY;
    if (lengthSquared <= 0.0000001) {
      final offsetX = pointX - startX;
      final offsetY = pointY - startY;
      return offsetX * offsetX + offsetY * offsetY;
    }
    final progress =
        (((pointX - startX) * deltaX + (pointY - startY) * deltaY) /
                lengthSquared)
            .clamp(0.0, 1.0);
    final nearestX = startX + deltaX * progress;
    final nearestY = startY + deltaY * progress;
    final offsetX = pointX - nearestX;
    final offsetY = pointY - nearestY;
    return offsetX * offsetX + offsetY * offsetY;
  }

  double _lerpDouble(double from, double to, double progress) {
    return from + (to - from) * progress;
  }

  static const double _maximumPixelSweepStep = 0.5;
  static const int _pixelHitRefinementSteps = 5;
  final List<double> _collisionInterval = List.filled(2, 0);
  double _candidateHitTime = double.infinity;
  double _candidateHitX = 0;
  double _candidateHitY = 0;

  bool _findPixelAccurateHit(
    TankBulletComponent bullet,
    EnemyPlaneComponent plane,
  ) {
    if (!_sweptBulletPlaneBroadphase(bullet, plane)) {
      return false;
    }
    final entryTime = _collisionInterval[0];
    final exitTime = _collisionInterval[1];
    if (_projectilePixelsOverlapPlane(
      bullet,
      plane,
      entryTime,
      recordContact: true,
    )) {
      _candidateHitTime = entryTime;
      return true;
    }

    final relativeDeltaX =
        (bullet.position.x - bullet.previousX) -
        (plane.position.x - plane.previousX);
    final relativeDeltaY =
        (bullet.position.y - bullet.previousY) -
        (plane.position.y - plane.previousY);
    final intervalDistance =
        math.sqrt(
          relativeDeltaX * relativeDeltaX + relativeDeltaY * relativeDeltaY,
        ) *
        (exitTime - entryTime);
    final sampleCount = math.max(
      1,
      (intervalDistance / _maximumPixelSweepStep).ceil(),
    );
    var previousTime = entryTime;
    for (var sample = 1; sample <= sampleCount; sample++) {
      final sampleTime =
          entryTime + (exitTime - entryTime) * sample / sampleCount;
      if (!_projectilePixelsOverlapPlane(
        bullet,
        plane,
        sampleTime,
        recordContact: false,
      )) {
        previousTime = sampleTime;
        continue;
      }

      var emptyTime = previousTime;
      var solidTime = sampleTime;
      for (
        var refinement = 0;
        refinement < _pixelHitRefinementSteps;
        refinement++
      ) {
        final midpoint = (emptyTime + solidTime) / 2;
        if (_projectilePixelsOverlapPlane(
          bullet,
          plane,
          midpoint,
          recordContact: false,
        )) {
          solidTime = midpoint;
        } else {
          emptyTime = midpoint;
        }
      }
      if (_projectilePixelsOverlapPlane(
        bullet,
        plane,
        solidTime,
        recordContact: true,
      )) {
        _candidateHitTime = solidTime;
        return true;
      }
      return false;
    }
    return false;
  }

  bool _findPixelAccurateMissileHit(
    TankBulletComponent bullet,
    EnemyPlaneMissileComponent missile,
  ) {
    if (!_sweptBulletMissileBroadphase(bullet, missile)) {
      return false;
    }
    final entryTime = _collisionInterval[0];
    final exitTime = _collisionInterval[1];
    if (_projectilePixelsOverlapMissile(
      bullet,
      missile,
      entryTime,
      recordContact: true,
    )) {
      _candidateHitTime = entryTime;
      return true;
    }

    final relativeDeltaX =
        (bullet.position.x - bullet.previousX) -
        (missile.position.x - missile.previousX);
    final relativeDeltaY =
        (bullet.position.y - bullet.previousY) -
        (missile.position.y - missile.previousY);
    final intervalDistance =
        math.sqrt(
          relativeDeltaX * relativeDeltaX + relativeDeltaY * relativeDeltaY,
        ) *
        (exitTime - entryTime);
    final sampleCount = math.max(
      1,
      (intervalDistance / _maximumPixelSweepStep).ceil(),
    );
    var previousTime = entryTime;
    for (var sample = 1; sample <= sampleCount; sample++) {
      final sampleTime =
          entryTime + (exitTime - entryTime) * sample / sampleCount;
      if (!_projectilePixelsOverlapMissile(
        bullet,
        missile,
        sampleTime,
        recordContact: false,
      )) {
        previousTime = sampleTime;
        continue;
      }

      var emptyTime = previousTime;
      var solidTime = sampleTime;
      for (
        var refinement = 0;
        refinement < _pixelHitRefinementSteps;
        refinement++
      ) {
        final midpoint = (emptyTime + solidTime) / 2;
        if (_projectilePixelsOverlapMissile(
          bullet,
          missile,
          midpoint,
          recordContact: false,
        )) {
          solidTime = midpoint;
        } else {
          emptyTime = midpoint;
        }
      }
      if (_projectilePixelsOverlapMissile(
        bullet,
        missile,
        solidTime,
        recordContact: true,
      )) {
        _candidateHitTime = solidTime;
        return true;
      }
      return false;
    }
    return false;
  }

  bool _sweptBulletPlaneBroadphase(
    TankBulletComponent bullet,
    EnemyPlaneComponent plane,
  ) {
    final startX = bullet.previousCollisionCenterX - plane.previousX;
    final startY = bullet.previousCollisionCenterY - plane.previousY;
    final endX = bullet.collisionCenterX - plane.position.x;
    final endY = bullet.collisionCenterY - plane.position.y;
    final deltaX = endX - startX;
    final deltaY = endY - startY;
    final halfWidth = plane.size.x / 2 + bullet.collisionRadius;
    final halfHeight = plane.size.y / 2 + bullet.collisionRadius;
    var entryTime = 0.0;
    var exitTime = 1.0;
    if (!_clipSweepAxis(
      start: startX,
      delta: deltaX,
      minimum: -halfWidth,
      maximum: halfWidth,
      interval: _collisionInterval,
      initialEntry: entryTime,
      initialExit: exitTime,
    )) {
      return false;
    }
    entryTime = _collisionInterval[0];
    exitTime = _collisionInterval[1];
    if (!_clipSweepAxis(
      start: startY,
      delta: deltaY,
      minimum: -halfHeight,
      maximum: halfHeight,
      interval: _collisionInterval,
      initialEntry: entryTime,
      initialExit: exitTime,
    )) {
      return false;
    }
    return true;
  }

  bool _sweptBulletMissileBroadphase(
    TankBulletComponent bullet,
    EnemyPlaneMissileComponent missile,
  ) {
    final startX = bullet.previousCollisionCenterX - missile.previousX;
    final startY = bullet.previousCollisionCenterY - missile.previousY;
    final endX = bullet.collisionCenterX - missile.position.x;
    final endY = bullet.collisionCenterY - missile.position.y;
    final deltaX = endX - startX;
    final deltaY = endY - startY;
    final missileRadius = math.sqrt(
      EnemyPlaneMissileComponent.missileWidth *
              EnemyPlaneMissileComponent.missileWidth /
              4 +
          EnemyPlaneMissileComponent.missileHeight *
              EnemyPlaneMissileComponent.missileHeight /
              4,
    );
    final extent = missileRadius + bullet.collisionRadius;
    var entryTime = 0.0;
    var exitTime = 1.0;
    if (!_clipSweepAxis(
      start: startX,
      delta: deltaX,
      minimum: -extent,
      maximum: extent,
      interval: _collisionInterval,
      initialEntry: entryTime,
      initialExit: exitTime,
    )) {
      return false;
    }
    entryTime = _collisionInterval[0];
    exitTime = _collisionInterval[1];
    return _clipSweepAxis(
      start: startY,
      delta: deltaY,
      minimum: -extent,
      maximum: extent,
      interval: _collisionInterval,
      initialEntry: entryTime,
      initialExit: exitTime,
    );
  }

  bool _projectilePixelsOverlapPlane(
    TankBulletComponent bullet,
    EnemyPlaneComponent plane,
    double time, {
    required bool recordContact,
  }) {
    final bulletX =
        bullet.previousX + (bullet.position.x - bullet.previousX) * time;
    final bulletY =
        bullet.previousY + (bullet.position.y - bullet.previousY) * time;
    final planeX =
        plane.previousX + (plane.position.x - plane.previousX) * time;
    final planeY =
        plane.previousY + (plane.position.y - plane.previousY) * time;
    final profile = bullet.collisionProfile;
    final pixelScale = bullet.collisionPixelScale;
    final cosine = bullet.angleCosine;
    final sine = bullet.angleSine;
    final planeMask = game.collisionMaskCache.planeMask;

    for (
      var pointIndex = 0;
      pointIndex < profile.boundaryPointCount;
      pointIndex++
    ) {
      final localX = profile.boundaryXs[pointIndex] * pixelScale;
      final localY = profile.boundaryYs[pointIndex] * pixelScale;
      final worldX = bulletX + cosine * localX - sine * localY;
      final worldY = bulletY + sine * localX + cosine * localY;
      var normalizedX = (worldX - planeX) / plane.size.x + 0.5;
      if (!plane.movesRight) {
        normalizedX = 1 - normalizedX;
      }
      final normalizedY = (worldY - planeY) / plane.size.y + 0.5;
      final sourceX = (normalizedX * planeMask.width).floor();
      final sourceY = (normalizedY * planeMask.height).floor();
      if (!planeMask.isSolid(sourceX, sourceY)) {
        continue;
      }
      if (recordContact) {
        // Keep the resolved opaque pixel attached to the plane's current
        // frame position after finding it at the sub-frame sweep time.
        _candidateHitX = plane.position.x + (worldX - planeX);
        _candidateHitY = plane.position.y + (worldY - planeY);
      }
      return true;
    }
    return false;
  }

  bool _projectilePixelsOverlapMissile(
    TankBulletComponent bullet,
    EnemyPlaneMissileComponent missile,
    double time, {
    required bool recordContact,
  }) {
    final bulletX =
        bullet.previousX + (bullet.position.x - bullet.previousX) * time;
    final bulletY =
        bullet.previousY + (bullet.position.y - bullet.previousY) * time;
    final missileX =
        missile.previousX + (missile.position.x - missile.previousX) * time;
    final missileY =
        missile.previousY + (missile.position.y - missile.previousY) * time;
    final angleDelta = math.atan2(
      math.sin(missile.angle - missile.previousAngle),
      math.cos(missile.angle - missile.previousAngle),
    );
    final missileAngle = missile.previousAngle + angleDelta * time;
    final missileCosine = math.cos(missileAngle);
    final missileSine = math.sin(missileAngle);
    final profile = bullet.collisionProfile;
    final pixelScale = bullet.collisionPixelScale;
    final bulletCosine = bullet.angleCosine;
    final bulletSine = bullet.angleSine;

    for (
      var pointIndex = 0;
      pointIndex < profile.boundaryPointCount;
      pointIndex++
    ) {
      final bulletLocalX = profile.boundaryXs[pointIndex] * pixelScale;
      final bulletLocalY = profile.boundaryYs[pointIndex] * pixelScale;
      final worldX =
          bulletX + bulletCosine * bulletLocalX - bulletSine * bulletLocalY;
      final worldY =
          bulletY + bulletSine * bulletLocalX + bulletCosine * bulletLocalY;
      final relativeX = worldX - missileX;
      final relativeY = worldY - missileY;
      final missileLocalX = missileCosine * relativeX + missileSine * relativeY;
      final missileLocalY =
          -missileSine * relativeX + missileCosine * relativeY;
      final authoredX =
          missileLocalX + EnemyPlaneMissileComponent.missileWidth / 2;
      final authoredY =
          missileLocalY + EnemyPlaneMissileComponent.missileHeight / 2;
      if (!_isPointInsideMissileTriangle(authoredX, authoredY)) {
        continue;
      }
      if (recordContact) {
        _candidateHitX = missile.position.x + (worldX - missileX);
        _candidateHitY = missile.position.y + (worldY - missileY);
      }
      return true;
    }
    return false;
  }

  bool _isPointInsideMissileTriangle(double x, double y) {
    if (y < 0 || y > EnemyPlaneMissileComponent.missileHeight) {
      return false;
    }
    final halfWidthAtY =
        EnemyPlaneMissileComponent.missileWidth /
        2 *
        (1 - y / EnemyPlaneMissileComponent.missileHeight);
    return (x - EnemyPlaneMissileComponent.missileWidth / 2).abs() <=
        halfWidthAtY;
  }

  bool _clipSweepAxis({
    required double start,
    required double delta,
    required double minimum,
    required double maximum,
    required List<double> interval,
    required double initialEntry,
    required double initialExit,
  }) {
    var entry = initialEntry;
    var exit = initialExit;
    if (delta.abs() < 0.0000001) {
      if (start < minimum || start > maximum) {
        return false;
      }
    } else {
      var first = (minimum - start) / delta;
      var second = (maximum - start) / delta;
      if (first > second) {
        final swap = first;
        first = second;
        second = swap;
      }
      entry = math.max(entry, first);
      exit = math.min(exit, second);
      if (entry > exit) {
        return false;
      }
    }
    interval[0] = entry;
    interval[1] = exit;
    return true;
  }

  void _activateBulletHitEffect({
    required double x,
    required double y,
    required EnemyPlaneComponent? attachedPlane,
  }) {
    var effect = _bulletHitPool.first;
    for (var index = 0; index < _bulletHitPool.length; index++) {
      final candidate = _bulletHitPool[index];
      if (!candidate.isActive) {
        effect = candidate;
        break;
      }
      if (candidate.age > effect.age) {
        effect = candidate;
      }
    }
    final triangularRandom =
        (_impactRandom.nextDouble() + _impactRandom.nextDouble()) / 2;
    final visualScale =
        BulletHitEffectComponent.minimumVisualScale +
        (BulletHitEffectComponent.maximumVisualScale -
                BulletHitEffectComponent.minimumVisualScale) *
            triangularRandom;
    effect.activate(
      x: x,
      y: y,
      visualScale: visualScale,
      attachedPlane: attachedPlane,
    );
  }

  void _activatePlaneExplosion({
    required double x,
    required double y,
    double visualScale = 1,
  }) {
    var explosion = _planeExplosionPool.first;
    for (var index = 0; index < _planeExplosionPool.length; index++) {
      final candidate = _planeExplosionPool[index];
      if (!candidate.isActive) {
        explosion = candidate;
        break;
      }
      if (candidate.age > explosion.age) {
        explosion = candidate;
      }
    }
    explosion.activate(x: x, y: y, visualScale: visualScale);
  }

  void _activatePlaneSmoke({
    required double x,
    required double y,
    required double planeVelocity,
    double visualScale = 1,
  }) {
    var smoke = _planeSmokePool.first;
    for (var index = 0; index < _planeSmokePool.length; index++) {
      final candidate = _planeSmokePool[index];
      if (!candidate.isActive) {
        smoke = candidate;
        break;
      }
      if (candidate.age > smoke.age) {
        smoke = candidate;
      }
    }
    smoke.activate(
      x: x,
      y: y,
      horizontalVelocity: planeVelocity * 0.12,
      visualScale: visualScale,
    );
  }

  void _activatePlaneMissile(EnemyPlaneComponent plane) {
    var missile = _planeMissilePool.first;
    for (var index = 0; index < _planeMissilePool.length; index++) {
      final candidate = _planeMissilePool[index];
      if (!candidate.isActive && !candidate.impactPending) {
        missile = candidate;
        break;
      }
      if (candidate.age > missile.age) {
        missile = candidate;
      }
    }
    missile.deactivate();
    final direction = plane.movesRight ? 1.0 : -1.0;
    missile.activate(
      x:
          plane.position.x +
          direction * _randomPlaneBetween(-plane.size.x * 0.18, 0),
      y: plane.position.y + plane.size.y * 0.34,
      velocityX:
          plane.horizontalVelocity * 0.38 +
          direction * _randomPlaneBetween(85, 155),
      velocityY: _randomPlaneBetween(38, 76),
    );
    _planeMissilesDropped++;
  }

  void _activateGroundHit({
    required double x,
    required double y,
    required double visualScale,
  }) {
    var effect = _groundHitPool.first;
    for (var index = 0; index < _groundHitPool.length; index++) {
      final candidate = _groundHitPool[index];
      if (!candidate.isActive) {
        effect = candidate;
        break;
      }
      if (candidate.age > effect.age) {
        effect = candidate;
      }
    }
    effect.activate(x: x, y: y, visualScale: visualScale);
  }

  void _activateGroundHitSmoke({
    required double x,
    required double y,
    required double visualScale,
  }) {
    var effect = _groundHitSmokePool.first;
    for (var index = 0; index < _groundHitSmokePool.length; index++) {
      final candidate = _groundHitSmokePool[index];
      if (!candidate.isActive) {
        effect = candidate;
        break;
      }
      if (candidate.age > effect.age) {
        effect = candidate;
      }
    }
    effect.activate(x: x, y: y, visualScale: visualScale);
  }

  void _emitPlaneSmokeParticles({
    required double x,
    required double y,
    required double planeVelocity,
    double visualScale = 1,
  }) {
    final burstCount = 7 + _impactRandom.nextInt(3);
    final lingeringCount = 7 + _impactRandom.nextInt(3);
    _lastPlaneSmokeParticleCount = burstCount + lingeringCount;
    for (var typeIndex = 0; typeIndex < 2; typeIndex++) {
      final type = typeIndex == 0
          ? PlaneSmokeParticleType.burst
          : PlaneSmokeParticleType.lingering;
      final particleCount = type == PlaneSmokeParticleType.burst
          ? burstCount
          : lingeringCount;
      for (
        var particleIndex = 0;
        particleIndex < particleCount;
        particleIndex++
      ) {
        final artworkIndex =
            particleIndex < PlaneSmokeParticleComponent.artworkCount
            ? particleIndex
            : _impactRandom.nextInt(PlaneSmokeParticleComponent.artworkCount);
        final particle = _acquirePlaneSmokeParticle();
        if (type == PlaneSmokeParticleType.burst) {
          particle.activate(
            type: type,
            artworkIndex: artworkIndex,
            x: x + _randomImpactBetween(-18, 18) * visualScale,
            y: y + _randomImpactBetween(-10, 10) * visualScale,
            velocityX:
                planeVelocity * 0.20 +
                _randomImpactBetween(-150, 150) * visualScale,
            velocityY: _randomImpactBetween(-180, -60) * visualScale,
            angularVelocity: _randomImpactBetween(-6, 6),
            activationDelay: _randomImpactBetween(0.015, 0.060),
            lifetime: _randomImpactBetween(0.65, 1.05),
            initialScale: _randomImpactBetween(0.80, 1.15) * visualScale,
          );
        } else {
          final halfParticleCount = math.max(1, (particleCount - 1) / 2);
          final plumeDirection =
              (particleIndex - (particleCount - 1) / 2) / halfParticleCount;
          final outwardSpeed = _randomImpactBetween(52, 92);
          particle.activate(
            type: type,
            artworkIndex: artworkIndex,
            x: x + _randomImpactBetween(-5, 5) * visualScale,
            y: y + _randomImpactBetween(-8, 8) * visualScale,
            velocityX:
                planeVelocity * 0.08 +
                plumeDirection * outwardSpeed * visualScale +
                _randomImpactBetween(-9, 9) * visualScale,
            velocityY: _randomImpactBetween(-86, -48) * visualScale,
            angularVelocity: _randomImpactBetween(-3, 3),
            activationDelay: _randomImpactBetween(0.12, 0.30),
            lifetime: _randomImpactBetween(1.35, 2.0),
            initialScale: _randomImpactBetween(0.90, 1.15) * visualScale,
          );
        }
      }
    }
  }

  void _emitBulletHitParticles({
    required double x,
    required double y,
    required double planeVelocity,
  }) {
    final particleCount = 12 + _impactRandom.nextInt(5);
    _lastBulletHitParticleCount = particleCount;
    for (
      var particleIndex = 0;
      particleIndex < particleCount;
      particleIndex++
    ) {
      final artworkIndex =
          particleIndex < BulletHitParticleComponent.artworkCount
          ? particleIndex
          : _impactRandom.nextInt(BulletHitParticleComponent.artworkCount);
      final particle = _acquireBulletHitParticle();
      particle.activate(
        artworkIndex: artworkIndex,
        x: x,
        y: y,
        velocityX: planeVelocity * 0.30 + _randomImpactBetween(-240, 240),
        velocityY: _randomImpactBetween(80, 220),
        angularVelocity: _randomImpactBetween(-10, 10),
        lifetime: _randomImpactBetween(0.22, 0.38),
        initialScale: _randomImpactBetween(0.85, 1.15),
      );
    }
  }

  BulletHitParticleComponent _acquireBulletHitParticle() {
    var particle = _bulletHitParticlePool.first;
    for (var index = 0; index < _bulletHitParticlePool.length; index++) {
      final candidate = _bulletHitParticlePool[index];
      if (!candidate.isActive) {
        return candidate;
      }
      if (candidate.age > particle.age) {
        particle = candidate;
      }
    }
    return particle;
  }

  PlaneSmokeParticleComponent _acquirePlaneSmokeParticle() {
    var particle = _planeSmokeParticlePool.first;
    for (var index = 0; index < _planeSmokeParticlePool.length; index++) {
      final candidate = _planeSmokeParticlePool[index];
      if (!candidate.isActive) {
        return candidate;
      }
      if (candidate.age > particle.age) {
        particle = candidate;
      }
    }
    return particle;
  }

  double _randomImpactBetween(double minimum, double maximum) {
    return minimum + (maximum - minimum) * _impactRandom.nextDouble();
  }

  double _nextGroundHitVisualScale() {
    var candidate = _randomImpactBetween(
      GroundHitEffectComponent.minimumVisualScale,
      GroundHitEffectComponent.maximumVisualScale,
    );
    if (_lastGroundHitVisualScale.isFinite) {
      for (var attempt = 0; attempt < 4; attempt++) {
        if ((candidate - _lastGroundHitVisualScale).abs() >=
            GroundHitEffectComponent.minimumConsecutiveScaleDifference) {
          break;
        }
        candidate = _randomImpactBetween(
          GroundHitEffectComponent.minimumVisualScale,
          GroundHitEffectComponent.maximumVisualScale,
        );
      }
      if ((candidate - _lastGroundHitVisualScale).abs() <
          GroundHitEffectComponent.minimumConsecutiveScaleDifference) {
        const edgeBand = 0.035;
        final midpoint =
            (GroundHitEffectComponent.minimumVisualScale +
                GroundHitEffectComponent.maximumVisualScale) /
            2;
        candidate = _lastGroundHitVisualScale <= midpoint
            ? _randomImpactBetween(
                GroundHitEffectComponent.maximumVisualScale - edgeBand,
                GroundHitEffectComponent.maximumVisualScale,
              )
            : _randomImpactBetween(
                GroundHitEffectComponent.minimumVisualScale,
                GroundHitEffectComponent.minimumVisualScale + edgeBand,
              );
      }
    }
    _lastGroundHitVisualScale = candidate;
    return candidate;
  }

  double _randomPlaneBetween(double minimum, double maximum) {
    return minimum + (maximum - minimum) * _planeSpawnRandom.nextDouble();
  }

  double _groundLine() => _tankCreated
      ? tank.position.y
      : _stageSize.y - TankMotionTuning.groundInset;

  double _groundEffectVelocity() => _movementMode == TankMovementMode.continuous
      ? -TankBulletShellComponent.continuousGroundDriftSpeed
      : 0;

  @override
  void onRemove() {
    _bulletHitFrameCache.dispose();
    _planeExplosionFrameCache.dispose();
    _groundHitFrameCache.dispose();
    super.onRemove();
  }

  void _scheduleNextPlaneWave() {
    _pendingPlaneSpawns
      ..clear()
      ..addAll(createEnemyPlaneWave(_planeSpawnRandom));
    _timeUntilNextPlane = _pendingPlaneSpawns.first.delayAfterPrevious;
  }

  void _queueImmediatePlaneReplacement() {
    const delay = EnemyPlaneSpawnTuning.immediateReplacementDelay;
    _pendingPlaneSpawns.addFirst(
      EnemyPlaneSpawnSpec(
        delayAfterPrevious: delay,
        movesRight: _planeSpawnRandom.nextBool(),
        speed: _randomPlaneBetween(
          EnemyPlaneSpawnTuning.minimumSpeed,
          EnemyPlaneSpawnTuning.maximumSpeed,
        ),
        altitudeLane: _planeSpawnRandom.nextInt(
          EnemyPlaneSpawnTuning.altitudeLaneCount,
        ),
      ),
    );
    _timeUntilNextPlane = math.min(_timeUntilNextPlane, delay);
  }

  bool _spawnNextPlane() {
    final spec = _pendingPlaneSpawns.first;
    EnemyPlaneComponent? plane;
    for (final candidate in _planePool) {
      if (!candidate.isActive) {
        plane = candidate;
        break;
      }
    }
    if (plane == null) {
      _timeUntilNextPlane = EnemyPlaneSpawnTuning.blockedSpawnRetryDelay;
      return false;
    }

    final planeSize = _planeSize;
    final altitudeOffset =
        EnemyPlaneSpawnTuning.oppositeDirectionAltitudeOffset;
    final minimumCenterY =
        EnemyPlaneComponent.safeTopGap + planeSize.y / 2 + altitudeOffset;
    final maximumCenterY = math.max(
      minimumCenterY,
      math.min(
        _stageSize.y * EnemyPlaneComponent.maximumAltitudeFraction -
            altitudeOffset,
        _stageSize.y -
            TankMotionTuning.groundInset -
            TankComponent.renderedTankHeight -
            100 -
            altitudeOffset,
      ),
    );
    final lane = _selectSafePlaneLane(spec, planeSize: planeSize);
    if (lane == null) {
      _timeUntilNextPlane = EnemyPlaneSpawnTuning.blockedSpawnRetryDelay;
      return false;
    }

    final laneY = _planeLaneY(
      lane,
      minimumCenterY: minimumCenterY,
      maximumCenterY: maximumCenterY,
    );
    final y = laneY + (spec.movesRight ? -altitudeOffset : altitudeOffset);
    final x = spec.movesRight
        ? -planeSize.x / 2 - EnemyPlaneComponent.spawnPadding
        : _stageSize.x + planeSize.x / 2 + EnemyPlaneComponent.spawnPadding;
    plane.activate(
      movesRight: spec.movesRight,
      speed: spec.speed,
      altitudeLane: lane,
      altitudeOffset: spec.movesRight ? -altitudeOffset : altitudeOffset,
      missileDropDelay: _randomPlaneBetween(
        EnemyPlaneSpawnTuning.initialMissileDelayMinimum,
        EnemyPlaneSpawnTuning.initialMissileDelayMaximum,
      ),
      position: Vector2(x, y),
    );
    _pendingPlaneSpawns.removeFirst();
    _planesSpawned++;

    if (_pendingPlaneSpawns.isEmpty) {
      _scheduleNextPlaneWave();
    } else {
      _timeUntilNextPlane = _pendingPlaneSpawns.first.delayAfterPrevious;
    }
    return true;
  }

  int? _selectSafePlaneLane(
    EnemyPlaneSpawnSpec spec, {
    required Vector2 planeSize,
  }) {
    _alternativePlaneLanes.clear();
    for (var lane = 0; lane < EnemyPlaneSpawnTuning.altitudeLaneCount; lane++) {
      if (lane != spec.altitudeLane) {
        _alternativePlaneLanes.add(lane);
      }
    }
    _alternativePlaneLanes.shuffle(_planeSpawnRandom);
    _candidatePlaneLanes
      ..clear()
      ..add(spec.altitudeLane)
      ..addAll(_alternativePlaneLanes);
    final spawnX = spec.movesRight
        ? -planeSize.x / 2 - EnemyPlaneComponent.spawnPadding
        : _stageSize.x + planeSize.x / 2 + EnemyPlaneComponent.spawnPadding;
    _planeTrafficBuffer.clear();
    for (final activePlane in _planePool) {
      if (!activePlane.isActive) {
        continue;
      }
      final exitX = spec.movesRight
          ? _stageSize.x + planeSize.x / 2 + EnemyPlaneComponent.despawnPadding
          : -planeSize.x / 2 - EnemyPlaneComponent.despawnPadding;
      _planeTrafficBuffer.add(
        movesRight: activePlane.movesRight,
        speed: activePlane.speed,
        altitudeLane: activePlane.altitudeLane,
        separationFromSpawn: (activePlane.position.x - spawnX).abs(),
        timeUntilExit:
            (exitX - activePlane.position.x).abs() / activePlane.speed,
      );
    }
    return chooseSafeEnemyPlaneLane(
      candidateLanes: _candidatePlaneLanes,
      movesRight: spec.movesRight,
      speed: spec.speed,
      planeWidth: planeSize.x,
      activeTraffic: const <ActiveEnemyPlaneTraffic>[],
      trafficBuffer: _planeTrafficBuffer,
    );
  }

  double _planeLaneY(
    int lane, {
    required double minimumCenterY,
    required double maximumCenterY,
  }) {
    final altitudeProgress =
        lane / math.max(1, EnemyPlaneSpawnTuning.altitudeLaneCount - 1);
    return minimumCenterY +
        (maximumCenterY - minimumCenterY) * altitudeProgress;
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

class _PlaneCombatCollisionPass extends Component {
  _PlaneCombatCollisionPass(this.world) : super(priority: 10000);

  final CannonMileWorld world;

  @override
  void update(double dt) {
    if (!world._rendererWarmupActive && dt >= 0) {
      world._resolveBulletPlaneCollisions();
      world._resolveLaserCollisions();
    }
  }
}

class _PlaneAttackPass extends Component {
  _PlaneAttackPass(this.world) : super(priority: 11000);

  final CannonMileWorld world;

  @override
  void update(double dt) {
    if (!world._rendererWarmupActive && dt > 0) {
      world._resolvePlaneMissileImpacts();
      world._updatePlaneMissileDrops();
    }
  }
}
