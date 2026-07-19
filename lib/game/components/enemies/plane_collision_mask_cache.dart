import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

class PlaneCollisionMaskCache {
  const PlaneCollisionMaskCache({
    required this.planeMask,
    required this.projectileProfiles,
  });

  static const int planeAlphaThreshold = 64;
  static const int projectileAlphaThreshold = 128;

  final SpriteAlphaMask planeMask;
  final List<ProjectileCollisionProfile> projectileProfiles;

  static Future<PlaneCollisionMaskCache> build({
    required ui.Image planeImage,
    required List<ui.Image> projectileImages,
    required List<int> projectileArtworkIndices,
  }) async {
    final planeMask = await SpriteAlphaMask.fromImage(
      planeImage,
      alphaThreshold: planeAlphaThreshold,
    );
    final artworkProfiles = <ProjectileCollisionProfile>[];
    for (final image in projectileImages) {
      artworkProfiles.add(
        await ProjectileCollisionProfile.fromImage(
          image,
          alphaThreshold: projectileAlphaThreshold,
        ),
      );
    }
    return PlaneCollisionMaskCache(
      planeMask: planeMask,
      projectileProfiles: List.unmodifiable([
        for (final artworkIndex in projectileArtworkIndices)
          artworkProfiles[artworkIndex],
      ]),
    );
  }
}

class SpriteAlphaMask {
  const SpriteAlphaMask._({
    required this.width,
    required this.height,
    required this.alphaThreshold,
    required this._solidPixels,
  });

  final int width;
  final int height;
  final int alphaThreshold;
  final Uint8List _solidPixels;

  static Future<SpriteAlphaMask> fromImage(
    ui.Image image, {
    required int alphaThreshold,
  }) async {
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) {
      throw StateError('Unable to read image pixels for collision masking.');
    }
    final bytes = rgba.buffer.asUint8List(
      rgba.offsetInBytes,
      rgba.lengthInBytes,
    );
    final solidPixels = Uint8List(image.width * image.height);
    for (var pixelIndex = 0; pixelIndex < solidPixels.length; pixelIndex++) {
      solidPixels[pixelIndex] = bytes[pixelIndex * 4 + 3] >= alphaThreshold
          ? 1
          : 0;
    }
    return SpriteAlphaMask._(
      width: image.width,
      height: image.height,
      alphaThreshold: alphaThreshold,
      solidPixels: solidPixels,
    );
  }

  bool isSolid(int x, int y) {
    return x >= 0 &&
        x < width &&
        y >= 0 &&
        y < height &&
        _solidPixels[y * width + x] != 0;
  }
}

class ProjectileCollisionProfile {
  const ProjectileCollisionProfile._({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.alphaThreshold,
    required this.boundaryXs,
    required this.boundaryYs,
    required this.centerX,
    required this.centerY,
    required this.boundingRadius,
  });

  final int sourceWidth;
  final int sourceHeight;
  final int alphaThreshold;
  final Float32List boundaryXs;
  final Float32List boundaryYs;

  /// Local source-pixel coordinates relative to the sprite's bottom center.
  final double centerX;
  final double centerY;
  final double boundingRadius;

  int get boundaryPointCount => boundaryXs.length;

  static Future<ProjectileCollisionProfile> fromImage(
    ui.Image image, {
    required int alphaThreshold,
  }) async {
    final mask = await SpriteAlphaMask.fromImage(
      image,
      alphaThreshold: alphaThreshold,
    );
    final boundaryXValues = <double>[];
    final boundaryYValues = <double>[];
    var minimumX = image.width.toDouble();
    var maximumX = 0.0;
    var minimumY = image.height.toDouble();
    var maximumY = 0.0;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (!mask.isSolid(x, y)) {
          continue;
        }
        minimumX = math.min(minimumX, x + 0.5);
        maximumX = math.max(maximumX, x + 0.5);
        minimumY = math.min(minimumY, y + 0.5);
        maximumY = math.max(maximumY, y + 0.5);
        final isBoundary =
            !mask.isSolid(x - 1, y) ||
            !mask.isSolid(x + 1, y) ||
            !mask.isSolid(x, y - 1) ||
            !mask.isSolid(x, y + 1);
        if (isBoundary) {
          boundaryXValues.add(x + 0.5 - image.width / 2);
          boundaryYValues.add(y + 0.5 - image.height);
        }
      }
    }
    if (boundaryXValues.isEmpty) {
      throw StateError(
        'Projectile collision artwork contains no solid pixels.',
      );
    }

    final centerX = (minimumX + maximumX) / 2 - image.width / 2;
    final centerY = (minimumY + maximumY) / 2 - image.height;
    var boundingRadiusSquared = 0.0;
    for (var index = 0; index < boundaryXValues.length; index++) {
      final offsetX = boundaryXValues[index] - centerX;
      final offsetY = boundaryYValues[index] - centerY;
      boundingRadiusSquared = math.max(
        boundingRadiusSquared,
        offsetX * offsetX + offsetY * offsetY,
      );
    }
    return ProjectileCollisionProfile._(
      sourceWidth: image.width,
      sourceHeight: image.height,
      alphaThreshold: alphaThreshold,
      boundaryXs: Float32List.fromList(boundaryXValues),
      boundaryYs: Float32List.fromList(boundaryYValues),
      centerX: centerX,
      centerY: centerY,
      boundingRadius: math.sqrt(boundingRadiusSquared),
    );
  }
}
