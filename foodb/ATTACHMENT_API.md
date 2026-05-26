# Attachment API

This document describes the attachment API support in foodb, which implements the CouchDB attachment API specification.

## Overview

The attachment API allows you to store binary data (files) associated with documents. This is useful for storing images, PDFs, or any other binary data alongside your JSON documents.

## Architecture

The implementation follows a pluggable architecture:

1. **AttachmentStore Interface**: An abstract interface that defines how attachments are stored and retrieved
2. **FileSystemAttachmentStore**: A default implementation that stores attachments on the file system
3. **KeyvalueFoodb Integration**: Seamless integration with the key-value adapter
4. **CouchDB Adapter Support**: Full support for CouchDB's HTTP attachment API

## Usage

### With KeyValue Adapter

```dart
import 'dart:typed_data';
import 'package:foodb/foodb.dart';

// Create a KeyValue database
final db = Foodb.keyvalue(
  dbName: 'my-database',
  keyValueDb: KeyValueAdapter.inMemory(),
  autoCompaction: false,
) as KeyvalueFoodb;

await db.initDb();

// Initialize and set attachment store
final attachmentStore = FileSystemAttachmentStore(
  baseDirectory: '/path/to/attachments'
);
await attachmentStore.init();
db.setAttachmentStore(attachmentStore);

// Create a document
final response = await db.put(doc: Doc(
  id: 'user-123',
  model: {'name': 'John Doe'},
));

// Add an attachment
final imageData = Uint8List.fromList([...]);
await db.putAttachment(
  'user-123',
  'profile-photo.jpg',
  imageData,
  'image/jpeg',
);

// Retrieve an attachment
final data = await db.getAttachment('user-123', 'profile-photo.jpg');

// Delete an attachment
await db.deleteAttachment(
  'user-123',
  'profile-photo.jpg',
  rev: response.rev,
);
```

### With CouchDB Adapter

The CouchDB adapter uses the standard CouchDB attachment API endpoints:

```dart
final db = Foodb.couchdb(
  dbName: 'my-database',
  baseUri: Uri.parse('http://localhost:5984'),
);

// Create a document
final response = await db.put(doc: Doc(
  id: 'doc-1',
  model: {'key': 'value'},
));

// Add an attachment (requires revision)
await db.putAttachment(
  'doc-1',
  'file.txt',
  Uint8List.fromList('content'.codeUnits),
  'text/plain',
  rev: response.rev,
);

// Get an attachment
final data = await db.getAttachment('doc-1', 'file.txt');

// Delete an attachment (requires revision)
await db.deleteAttachment(
  'doc-1',
  'file.txt',
  rev: response.rev,
);
```

## Custom Attachment Store

You can implement your own attachment store to use cloud storage (S3, Azure Blob, etc.):

```dart
class S3AttachmentStore implements AttachmentStore {
  @override
  Future<Uint8List?> getAttachment(String docId, String attachmentName) async {
    // Download from S3
  }
  
  @override
  Future<void> putAttachment(
    String docId,
    String attachmentName,
    Uint8List data,
    String contentType,
  ) async {
    // Upload to S3
  }
  
  @override
  Future<void> deleteAttachment(String docId, String attachmentName) async {
    // Delete from S3
  }
  
  @override
  Future<void> deleteDocAttachments(String docId) async {
    // Delete all attachments for a document
  }
  
  @override
  Future<void> init() async {
    // Initialize S3 client
  }
  
  @override
  Future<void> close() async {
    // Cleanup
  }
}
```

## API Reference

### Foodb Methods

#### `getAttachment(String docId, String attachmentName)`

Retrieves an attachment from a document.

- **Parameters:**
  - `docId`: The document ID
  - `attachmentName`: The name of the attachment
- **Returns:** `Future<Uint8List?>` - The attachment data, or null if not found

#### `putAttachment(String docId, String attachmentName, Uint8List data, String contentType, {Rev? rev})`

Stores an attachment for a document.

- **Parameters:**
  - `docId`: The document ID
  - `attachmentName`: The name of the attachment
  - `data`: The attachment data as bytes
  - `contentType`: The MIME type of the attachment
  - `rev`: (Optional for KeyValue, Required for CouchDB) The document revision
- **Returns:** `Future<void>`

#### `deleteAttachment(String docId, String attachmentName, {required Rev rev})`

Deletes an attachment from a document.

- **Parameters:**
  - `docId`: The document ID
  - `attachmentName`: The name of the attachment
  - `rev`: The document revision
- **Returns:** `Future<void>`

### AttachmentStore Interface

#### `getAttachment(String docId, String attachmentName)`

Retrieves an attachment.

#### `putAttachment(String docId, String attachmentName, Uint8List data, String contentType)`

Stores an attachment.

#### `deleteAttachment(String docId, String attachmentName)`

Deletes an attachment.

#### `deleteDocAttachments(String docId)`

Deletes all attachments for a document.

#### `init()`

Initializes the attachment store.

#### `close()`

Closes/cleanup the attachment store.

## Implementation Details

### FileSystemAttachmentStore

The default implementation stores attachments in the following structure:

```
baseDirectory/
  ├── {docId}/
  │   ├── {attachmentName}
  │   ├── {attachmentName}.meta (content type)
  │   └── ...
  └── ...
```

- Special characters in document IDs and attachment names are sanitized for file system compatibility
- Content types are stored in `.meta` files alongside the attachment data
- Directory structure is created automatically as needed

### CouchDB Adapter

The CouchDB adapter implements the standard CouchDB attachment API:

- **GET**: `/{db}/{docId}/{attachmentName}` - Retrieve attachment
- **PUT**: `/{db}/{docId}/{attachmentName}?rev={rev}` - Store attachment
- **DELETE**: `/{db}/{docId}/{attachmentName}?rev={rev}` - Delete attachment

## Error Handling

- `AdapterException` is thrown for errors (document not found, attachment not found, etc.)
- For KeyValue adapter, attempting to add an attachment to a non-existent document throws an error
- For CouchDB adapter, revision conflicts are handled according to CouchDB semantics

## Best Practices

1. **Initialize the attachment store** before using attachment methods with KeyValue adapter
2. **Clean up** by calling `close()` on the attachment store when done
3. **Handle revisions** properly, especially with CouchDB adapter
4. **Consider storage limits** when storing large attachments
5. **Use appropriate content types** for proper MIME type handling

## Testing

See `test/attachment_test.dart` for comprehensive test examples.

## Future Enhancements

Possible future improvements:

- Attachment metadata caching
- Compression support
- Chunk-based upload/download for large files
- Attachment synchronization in replication
- Content-addressable storage (deduplicate identical attachments)
