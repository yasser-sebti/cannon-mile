import 'dart:math' as math;

import 'package:cannon_mile/game/components/tank/tank_bullet_level.dart';
import 'package:cannon_mile/game/components/tank/tank_fire_sound_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows playback commands pack sound and clamped pitch compactly', () {
    expect(encodeWindowsFireAudioCommand(0, 0.95), 9500);
    expect(encodeWindowsFireAudioCommand(5, 1.05), (5 << 16) | 10500);
    expect(encodeWindowsFireAudioCommand(2, 0.2), (2 << 16) | 9500);
    expect(encodeWindowsFireAudioCommand(3, 4), (3 << 16) | 10500);
    expect(encodeWindowsBulletDropAudioCommand(0, 0.95), 9500);
    expect(encodeWindowsBulletDropAudioCommand(3, 1.05), (3 << 16) | 10500);
    expect(encodeWindowsExplosionAudioCommand(0, 0.95), 9500);
    expect(encodeWindowsExplosionAudioCommand(2, 1.05), (2 << 16) | 10500);
    expect(encodeWindowsMetalHitAudioCommand(0, 0.90), 9000);
    expect(encodeWindowsMetalHitAudioCommand(2, 1.10), (2 << 16) | 11000);
    expect(encodeWindowsMetalHitAudioCommand(1, 0.2), (1 << 16) | 9000);
    expect(encodeWindowsMetalHitAudioCommand(1, 4), (1 << 16) | 11000);
  });

  test('Windows uses the runner-native player instead of audioplayers', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(createTankFireSoundPlayer(), isA<WindowsTankFireSoundPlayer>());
  });

  test('other platforms retain pooled audio playback', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(createTankFireSoundPlayer(), isA<PooledTankFireSoundPlayer>());
  });

  test('gunfire playback uses the boosted shared volume', () {
    expect(
      PooledTankFireSoundPlayer.playbackVolume,
      closeTo(0.15925, 0.000001),
    );
  });

  test('gunfire maps bullet levels to sounds and varies playback speed', () {
    final player = SilentTankFireSoundPlayer(random: math.Random(17));

    for (final level in TankBulletLevel.values) {
      player.playForBulletLevel(level);
    }

    expect(player.playedSoundIndices, [0, 1, 2, 3, 4, 5]);
    expect(player.playCount, 6);
    expect(player.lastSoundIndex, 5);
    expect(
      player.playedPlaybackRates,
      everyElement(
        inInclusiveRange(
          TankFireSoundPlayer.minimumPlaybackRate,
          TankFireSoundPlayer.maximumPlaybackRate,
        ),
      ),
    );
    expect(player.playedPlaybackRates.toSet(), hasLength(greaterThan(1)));
    expect(player.lastPlaybackRate, player.playedPlaybackRates.last);
    expect(TankFireSoundPlayer.minimumPlaybackRate, 0.95);
    expect(TankFireSoundPlayer.maximumPlaybackRate, 1.05);
  });

  test('bullet-drop sounds randomize without immediate repetition', () {
    final player = SilentTankFireSoundPlayer(random: math.Random(29));

    for (var index = 0; index < 80; index++) {
      player.playBulletDrop();
    }

    expect(player.bulletDropPlayCount, 80);
    expect(player.playedBulletDropSoundIndices.toSet(), {0, 1, 2, 3});
    for (
      var index = 1;
      index < player.playedBulletDropSoundIndices.length;
      index++
    ) {
      expect(
        player.playedBulletDropSoundIndices[index],
        isNot(player.playedBulletDropSoundIndices[index - 1]),
      );
    }
    expect(
      player.playedBulletDropPlaybackRates,
      everyElement(
        inInclusiveRange(
          TankFireSoundPlayer.minimumPlaybackRate,
          TankFireSoundPlayer.maximumPlaybackRate,
        ),
      ),
    );
    expect(PooledTankFireSoundPlayer.bulletDropPlaybackVolume, 0.21);
  });

  test(
    'ground explosions randomize without repetition at 1.715 percent volume',
    () {
      final player = SilentTankFireSoundPlayer(random: math.Random(41));

      for (var index = 0; index < 60; index++) {
        player.playExplosion();
      }

      expect(player.explosionPlayCount, 60);
      expect(player.playedExplosionSoundIndices.toSet(), {0, 1, 2});
      for (
        var index = 1;
        index < player.playedExplosionSoundIndices.length;
        index++
      ) {
        expect(
          player.playedExplosionSoundIndices[index],
          isNot(player.playedExplosionSoundIndices[index - 1]),
        );
      }
      expect(
        player.playedExplosionPlaybackRates,
        everyElement(
          inInclusiveRange(
            TankFireSoundPlayer.minimumPlaybackRate,
            TankFireSoundPlayer.maximumPlaybackRate,
          ),
        ),
      );
      expect(PooledTankFireSoundPlayer.explosionPlaybackVolume, 0.01715);
    },
  );

  test('metal hits vary subtly without repeating the same clip', () {
    final player = SilentTankFireSoundPlayer(random: math.Random(53));

    for (var index = 0; index < 60; index++) {
      player.playMetalHit();
    }

    expect(player.metalHitPlayCount, 60);
    expect(player.playedMetalHitSoundIndices.toSet(), {0, 1, 2});
    for (
      var index = 1;
      index < player.playedMetalHitSoundIndices.length;
      index++
    ) {
      expect(
        player.playedMetalHitSoundIndices[index],
        isNot(player.playedMetalHitSoundIndices[index - 1]),
      );
    }
    expect(
      player.playedMetalHitPlaybackRates,
      everyElement(
        inInclusiveRange(
          TankFireSoundPlayer.minimumMetalHitPlaybackRate,
          TankFireSoundPlayer.maximumMetalHitPlaybackRate,
        ),
      ),
    );
    expect(
      player.playedMetalHitPlaybackRates.toSet(),
      hasLength(greaterThan(1)),
    );
    expect(PooledTankFireSoundPlayer.metalHitPlaybackVolume, 0.042);
  });

  test('gunfire one stays fixed while levels two through six are boosted', () {
    expect(PooledTankFireSoundPlayer.playbackVolumes, const [
      0.15925,
      0.1449175,
      0.207025,
      0.1863225,
      0.1035125,
      0.1035125,
    ]);
  });
}
