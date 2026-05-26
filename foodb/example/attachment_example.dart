import 'dart:io';
import 'dart:typed_data';
import 'package:foodb/foodb.dart';
import 'package:path/path.dart' as path;

/// Example demonstrating how to use the attachment API with foodb
void main() async {
  // Example 1: Using attachments with KeyValue adapter
  print('Example 1: KeyValue Adapter with FileSystem Attachment Store');
  
  // Create a KeyValue-based Foodb instance
  final db = Foodb.keyvalue(
    dbName: 'my-database',
    keyValueDb: KeyValueAdapter.inMemory(),
    autoCompaction: false,
  ) as KeyvalueFoodb;
  
  await db.initDb();
  
  // Initialize the attachment store with a directory
  final attachmentDir = path.join(Directory.systemTemp.path, 'foodb_attachments');
  final attachmentStore = FileSystemAttachmentStore(baseDirectory: attachmentDir);
  await attachmentStore.init();
  
  // Set the attachment store for the database
  db.setAttachmentStore(attachmentStore);
  
  // Create a document
  final docId = 'user-123';
  final putResponse = await db.put(doc: Doc(
    id: docId,
    model: {
      'name': 'John Doe',
      'email': 'john@example.com',
    },
  ));
  
  print('Created document: $docId with rev: ${putResponse.rev}');
  
  // Add an attachment to the document
  final imageData = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG header
  await db.putAttachment(
    docId,
    'profile-photo.jpg',
    imageData,
    'image/jpeg',
  );
  
  print('Added attachment: profile-photo.jpg');
  
  // Retrieve the attachment
  final retrievedData = await db.getAttachment(docId, 'profile-photo.jpg');
  if (retrievedData != null) {
    print('Retrieved attachment size: ${retrievedData.length} bytes');
  }
  
  // Delete the attachment
  await db.deleteAttachment(docId, 'profile-photo.jpg', rev: putResponse.rev);
  print('Deleted attachment: profile-photo.jpg');
  
  // Clean up
  await attachmentStore.close();
  await db.destroy();
  
  // Clean up attachment directory
  final dir = Directory(attachmentDir);
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
  
  print('\nExample 1 completed!\n');
  
  // Example 2: Using attachments with CouchDB adapter
  print('Example 2: CouchDB Adapter');
  print('To use attachments with CouchDB adapter:');
  print('''
  
  final couchDb = Foodb.couchdb(
    dbName: 'my-database',
    baseUri: Uri.parse('http://localhost:5984'),
  );
  
  // Create a document first
  final doc = Doc(id: 'doc-1', model: {'key': 'value'});
  final response = await couchDb.put(doc: doc);
  
  // Add an attachment
  final data = Uint8List.fromList('Hello, World!'.codeUnits);
  await couchDb.putAttachment(
    'doc-1',
    'hello.txt',
    data,
    'text/plain',
    rev: response.rev,
  );
  
  // Retrieve the attachment
  final retrieved = await couchDb.getAttachment('doc-1', 'hello.txt');
  
  // Delete the attachment
  await couchDb.deleteAttachment('doc-1', 'hello.txt', rev: response.rev);
  ''');
  
  print('\nExample 2 completed!\n');
  
  // Example 3: Creating a custom attachment store
  print('Example 3: Custom Attachment Store');
  print('You can implement your own AttachmentStore:');
  print('''
  
  class MyCustomAttachmentStore implements AttachmentStore {
    @override
    Future<Uint8List?> getAttachment(String docId, String attachmentName) async {
      // Implement custom logic (e.g., S3, Azure Blob, etc.)
      return null;
    }
    
    @override
    Future<void> putAttachment(
      String docId,
      String attachmentName,
      Uint8List data,
      String contentType,
    ) async {
      // Implement custom logic
    }
    
    @override
    Future<void> deleteAttachment(String docId, String attachmentName) async {
      // Implement custom logic
    }
    
    @override
    Future<void> deleteDocAttachments(String docId) async {
      // Implement custom logic
    }
    
    @override
    Future<void> init() async {
      // Initialize your store
    }
    
    @override
    Future<void> close() async {
      // Clean up
    }
  }
  
  // Use it with KeyvalueFoodb
  final customStore = MyCustomAttachmentStore();
  await customStore.init();
  db.setAttachmentStore(customStore);
  ''');
  
  print('\nAll examples completed!');
}
