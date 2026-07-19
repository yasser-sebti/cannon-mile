import 'dart:math' as math;

import 'package:cannon_mile/game/components/enemies/enemy_plane_spawn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('continuous waves cover bursts, fast delays, directions, and lanes', () {
    final random = math.Random(7429);
    final waveSizes = <int>{};
    final directions = <bool>{};
    final lanes = <int>{};
    var sawShortWaveDelay = false;
    var sawLongWaveDelay = false;

    for (var waveIndex = 0; waveIndex < 200; waveIndex++) {
      final wave = createEnemyPlaneWave(random);
      waveSizes.add(wave.length);
      directions.addAll(wave.map((spec) => spec.movesRight));
      lanes.addAll(wave.map((spec) => spec.altitudeLane));
      final firstDelay = wave.first.delayAfterPrevious;
      sawShortWaveDelay |=
          firstDelay <= EnemyPlaneSpawnTuning.shortWaveDelayMaximum;
      sawLongWaveDelay |=
          firstDelay >= EnemyPlaneSpawnTuning.longWaveDelayMinimum;

      expect(wave, hasLength(inInclusiveRange(2, 4)));
      expect(
        wave.map((spec) => spec.altitudeLane).toSet(),
        hasLength(wave.length),
      );
      for (var index = 0; index < wave.length; index++) {
        final spec = wave[index];
        expect(
          spec.speed,
          inInclusiveRange(
            EnemyPlaneSpawnTuning.minimumSpeed,
            EnemyPlaneSpawnTuning.maximumSpeed,
          ),
        );
        if (index > 0) {
          expect(
            spec.delayAfterPrevious,
            inInclusiveRange(
              EnemyPlaneSpawnTuning.burstDelayMinimum,
              EnemyPlaneSpawnTuning.burstDelayMaximum,
            ),
          );
        }
      }
    }

    expect(waveSizes, {2, 3, 4});
    expect(directions, {false, true});
    expect(lanes, {0, 1, 2, 3});
    expect(sawShortWaveDelay, isTrue);
    expect(sawLongWaveDelay, isTrue);
    expect(EnemyPlaneSpawnTuning.minimumSpeed, 280);
    expect(EnemyPlaneSpawnTuning.maximumSpeed, 700);
    expect(EnemyPlaneSpawnTuning.immediateReplacementDelay, 0.06);
  });

  test('same-direction traffic changes lane when spacing is unsafe', () {
    const width = 200.0;
    const traffic = [
      ActiveEnemyPlaneTraffic(
        movesRight: true,
        speed: 400,
        altitudeLane: 2,
        separationFromSpawn: 250,
        timeUntilExit: 3,
      ),
    ];

    expect(
      chooseSafeEnemyPlaneLane(
        candidateLanes: const [2, 1, 3, 0],
        movesRight: true,
        speed: 500,
        planeWidth: width,
        activeTraffic: traffic,
      ),
      1,
    );
  });

  test('predictive spacing prevents a faster plane catching its leader', () {
    const traffic = [
      ActiveEnemyPlaneTraffic(
        movesRight: false,
        speed: 300,
        altitudeLane: 0,
        separationFromSpawn: 500,
        timeUntilExit: 3,
      ),
    ];

    expect(
      chooseSafeEnemyPlaneLane(
        candidateLanes: const [0],
        movesRight: false,
        speed: 400,
        planeWidth: 200,
        activeTraffic: traffic,
      ),
      isNull,
    );
    expect(
      chooseSafeEnemyPlaneLane(
        candidateLanes: const [0],
        movesRight: false,
        speed: 320,
        planeWidth: 200,
        activeTraffic: traffic,
      ),
      0,
    );
  });

  test('opposite-direction planes may share an occupied lane', () {
    const traffic = [
      ActiveEnemyPlaneTraffic(
        movesRight: false,
        speed: 700,
        altitudeLane: 3,
        separationFromSpawn: 1,
        timeUntilExit: 10,
      ),
    ];

    expect(
      chooseSafeEnemyPlaneLane(
        candidateLanes: const [3],
        movesRight: true,
        speed: 700,
        planeWidth: 200,
        activeTraffic: traffic,
      ),
      3,
    );
  });

  test('returns no lane when all same-direction lanes are blocked', () {
    final traffic = [
      for (var lane = 0; lane < 4; lane++)
        ActiveEnemyPlaneTraffic(
          movesRight: true,
          speed: 500,
          altitudeLane: lane,
          separationFromSpawn: 100,
          timeUntilExit: 2,
        ),
    ];

    expect(
      chooseSafeEnemyPlaneLane(
        candidateLanes: const [0, 1, 2, 3],
        movesRight: true,
        speed: 500,
        planeWidth: 200,
        activeTraffic: traffic,
      ),
      isNull,
    );
  });
}
