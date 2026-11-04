import 'dart:io';
import 'dart:typed_data';
import 'package:foodb/attachment_store.dart';
import 'package:path/path.dart' as path;

/// Default attachment store implementation using the file system
/// Stores attachments in a directory structure: {baseDir}/{docId}/{attachmentName}
class FileSystemAttachmentStore implements AttachmentStore {
  final String baseDirectory;
  late Directory _baseDir;

  FileSystemAttachmentStore({required this.baseDirectory});

  @override
  Future<void> init() async {
    _baseDir = Directory(baseDirectory);
    if (!await _baseDir.exists()) {
      await _baseDir.create(recursive: true);
    }
  }

  @override
  Future<void> close() async {
    // No cleanup needed for file system
  }

  /// Get the directory path for a document's attachments
  String _getDocDirectory(String docId) {
    // Sanitize docId for file system use
    final sanitizedDocId = docId.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return path.join(baseDirectory, sanitizedDocId);
  }

  /// Get the file path for a specific attachment
  String _getAttachmentPath(String docId, String attachmentName) {
    // Sanitize attachment name for file system use
    final sanitizedName = attachmentName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return path.join(_getDocDirectory(docId), sanitizedName);
  }

  @override
  Future<Uint8List?> getAttachment(String docId, String attachmentName) async {
    final filePath = _getAttachmentPath(docId, attachmentName);
    final file = File(filePath);
    
    if (!await file.exists()) {
      return null;
    }
    
    return await file.readAsBytes();
  }

  @override
  Future<void> putAttachment(
    String docId,
    String attachmentName,
    Uint8List data,
    String contentType,
  ) async {
    final docDir = Directory(_getDocDirectory(docId));
    if (!await docDir.exists()) {
      await docDir.create(recursive: true);
    }
    
    final filePath = _getAttachmentPath(docId, attachmentName);
    final file = File(filePath);
    await file.writeAsBytes(data);
    
    // Store content type in a metadata file
    final metaPath = '$filePath.meta';
    final metaFile = File(metaPath);
    await metaFile.writeAsString(contentType);
  }

  @override
  Future<void> deleteAttachment(String docId, String attachmentName) async {
    final filePath = _getAttachmentPath(docId, attachmentName);
    final file = File(filePath);
    
    if (await file.exists()) {
      await file.delete();
    }
    
    // Also delete metadata file
    final metaPath = '$filePath.meta';
    final metaFile = File(metaPath);
    if (await metaFile.exists()) {
      await metaFile.delete();
    }
  }

  @override
  Future<void> deleteDocAttachments(String docId) async {
    final docDir = Directory(_getDocDirectory(docId));
    
    if (await docDir.exists()) {
      await docDir.delete(recursive: true);
    }
  }

  /// Get the content type for an attachment
  Future<String?> getAttachmentContentType(
      String docId, String attachmentName) async {
    final filePath = _getAttachmentPath(docId, attachmentName);
    final metaPath = '$filePath.meta';
    final metaFile = File(metaPath);
    
    if (!await metaFile.exists()) {
      return null;
    }
    
    return await metaFile.readAsString();
  }
}
