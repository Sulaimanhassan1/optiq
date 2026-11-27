import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../capture/image_capture.dart';
import '../core/diagnostics.dart';
import '../documents/document_repository.dart';
import '../export/pdf_export.dart';
import '../export/share_export.dart';
import '../ml/model_policy.dart';
import '../ocr/text_recognition.dart';

typedef ScanDraft = ({XFile photo, String text, String suggestion});
typedef ScanChoice = ({String name, bool grayscale});

class LibraryController extends ChangeNotifier {
  LibraryController({
    required this._openDocuments,
    required this.capture,
    required this.ocr,
    required this.pdf,
    required this.sharing,
    this.personalization,
    this.diagnostics = const Diagnostics(),
  });

  final Future<DocumentRepository> Function() _openDocuments;
  final ImageCapture capture;
  final OcrEngine ocr;
  final PdfExporter pdf;
  final ShareExporter sharing;
  final PersonalizationEngine? personalization;
  final Diagnostics diagnostics;
  DocumentRepository? _documents;
  List<DocumentEntry> entries = const [];
  String? error;
  String? activity;
  bool get ready => _documents != null;
  bool get busy => activity != null;
  bool _disposed = false;

  Future<void> load() => _perform(
    'Loading library',
    'Unable to open your document library.',
    () async {
      final documents = _documents ?? await _openDocuments();
      _documents = documents;
      entries = List.unmodifiable(await documents.list());
    },
  );

  Future<void> scan(
    ImageSource? source,
    Future<ScanChoice?> Function(ScanDraft) review,
  ) => _perform(
    'Preparing scan',
    'Unable to process the scan. Try a smaller JPEG or PNG image.',
    () async {
      final photo = source == null
          ? await capture.recover()
          : await capture.pick(source);
      if (photo == null) return;
      try {
        if (await photo.length() > 24 * 1024 * 1024) {
          throw const FormatException('Image exceeds size limit.');
        }
        final text = await diagnostics.measure(
          'ocr',
          () => ocr.recognize(photo.path),
        );
        final suggestion =
            await personalization?.suggestTitle(text) ?? suggestedName(text);
        if (_disposed) return;
        final decision = await review((
          photo: photo,
          text: text,
          suggestion: suggestion,
        ));
        if (decision == null || _disposed) return;
        activity = 'Saving PDF';
        _notify();
        final bytes = await diagnostics.measure(
          'pdf generation',
          () async => pdf.generate(
            await photo.readAsBytes(),
            grayscale: decision.grayscale,
          ),
        );
        await _documents!.save(
          documentFilename(decision.name, DateTime.now()),
          bytes,
        );
        entries = List.unmodifiable(await _documents!.list());
        if (decision.name != suggestion) {
          try {
            await personalization?.recordCorrection(suggestion, decision.name);
          } catch (error) {
            diagnostics.failure('personalization feedback', error);
          }
        }
      } finally {
        // Image Picker returns app-owned temporary copies on the mobile targets.
        try {
          final file = File(photo.path);
          if (await file.exists()) await file.delete();
        } on FileSystemException catch (error) {
          diagnostics.failure('capture cleanup', error);
        }
      }
    },
  );

  Future<void> share(DocumentEntry entry, Rect anchor) =>
      _perform('Preparing share', 'Unable to share this document.', () async {
        final bytes = await _documents!.read(entry);
        await sharing.share(entry.filename, bytes, anchor);
      });

  Future<void> _perform(
    String label,
    String failure,
    Future<void> Function() run,
  ) async {
    if (busy || _disposed) return;
    activity = label;
    error = null;
    _notify();
    try {
      await diagnostics.measure(label, run);
    } on PlatformException catch (exception) {
      error =
          exception.code.contains('access_denied') ||
              exception.code.contains('access_restricted')
          ? 'Allow camera or photo access in system Settings, then try again.'
          : failure;
    } catch (_) {
      error = failure;
    } finally {
      activity = null;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String suggestedName(String recognized) =>
    recognized
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .firstOrNull ??
    'Document';

String documentFilename(String name, DateTime timestamp) {
  final cleaned = name.replaceAll(RegExp(r'[/\\\x00-\x1f\x7f]'), '_').trim();
  final basename = cleaned.isEmpty || cleaned == '.' || cleaned == '..'
      ? 'Document'
      : cleaned;
  final shortened = String.fromCharCodes(basename.runes.take(55));
  return '${shortened}_${timestamp.millisecondsSinceEpoch}.pdf';
}
