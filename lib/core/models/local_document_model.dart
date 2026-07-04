/// Sentinel so copyWith can tell "leave folder unchanged" from "set to null".
const Object _unset = Object();

class LocalDocumentModel {
  final String id;
  final String title;
  final String date;
  final int pageCount;
  final String type; // 'PDF' | 'JPEG'
  final bool isStarred;
  final String pdfPath;         // absolute path to PDF file on device
  final String thumbnailPath;   // absolute path to first-page image
  final List<String> imagePaths; // absolute paths to all captured images
  final String? folder;         // folder name this doc belongs to (null = none)

  const LocalDocumentModel({
    required this.id,
    required this.title,
    required this.date,
    required this.pageCount,
    required this.type,
    this.isStarred = false,
    required this.pdfPath,
    required this.thumbnailPath,
    required this.imagePaths,
    this.folder,
  });

  LocalDocumentModel copyWith({
    String? id,
    String? title,
    String? date,
    int? pageCount,
    String? type,
    bool? isStarred,
    String? pdfPath,
    String? thumbnailPath,
    List<String>? imagePaths,
    Object? folder = _unset,
  }) {
    return LocalDocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      pageCount: pageCount ?? this.pageCount,
      type: type ?? this.type,
      isStarred: isStarred ?? this.isStarred,
      pdfPath: pdfPath ?? this.pdfPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      imagePaths: imagePaths ?? this.imagePaths,
      folder: identical(folder, _unset) ? this.folder : folder as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': date,
        'pageCount': pageCount,
        'type': type,
        'isStarred': isStarred,
        'pdfPath': pdfPath,
        'thumbnailPath': thumbnailPath,
        'imagePaths': imagePaths,
        'folder': folder,
      };

  factory LocalDocumentModel.fromMap(Map<String, dynamic> map) =>
      LocalDocumentModel(
        id: map['id'] as String,
        title: map['title'] as String,
        date: map['date'] as String,
        pageCount: map['pageCount'] as int,
        type: map['type'] as String? ?? 'PDF',
        isStarred: map['isStarred'] as bool? ?? false,
        pdfPath: map['pdfPath'] as String,
        thumbnailPath: map['thumbnailPath'] as String,
        imagePaths: map['imagePaths'] != null
            ? List<String>.from(map['imagePaths'] as List<dynamic>)
            : [map['thumbnailPath'] as String],
        folder: map['folder'] as String?,
      );
}
