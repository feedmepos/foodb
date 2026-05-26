part of 'package:foodb/foodb.dart';

mixin _KeyValueAttachment on _AbstractKeyValue {
  AttachmentStore? _attachmentStore;

  /// Set the attachment store to use for this database
  void setAttachmentStore(AttachmentStore store) {
    _attachmentStore = store;
  }

  /// Get the attachment store, throwing if not initialized
  AttachmentStore get attachmentStore {
    if (_attachmentStore == null) {
      throw AdapterException(
        error: 'Attachment store not initialized',
        reason: 'Call setAttachmentStore() before using attachment methods',
      );
    }
    return _attachmentStore!;
  }

  @override
  Future<Uint8List?> getAttachment(String docId, String attachmentName) async {
    return await attachmentStore.getAttachment(docId, attachmentName);
  }

  @override
  Future<void> putAttachment(
    String docId,
    String attachmentName,
    Uint8List data,
    String contentType,
    {Rev? rev}
  ) async {
    // Verify the document exists
    try {
      await get<Map<String, dynamic>>(
        id: docId,
        fromJsonT: (json) => json as Map<String, dynamic>,
      );
    } catch (e) {
      throw AdapterException(
        error: 'Document not found',
        reason: 'Cannot add attachment to non-existent document',
      );
    }

    await attachmentStore.putAttachment(docId, attachmentName, data, contentType);
  }

  @override
  Future<void> deleteAttachment(
    String docId,
    String attachmentName,
    {required Rev rev}
  ) async {
    // Verify the document exists
    try {
      await get<Map<String, dynamic>>(
        id: docId,
        fromJsonT: (json) => json as Map<String, dynamic>,
      );
    } catch (e) {
      throw AdapterException(
        error: 'Document not found',
        reason: 'Cannot delete attachment from non-existent document',
      );
    }

    await attachmentStore.deleteAttachment(docId, attachmentName);
  }
}
