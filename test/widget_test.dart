import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optiq/application/library_controller.dart';
import 'package:optiq/capture/image_capture.dart';
import 'package:optiq/documents/document_repository.dart';
import 'package:optiq/export/pdf_export.dart';
import 'package:optiq/export/share_export.dart';
import 'package:optiq/ocr/text_recognition.dart';
import 'package:optiq/ui/optiq_app.dart';

class _EmptyRepository implements DocumentRepository {
  @override
  Future<List<DocumentEntry>> list() async => [];
  @override
  Future<Uint8List> read(DocumentEntry entry) => throw UnimplementedError();
  @override
  Future<void> save(String filename, Uint8List pdf) =>
      throw UnimplementedError();
}

class _Capture implements ImageCapture {
  @override
  Future<XFile?> pick(ImageSource source) async => null;
  @override
  Future<XFile?> recover() async => null;
}

void main() {
  testWidgets('The library loads and cancelled capture returns to idle', (
    tester,
  ) async {
    final controller = LibraryController(
      openDocuments: () async => _EmptyRepository(),
      capture: _Capture(),
      ocr: const MlKitOcrEngine(),
      pdf: const PdfExporter(),
      sharing: const ShareExporter(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(Optiq(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('No documents yet'), findsOneWidget);
    await tester.tap(find.text('Import image'));
    await tester.pumpAndSettle();
    expect(controller.busy, isFalse);
    expect(controller.error, isNull);
  });
}
