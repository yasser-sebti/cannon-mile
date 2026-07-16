import 'package:cannon_mile/ui/overlays/coming_soon_overlay.dart';
import 'package:cannon_mile/ui/stage/virtual_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StageMetrics preserves the 1920 by 1080 design stage', () {
    final metrics = StageMetrics.fromViewport(const Size(1280, 720));

    expect(metrics.scale, closeTo(2 / 3, 0.0001));
    expect(metrics.virtualSize, const Size(1920, 1080));
  });

  test('StageMetrics exposes extra ultrawide space without distortion', () {
    final metrics = StageMetrics.fromViewport(const Size(2560, 1080));

    expect(metrics.scale, 1);
    expect(metrics.virtualSize, const Size(2560, 1080));
  });

  test('StageMetrics exposes extra height on taller viewports', () {
    final metrics = StageMetrics.fromViewport(
      const Size(1280, 800),
      viewPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
    );

    expect(metrics.scale, closeTo(2 / 3, 0.0001));
    expect(metrics.virtualSize.width, closeTo(1920, 0.0001));
    expect(metrics.virtualSize.height, closeTo(1200, 0.0001));
    expect(metrics.safePadding.left, closeTo(30, 0.0001));
    expect(metrics.safePadding.top, closeTo(15, 0.0001));
  });

  testWidgets('Coming Soon stage does not overflow common landscape sizes', (
    tester,
  ) async {
    for (final size in [
      const Size(1280, 720),
      const Size(1366, 768),
      const Size(1920, 1080),
      const Size(2560, 1080),
      const Size(3440, 1440),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VirtualStage(child: ComingSoonOverlay())),
        ),
      );

      expect(find.text('Coming Soon'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Coming Soon stage accepts landscape safe-area padding', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(1280, 720),
            viewPadding: EdgeInsets.fromLTRB(48, 18, 48, 18),
          ),
          child: Scaffold(body: VirtualStage(child: ComingSoonOverlay())),
        ),
      ),
    );

    final context = tester.element(find.byType(ComingSoonOverlay));
    final metrics = StageMetrics.of(context);
    expect(metrics.safePadding.left, greaterThan(0));
    expect(find.text('Coming Soon'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(null);
  });
}
