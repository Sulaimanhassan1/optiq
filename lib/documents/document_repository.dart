import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../security/document_cipher.dart';

typedef DocumentEntry = ({String id, String filename});

abstract interface class DocumentRepository {
  Future<List<DocumentEntry>> list();
  Future<void> save(String filename, Uint8List pdf);
  Future<Uint8List> read(DocumentEntry entry);
}

class SqliteDocuments implements DocumentRepository {
  SqliteDocuments._(this._database, this._cipher);

  final Database _database;
  final DocumentCipher _cipher;
  static const _chunkSize = 256 * 1024;
  static const maxPdfBytes = 24 * 1024 * 1024;

  static Future<SqliteDocuments> open() async {
    final support = await getApplicationSupportDirectory();
    final database = await openDatabase(
      '${support.path}/optiq-vault.sqlite',
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE document ('
          'id TEXT PRIMARY KEY, created INTEGER NOT NULL, title BLOB NOT NULL)',
        );
        await db.execute(
          'CREATE INDEX document_created ON document(created DESC)',
        );
        await db.execute(
          'CREATE TABLE document_chunk ('
          'document_id TEXT NOT NULL REFERENCES document(id) ON DELETE CASCADE, '
          'position INTEGER NOT NULL, payload BLOB NOT NULL, '
          'PRIMARY KEY(document_id, position))',
        );
      },
    );
    try {
      final hasDocuments = (await database.query(
        'document',
        columns: ['id'],
        limit: 1,
      )).isNotEmpty;
      final cipher = await DocumentCipher.open(existingVault: hasDocuments);
      final repository = SqliteDocuments._(database, cipher);
      await repository._migrateLegacy();
      return repository;
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  Future<void> _migrateLegacy() async {
    final root = await getApplicationDocumentsDirectory();
    final legacy = Directory('${root.path}/optiq');
    if (!await legacy.exists()) return;
    await for (final entity in legacy.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.pdf')) continue;
      if (await entity.length() > maxPdfBytes) continue;
      final filename = entity.uri.pathSegments.last;
      final created = await entity.lastModified();
      final bytes = await entity.readAsBytes();
      final digest = await Sha256().hash(bytes);
      final identity = await Sha256().hash(
        utf8.encode('$filename:${base64Encode(digest.bytes)}'),
      );
      final id = 'legacy:${base64UrlEncode(identity.bytes)}';
      await _save(id, filename, bytes, created);
      // Delete only after the encrypted transaction has committed.
      await entity.delete();
    }
  }

  @override
  Future<List<DocumentEntry>> list() async {
    final rows = await _database.query(
      'document',
      columns: ['id', 'title'],
      orderBy: 'created DESC, id DESC',
    );
    return [
      for (final row in rows)
        (
          id: row['id'] as String,
          filename: utf8.decode(
            await _cipher.unseal(
              row['title'] as Uint8List,
              '${row['id']}:title',
              background: false,
            ),
          ),
        ),
    ];
  }

  @override
  Future<void> save(String filename, Uint8List pdf) {
    final created = DateTime.now();
    final nonce = AesGcm.with256bits().newNonce();
    final id = nonce
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return _save(id, filename, pdf, created);
  }

  Future<void> _save(
    String id,
    String filename,
    Uint8List pdf,
    DateTime created,
  ) async {
    if (pdf.length > maxPdfBytes) {
      throw const FormatException('PDF exceeds the vault file limit.');
    }
    final ciphertext = await _cipher.seal(pdf, '$id:pdf');
    final title = await _cipher.seal(
      Uint8List.fromList(utf8.encode(filename)),
      '$id:title',
    );
    await _database.transaction((tx) async {
      if ((await tx.query(
        'document',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
      )).isNotEmpty) {
        return;
      }
      await tx.insert('document', {
        'id': id,
        'created': created.millisecondsSinceEpoch,
        'title': title,
      });
      final batch = tx.batch();
      for (var offset = 0; offset < ciphertext.length; offset += _chunkSize) {
        final end = offset + _chunkSize;
        batch.insert('document_chunk', {
          'document_id': id,
          'position': offset ~/ _chunkSize,
          'payload': Uint8List.sublistView(
            ciphertext,
            offset,
            end < ciphertext.length ? end : ciphertext.length,
          ),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<Uint8List> read(DocumentEntry entry) async {
    final rows = await _database.query(
      'document_chunk',
      columns: ['payload'],
      where: 'document_id = ?',
      whereArgs: [entry.id],
      orderBy: 'position',
    );
    final ciphertext = BytesBuilder(copy: false);
    for (final row in rows) {
      ciphertext.add(row['payload'] as Uint8List);
    }
    return _cipher.unseal(ciphertext.takeBytes(), '${entry.id}:pdf');
  }
}
