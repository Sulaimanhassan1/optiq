import 'dart:io';

import 'package:image_picker/image_picker.dart';

abstract interface class ImageCapture {
  Future<XFile?> pick(ImageSource source);
  Future<XFile?> recover();
}

class NativeImageCapture implements ImageCapture {
  final _picker = ImagePicker();

  @override
  Future<XFile?> pick(ImageSource source) => _picker.pickImage(
    source: source,
    maxWidth: 2400,
    maxHeight: 2400,
    imageQuality: 92,
    requestFullMetadata: false,
  );

  @override
  Future<XFile?> recover() async {
    if (!Platform.isAndroid) return null;
    final response = await _picker.retrieveLostData();
    if (response.exception case final error?) throw error;
    return response.file;
  }
}
