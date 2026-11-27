import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DocumentCipher {
  DocumentCipher(this._key);

  final Uint8List _key;
  static const _keyName = 'optiq.document-key.v1';

  static Future<DocumentCipher> open({required bool existingVault}) async {
    const store = FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    );
    final saved = await store.read(key: _keyName);
    if (saved != null) return DocumentCipher(base64Decode(saved));
    if (existingVault) throw StateError('The vault key is unavailable.');
    final generated = await AesGcm.with256bits().newSecretKey();
    final bytes = Uint8List.fromList(await generated.extractBytes());
    await store.write(key: _keyName, value: base64Encode(bytes));
    if (await store.read(key: _keyName) != base64Encode(bytes)) {
      throw StateError('The vault key could not be persisted.');
    }
    return DocumentCipher(bytes);
  }

  Future<Uint8List> seal(Uint8List bytes, String context) {
    final key = _key;
    return Isolate.run(() async {
      final box = await AesGcm.with256bits().encrypt(
        bytes,
        secretKey: SecretKey(key),
        aad: utf8.encode(context),
      );
      return Uint8List.fromList(box.concatenation());
    });
  }

  Future<Uint8List> unseal(
    Uint8List bytes,
    String context, {
    bool background = true,
  }) {
    final key = _key;
    Future<Uint8List> decrypt() async => Uint8List.fromList(
      await AesGcm.with256bits().decrypt(
        SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16),
        secretKey: SecretKey(key),
        aad: utf8.encode(context),
      ),
    );
    return background ? Isolate.run(decrypt) : decrypt();
  }
}
