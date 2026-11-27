import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'application/library_controller.dart';
import 'capture/image_capture.dart';
import 'core/diagnostics.dart';
import 'documents/document_repository.dart';
import 'export/pdf_export.dart';
import 'export/share_export.dart';
import 'ocr/text_recognition.dart';
import 'ui/optiq_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) =>
      debugPrint('Optiq UI error (${details.exception.runtimeType})');
  PlatformDispatcher.instance.onError = (error, _) {
    debugPrint('Optiq uncaught error (${error.runtimeType})');
    return true;
  };
  const diagnostics = Diagnostics();
  const sharing = ShareExporter();
  runApp(
    Optiq(
      controller: LibraryController(
        openDocuments: () async {
          await diagnostics.measure(
            'export cleanup',
            sharing.clearInterruptedExports,
          );
          return SqliteDocuments.open();
        },
        capture: NativeImageCapture(),
        ocr: const MlKitOcrEngine(),
        pdf: const PdfExporter(),
        sharing: sharing,
        diagnostics: diagnostics,
      ),
    ),
  );
}
