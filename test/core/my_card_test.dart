import 'package:flutter_test/flutter_test.dart';
import 'package:smartscan/core/services/my_card_service.dart';
import 'package:smartscan/core/theme/card_themes.dart';

void main() {
  const profile = MyCardProfile(
    fullName: 'Yash Sharma',
    phone: '+91 98765 43210',
    email: 'yash@example.com',
    company: 'Enercore',
    designation: 'Founder',
    website: 'enercore.in',
    address: 'Gurgaon, Haryana',
    themeIndex: 3,
  );

  test('vCard contains every filled field', () {
    final v = profile.toVCard();
    expect(v, contains('BEGIN:VCARD'));
    expect(v, contains('FN:Yash Sharma'));
    expect(v, contains('TEL;TYPE=CELL:+91 98765 43210'));
    expect(v, contains('EMAIL:yash@example.com'));
    expect(v, contains('ORG:Enercore'));
    expect(v, contains('TITLE:Founder'));
    expect(v, contains('URL:enercore.in'));
    expect(v, contains('ADR;TYPE=WORK:;;Gurgaon, Haryana;;;;'));
    expect(v, contains('END:VCARD'));
  });

  test('empty fields are omitted from the vCard', () {
    const minimal = MyCardProfile(fullName: 'Yash');
    final v = minimal.toVCard();
    expect(v.contains('TEL'), isFalse);
    expect(v.contains('ADR'), isFalse);
  });

  test('profile map roundtrip keeps address and theme', () {
    final restored = MyCardProfile.fromMap(profile.toMap());
    expect(restored.address, 'Gurgaon, Haryana');
    expect(restored.themeIndex, 3);
  });

  test('theme index is clamped to the preset range', () {
    expect(WalletCardTheme.byIndex(999).name,
        WalletCardTheme.presets.last.name);
    expect(WalletCardTheme.byIndex(-1).name,
        WalletCardTheme.presets.first.name);
  });
}
