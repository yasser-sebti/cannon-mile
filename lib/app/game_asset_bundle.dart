import 'package:flutter/services.dart';

import 'game_asset_bundle_stub.dart'
    if (dart.library.io) 'game_asset_bundle_io.dart'
    as platform;

AssetBundle createGameAssetBundle() => platform.createGameAssetBundle();
