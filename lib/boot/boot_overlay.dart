import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_config.dart';
import '../game/cannon_mile_game.dart';
import '../game/game_loading_progress.dart';
import 'boot_controller.dart';

class BootTimings {
  const BootTimings({
    required this.logoPop,
    required this.loadingDelay,
    required this.progressSettle,
    required this.completedHold,
    required this.fadeOut,
  });

  static const production = BootTimings(
    logoPop: AppConfig.logoPopDuration,
    loadingDelay: AppConfig.loadingDelay,
    progressSettle: AppConfig.progressSettleDuration,
    completedHold: AppConfig.completedHoldDuration,
    fadeOut: AppConfig.loadingFadeDuration,
  );

  static const instant = BootTimings(
    logoPop: Duration.zero,
    loadingDelay: Duration.zero,
    progressSettle: Duration.zero,
    completedHold: Duration.zero,
    fadeOut: Duration.zero,
  );

  final Duration logoPop;
  final Duration loadingDelay;
  final Duration progressSettle;
  final Duration completedHold;
  final Duration fadeOut;
}

class BootOverlay extends StatefulWidget {
  const BootOverlay({
    required this.game,
    required this.onFinished,
    this.onLoadingStarted,
    this.tasks,
    this.timings = BootTimings.production,
    super.key,
  });

  final CannonMileGame game;
  final VoidCallback onFinished;
  final VoidCallback? onLoadingStarted;
  final List<BootTask>? tasks;
  final BootTimings timings;

  @override
  State<BootOverlay> createState() => _BootOverlayState();
}

class _BootOverlayState extends State<BootOverlay>
    with SingleTickerProviderStateMixin {
  static const double _minLogoWidth = 340;
  static const double _maxLogoWidth = 720;
  static const double _logoWidthFactor = 0.44;
  static const double _minHorizontalInset = 54;
  static const double _horizontalInsetFactor = 0.07;
  static const double _bottomInsetFactor = 0.075;
  static const double _minBottomInset = 72;

  late final AnimationController _fadeController;
  late BootProgress _progress;
  bool _loadingStarted = false;

  int get _taskCount =>
      widget.tasks?.length ?? widget.game.loadingProgress.value.total;

  @override
  void initState() {
    super.initState();
    _progress = widget.tasks == null
        ? _bootProgressForGame(widget.game.loadingProgress.value)
        : BootProgress(completed: 0, total: _taskCount, label: 'Preparing');
    if (widget.tasks == null) {
      widget.game.loadingProgress.addListener(_handleGameProgress);
    }
    _fadeController = AnimationController(
      vsync: this,
      duration: widget.timings.fadeOut,
      value: 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_runBootSequence());
      }
    });
  }

  Future<void> _runBootSequence() async {
    await _delay(widget.timings.logoPop + widget.timings.loadingDelay);
    if (!mounted) {
      return;
    }

    setState(() {
      _loadingStarted = true;
    });
    widget.onLoadingStarted?.call();
    await WidgetsBinding.instance.endOfFrame;
    await _delay(widget.timings.progressSettle);
    if (!mounted) {
      return;
    }

    if (widget.tasks == null) {
      await precacheImage(const AssetImage(AppConfig.brandingAsset), context);
      await widget.game.initialized;
      await WidgetsBinding.instance.endOfFrame;
    } else {
      final controller = BootController(
        tasks: widget.tasks!,
        onProgress: _handleProgress,
      );
      await controller.run();
      await widget.game.initialized;
      await WidgetsBinding.instance.endOfFrame;
    }
    await _delay(widget.timings.completedHold);
    if (!mounted) {
      return;
    }

    await _fadeController.reverse();
    if (mounted) {
      widget.onFinished();
    }
  }

  Future<void> _delay(Duration duration) {
    if (duration == Duration.zero) {
      return Future<void>.value();
    }
    return Future<void>.delayed(duration);
  }

  void _handleGameProgress() {
    _handleProgress(_bootProgressForGame(widget.game.loadingProgress.value));
  }

  BootProgress _bootProgressForGame(GameLoadingProgress progress) {
    return BootProgress(
      completed: progress.completed,
      total: progress.total,
      label: progress.label,
    );
  }

  void _handleProgress(BootProgress progress) {
    if (mounted) {
      setState(() {
        _progress = progress;
      });
    }
  }

  @override
  void dispose() {
    if (widget.tasks == null) {
      widget.game.loadingProgress.removeListener(_handleGameProgress);
    }
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      key: const Key('boot_overlay'),
      opacity: _fadeController,
      child: ColoredBox(
        color: AppConfig.backgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth = _finiteDimension(
              constraints.maxWidth,
              AppConfig.designWidth,
            );
            final viewportHeight = _finiteDimension(
              constraints.maxHeight,
              AppConfig.designHeight,
            );
            final horizontalInset = _fitDimension(
              preferred: viewportWidth * _horizontalInsetFactor,
              min: _minHorizontalInset,
              max: 120,
              available: viewportWidth * 0.22,
            );
            final bottomInset = _fitDimension(
              preferred: viewportHeight * _bottomInsetFactor,
              min: _minBottomInset,
              max: 180,
              available: viewportHeight * 0.18,
            );
            final availableWidth = math.max(
              0.0,
              viewportWidth - horizontalInset * 2,
            );
            final logoWidth = _fitDimension(
              preferred: viewportWidth * _logoWidthFactor,
              min: _minLogoWidth,
              max: _maxLogoWidth,
              available: availableWidth,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.78, end: 1),
                    duration: widget.timings.logoPop,
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      final opacity = ((value - 0.78) / 0.22).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: opacity,
                        child: Transform.scale(scale: value, child: child),
                      );
                    },
                    child: Image.asset(
                      AppConfig.brandingAsset,
                      key: const Key('orange_hat_boy_logo'),
                      width: logoWidth,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Boot logo failed to load: $error');
                        return SizedBox(width: logoWidth);
                      },
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalInset,
                        0,
                        horizontalInset,
                        bottomInset,
                      ),
                      child: AnimatedOpacity(
                        opacity: _loadingStarted ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: BootProgressBar(
                          progress: _progress,
                          availableWidth: availableWidth,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class BootProgressBar extends StatelessWidget {
  const BootProgressBar({
    required this.progress,
    required this.availableWidth,
    super.key,
  });

  final BootProgress progress;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.fraction;
    final safeAvailableWidth = _finiteDimension(availableWidth, 360);
    final barWidth = _fitDimension(
      preferred: safeAvailableWidth * 0.82,
      min: 260,
      max: 760,
      available: safeAvailableWidth,
    );
    final barHeight = _fitDimension(
      preferred: barWidth * 0.046,
      min: 14,
      max: 30,
      available: 30,
    );
    final percentSize = _fitDimension(
      preferred: barWidth * 0.073,
      min: 20,
      max: 44,
      available: barWidth * 0.12,
    );
    final labelSize = _fitDimension(
      preferred: barWidth * 0.052,
      min: 14,
      max: 30,
      available: barWidth * 0.09,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: fraction),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, displayedFraction, child) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: barWidth,
              height: barHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppConfig.primaryTextColor.withValues(alpha: 0.16),
                  border: Border.all(
                    color: AppConfig.primaryTextColor.withValues(alpha: 0.22),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    key: const Key('boot_progress_fill'),
                    widthFactor: displayedFraction,
                    heightFactor: 1,
                    child: const ColoredBox(color: AppConfig.progressColor),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: barHeight * 1.15),
          Text(
            '${(displayedFraction * 100).round()}%',
            key: const Key('boot_progress_percent'),
            style: TextStyle(
              color: AppConfig.primaryTextColor.withValues(alpha: 0.72),
              fontSize: percentSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: barHeight * 0.45),
          Text(
            progress.label,
            key: const Key('boot_progress_label'),
            style: TextStyle(
              color: AppConfig.primaryTextColor.withValues(alpha: 0.56),
              fontSize: labelSize,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

double _finiteDimension(double value, double fallback) {
  if (value.isFinite && value > 0) {
    return value;
  }
  return fallback;
}

double _fitDimension({
  required double preferred,
  required double min,
  required double max,
  required double available,
}) {
  final safeAvailable = _finiteDimension(available, max);
  final safeMax = math.max(0.0, math.min(max, safeAvailable));
  if (safeMax <= 0) {
    return 0.0;
  }
  final safeMin = math.min(math.max(0.0, min), safeMax);
  final safePreferred = _finiteDimension(preferred, safeMin);
  return safePreferred.clamp(safeMin, safeMax).toDouble();
}
