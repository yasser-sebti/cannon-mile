import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DesktopPreview {
  const DesktopPreview({
    required this.width,
    required this.height,
    required this.scale,
  });

  final double width;
  final double height;
  final double scale;

  static DesktopPreview? parse(List<String> args) {
    if (defaultTargetPlatform != TargetPlatform.windows) {
      return null;
    }

    double? width;
    double? height;
    double scale = 1;
    for (final argument in args) {
      if (argument.startsWith('--preview-width=')) {
        width = double.tryParse(argument.substring('--preview-width='.length));
      } else if (argument.startsWith('--preview-height=')) {
        height = double.tryParse(
          argument.substring('--preview-height='.length),
        );
      } else if (argument.startsWith('--preview-scale=')) {
        scale =
            double.tryParse(argument.substring('--preview-scale='.length)) ??
            scale;
      }
    }

    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }

    return DesktopPreview(
      width: width,
      height: height,
      scale: scale.clamp(0.1, 1.0),
    );
  }
}

class DesktopPreviewSurface extends StatelessWidget {
  const DesktopPreviewSurface({
    required this.preview,
    required this.child,
    super.key,
  });

  final DesktopPreview? preview;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final preview = this.preview;
    if (preview == null) {
      return child;
    }

    return ColoredBox(
      color: const Color(0xFF101014),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: preview.width * preview.scale,
          height: preview.height * preview.scale,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: preview.width,
              height: preview.height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
