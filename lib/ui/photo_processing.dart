import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

const maxPhotoInputBytes = 20 * 1024 * 1024;
const maxPhotoBytes = 1024 * 1024;
const maxPhotoDimension = 1200;

Future<String> prepareEventPhoto(Uint8List bytes) async {
  if (bytes.isEmpty) {
    throw Exception('照片未能读取，请重新选择。');
  }
  if (bytes.length > maxPhotoInputBytes) {
    throw Exception('照片超过 20 MB，请选择较小的图片。');
  }
  var qualityScale = 1.0;
  for (var attempt = 0; attempt < 8; attempt++) {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (width, height) {
        final scale =
            math.min(1.0, maxPhotoDimension / math.max(width, height)) *
            qualityScale;
        return ui.TargetImageSize(
          width: (width * scale).round().clamp(1, maxPhotoDimension),
          height: (height * scale).round().clamp(1, maxPhotoDimension),
        );
      },
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data != null && data.lengthInBytes <= maxPhotoBytes) {
          return base64Encode(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        }
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
    qualityScale *= .75;
  }
  throw Exception('照片无法缩小到 1 MB，请换一张图片。');
}
