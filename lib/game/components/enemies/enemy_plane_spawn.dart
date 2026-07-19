import 'dart:math' as math;

abstract final class EnemyPlaneSpawnTuning {
  static const int altitudeLaneCount = 4;
  static const double shortWaveDelayMinimum = 0.12;
  static const double shortWaveDelayMaximum = 0.28;
  static const double longWaveDelayMinimum = 0.35;
  static const double longWaveDelayMaximum = 0.65;
  static const double burstDelayMinimum = 0.12;
  static const double burstDelayMaximum = 0.30;
  static const double immediateReplacementDelay = 0.06;
  static const double initialMissileDelayMinimum = 0.35;
  static const double initialMissileDelayMaximum = 0.85;
  static const double missileDelayMinimum = 0.65;
  static const double missileDelayMaximum = 1.35;
  static const double minimumSpeed = 280;
  static const double maximumSpeed = 700;
  static const double minimumSameDirectionSpacingInWidths = 1.5;
  static const double blockedSpawnRetryDelay = 0.10;
  static const double oppositeDirectionAltitudeOffset = 12;
  static const int poolCapacity = 20;
}

class EnemyPlaneSpawnSpec {
  const EnemyPlaneSpawnSpec({
    required this.delayAfterPrevious,
    required this.movesRight,
    required this.speed,
    required this.altitudeLane,
  });

  final double delayAfterPrevious;
  final bool movesRight;
  final double speed;
  final int altitudeLane;
}

class ActiveEnemyPlaneTraffic {
  const ActiveEnemyPlaneTraffic({
    required this.movesRight,
    required this.speed,
    required this.altitudeLane,
    required this.separationFromSpawn,
    required this.timeUntilExit,
  });

  final bool movesRight;
  final double speed;
  final int altitudeLane;
  final double separationFromSpawn;
  final double timeUntilExit;
}

class ActiveEnemyPlaneTrafficBuffer {
  ActiveEnemyPlaneTrafficBuffer(int capacity)
    : movesRight = List.filled(capacity, false),
      speeds = List.filled(capacity, 0),
      altitudeLanes = List.filled(capacity, 0),
      separationsFromSpawn = List.filled(capacity, 0),
      timesUntilExit = List.filled(capacity, 0);

  final List<bool> movesRight;
  final List<double> speeds;
  final List<int> altitudeLanes;
  final List<double> separationsFromSpawn;
  final List<double> timesUntilExit;
  int length = 0;

  void clear() {
    length = 0;
  }

  void add({
    required bool movesRight,
    required double speed,
    required int altitudeLane,
    required double separationFromSpawn,
    required double timeUntilExit,
  }) {
    assert(length < speeds.length);
    this.movesRight[length] = movesRight;
    speeds[length] = speed;
    altitudeLanes[length] = altitudeLane;
    separationsFromSpawn[length] = separationFromSpawn;
    timesUntilExit[length] = timeUntilExit;
    length++;
  }
}

int? chooseSafeEnemyPlaneLane({
  required List<int> candidateLanes,
  required bool movesRight,
  required double speed,
  required double planeWidth,
  required Iterable<ActiveEnemyPlaneTraffic> activeTraffic,
  ActiveEnemyPlaneTrafficBuffer? trafficBuffer,
}) {
  final minimumSpacing =
      planeWidth * EnemyPlaneSpawnTuning.minimumSameDirectionSpacingInWidths;
  if (trafficBuffer == null) {
    for (final lane in candidateLanes) {
      var isSafe = true;
      for (final activePlane in activeTraffic) {
        if (!_isPlaneTrafficSafe(
          activePlaneMovesRight: activePlane.movesRight,
          activePlaneSpeed: activePlane.speed,
          activePlaneLane: activePlane.altitudeLane,
          activePlaneSeparation: activePlane.separationFromSpawn,
          activePlaneTimeUntilExit: activePlane.timeUntilExit,
          requestedMovesRight: movesRight,
          requestedSpeed: speed,
          requestedLane: lane,
          minimumSpacing: minimumSpacing,
        )) {
          isSafe = false;
          break;
        }
      }
      if (isSafe) {
        return lane;
      }
    }
    return null;
  }

  for (final lane in candidateLanes) {
    var isSafe = true;
    for (var index = 0; index < trafficBuffer.length; index++) {
      if (!_isPlaneTrafficSafe(
        activePlaneMovesRight: trafficBuffer.movesRight[index],
        activePlaneSpeed: trafficBuffer.speeds[index],
        activePlaneLane: trafficBuffer.altitudeLanes[index],
        activePlaneSeparation: trafficBuffer.separationsFromSpawn[index],
        activePlaneTimeUntilExit: trafficBuffer.timesUntilExit[index],
        requestedMovesRight: movesRight,
        requestedSpeed: speed,
        requestedLane: lane,
        minimumSpacing: minimumSpacing,
      )) {
        isSafe = false;
        break;
      }
    }
    if (isSafe) {
      return lane;
    }
  }
  return null;
}

bool _isPlaneTrafficSafe({
  required bool activePlaneMovesRight,
  required double activePlaneSpeed,
  required int activePlaneLane,
  required double activePlaneSeparation,
  required double activePlaneTimeUntilExit,
  required bool requestedMovesRight,
  required double requestedSpeed,
  required int requestedLane,
  required double minimumSpacing,
}) {
  if (activePlaneMovesRight != requestedMovesRight ||
      activePlaneLane != requestedLane) {
    return true;
  }
  final predictedMinimumSeparation = requestedSpeed <= activePlaneSpeed
      ? activePlaneSeparation
      : activePlaneSeparation -
            (requestedSpeed - activePlaneSpeed) * activePlaneTimeUntilExit;
  return activePlaneSeparation >= minimumSpacing &&
      predictedMinimumSeparation >= minimumSpacing;
}

List<EnemyPlaneSpawnSpec> createEnemyPlaneWave(math.Random random) {
  final countRoll = random.nextDouble();
  final planeCount = countRoll < 0.40
      ? 2
      : countRoll < 0.82
      ? 3
      : 4;
  final useShortDelay = random.nextDouble() < 0.80;
  final firstDelay = useShortDelay
      ? _randomBetween(
          random,
          EnemyPlaneSpawnTuning.shortWaveDelayMinimum,
          EnemyPlaneSpawnTuning.shortWaveDelayMaximum,
        )
      : _randomBetween(
          random,
          EnemyPlaneSpawnTuning.longWaveDelayMinimum,
          EnemyPlaneSpawnTuning.longWaveDelayMaximum,
        );
  final altitudeLanes = List<int>.generate(
    EnemyPlaneSpawnTuning.altitudeLaneCount,
    (index) => index,
  )..shuffle(random);

  return [
    for (var index = 0; index < planeCount; index++)
      EnemyPlaneSpawnSpec(
        delayAfterPrevious: index == 0
            ? firstDelay
            : _randomBetween(
                random,
                EnemyPlaneSpawnTuning.burstDelayMinimum,
                EnemyPlaneSpawnTuning.burstDelayMaximum,
              ),
        movesRight: random.nextBool(),
        speed: _randomBetween(
          random,
          EnemyPlaneSpawnTuning.minimumSpeed,
          EnemyPlaneSpawnTuning.maximumSpeed,
        ),
        altitudeLane: altitudeLanes[index],
      ),
  ];
}

double _randomBetween(math.Random random, double minimum, double maximum) {
  return minimum + (maximum - minimum) * random.nextDouble();
}
