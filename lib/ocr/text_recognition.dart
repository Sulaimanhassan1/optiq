import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

abstract interface class OcrEngine {
  Future<String> recognize(String path);
}

class MlKitOcrEngine implements OcrEngine {
  const MlKitOcrEngine();

  @override
  Future<String> recognize(String path) async {
    final engine = TextRecognizer();
    try {
      return (await engine.processImage(InputImage.fromFilePath(path))).text;
    } finally {
      await engine.close();
    }
  }
}
