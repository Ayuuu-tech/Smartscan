import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadDocumentFile({
    required String userId,
    required File file,
    required String filename,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('users')
          .child(userId)
          .child('documents')
          .child(filename);

      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Firebase Storage upload error: $e');
      rethrow;
    }
  }

  Future<void> deleteDocumentFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Storage delete error: $e');
    }
  }

  Future<String> uploadDocumentWithBytes({
    required String userId,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('users')
          .child(userId)
          .child('documents')
          .child(filename);

      final uploadTask = await ref.putData(bytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Firebase Storage upload bytes error: $e');
      rethrow;
    }
  }
}
