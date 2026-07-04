import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentModel {
  final String id;
  final String title;
  final String date;
  final int pageCount;
  final String type;
  final bool isStarred;
  final String thumbnailType;
  final String? fileUrl;
  final String? ocrText;
  final DateTime? createdAt;

  const DocumentModel({
    required this.id,
    required this.title,
    required this.date,
    required this.pageCount,
    required this.type,
    this.isStarred = false,
    required this.thumbnailType,
    this.fileUrl,
    this.ocrText,
    this.createdAt,
  });

  DocumentModel copyWith({
    String? id,
    String? title,
    String? date,
    int? pageCount,
    String? type,
    bool? isStarred,
    String? thumbnailType,
    String? fileUrl,
    String? ocrText,
    DateTime? createdAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      pageCount: pageCount ?? this.pageCount,
      type: type ?? this.type,
      isStarred: isStarred ?? this.isStarred,
      thumbnailType: thumbnailType ?? this.thumbnailType,
      fileUrl: fileUrl ?? this.fileUrl,
      ocrText: ocrText ?? this.ocrText,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'pageCount': pageCount,
      'type': type,
      'isStarred': isStarred,
      'thumbnailType': thumbnailType,
      'fileUrl': fileUrl,
      'ocrText': ocrText,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      date: map['date'] ?? '',
      pageCount: map['pageCount'] as int? ?? 1,
      type: map['type'] ?? 'PDF',
      isStarred: map['isStarred'] as bool? ?? false,
      thumbnailType: map['thumbnailType'] ?? 'empty',
      fileUrl: map['fileUrl'],
      ocrText: map['ocrText'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
