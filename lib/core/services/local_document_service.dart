import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scanmate/core/models/local_document_model.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

/// Notifier that holds the live list of local docs and persists changes.
class LocalDocumentNotifier extends AsyncNotifier<List<LocalDocumentModel>> {
  @override
  Future<List<LocalDocumentModel>> build() => _load();

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> addDocument(LocalDocumentModel doc) async {
    final current = state.value ?? <LocalDocumentModel>[];
    final index = current.indexWhere((d) => d.id == doc.id);
    final List<LocalDocumentModel> updated;
    if (index != -1) {
      updated = List<LocalDocumentModel>.from(current);
      updated[index] = doc;
    } else {
      updated = <LocalDocumentModel>[doc, ...current]; // newest first
    }
    await _save(updated);
    state = AsyncData(updated);
  }

  Future<void> deleteDocument(String id) async {
    final current = state.value ?? <LocalDocumentModel>[];
    final updated = current.where((d) => d.id != id).toList();
    await _save(updated);
    state = AsyncData(updated);
  }

  Future<void> toggleStar(String id) async {
    final current = state.value ?? <LocalDocumentModel>[];
    final updated = current.map((d) {
      if (d.id == id) return d.copyWith(isStarred: !d.isStarred);
      return d;
    }).toList();
    await _save(updated);
    state = AsyncData(updated);
  }

  /// Moves a document into [folder]; pass null to remove it from any folder.
  Future<void> moveToFolder(String id, String? folder) async {
    final current = state.value ?? <LocalDocumentModel>[];
    final updated = current.map((d) {
      if (d.id == id) return d.copyWith(folder: folder);
      return d;
    }).toList();
    await _save(updated);
    state = AsyncData(updated);
  }

  // ── Persistence helpers ────────────────────────────────────────────────────

  static Future<File> _indexFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/scanmate_docs.json');
  }

  static Future<List<LocalDocumentModel>> _load() async {
    try {
      final file = await _indexFile();
      if (!file.existsSync()) return [];
      final raw = await file.readAsString();
      final List<dynamic> list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => LocalDocumentModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('LocalDocumentService load error: $e');
      return [];
    }
  }

  static Future<void> _save(List<LocalDocumentModel> docs) async {
    try {
      final file = await _indexFile();
      final encoded = json.encode(docs.map((d) => d.toMap()).toList());
      await file.writeAsString(encoded);
    } catch (e) {
      debugPrint('LocalDocumentService save error: $e');
    }
  }
}

final localDocumentProvider =
    AsyncNotifierProvider<LocalDocumentNotifier, List<LocalDocumentModel>>(
        LocalDocumentNotifier.new);

// ─── Folders ──────────────────────────────────────────────────────────────────

/// Persists the list of folder names so that even empty folders are remembered.
class FolderNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() => _load();

  Future<void> addFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final current = state.value ?? <String>[];
    if (current.any((f) => f.toLowerCase() == trimmed.toLowerCase())) return;
    final updated = [...current, trimmed]..sort();
    await _save(updated);
    state = AsyncData(updated);
  }

  Future<void> removeFolder(String name) async {
    final current = state.value ?? <String>[];
    final updated = current.where((f) => f != name).toList();
    await _save(updated);
    state = AsyncData(updated);
    // Detach any documents that lived in the removed folder.
    final docs = ref.read(localDocumentProvider).value ?? [];
    for (final d in docs.where((d) => d.folder == name)) {
      await ref.read(localDocumentProvider.notifier).moveToFolder(d.id, null);
    }
  }

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/scanmate_folders.json');
  }

  static Future<List<String>> _load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return [];
      final raw = await file.readAsString();
      return List<String>.from(json.decode(raw) as List<dynamic>);
    } catch (e) {
      debugPrint('FolderNotifier load error: $e');
      return [];
    }
  }

  static Future<void> _save(List<String> folders) async {
    try {
      final file = await _file();
      await file.writeAsString(json.encode(folders));
    } catch (e) {
      debugPrint('FolderNotifier save error: $e');
    }
  }
}

final folderProvider =
    AsyncNotifierProvider<FolderNotifier, List<String>>(FolderNotifier.new);
