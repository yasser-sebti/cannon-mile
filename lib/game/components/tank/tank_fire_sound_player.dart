import 'dart:async';
import 'dart:math' as math;

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'tank_bullet_level.dart';

abstract interface class TankFireSoundPlayer {
  static const double minimumPlaybackRate = 0.95;
  static const double maximumPlaybackRate = 1.05;
  static const double minimumMetalHitPlaybackRate = 0.90;
  static const double maximumMetalHitPlaybackRate = 1.10;

  Future<void> load();

  void playForBulletLevel(TankBulletLevel level);

  void playBulletDrop();

  void playExplosion();

  void playMetalHit();

  void startLaser();

  void stopLaser();

  Future<void> dispose();

  int get playCount;

  int? get lastSoundIndex;

  double? get lastPlaybackRate;

  int get bulletDropPlayCount;

  int? get lastBulletDropSoundIndex;

  double? get lastBulletDropPlaybackRate;

  int get explosionPlayCount;

  int? get lastExplosionSoundIndex;

  double? get lastExplosionPlaybackRate;

  int get metalHitPlayCount;

  int? get lastMetalHitSoundIndex;

  double? get lastMetalHitPlaybackRate;

  int get laserStartCount;

  int get laserStopCount;

  bool get isLaserIdlePlaying;
}

double _nextPlaybackRate(math.Random random) {
  return TankFireSoundPlayer.minimumPlaybackRate +
      random.nextDouble() *
          (TankFireSoundPlayer.maximumPlaybackRate -
              TankFireSoundPlayer.minimumPlaybackRate);
}

double _nextMetalHitPlaybackRate(math.Random random) {
  return TankFireSoundPlayer.minimumMetalHitPlaybackRate +
      random.nextDouble() *
          (TankFireSoundPlayer.maximumMetalHitPlaybackRate -
              TankFireSoundPlayer.minimumMetalHitPlaybackRate);
}

int _nextNonRepeatingSoundIndex(
  math.Random random,
  int? previousIndex,
  int soundCount,
) {
  if (previousIndex == null) {
    return random.nextInt(soundCount);
  }
  var nextIndex = random.nextInt(soundCount - 1);
  if (nextIndex >= previousIndex) {
    nextIndex++;
  }
  return nextIndex;
}

@visibleForTesting
int encodeWindowsFireAudioCommand(int soundIndex, double playbackRate) {
  assert(soundIndex >= 0 && soundIndex < TankBulletLevel.values.length);
  final rateUnits = (playbackRate * 10000).round().clamp(9500, 10500);
  return (soundIndex << 16) | rateUnits;
}

@visibleForTesting
int encodeWindowsBulletDropAudioCommand(int soundIndex, double playbackRate) {
  assert(
    soundIndex >= 0 &&
        soundIndex < PooledTankFireSoundPlayer.bulletDropSoundCount,
  );
  final rateUnits = (playbackRate * 10000).round().clamp(9500, 10500);
  return (soundIndex << 16) | rateUnits;
}

@visibleForTesting
int encodeWindowsExplosionAudioCommand(int soundIndex, double playbackRate) {
  assert(
    soundIndex >= 0 &&
        soundIndex < PooledTankFireSoundPlayer.explosionSoundCount,
  );
  final rateUnits = (playbackRate * 10000).round().clamp(9500, 10500);
  return (soundIndex << 16) | rateUnits;
}

@visibleForTesting
int encodeWindowsMetalHitAudioCommand(int soundIndex, double playbackRate) {
  assert(
    soundIndex >= 0 &&
        soundIndex < PooledTankFireSoundPlayer.metalHitSoundCount,
  );
  final rateUnits = (playbackRate * 10000).round().clamp(9000, 11000);
  return (soundIndex << 16) | rateUnits;
}

TankFireSoundPlayer createTankFireSoundPlayer() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    return WindowsTankFireSoundPlayer();
  }
  return PooledTankFireSoundPlayer();
}

class WindowsTankFireSoundPlayer implements TankFireSoundPlayer {
  WindowsTankFireSoundPlayer({math.Random? random})
    : _random = random ?? math.Random();

  static const MethodChannel _channel = MethodChannel('cannon_mile/fire_audio');

  final math.Random _random;
  int _playCount = 0;
  int? _lastSoundIndex;
  double? _lastPlaybackRate;
  int _bulletDropPlayCount = 0;
  int? _lastBulletDropSoundIndex;
  double? _lastBulletDropPlaybackRate;
  int _explosionPlayCount = 0;
  int? _lastExplosionSoundIndex;
  double? _lastExplosionPlaybackRate;
  int _metalHitPlayCount = 0;
  int? _lastMetalHitSoundIndex;
  double? _lastMetalHitPlaybackRate;
  int _laserStartCount = 0;
  int _laserStopCount = 0;
  bool _isLaserIdlePlaying = false;
  bool _isLoaded = false;

  @override
  int get playCount => _playCount;

  @override
  int? get lastSoundIndex => _lastSoundIndex;

  @override
  double? get lastPlaybackRate => _lastPlaybackRate;

  @override
  int get bulletDropPlayCount => _bulletDropPlayCount;

  @override
  int? get lastBulletDropSoundIndex => _lastBulletDropSoundIndex;

  @override
  double? get lastBulletDropPlaybackRate => _lastBulletDropPlaybackRate;

  @override
  int get explosionPlayCount => _explosionPlayCount;

  @override
  int? get lastExplosionSoundIndex => _lastExplosionSoundIndex;

  @override
  double? get lastExplosionPlaybackRate => _lastExplosionPlaybackRate;

  @override
  int get metalHitPlayCount => _metalHitPlayCount;

  @override
  int? get lastMetalHitSoundIndex => _lastMetalHitSoundIndex;

  @override
  double? get lastMetalHitPlaybackRate => _lastMetalHitPlaybackRate;

  @override
  int get laserStartCount => _laserStartCount;

  @override
  int get laserStopCount => _laserStopCount;

  @override
  bool get isLaserIdlePlaying => _isLaserIdlePlaying;

  @override
  Future<void> load() async {
    try {
      _isLoaded =
          await _channel.invokeMethod<bool>('load', {
            'volumes': PooledTankFireSoundPlayer.playbackVolumes,
            'dropVolumes': PooledTankFireSoundPlayer.bulletDropPlaybackVolumes,
            'explosionVolumes':
                PooledTankFireSoundPlayer.explosionPlaybackVolumes,
            'metalHitVolumes':
                PooledTankFireSoundPlayer.metalHitPlaybackVolumes,
            'laserStartVolume':
                PooledTankFireSoundPlayer.laserStartPlaybackVolume,
            'laserIdleVolume':
                PooledTankFireSoundPlayer.laserIdlePlaybackVolume,
          }) ??
          false;
    } on PlatformException catch (error) {
      debugPrint('Windows gunfire audio could not be loaded: $error');
      _isLoaded = false;
    } on MissingPluginException catch (error) {
      debugPrint('Windows gunfire channel is unavailable: $error');
      _isLoaded = false;
    }
  }

  @override
  void playForBulletLevel(TankBulletLevel level) {
    final soundIndex = level.index;
    final playbackRate = _nextPlaybackRate(_random);
    _lastSoundIndex = soundIndex;
    _lastPlaybackRate = playbackRate;
    _playCount++;
    if (_isLoaded) {
      unawaited(_play(soundIndex, playbackRate));
    }
  }

  @override
  void playBulletDrop() {
    final soundIndex = _nextNonRepeatingSoundIndex(
      _random,
      _lastBulletDropSoundIndex,
      PooledTankFireSoundPlayer.bulletDropSoundCount,
    );
    final playbackRate = _nextPlaybackRate(_random);
    _lastBulletDropSoundIndex = soundIndex;
    _lastBulletDropPlaybackRate = playbackRate;
    _bulletDropPlayCount++;
    if (_isLoaded) {
      unawaited(_playDrop(soundIndex, playbackRate));
    }
  }

  @override
  void playExplosion() {
    final soundIndex = _nextNonRepeatingSoundIndex(
      _random,
      _lastExplosionSoundIndex,
      PooledTankFireSoundPlayer.explosionSoundCount,
    );
    final playbackRate = _nextPlaybackRate(_random);
    _lastExplosionSoundIndex = soundIndex;
    _lastExplosionPlaybackRate = playbackRate;
    _explosionPlayCount++;
    if (_isLoaded) {
      unawaited(_playExplosion(soundIndex, playbackRate));
    }
  }

  @override
  void playMetalHit() {
    final soundIndex = _nextNonRepeatingSoundIndex(
      _random,
      _lastMetalHitSoundIndex,
      PooledTankFireSoundPlayer.metalHitSoundCount,
    );
    final playbackRate = _nextMetalHitPlaybackRate(_random);
    _lastMetalHitSoundIndex = soundIndex;
    _lastMetalHitPlaybackRate = playbackRate;
    _metalHitPlayCount++;
    if (_isLoaded) {
      unawaited(_playMetalHit(soundIndex, playbackRate));
    }
  }

  @override
  void startLaser() {
    if (_isLaserIdlePlaying) {
      return;
    }
    _laserStartCount++;
    _isLaserIdlePlaying = true;
    if (_isLoaded) {
      unawaited(_startLaser());
    }
  }

  @override
  void stopLaser() {
    if (!_isLaserIdlePlaying) {
      return;
    }
    _laserStopCount++;
    _isLaserIdlePlaying = false;
    if (_isLoaded) {
      unawaited(_stopLaser());
    }
  }

  Future<void> _startLaser() async {
    try {
      await _channel.invokeMethod<bool>('startLaser');
    } on PlatformException catch (error) {
      debugPrint('Windows laser playback failed: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Windows gunfire channel is unavailable: $error');
    }
  }

  Future<void> _stopLaser() async {
    try {
      await _channel.invokeMethod<bool>('stopLaser');
    } on PlatformException catch (error) {
      debugPrint('Windows laser stop failed: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Windows gunfire channel is unavailable: $error');
    }
  }

  Future<void> _play(int soundIndex, double playbackRate) async {
    try {
      final packedCommand = encodeWindowsFireAudioCommand(
        soundIndex,
        playbackRate,
      );
      await _channel.invokeMethod<bool>('play', packedCommand);
    } on PlatformException catch (error) {
      debugPrint('Windows gunfire playback failed: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Windows gunfire channel is unavailable: $error');
    }
  }

  Future<void> _playDrop(int soundIndex, double playbackRate) async {
    try {
      final packedCommand = encodeWindowsBulletDropAudioCommand(
        soundIndex,
        playbackRate,
      );
      await _channel.invokeMethod<bool>('playDrop', packedCommand);
    } on PlatformException catch (error) {
      debugPrint('Windows bullet-drop playback failed: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Windows gunfire channel is unavailable: $error');
    }
  }

  Future<void> _playExplosion(int soundIndex, double playbackRate) async {
    try {
      final packedCommand = encodeWindowsExplosionAudioCommand(
        soundIndex,
        playbackRate,
      );
      await _channel.invokeMethod<bool>('playExplosion', packedCommand);
    } on PlatformException catch (error) {
      debugPrint('Windows explosion playback failed: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Windows gunfire channel is unavailable: $error');
    }
  }

  Future<void> _playMetalHit(int soundIndex, double playbackRate) async {
    try {
      final packedCommand = encodeWindowsMetalHitAudioCommand(
        soundIndex,
        playbackRate,
      );
      await _channel.invokeMethod<bool>('playMetalHit', packedCommand);
    } on PlatformException catch (error) {
      debugPrint('Windows metal-hit playback failed: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Windows gunfire channel is unavailable: $error');
    }
  }

  @override
  Future<void> dispose() async {
    if (_isLaserIdlePlaying && _isLoaded) {
      await _stopLaser();
    }
    _isLaserIdlePlaying = false;
    _isLoaded = false;
  }
}

class PooledTankFireSoundPlayer implements TankFireSoundPlayer {
  PooledTankFireSoundPlayer({math.Random? random})
    : _random = random ?? math.Random();

  static const List<String> _soundAssets = [
    'sounds/gunfire1.wav',
    'sounds/gunfire2.wav',
    'sounds/gunfire3.wav',
    'sounds/gunfire4.wav',
    'sounds/gunfire5.wav',
    'sounds/gunfire6.wav',
  ];
  static const List<String> _bulletDropSoundAssets = [
    'sounds/bulletdrop1.wav',
    'sounds/bulletdrop2.wav',
    'sounds/bulletdrop3.wav',
    'sounds/bulletdrop4.wav',
  ];
  static const List<String> _explosionSoundAssets = [
    'sounds/bomb-explosion1.wav',
    'sounds/bomb-explosion2.wav',
    'sounds/bomb-explosion3.wav',
  ];
  static const List<String> _metalHitSoundAssets = [
    'sounds/metal-hit1.wav',
    'sounds/metal-hit2.wav',
    'sounds/metal-hit3.wav',
  ];
  static const String laserStartSoundAsset = 'sounds/laser-beam-start.wav';
  static const String laserIdleSoundAsset = 'sounds/laser-beam.wav';
  static const double laserStartPlaybackVolume = 0.34;
  static const double laserIdlePlaybackVolume = 0.24;
  static const int bulletDropSoundCount = 4;
  static const int explosionSoundCount = 3;
  static const int metalHitSoundCount = 3;
  static const double playbackVolume = 0.207025;
  static const double bulletDropPlaybackVolume = 0.273;
  static const double explosionPlaybackVolume = 0.022295;
  static const double metalHitPlaybackVolume = 0.0546;
  static const List<double> playbackVolumes = [
    playbackVolume,
    0.18839275,
    0.2691325,
    0.24221925,
    0.13456625,
    0.13456625,
  ];
  static const List<double> bulletDropPlaybackVolumes = [
    bulletDropPlaybackVolume,
    bulletDropPlaybackVolume,
    bulletDropPlaybackVolume,
    bulletDropPlaybackVolume,
  ];
  static const List<double> explosionPlaybackVolumes = [
    explosionPlaybackVolume,
    explosionPlaybackVolume,
    explosionPlaybackVolume,
  ];
  static const List<double> metalHitPlaybackVolumes = [
    metalHitPlaybackVolume,
    metalHitPlaybackVolume,
    metalHitPlaybackVolume,
  ];

  final math.Random _random;
  final List<_RateAwareAudioPool> _pools = [];
  final List<_RateAwareAudioPool> _bulletDropPools = [];
  final List<_RateAwareAudioPool> _explosionPools = [];
  final List<_RateAwareAudioPool> _metalHitPools = [];
  final _LaserBeamAudioController _laserAudio = _LaserBeamAudioController();
  int _playCount = 0;
  int? _lastSoundIndex;
  double? _lastPlaybackRate;
  int _bulletDropPlayCount = 0;
  int? _lastBulletDropSoundIndex;
  double? _lastBulletDropPlaybackRate;
  int _explosionPlayCount = 0;
  int? _lastExplosionSoundIndex;
  double? _lastExplosionPlaybackRate;
  int _metalHitPlayCount = 0;
  int? _lastMetalHitSoundIndex;
  double? _lastMetalHitPlaybackRate;
  int _laserStartCount = 0;
  int _laserStopCount = 0;
  bool _isLoaded = false;

  @override
  int get playCount => _playCount;

  @override
  int? get lastSoundIndex => _lastSoundIndex;

  @override
  double? get lastPlaybackRate => _lastPlaybackRate;

  @override
  int get bulletDropPlayCount => _bulletDropPlayCount;

  @override
  int? get lastBulletDropSoundIndex => _lastBulletDropSoundIndex;

  @override
  double? get lastBulletDropPlaybackRate => _lastBulletDropPlaybackRate;

  @override
  int get explosionPlayCount => _explosionPlayCount;

  @override
  int? get lastExplosionSoundIndex => _lastExplosionSoundIndex;

  @override
  double? get lastExplosionPlaybackRate => _lastExplosionPlaybackRate;

  @override
  int get metalHitPlayCount => _metalHitPlayCount;

  @override
  int? get lastMetalHitSoundIndex => _lastMetalHitSoundIndex;

  @override
  double? get lastMetalHitPlaybackRate => _lastMetalHitPlaybackRate;

  @override
  int get laserStartCount => _laserStartCount;

  @override
  int get laserStopCount => _laserStopCount;

  @override
  bool get isLaserIdlePlaying => _laserAudio.isActive;

  @override
  Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    final audioCache = AudioCache(prefix: 'assets/');
    try {
      for (final asset in _soundAssets) {
        _pools.add(
          await _RateAwareAudioPool.create(
            source: AssetSource(asset),
            audioCache: audioCache,
            minPlayers: 8,
            maxPlayers: 8,
          ),
        );
      }
      for (final asset in _bulletDropSoundAssets) {
        _bulletDropPools.add(
          await _RateAwareAudioPool.create(
            source: AssetSource(asset),
            audioCache: audioCache,
            minPlayers: 1,
            maxPlayers: 1,
          ),
        );
      }
      for (final asset in _explosionSoundAssets) {
        _explosionPools.add(
          await _RateAwareAudioPool.create(
            source: AssetSource(asset),
            audioCache: audioCache,
            minPlayers: 8,
            maxPlayers: 8,
          ),
        );
      }
      for (final asset in _metalHitSoundAssets) {
        _metalHitPools.add(
          await _RateAwareAudioPool.create(
            source: AssetSource(asset),
            audioCache: audioCache,
            minPlayers: 8,
            maxPlayers: 8,
          ),
        );
      }
      await _laserAudio.load();
      _isLoaded = true;
    } catch (error, stackTrace) {
      debugPrint('Gunfire audio could not be loaded: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _disposePools();
    }
  }

  @override
  void playForBulletLevel(TankBulletLevel level) {
    final soundIndex = level.index;
    final playbackRate = _nextPlaybackRate(_random);
    _lastSoundIndex = soundIndex;
    _lastPlaybackRate = playbackRate;
    _playCount++;
    if (!_isLoaded) {
      return;
    }
    unawaited(_play(soundIndex, playbackRate));
  }

  @override
  void playBulletDrop() {
    final soundIndex = _nextNonRepeatingSoundIndex(
      _random,
      _lastBulletDropSoundIndex,
      bulletDropSoundCount,
    );
    final playbackRate = _nextPlaybackRate(_random);
    _lastBulletDropSoundIndex = soundIndex;
    _lastBulletDropPlaybackRate = playbackRate;
    _bulletDropPlayCount++;
    if (!_isLoaded) {
      return;
    }
    unawaited(_playDrop(soundIndex, playbackRate));
  }

  @override
  void playExplosion() {
    final soundIndex = _nextNonRepeatingSoundIndex(
      _random,
      _lastExplosionSoundIndex,
      explosionSoundCount,
    );
    final playbackRate = _nextPlaybackRate(_random);
    _lastExplosionSoundIndex = soundIndex;
    _lastExplosionPlaybackRate = playbackRate;
    _explosionPlayCount++;
    if (!_isLoaded) {
      return;
    }
    unawaited(_playExplosion(soundIndex, playbackRate));
  }

  @override
  void playMetalHit() {
    final soundIndex = _nextNonRepeatingSoundIndex(
      _random,
      _lastMetalHitSoundIndex,
      metalHitSoundCount,
    );
    final playbackRate = _nextMetalHitPlaybackRate(_random);
    _lastMetalHitSoundIndex = soundIndex;
    _lastMetalHitPlaybackRate = playbackRate;
    _metalHitPlayCount++;
    if (!_isLoaded) {
      return;
    }
    unawaited(_playMetalHit(soundIndex, playbackRate));
  }

  @override
  void startLaser() {
    if (_laserAudio.isActive) {
      return;
    }
    _laserStartCount++;
    _laserAudio.start();
  }

  @override
  void stopLaser() {
    if (!_laserAudio.isActive) {
      return;
    }
    _laserStopCount++;
    _laserAudio.stop();
  }

  Future<void> _play(int soundIndex, double playbackRate) async {
    try {
      await _pools[soundIndex].start(
        volume: playbackVolumes[soundIndex],
        playbackRate: playbackRate,
      );
    } catch (error) {
      debugPrint('Gunfire audio playback failed: $error');
    }
  }

  Future<void> _playDrop(int soundIndex, double playbackRate) async {
    try {
      await _bulletDropPools[soundIndex].start(
        volume: bulletDropPlaybackVolumes[soundIndex],
        playbackRate: playbackRate,
      );
    } catch (error) {
      debugPrint('Bullet-drop audio playback failed: $error');
    }
  }

  Future<void> _playExplosion(int soundIndex, double playbackRate) async {
    try {
      for (var offset = 0; offset < _explosionPools.length; offset++) {
        final fallbackIndex = (soundIndex + offset) % _explosionPools.length;
        final started = await _explosionPools[fallbackIndex].start(
          volume: explosionPlaybackVolumes[fallbackIndex],
          playbackRate: playbackRate,
          interruptOldestWhenFull: false,
        );
        if (started) {
          return;
        }
      }
    } catch (error) {
      debugPrint('Explosion audio playback failed: $error');
    }
  }

  Future<void> _playMetalHit(int soundIndex, double playbackRate) async {
    try {
      for (var offset = 0; offset < _metalHitPools.length; offset++) {
        final fallbackIndex = (soundIndex + offset) % _metalHitPools.length;
        final started = await _metalHitPools[fallbackIndex].start(
          volume: metalHitPlaybackVolumes[fallbackIndex],
          playbackRate: playbackRate,
          interruptOldestWhenFull: false,
        );
        if (started) {
          return;
        }
      }
    } catch (error) {
      debugPrint('Metal-hit audio playback failed: $error');
    }
  }

  @override
  Future<void> dispose() async {
    _isLoaded = false;
    await _laserAudio.dispose();
    await _disposePools();
  }

  Future<void> _disposePools() async {
    final pools = <_RateAwareAudioPool>[
      ..._pools,
      ..._bulletDropPools,
      ..._explosionPools,
      ..._metalHitPools,
    ];
    _pools.clear();
    _bulletDropPools.clear();
    _explosionPools.clear();
    _metalHitPools.clear();
    await Future.wait(pools.map((pool) => pool.dispose()));
  }
}

class _LaserBeamAudioController {
  AudioPlayer? _startPlayer;
  AudioPlayer? _idlePlayer;
  bool _isLoaded = false;
  bool _isActive = false;
  bool _isDisposed = false;
  int _generation = 0;

  bool get isActive => _isActive;

  Future<void> load() async {
    if (_isLoaded || _isDisposed) {
      return;
    }
    final startPlayer = AudioPlayer();
    final idlePlayer = AudioPlayer();
    try {
      final startData = await rootBundle.load(
        'assets/${PooledTankFireSoundPlayer.laserStartSoundAsset}',
      );
      final idleData = await rootBundle.load(
        'assets/${PooledTankFireSoundPlayer.laserIdleSoundAsset}',
      );
      final startBytes = startData.buffer.asUint8List(
        startData.offsetInBytes,
        startData.lengthInBytes,
      );
      final idleBytes = idleData.buffer.asUint8List(
        idleData.offsetInBytes,
        idleData.lengthInBytes,
      );
      await Future.wait([
        startPlayer.setPlayerMode(PlayerMode.mediaPlayer),
        idlePlayer.setPlayerMode(PlayerMode.mediaPlayer),
      ]);
      await Future.wait([
        startPlayer.setSource(BytesSource(startBytes, mimeType: 'audio/wav')),
        idlePlayer.setSource(BytesSource(idleBytes, mimeType: 'audio/wav')),
      ]);
      await Future.wait([
        startPlayer.setReleaseMode(ReleaseMode.stop),
        idlePlayer.setReleaseMode(ReleaseMode.loop),
        startPlayer.setVolume(
          PooledTankFireSoundPlayer.laserStartPlaybackVolume,
        ),
        idlePlayer.setVolume(PooledTankFireSoundPlayer.laserIdlePlaybackVolume),
      ]);
      if (_isDisposed) {
        await Future.wait([startPlayer.dispose(), idlePlayer.dispose()]);
        return;
      }
      _startPlayer = startPlayer;
      _idlePlayer = idlePlayer;
      _isLoaded = true;
    } catch (error, stackTrace) {
      debugPrint('Laser audio could not be loaded: $error');
      debugPrintStack(stackTrace: stackTrace);
      await Future.wait([startPlayer.dispose(), idlePlayer.dispose()]);
    }
  }

  void start() {
    if (_isDisposed || _isActive) {
      return;
    }
    _isActive = true;
    final generation = ++_generation;
    if (_isLoaded) {
      unawaited(_start(generation));
    }
  }

  Future<void> _start(int generation) async {
    final startPlayer = _startPlayer;
    final idlePlayer = _idlePlayer;
    if (startPlayer == null || idlePlayer == null) {
      return;
    }
    try {
      await Future.wait([startPlayer.stop(), idlePlayer.stop()]);
      if (!_isActive || generation != _generation || _isDisposed) {
        return;
      }
      await Future.wait([startPlayer.resume(), idlePlayer.resume()]);
      if (!_isActive || generation != _generation || _isDisposed) {
        await Future.wait([startPlayer.stop(), idlePlayer.stop()]);
      }
    } catch (error) {
      debugPrint('Laser audio playback failed: $error');
    }
  }

  void stop() {
    if (!_isActive) {
      return;
    }
    _isActive = false;
    _generation++;
    final startPlayer = _startPlayer;
    final idlePlayer = _idlePlayer;
    if (_isLoaded && startPlayer != null && idlePlayer != null) {
      unawaited(Future.wait([startPlayer.stop(), idlePlayer.stop()]));
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _isActive = false;
    _isLoaded = false;
    _generation++;
    final players = <AudioPlayer>[?_startPlayer, ?_idlePlayer];
    _startPlayer = null;
    _idlePlayer = null;
    await Future.wait(players.map((player) => player.dispose()));
  }
}

class _RateAwareAudioPool {
  _RateAwareAudioPool._({
    required this.source,
    required this.audioCache,
    required this.maxPlayers,
  });

  static Future<_RateAwareAudioPool> create({
    required Source source,
    required AudioCache audioCache,
    required int minPlayers,
    required int maxPlayers,
  }) async {
    final pool = _RateAwareAudioPool._(
      source: source,
      audioCache: audioCache,
      maxPlayers: maxPlayers,
    );
    for (var index = 0; index < minPlayers; index++) {
      pool._available.add(await pool._createVoice());
    }
    return pool;
  }

  final Source source;
  final AudioCache audioCache;
  final int maxPlayers;
  final List<_RateAwareAudioVoice> _available = [];
  final Set<_RateAwareAudioVoice> _active = {};
  int _playSequence = 0;
  bool _isDisposed = false;

  Future<bool> start({
    required double volume,
    required double playbackRate,
    bool interruptOldestWhenFull = true,
  }) async {
    if (_isDisposed) {
      return false;
    }

    final _RateAwareAudioVoice voice;
    if (_available.isNotEmpty) {
      voice = _available.removeLast();
    } else if (_available.length + _active.length < maxPlayers) {
      voice = await _createVoice();
    } else {
      if (!interruptOldestWhenFull) {
        return false;
      }
      voice = _active.reduce(
        (oldest, candidate) =>
            candidate.playSequence < oldest.playSequence ? candidate : oldest,
      );
      _active.remove(voice);
      await voice.player.stop();
    }
    if (_isDisposed) {
      await voice.dispose();
      return false;
    }

    voice.playSequence = ++_playSequence;
    _active.add(voice);
    try {
      await voice.player.setPlaybackRate(playbackRate);
      await voice.player.setVolume(volume);
      await voice.player.resume();
      return true;
    } catch (_) {
      _release(voice);
      rethrow;
    }
  }

  Future<_RateAwareAudioVoice> _createVoice() async {
    final player = AudioPlayer()..audioCache = audioCache;
    await player.setPlayerMode(PlayerMode.mediaPlayer);
    await player.setSource(source);
    await player.setReleaseMode(ReleaseMode.stop);
    final voice = _RateAwareAudioVoice(player);
    voice.completionSubscription = player.onPlayerComplete.listen((_) {
      _release(voice);
    });
    return voice;
  }

  void _release(_RateAwareAudioVoice voice) {
    if (!_active.remove(voice)) {
      return;
    }
    if (_isDisposed || _available.length >= maxPlayers) {
      unawaited(voice.dispose());
    } else {
      _available.add(voice);
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    final voices = {..._available, ..._active};
    _available.clear();
    _active.clear();
    await Future.wait(voices.map((voice) => voice.dispose()));
  }
}

class _RateAwareAudioVoice {
  _RateAwareAudioVoice(this.player);

  final AudioPlayer player;
  StreamSubscription<void>? completionSubscription;
  int playSequence = 0;

  Future<void> dispose() async {
    await completionSubscription?.cancel();
    await player.dispose();
  }
}

@visibleForTesting
class SilentTankFireSoundPlayer implements TankFireSoundPlayer {
  SilentTankFireSoundPlayer({math.Random? random})
    : _random = random ?? math.Random(0);

  final math.Random _random;
  final List<int> _playedSoundIndices = [];
  final List<double> _playedPlaybackRates = [];
  final List<int> _playedBulletDropSoundIndices = [];
  final List<double> _playedBulletDropPlaybackRates = [];
  final List<int> _playedExplosionSoundIndices = [];
  final List<double> _playedExplosionPlaybackRates = [];
  final List<int> _playedMetalHitSoundIndices = [];
  final List<double> _playedMetalHitPlaybackRates = [];
  int _laserStartCount = 0;
  int _laserStopCount = 0;
  bool _isLaserIdlePlaying = false;

  List<int> get playedSoundIndices => List.unmodifiable(_playedSoundIndices);

  List<double> get playedPlaybackRates =>
      List.unmodifiable(_playedPlaybackRates);

  List<int> get playedBulletDropSoundIndices =>
      List.unmodifiable(_playedBulletDropSoundIndices);

  List<double> get playedBulletDropPlaybackRates =>
      List.unmodifiable(_playedBulletDropPlaybackRates);

  List<int> get playedExplosionSoundIndices =>
      List.unmodifiable(_playedExplosionSoundIndices);

  List<double> get playedExplosionPlaybackRates =>
      List.unmodifiable(_playedExplosionPlaybackRates);

  List<int> get playedMetalHitSoundIndices =>
      List.unmodifiable(_playedMetalHitSoundIndices);

  List<double> get playedMetalHitPlaybackRates =>
      List.unmodifiable(_playedMetalHitPlaybackRates);

  @override
  int get playCount => _playedSoundIndices.length;

  @override
  int? get lastSoundIndex =>
      _playedSoundIndices.isEmpty ? null : _playedSoundIndices.last;

  @override
  double? get lastPlaybackRate =>
      _playedPlaybackRates.isEmpty ? null : _playedPlaybackRates.last;

  @override
  int get bulletDropPlayCount => _playedBulletDropSoundIndices.length;

  @override
  int? get lastBulletDropSoundIndex => _playedBulletDropSoundIndices.isEmpty
      ? null
      : _playedBulletDropSoundIndices.last;

  @override
  double? get lastBulletDropPlaybackRate =>
      _playedBulletDropPlaybackRates.isEmpty
      ? null
      : _playedBulletDropPlaybackRates.last;

  @override
  int get explosionPlayCount => _playedExplosionSoundIndices.length;

  @override
  int? get lastExplosionSoundIndex => _playedExplosionSoundIndices.isEmpty
      ? null
      : _playedExplosionSoundIndices.last;

  @override
  double? get lastExplosionPlaybackRate => _playedExplosionPlaybackRates.isEmpty
      ? null
      : _playedExplosionPlaybackRates.last;

  @override
  int get metalHitPlayCount => _playedMetalHitSoundIndices.length;

  @override
  int? get lastMetalHitSoundIndex => _playedMetalHitSoundIndices.isEmpty
      ? null
      : _playedMetalHitSoundIndices.last;

  @override
  double? get lastMetalHitPlaybackRate => _playedMetalHitPlaybackRates.isEmpty
      ? null
      : _playedMetalHitPlaybackRates.last;

  @override
  int get laserStartCount => _laserStartCount;

  @override
  int get laserStopCount => _laserStopCount;

  @override
  bool get isLaserIdlePlaying => _isLaserIdlePlaying;

  @override
  Future<void> load() async {}

  @override
  void playForBulletLevel(TankBulletLevel level) {
    _playedSoundIndices.add(level.index);
    _playedPlaybackRates.add(_nextPlaybackRate(_random));
  }

  @override
  void playBulletDrop() {
    final soundIndex = _nextNonRepeatingSoundIndex(
      _random,
      lastBulletDropSoundIndex,
      PooledTankFireSoundPlayer.bulletDropSoundCount,
    );
    _playedBulletDropSoundIndices.add(soundIndex);
    _playedBulletDropPlaybackRates.add(_nextPlaybackRate(_random));
  }

  @override
  void playExplosion() {
    final soundIndex = _nextNonRepeatingSoundIndex(
      _random,
      lastExplosionSoundIndex,
      PooledTankFireSoundPlayer.explosionSoundCount,
    );
    _playedExplosionSoundIndices.add(soundIndex);
    _playedExplosionPlaybackRates.add(_nextPlaybackRate(_random));
  }

  @override
  void playMetalHit() {
    final soundIndex = _nextNonRepeatingSoundIndex(
      _random,
      lastMetalHitSoundIndex,
      PooledTankFireSoundPlayer.metalHitSoundCount,
    );
    _playedMetalHitSoundIndices.add(soundIndex);
    _playedMetalHitPlaybackRates.add(_nextMetalHitPlaybackRate(_random));
  }

  @override
  void startLaser() {
    if (_isLaserIdlePlaying) {
      return;
    }
    _isLaserIdlePlaying = true;
    _laserStartCount++;
  }

  @override
  void stopLaser() {
    if (!_isLaserIdlePlaying) {
      return;
    }
    _isLaserIdlePlaying = false;
    _laserStopCount++;
  }

  @override
  Future<void> dispose() async {
    _isLaserIdlePlaying = false;
  }
}
