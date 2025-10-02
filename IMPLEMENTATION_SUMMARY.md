# Implementation Summary: CouchDB Attachment API Support

## Overview

This implementation adds comprehensive support for the CouchDB attachment API to the foodb library, following the approach used by PouchDB for handling attachments in key-value stores.

## What Was Implemented

### 1. Abstract AttachmentStore Interface (`attachment_store.dart`)

Created an abstract interface that defines how attachments are stored and retrieved:

```dart
abstract class AttachmentStore {
  Future<Uint8List?> getAttachment(String docId, String attachmentName);
  Future<void> putAttachment(String docId, String attachmentName, Uint8List data, String contentType);
  Future<void> deleteAttachment(String docId, String attachmentName);
  Future<void> deleteDocAttachments(String docId);
  Future<void> init();
  Future<void> close();
}
```

This allows for pluggable storage backends (filesystem, S3, Azure Blob, etc.).

### 2. FileSystemAttachmentStore Implementation (`src/file_system_attachment_store.dart`)

Implemented a default attachment store using Dart's native file system:

- Stores attachments in: `{baseDir}/{docId}/{attachmentName}`
- Stores content type metadata in: `{attachmentName}.meta`
- Sanitizes document IDs and attachment names for filesystem compatibility
- Handles special characters safely
- Creates directory structure automatically

### 3. Foodb Abstract Class Updates (`foodb.dart`)

Added three new abstract methods to the Foodb interface:

```dart
Future<Uint8List?> getAttachment(String docId, String attachmentName);
Future<void> putAttachment(String docId, String attachmentName, Uint8List data, String contentType, {Rev? rev});
Future<void> deleteAttachment(String docId, String attachmentName, {required Rev rev});
```

### 4. CouchDB Adapter Implementation (`src/couchdb.dart`)

Implemented full CouchDB HTTP attachment API support:

- **GET** `/{db}/{docId}/{attachmentName}` - Retrieve attachment
- **PUT** `/{db}/{docId}/{attachmentName}?rev={rev}` - Store attachment  
- **DELETE** `/{db}/{docId}/{attachmentName}?rev={rev}` - Delete attachment

Follows CouchDB conventions including:
- Revision handling
- Proper HTTP status codes
- Content-Type headers
- Error handling via AdapterException

### 5. KeyValue Adapter Implementation (`src/key_value/key_value_attachment.dart`)

Created a mixin `_KeyValueAttachment` that:

- Integrates with the AttachmentStore interface
- Validates document existence before attachment operations
- Provides `setAttachmentStore()` method to configure the store
- Throws helpful errors if attachment store is not initialized

### 6. WebSocket Adapter Stubs (`src/websocket.dart`)

Added stub implementations that throw `UnimplementedError` with clear messages, allowing the API to be defined while deferring WebSocket-specific implementation.

### 7. Comprehensive Tests (`test/attachment_test.dart`)

Created extensive test coverage including:

- FileSystemAttachmentStore unit tests
  - Put and get attachments
  - Delete attachments
  - Delete all document attachments
  - Overwrite existing attachments
  - Handle special characters in IDs
  - Content type persistence

- KeyvalueFoodb integration tests
  - Document existence validation
  - Attachment CRUD operations with documents
  - Error handling

### 8. Documentation and Examples

- **ATTACHMENT_API.md**: Comprehensive API documentation with usage examples
- **example/attachment_example.dart**: Working code examples for:
  - KeyValue adapter usage
  - CouchDB adapter usage
  - Custom attachment store implementation

## Architecture Design

The implementation follows a clean, extensible architecture:

```
┌─────────────────────────────────────┐
│         Foodb Abstract              │
│  (getAttachment, putAttachment,     │
│   deleteAttachment methods)         │
└─────────┬─────────────┬─────────────┘
          │             │
          │             │
┌─────────▼──────┐ ┌───▼──────────────────┐
│  CouchDB       │ │  KeyvalueFoodb       │
│  Adapter       │ │  + _KeyValueAttachment│
│  (HTTP API)    │ │      mixin           │
└────────────────┘ └──────┬───────────────┘
                          │
                          │ uses
                          │
                  ┌───────▼─────────────┐
                  │ AttachmentStore     │
                  │   (interface)       │
                  └───────┬─────────────┘
                          │
              ┌───────────┴───────────┐
              │                       │
    ┌─────────▼─────────────┐ ┌──────▼─────────┐
    │FileSystemAttachment   │ │Custom Store    │
    │Store                  │ │(S3, Azure, etc)│
    └───────────────────────┘ └────────────────┘
```

## Key Design Decisions

1. **Pluggable Architecture**: Abstract AttachmentStore allows users to implement custom storage backends
2. **Default Implementation**: FileSystemAttachmentStore provides a working solution out of the box
3. **Separation of Concerns**: Attachment storage is separate from document storage in KeyValue adapter
4. **CouchDB Compatibility**: CouchDB adapter follows standard HTTP API exactly
5. **Type Safety**: Uses Uint8List for binary data throughout
6. **Error Handling**: Consistent error handling via AdapterException

## Usage Example

```dart
// Create a KeyValue database
final db = Foodb.keyvalue(
  dbName: 'my-db',
  keyValueDb: KeyValueAdapter.inMemory(),
) as KeyvalueFoodb;

await db.initDb();

// Set up attachment store
final store = FileSystemAttachmentStore(baseDirectory: '/tmp/attachments');
await store.init();
db.setAttachmentStore(store);

// Create document and add attachment
await db.put(doc: Doc(id: 'doc-1', model: {'key': 'value'}));
await db.putAttachment('doc-1', 'file.txt', data, 'text/plain');

// Retrieve attachment
final data = await db.getAttachment('doc-1', 'file.txt');
```

## Benefits

1. **Standards Compliant**: Follows CouchDB attachment API specification
2. **Flexible**: Supports both CouchDB HTTP and KeyValue adapters
3. **Extensible**: Easy to add custom storage backends
4. **Well Tested**: Comprehensive test coverage
5. **Well Documented**: Clear documentation and examples
6. **Type Safe**: Strong typing throughout
7. **Error Handling**: Proper error messages and exception handling

## Files Changed

- `foodb/lib/attachment_store.dart` (NEW) - Abstract interface
- `foodb/lib/src/file_system_attachment_store.dart` (NEW) - Default implementation
- `foodb/lib/src/key_value/key_value_attachment.dart` (NEW) - KeyValue mixin
- `foodb/lib/foodb.dart` (MODIFIED) - Added abstract methods and exports
- `foodb/lib/src/couchdb.dart` (MODIFIED) - HTTP API implementation
- `foodb/lib/src/websocket.dart` (MODIFIED) - Stub implementation
- `foodb/test/attachment_test.dart` (NEW) - Comprehensive tests
- `foodb/example/attachment_example.dart` (NEW) - Usage examples
- `foodb/ATTACHMENT_API.md` (NEW) - API documentation

## Future Enhancements

Possible improvements for future versions:

1. Attachment metadata caching
2. Compression support
3. Chunked upload/download for large files
4. Attachment synchronization during replication
5. Content-addressable storage for deduplication
6. Attachment indexing and search
