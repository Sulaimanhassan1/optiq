import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// A personalization engine is supplied by a real on-device runtime/model.
abstract interface class PersonalizationEngine {
  Future<String?> suggestTitle(String recognizedText);
  Future<void> recordCorrection(String suggestedTitle, String chosenTitle);
}

typedef ModelManifest = ({String id, int version, int runtime, String sha256});

/// Verifies a candidate before a caller stages it for explicit activation.
class ModelUpdatePolicy {
  const ModelUpdatePolicy({required this.publicKey, required this.runtime});

  final SimplePublicKey publicKey;
  final int runtime;

  Future<bool> accepts({
    required ModelManifest candidate,
    required String modelId,
    required int highestAcceptedVersion,
    required Uint8List artifact,
    required Uint8List signature,
  }) async {
    if (candidate.id != modelId ||
        candidate.version <= highestAcceptedVersion ||
        candidate.runtime != runtime ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(candidate.sha256)) {
      return false;
    }
    final hash = await Sha256().hash(artifact);
    final digest = hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    if (digest != candidate.sha256) return false;
    final manifest = utf8.encode(
      jsonEncode([
        candidate.id,
        candidate.version,
        candidate.runtime,
        candidate.sha256,
      ]),
    );
    return Ed25519().verify(
      manifest,
      signature: Signature(signature, publicKey: publicKey),
    );
  }
}
