import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../vision/image_geometry.dart';

Uint8List enhanceImage(Uint8List source, {required bool grayscale}) {
  final decoder = img.findDecoderForData(source);
  final info = decoder?.startDecode(source);
  if (info == null || info.width * info.height > 16 * 1024 * 1024) {
    throw const FormatException('Unsupported image or pixel count');
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) throw const FormatException('Unsupported image format');
  final prepared = normalizeGeometry(decoded);
  if (grayscale) img.grayscale(prepared);
  return img.encodeJpg(prepared, quality: 88);
}
