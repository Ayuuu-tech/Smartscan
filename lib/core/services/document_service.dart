import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanmate/core/models/document_model.dart';
import 'package:scanmate/core/services/auth_service.dart';

final documentListProvider =
    StreamProvider<List<DocumentModel>>((ref) {
  final user = ref.watch(authStateProvider);
  if (user == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('documents')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => DocumentModel.fromMap(d.data())).toList())
      .handleError((e) {
    debugPrint('Firestore stream error: $e');
    return <DocumentModel>[];
  });
});

final documentServiceProvider = Provider<DocumentService>((ref) {
  final user = ref.watch(authStateProvider);
  return DocumentService(userId: user?.uid);
});

class DocumentService {
  final String? userId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentService({this.userId});

  CollectionReference<Map<String, dynamic>>? get _docsRef {
    if (userId == null) return null;
    return _db.collection('users').doc(userId).collection('documents');
  }

  Future<void> addDocument(DocumentModel doc) async {
    try {
      await _docsRef?.doc(doc.id).set(doc.toMap());
    } catch (e) {
      debugPrint('addDocument error: $e');
      rethrow;
    }
  }

  Future<void> toggleStar(String docId) async {
    try {
      final ref = _docsRef?.doc(docId);
      final snap = await ref?.get();
      if (snap?.exists == true) {
        final starred = snap!.data()?['isStarred'] ?? false;
        await ref?.update({'isStarred': !starred});
      }
    } catch (e) {
      debugPrint('toggleStar error: $e');
    }
  }

  Future<void> deleteDocument(String docId) async {
    try {
      await _docsRef?.doc(docId).delete();
    } catch (e) {
      debugPrint('deleteDocument error: $e');
    }
  }
}
