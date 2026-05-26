import 'dart:typed_data';

/// Abstract interface for attachment storage
/// Similar to PouchDB's attachment handling approach
abstract class AttachmentStore {
  /// Get an attachment by document ID and attachment name
  /// Returns the attachment data as bytes, or null if not found
  Future<Uint8List?> getAttachment(String docId, String attachmentName);

  /// Put/store an attachment for a document
  /// @param docId - the document ID
  /// @param attachmentName - the name of the attachment
  /// @param data - the attachment data as bytes
  /// @param contentType - the MIME type of the attachment
  Future<void> putAttachment(
    String docId,
    String attachmentName,
    Uint8List data,
    String contentType,
  );

  /// Delete an attachment
  Future<void> deleteAttachment(String docId, String attachmentName);

  /// Delete all attachments for a document
  Future<void> deleteDocAttachments(String docId);

  /// Initialize the attachment store
  Future<void> init();

  /// Close/cleanup the attachment store
  Future<void> close();
}
