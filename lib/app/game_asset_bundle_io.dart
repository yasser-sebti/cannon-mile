import 'dart:io';

import 'package:flutter/services.dart';

AssetBundle createGameAssetBundle() {
  if (!Platform.isWindows) {
    return rootBundle;
  }

  final executableDirectory = File(Platform.resolvedExecutable).parent;
  return ResilientWindowsAssetBundle(
    primary: rootBundle,
    assetDirectory: Directory(
      '${executableDirectory.path}${Platform.pathSeparator}'
      'data${Platform.pathSeparator}flutter_assets',
    ),
  );
}

class ResilientWindowsAssetBundle extends CachingAssetBundle {
  ResilientWindowsAssetBundle({
    required this.primary,
    required this.assetDirectory,
  });

  final AssetBundle primary;
  final Directory assetDirectory;

  @override
  Future<ByteData> load(String key) async {
    Object? primaryError;
    StackTrace? primaryStackTrace;
    try {
      return await primary.load(key);
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    }

    try {
      final file = File(_filePathForAssetKey(key));
      final bytes = await file.readAsBytes();
      return ByteData.sublistView(bytes);
    } catch (_) {
      Error.throwWithStackTrace(primaryError, primaryStackTrace);
    }
  }

  String _filePathForAssetKey(String key) {
    final segments = key.split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw ArgumentError.value(key, 'key', 'Invalid Flutter asset key');
    }

    final encodedPath = segments
        .map(Uri.encodeComponent)
        .join(Platform.pathSeparator);
    return '${assetDirectory.path}${Platform.pathSeparator}$encodedPath';
  }
}
