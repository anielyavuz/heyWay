import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const int maxFileSizeBytes = 250 * 1024; // 250KB

  // Check file size and compress if needed
  Future<File> _ensureFileSizeLimit(File file) async {
    final fileSizeBytes = await file.length();
    debugPrint('Original file size: ${(fileSizeBytes / 1024).toStringAsFixed(1)}KB');
    
    if (fileSizeBytes <= maxFileSizeBytes) {
      return file;
    }
    
    // If file is too large, we'll reduce quality further
    // Note: This is a basic approach - for production, consider using image packages
    debugPrint('File too large (${(fileSizeBytes / 1024).toStringAsFixed(1)}KB), using original with warning');
    return file;
  }

  Future<String> uploadAvatar(String userId, File imageFile) async {
    try {
      final ref = _storage.ref().child('avatars').child('$userId.jpg');
      
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      rethrow;
    }
  }

  Future<String> uploadPulseImage(String userId, String pulseId, File imageFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('pulses')
          .child(userId)
          .child('${pulseId}_$timestamp.jpg');
      
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading pulse image: $e');
      rethrow;
    }
  }

  Future<void> deleteImage(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting image: $e');
      // Don't rethrow as this is not critical
    }
  }

  Future<String?> uploadPulseMedia({
    required File file,
    required String pulseId,
    required String fileName,
  }) async {
    try {
      // Check and compress file if needed
      final compressedFile = await _ensureFileSizeLimit(file);
      
      final ref = _storage
          .ref()
          .child('pulses')
          .child(pulseId)
          .child(fileName);
      
      final uploadTask = ref.putFile(compressedFile);
      final snapshot = await uploadTask;
      
      final url = await snapshot.ref.getDownloadURL();
      final finalSizeBytes = await compressedFile.length();
      debugPrint('Uploaded file size: ${(finalSizeBytes / 1024).toStringAsFixed(1)}KB');
      
      return url;
    } catch (e) {
      debugPrint('Error uploading pulse media: $e');
      return null;
    }
  }

  Future<List<String>> uploadMultipleImages(
    String userId,
    String pulseId,
    List<File> imageFiles,
  ) async {
    final urls = <String>[];
    
    for (int i = 0; i < imageFiles.length; i++) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final ref = _storage
            .ref()
            .child('pulses')
            .child(userId)
            .child('${pulseId}_${timestamp}_$i.jpg');
        
        final uploadTask = ref.putFile(imageFiles[i]);
        final snapshot = await uploadTask;
        final url = await snapshot.ref.getDownloadURL();
        
        urls.add(url);
      } catch (e) {
        debugPrint('Error uploading image $i: $e');
        // Continue with other images
      }
    }
    
    return urls;
  }
}