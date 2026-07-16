import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_config.dart';

class StageMetrics {
  const StageMetrics({
    required this.scale,
    required this.virtualSize,
    required this.safePadding,
  });

  final double scale;
  final Size virtualSize;
  final EdgeInsets safePadding;

  factory StageMetrics.fromViewport(
    Size viewport, {
    EdgeInsets viewPadding = EdgeInsets.zero,
  }) {
    final safeWidth = viewport.width.isFinite && viewport.width > 0
        ? viewport.width
        : AppConfig.designWidth;
    final safeHeight = viewport.height.isFinite && viewport.height > 0
        ? viewport.height
        : AppConfig.designHeight;
    final scale = math.min(
      safeWidth / AppConfig.designWidth,
      safeHeight / AppConfig.designHeight,
    );
    final virtualWidth = math.max(AppConfig.designWidth, safeWidth / scale);
    final virtualHeight = math.max(AppConfig.designHeight, safeHeight / scale);

    return StageMetrics(
      scale: scale,
      virtualSize: Size(virtualWidth, virtualHeight),
      safePadding: EdgeInsets.fromLTRB(
        viewPadding.left / scale,
        viewPadding.top / scale,
        viewPadding.right / scale,
        viewPadding.bottom / scale,
      ),
    );
  }

  static StageMetrics of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<StageMetricsScope>();
    return scope?.metrics ??
        StageMetrics.fromViewport(MediaQuery.sizeOf(context));
  }
}

class StageMetricsScope extends InheritedWidget {
  const StageMetricsScope({
    required this.metrics,
    required super.child,
    super.key,
  });

  final StageMetrics metrics;

  @override
  bool updateShouldNotify(covariant StageMetricsScope oldWidget) {
    return metrics.scale != oldWidget.metrics.scale ||
        metrics.virtualSize != oldWidget.metrics.virtualSize ||
        metrics.safePadding != oldWidget.metrics.safePadding;
  }
}

class VirtualStage extends StatelessWidget {
  const VirtualStage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = StageMetrics.fromViewport(
          Size(constraints.maxWidth, constraints.maxHeight),
          viewPadding: MediaQuery.viewPaddingOf(context),
        );

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: metrics.virtualSize.width * metrics.scale,
            height: metrics.virtualSize.height * metrics.scale,
            child: FittedBox(
              fit: BoxFit.fill,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: metrics.virtualSize.width,
                height: metrics.virtualSize.height,
                child: StageMetricsScope(
                  metrics: metrics,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: metrics.safePadding,
                      viewPadding: metrics.safePadding,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
