import 'dart:convert';

class BusinessCardModel {
  String? fullName;
  List<String> phoneNumbers;
  List<String> emailAddresses;
  String? companyName;
  String? designation;
  String? website;
  String? address;
  String? rawOcrText;
  String? imagePath;
  bool isDuplicate;

  BusinessCardModel({
    this.fullName,
    this.phoneNumbers = const [],
    this.emailAddresses = const [],
    this.companyName,
    this.designation,
    this.website,
    this.address,
    this.rawOcrText,
    this.imagePath,
    this.isDuplicate = false,
  });

  bool get hasCriticalFields =>
    (fullName != null && fullName!.trim().isNotEmpty) ||
    phoneNumbers.isNotEmpty ||
    emailAddresses.isNotEmpty;

  BusinessCardModel copyWith({
    String? fullName,
    List<String>? phoneNumbers,
    List<String>? emailAddresses,
    String? companyName,
    String? designation,
    String? website,
    String? address,
    String? rawOcrText,
    String? imagePath,
    bool? isDuplicate,
  }) {
    return BusinessCardModel(
      fullName: fullName ?? this.fullName,
      phoneNumbers: phoneNumbers ?? this.phoneNumbers,
      emailAddresses: emailAddresses ?? this.emailAddresses,
      companyName: companyName ?? this.companyName,
      designation: designation ?? this.designation,
      website: website ?? this.website,
      address: address ?? this.address,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      imagePath: imagePath ?? this.imagePath,
      isDuplicate: isDuplicate ?? this.isDuplicate,
    );
  }

  Map<String, dynamic> toMap() => {
    'fullName': fullName,
    'phoneNumbers': phoneNumbers,
    'emailAddresses': emailAddresses,
    'companyName': companyName,
    'designation': designation,
    'website': website,
    'address': address,
    'rawOcrText': rawOcrText,
    'imagePath': imagePath,
  };

  factory BusinessCardModel.fromMap(Map<String, dynamic> map) => BusinessCardModel(
    fullName: map['fullName'] as String?,
    phoneNumbers: map['phoneNumbers'] != null ? List<String>.from(map['phoneNumbers']) : [],
    emailAddresses: map['emailAddresses'] != null ? List<String>.from(map['emailAddresses']) : [],
    companyName: map['companyName'] as String?,
    designation: map['designation'] as String?,
    website: map['website'] as String?,
    address: map['address'] as String?,
    rawOcrText: map['rawOcrText'] as String?,
    imagePath: map['imagePath'] as String?,
  );

  String toJson() => json.encode(toMap());

  factory BusinessCardModel.fromJson(String source) =>
      BusinessCardModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
