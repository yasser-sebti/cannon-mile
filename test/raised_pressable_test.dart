import 'package:cannon_mile/ui/widgets/raised_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pressableKey = Key('pressable');

Widget _testApp({
  required VoidCallback onTap,
  VoidCallback? onTapFeedback,
  bool enabled = true,
  Duration actionDelay = const Duration(milliseconds: 60),
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: RaisedPressable(
          key: _pressableKey,
          width: 240,
          height: 80,
          radius: BorderRadius.circular(20),
          shadowOffset: 12,
          shadowColor: Colors.black,
          enabled: enabled,
          actionDelay: actionDelay,
          onTapFeedback: onTapFeedback,
          onTap: onTap,
          child: const ColoredBox(color: Colors.orange),
        ),
      ),
    ),
  );
}

double _faceOffset(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.byKey(raisedPressableFaceTransformKey),
  );
  return transform.transform.getTranslation().y;
}

void main() {
  testWidgets('press translates the face and delays the action', (
    tester,
  ) async {
    var taps = 0;
    var feedback = 0;
    await tester.pumpWidget(
      _testApp(onTap: () => taps++, onTapFeedback: () => feedback++),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_pressableKey)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(feedback, 1);
    expect(_faceOffset(tester), closeTo(12, 0.1));

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 59));
    expect(taps, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(taps, 1);
  });

  testWidgets('disabled pressable ignores feedback and actions', (
    tester,
  ) async {
    var taps = 0;
    var feedback = 0;
    await tester.pumpWidget(
      _testApp(
        enabled: false,
        onTap: () => taps++,
        onTapFeedback: () => feedback++,
      ),
    );

    await tester.tap(find.byType(RaisedPressable));
    await tester.pump(const Duration(milliseconds: 100));

    expect(taps, 0);
    expect(feedback, 0);
    expect(_faceOffset(tester), 0);
  });

  testWidgets('cancelled gesture releases without running the action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_testApp(onTap: () => taps++));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(RaisedPressable)),
    );
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 100));

    expect(taps, 0);
    expect(_faceOffset(tester), closeTo(0, 0.1));
  });

  testWidgets('pending delayed action is cancelled on disposal', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _testApp(
        onTap: () => taps++,
        actionDelay: const Duration(milliseconds: 200),
      ),
    );

    await tester.tap(find.byType(RaisedPressable));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));

    expect(taps, 0);
  });
}
