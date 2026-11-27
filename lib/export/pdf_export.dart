import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pdf;

import '../enhancement/image_enhancer.dart';

class PdfExporter {
  const PdfExporter();

  Future<Uint8List> generate(Uint8List image, {required bool grayscale}) =>
      Isolate.run(() async {
        final prepared = enhanceImage(image, grayscale: grayscale);
        final document = pdf.Document();
        document.addPage(
          pdf.Page(
            build: (_) => pdf.Center(
              child: pdf.Image(
                pdf.MemoryImage(prepared),
                fit: pdf.BoxFit.contain,
              ),
            ),
          ),
        );
        return document.save();
      });
}
