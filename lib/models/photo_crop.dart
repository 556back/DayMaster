import 'dart:math' as math;
import 'dart:ui';

/// Shared cover-and-zoom geometry for the editor and the saved photo widget.
class PhotoCrop {
  static Rect sourceRect(
    Size source,
    Size viewport,
    double scale,
    double x,
    double y,
  ) {
    _validateAlignment(Offset(x, y));
    final factor = _coverScale(source, viewport, scale);
    final width = math.min(source.width, viewport.width / factor);
    final height = math.min(source.height, viewport.height / factor);
    return Rect.fromLTWH(
      (source.width - width) * (x + 1) / 2,
      (source.height - height) * (y + 1) / 2,
      width,
      height,
    );
  }

  /// A drag moves the image, so alignment changes opposite to the drag.
  static Offset panAlignment(
    Size source,
    Size viewport,
    double scale,
    Offset alignment,
    Offset delta,
  ) {
    _validateAlignment(alignment);
    if (!delta.dx.isFinite || !delta.dy.isFinite) {
      throw ArgumentError.value(delta, 'delta', 'Must be finite');
    }
    final factor = _coverScale(source, viewport, scale);
    final overflowX = math.max(0.0, source.width * factor - viewport.width);
    final overflowY = math.max(0.0, source.height * factor - viewport.height);
    return Offset(
      overflowX == 0
          ? 0
          : (alignment.dx - 2 * delta.dx / overflowX).clamp(-1, 1),
      overflowY == 0
          ? 0
          : (alignment.dy - 2 * delta.dy / overflowY).clamp(-1, 1),
    );
  }

  /// Keeps the photo point under the initial fingers at their new focal point.
  static Offset transformAlignment(
    Size source,
    Size viewport,
    double startScale,
    Offset startAlignment,
    double nextScale,
    Offset startFocal,
    Offset nextFocal,
  ) {
    if (![
      startFocal.dx,
      startFocal.dy,
      nextFocal.dx,
      nextFocal.dy,
    ].every((value) => value.isFinite)) {
      throw ArgumentError('Photo gesture focal points must be finite');
    }
    final start = sourceRect(
      source,
      viewport,
      startScale,
      startAlignment.dx,
      startAlignment.dy,
    );
    final anchor = Offset(
      start.left + startFocal.dx * start.width / viewport.width,
      start.top + startFocal.dy * start.height / viewport.height,
    );
    final factor = _coverScale(source, viewport, nextScale);
    final overflowX = source.width * factor - viewport.width;
    final overflowY = source.height * factor - viewport.height;
    return Offset(
      overflowX <= 0
          ? 0
          : (2 * (anchor.dx * factor - nextFocal.dx) / overflowX - 1).clamp(
              -1,
              1,
            ),
      overflowY <= 0
          ? 0
          : (2 * (anchor.dy * factor - nextFocal.dy) / overflowY - 1).clamp(
              -1,
              1,
            ),
    );
  }

  static double _coverScale(Size source, Size viewport, double scale) {
    if (![
          source.width,
          source.height,
          viewport.width,
          viewport.height,
        ].every((value) => value.isFinite && value > 0) ||
        !scale.isFinite ||
        scale < 1 ||
        scale > 3) {
      throw ArgumentError('Invalid photo or viewport dimensions or zoom');
    }
    final factor =
        math.max(
          viewport.width / source.width,
          viewport.height / source.height,
        ) *
        scale;
    if (!factor.isFinite ||
        factor <= 0 ||
        !(source.width * factor).isFinite ||
        !(source.height * factor).isFinite) {
      throw ArgumentError('Photo dimensions exceed the supported range');
    }
    return factor;
  }

  static void _validateAlignment(Offset alignment) {
    if (![
      alignment.dx,
      alignment.dy,
    ].every((value) => value.isFinite && value >= -1 && value <= 1)) {
      throw ArgumentError.value(alignment, 'alignment', 'Must be in -1..1');
    }
  }
}
