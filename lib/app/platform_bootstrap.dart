import 'package:display_mode/display_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<void> configurePlatformForGame() async {
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await restoreImmersiveGameUi();
  await _requestHighRefreshRate();
}

Future<void> restoreImmersiveGameUi() async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      systemNavigationBarColor: Color(0x00000000),
      systemNavigationBarDividerColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

Future<void> _requestHighRefreshRate() async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } on PlatformException catch (error) {
    debugPrint('High refresh rate unavailable: ${error.code}');
  } catch (error) {
    debugPrint('High refresh rate request failed: $error');
  }
}
