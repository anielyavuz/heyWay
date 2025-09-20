import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

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