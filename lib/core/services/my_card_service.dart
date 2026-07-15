import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// The user's own digital visiting card, shared as a vCard QR.
class MyCardProfile {
  final String fullName;
  final String phone;
  final String email;
  final String company;
  final String designation;
  final String website;
  final String address;

  /// Index into [WalletCardTheme.presets] — the card's look.
  final int themeIndex;

  const MyCardProfile({
    this.fullName = '',
    this.phone = '',
    this.email = '',
    this.company = '',
    this.designation = '',
    this.website = '',
    this.address = '',
    this.themeIndex = 0,
  });

  bool get isEmpty => fullName.trim().isEmpty && phone.trim().isEmpty;

  /// vCard 3.0 — understood by every phone's camera / contacts app.
  String toVCard() {
    final b = StringBuffer()
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0')
      ..writeln('FN:$fullName');
    if (phone.isNotEmpty) b.writeln('TEL;TYPE=CELL:$phone');
    if (email.isNotEmpty) b.writeln('EMAIL:$email');
    if (company.isNotEmpty) b.writeln('ORG:$company');
    if (designation.isNotEmpty) b.writeln('TITLE:$designation');
    if (website.isNotEmpty) b.writeln('URL:$website');
    if (address.isNotEmpty) b.writeln('ADR;TYPE=WORK:;;$address;;;;');
    b.writeln('END:VCARD');
    return b.toString();
  }

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'company': company,
        'designation': designation,
        'website': website,
        'address': address,
        'themeIndex': themeIndex,
      };

  factory MyCardProfile.fromMap(Map<String, dynamic> map) => MyCardProfile(
        fullName: map['fullName'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        email: map['email'] as String? ?? '',
        company: map['company'] as String? ?? '',
        designation: map['designation'] as String? ?? '',
        website: map['website'] as String? ?? '',
        address: map['address'] as String? ?? '',
        themeIndex: map['themeIndex'] as int? ?? 0,
      );
}

class MyCardNotifier extends AsyncNotifier<MyCardProfile> {
  @override
  Future<MyCardProfile> build() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return const MyCardProfile();
      return MyCardProfile.fromMap(
          json.decode(await file.readAsString()) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('MyCard load error: $e');
      return const MyCardProfile();
    }
  }

  Future<void> save(MyCardProfile profile) async {
    state = AsyncData(profile);
    try {
      final file = await _file();
      await file.writeAsString(json.encode(profile.toMap()));
    } catch (e) {
      debugPrint('MyCard save error: $e');
    }
  }

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/my_card_profile.json');
  }
}

final myCardProvider =
    AsyncNotifierProvider<MyCardNotifier, MyCardProfile>(MyCardNotifier.new);
