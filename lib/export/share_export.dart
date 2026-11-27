import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareExporter {
  const ShareExporter();

  Future<Directory> _root() async =>
      Directory('${(await getTemporaryDirectory()).path}/optiq-share');

  Future<void> clearInterruptedExports() async {
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
  }

  Future<void> share(String filename, Uint8List pdf, Rect anchor) async {
    final root = await (await _root()).create(recursive: true);
    final directory = await root.createTemp('export-');
    try {
      final basename = filename.replaceAll(RegExp(r'[/\\\x00-\x1f]'), '_');
      final file = await File(
        '${directory.path}/$basename',
      ).writeAsBytes(pdf, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          sharePositionOrigin: anchor,
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  }
}
