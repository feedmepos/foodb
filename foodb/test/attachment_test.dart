import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:path/path.dart' as path;

void main() {
  group('FileSystemAttachmentStore', () {
    late String testDir;
    late FileSystemAttachmentStore store;

    setUp(() async {
      // Create a temporary directory for tests
      testDir = path.join(Directory.systemTemp.path, 'foodb_attachment_test_${DateTime.now().millisecondsSinceEpoch}');
      store = FileSystemAttachmentStore(baseDirectory: testDir);
      await store.init();
    });

    tearDown(() async {
      await store.close();
      // Clean up test directory
      final dir = Directory(testDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('putAttachment and getAttachment', () async {
      final docId = 'test-doc-1';
      final attachmentName = 'test.txt';
      final data = Uint8List.fromList('Hello, World!'.codeUnits);
      final contentType = 'text/plain';

      // Put attachment
      await store.putAttachment(docId, attachmentName, data, contentType);

      // Get attachment
      final retrieved = await store.getAttachment(docId, attachmentName);
      expect(retrieved, isNotNull);
      expect(retrieved, equals(data));

      // Check content type
      final retrievedContentType = await store.getAttachmentContentType(docId, attachmentName);
      expect(retrievedContentType, equals(contentType));
    });

    test('getAttachment returns null for non-existent attachment', () async {
      final retrieved = await store.getAttachment('non-existent-doc', 'non-existent-attachment');
      expect(retrieved, isNull);
    });

    test('deleteAttachment', () async {
      final docId = 'test-doc-2';
      final attachmentName = 'test.txt';
      final data = Uint8List.fromList('Test data'.codeUnits);

      // Put and verify
      await store.putAttachment(docId, attachmentName, data, 'text/plain');
      var retrieved = await store.getAttachment(docId, attachmentName);
      expect(retrieved, isNotNull);

      // Delete
      await store.deleteAttachment(docId, attachmentName);

      // Verify deleted
      retrieved = await store.getAttachment(docId, attachmentName);
      expect(retrieved, isNull);
    });

    test('deleteDocAttachments', () async {
      final docId = 'test-doc-3';
      final data = Uint8List.fromList('Test data'.codeUnits);

      // Put multiple attachments
      await store.putAttachment(docId, 'attachment1.txt', data, 'text/plain');
      await store.putAttachment(docId, 'attachment2.txt', data, 'text/plain');
      await store.putAttachment(docId, 'attachment3.txt', data, 'text/plain');

      // Verify all exist
      expect(await store.getAttachment(docId, 'attachment1.txt'), isNotNull);
      expect(await store.getAttachment(docId, 'attachment2.txt'), isNotNull);
      expect(await store.getAttachment(docId, 'attachment3.txt'), isNotNull);

      // Delete all attachments for the document
      await store.deleteDocAttachments(docId);

      // Verify all deleted
      expect(await store.getAttachment(docId, 'attachment1.txt'), isNull);
      expect(await store.getAttachment(docId, 'attachment2.txt'), isNull);
      expect(await store.getAttachment(docId, 'attachment3.txt'), isNull);
    });

    test('putAttachment overwrites existing attachment', () async {
      final docId = 'test-doc-4';
      final attachmentName = 'test.txt';
      final data1 = Uint8List.fromList('Original data'.codeUnits);
      final data2 = Uint8List.fromList('Updated data'.codeUnits);

      // Put original
      await store.putAttachment(docId, attachmentName, data1, 'text/plain');
      var retrieved = await store.getAttachment(docId, attachmentName);
      expect(retrieved, equals(data1));

      // Overwrite
      await store.putAttachment(docId, attachmentName, data2, 'text/plain');
      retrieved = await store.getAttachment(docId, attachmentName);
      expect(retrieved, equals(data2));
    });

    test('handles special characters in docId and attachmentName', () async {
      final docId = 'doc:with/special\\chars';
      final attachmentName = 'file:name<with>special|chars';
      final data = Uint8List.fromList('Test data'.codeUnits);

      // Should not throw
      await store.putAttachment(docId, attachmentName, data, 'text/plain');
      final retrieved = await store.getAttachment(docId, attachmentName);
      expect(retrieved, equals(data));
    });
  });

  group('KeyvalueFoodb attachment integration', () {
    late KeyvalueFoodb db;
    late String testDir;
    late FileSystemAttachmentStore attachmentStore;

    setUp(() async {
      testDir = path.join(Directory.systemTemp.path, 'foodb_kv_attachment_test_${DateTime.now().millisecondsSinceEpoch}');
      
      db = Foodb.keyvalue(
        dbName: 'test-db',
        keyValueDb: KeyValueAdapter.inMemory(),
        autoCompaction: false,
      ) as KeyvalueFoodb;
      
      await db.initDb();

      attachmentStore = FileSystemAttachmentStore(baseDirectory: testDir);
      await attachmentStore.init();
      db.setAttachmentStore(attachmentStore);
    });

    tearDown(() async {
      await attachmentStore.close();
      await db.destroy();
      final dir = Directory(testDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('putAttachment requires existing document', () async {
      final data = Uint8List.fromList('Test data'.codeUnits);
      
      // Should throw because document doesn't exist
      expect(
        () => db.putAttachment('non-existent-doc', 'test.txt', data, 'text/plain'),
        throwsA(isA<AdapterException>()),
      );
    });

    test('putAttachment and getAttachment with existing document', () async {
      final docId = 'test-doc';
      final attachmentName = 'test.txt';
      final data = Uint8List.fromList('Test attachment data'.codeUnits);

      // Create a document first
      await db.put(doc: Doc(
        id: docId,
        model: {'message': 'test'},
      ));

      // Put attachment
      await db.putAttachment(docId, attachmentName, data, 'text/plain');

      // Get attachment
      final retrieved = await db.getAttachment(docId, attachmentName);
      expect(retrieved, isNotNull);
      expect(retrieved, equals(data));
    });

    test('deleteAttachment with existing document', () async {
      final docId = 'test-doc-delete';
      final attachmentName = 'test.txt';
      final data = Uint8List.fromList('Test data'.codeUnits);

      // Create a document
      final putResponse = await db.put(doc: Doc(
        id: docId,
        model: {'message': 'test'},
      ));

      // Put attachment
      await db.putAttachment(docId, attachmentName, data, 'text/plain');

      // Verify it exists
      var retrieved = await db.getAttachment(docId, attachmentName);
      expect(retrieved, isNotNull);

      // Delete attachment
      await db.deleteAttachment(docId, attachmentName, rev: putResponse.rev);

      // Verify deleted
      retrieved = await db.getAttachment(docId, attachmentName);
      expect(retrieved, isNull);
    });
  });
}
