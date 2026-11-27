import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:optiq/application/library_controller.dart';
import 'package:optiq/export/pdf_export.dart';
import 'package:optiq/ml/model_policy.dart';
import 'package:optiq/security/document_cipher.dart';

void main() {
  test('Filename uses the first populated line and removes separators', () {
    expect(suggestedName('\r\n  Invoice\r\nNumber 1'), 'Invoice');
    expect(
      documentFilename('../résumé', DateTime.fromMillisecondsSinceEpoch(4)),
      '.._résumé_4.pdf',
    );
  });

  test(
    'Vault round trips bytes and rejects modified ciphertext and context',
    () async {
      final cipher = DocumentCipher(Uint8List(32));
      final bytes = Uint8List.fromList([1, 2, 3]);
      final sealed = await cipher.seal(bytes, 'id:pdf');
      expect(await cipher.unseal(sealed, 'id:pdf'), bytes);
      await expectLater(
        cipher.unseal(sealed, 'another:pdf'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      sealed[12] ^= 1;
      await expectLater(
        cipher.unseal(sealed, 'id:pdf'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );

  test('PDF export encodes a real grayscale image', () async {
    final pixels = img.Image(width: 30, height: 20);
    final bytes = await const PdfExporter().generate(
      img.encodePng(pixels),
      grayscale: true,
    );
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
  });

  test(
    'Model policy accepts only authentic, newer compatible artifacts',
    () async {
      final algorithm = Ed25519();
      final key = await algorithm.newKeyPair();
      final policy = ModelUpdatePolicy(
        publicKey: await key.extractPublicKey(),
        runtime: 1,
      );
      final artifact = Uint8List.fromList([1, 2, 3]);
      final hash = (await Sha256().hash(
        artifact,
      )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final signature = await algorithm.sign(
        utf8.encode(jsonEncode(['titles', 2, 1, hash])),
        keyPair: key,
      );
      Future<bool> accepts(int current, Uint8List bytes) => policy.accepts(
        candidate: (id: 'titles', version: 2, runtime: 1, sha256: hash),
        modelId: 'titles',
        highestAcceptedVersion: current,
        artifact: bytes,
        signature: Uint8List.fromList(signature.bytes),
      );
      expect(await accepts(1, artifact), isTrue);
      expect(await accepts(2, artifact), isFalse);
      expect(await accepts(1, Uint8List(3)), isFalse);
    },
  );
}
