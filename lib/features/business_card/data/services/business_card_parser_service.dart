import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanmate/features/business_card/data/models/business_card_model.dart';

final businessCardParserProvider = Provider<BusinessCardParserService>((ref) {
  return BusinessCardParserService();
});

class BusinessCardParserService {
  static final _emailRegex = RegExp(
    r'[\w\.\-]+@[\w\-]+\.(?:com|org|net|edu|gov|io|co|in|uk|de|fr|au|jp|br|ca|app|dev|ai)\b',
    caseSensitive: false,
  );

  static final _phoneRegex = RegExp(
    r'(\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,9}',
  );

  static final _webRegex = RegExp(
    r'(?:https?://)?(?:www\.)?[\w\-]+\.[\w\.\-]+',
    caseSensitive: false,
  );

  static final _designationKeywords = [
    'manager', 'director', 'engineer', 'developer', 'analyst',
    'consultant', 'specialist', 'coordinator', 'supervisor',
    'president', 'vice president', 'vp', 'ceo', 'cfo', 'cto',
    'coo', 'founder', 'co-founder', 'partner', 'principal',
    'lead', 'head', 'chief', 'officer', 'architect',
    'designer', 'representative', 'executive', 'assistant',
    'associate', 'technician', 'admin', 'administrator',
    'advisor', 'agent', 'broker', 'scientist', 'researcher',
    'professor', 'instructor', 'trainer', 'accountant',
    'attorney', 'lawyer', 'surgeon', 'doctor', 'nurse',
    'sales', 'marketing', 'operations', 'support', 'hr',
    'human resources', 'recruiter', 'freelancer',
  ];

  static final _companyIndicators = [
    'inc', 'llc', 'ltd', 'limited', 'corp', 'corporation',
    'technologies', 'technology', 'software', 'solutions',
    'services', 'consulting', 'group', 'industries',
    'international', 'enterprises', 'systems', 'digital',
    'labs', 'studio', 'ventures', 'partners', 'associates',
    'co\\.', 'company', 'gmbh', 'pvt', 'private',
  ];

  static final _addressKeywords = [
    'street', 'st\\.', 'road', 'rd\\.', 'avenue', 'ave\\.',
    'drive', 'dr\\.', 'lane', 'ln\\.', 'boulevard', 'blvd',
    'way', 'circle', 'cir\\.', 'court', 'ct\\.', 'suite',
    'ste\\.', 'floor', 'fl\\.', 'room', 'rm\\.',
    'building', 'bldg', 'apartment', 'apt\\.', 'unit',
    'po box', 'p\\.o\\.', 'post office',
  ];

  static final _zipRegex = RegExp(
    r'\b\d{5}(?:[-\s]\d{4})?\b',
  );

  static final _stateRegex = RegExp(
    r'\b(?:AL|AK|AZ|AR|CA|CO|CT|DE|FL|GA|HI|ID|IL|IN|IA|KS|KY|LA|ME|MD|MA|MI|MN|MS|MO|MT|NE|NV|NH|NJ|NM|NY|NC|ND|OH|OK|OR|PA|RI|SC|SD|TN|TX|UT|VT|VA|WA|WV|WI|WY)\b',
  );

  // International postal codes: UK (SW1A 1AA), Canada (K1A 0B1),
  // India/Germany/generic 6-digit and 4-digit (AU/NZ/many EU) forms.
  static final _intlPostalRegex = RegExp(
    r'\b(?:[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}|[A-Z]\d[A-Z]\s?\d[A-Z]\d|\d{6}|\d{4})\b',
    caseSensitive: false,
  );

  BusinessCardModel parse(String ocrText) {
    final lines = ocrText
        .split(RegExp(r'\n|\r\n?|\s{3,}'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final phones = <String>[];
    final emails = <String>[];
    final websites = <String>[];
    final nonMatched = <String>[];

    for (final line in lines) {
      if (line.isEmpty) continue;

      final linePhones = _phoneRegex.allMatches(line)
          .map((m) => m.group(0)!.trim())
          .where((p) => p.length >= 7)
          .toList();
      phones.addAll(linePhones);

      final lineEmails = _emailRegex.allMatches(line)
          .map((m) => m.group(0)!.trim().toLowerCase())
          .toList();
      emails.addAll(lineEmails);

      final lineWebs = _webRegex.allMatches(line)
          .map((m) => m.group(0)!.trim().toLowerCase())
          .where((w) => !lineEmails.contains(w))
          .toList();
      websites.addAll(lineWebs);

      final cleaned = line
          .replaceAll(_emailRegex, '')
          .replaceAll(_phoneRegex, '')
          .replaceAll(_webRegex, '')
          .replaceAll(RegExp(r'[\s,;]+'), ' ')
          .trim();

      if (cleaned.isNotEmpty && cleaned.length > 2) {
        nonMatched.add(cleaned);
      }
    }

    phones.sort((a, b) => a.length.compareTo(b.length));
    final uniquePhones = phones.toSet().toList();
    final uniqueEmails = emails.toSet().toList();
    final uniqueWebs = websites.toSet().toList();

    String? name;
    String? designation;
    String? company;
    final addressParts = <String>[];

    for (int i = 0; i < nonMatched.length; i++) {
      final line = nonMatched[i];

      if (_isAddressLine(line)) {
        addressParts.add(line);
        continue;
      }

      if (_isDesignationLine(line)) {
        designation ??= line;
        continue;
      }

      if (_isCompanyLine(line)) {
        company ??= line;
        continue;
      }

      if (name == null && _isNameLine(line, i, nonMatched)) {
        name = line;
        continue;
      }

      if (company == null && line.length > 3) {
        company = line;
        continue;
      }
    }

    if (name == null && nonMatched.isNotEmpty) {
      name = nonMatched.first;
    }

    final website = uniqueWebs.isNotEmpty ? uniqueWebs.first : null;
    final address = addressParts.isNotEmpty ? addressParts.join(', ') : null;

    return BusinessCardModel(
      fullName: _cleanName(name),
      phoneNumbers: uniquePhones,
      emailAddresses: uniqueEmails,
      companyName: company,
      designation: designation,
      website: website,
      address: address,
      rawOcrText: ocrText,
    );
  }

  bool _isNameLine(String line, int index, List<String> allLines) {
    if (line.length < 3 || line.length > 50) return false;
    if (line.contains(RegExp(r'[0-9@#$%^&*()+=\[\]{}|\\:;<>]'))) return false;
    if (line.contains("'") || line.contains('"')) return false;
    final words = line.split(RegExp(r'\s+'));
    if (words.length < 2 || words.length > 5) return false;
    if (words.any((w) => w.length <= 1)) return false;

    final upper = RegExp(r'^[A-Z]');
    final upperWords = words.where((w) => upper.hasMatch(w)).length;
    if (upperWords < 2 && line == line.toLowerCase()) return false;

    return true;
  }

  bool _isDesignationLine(String line) {
    final lower = line.toLowerCase();
    if (lower.length > 40) return false;
    return _designationKeywords.any((kw) {
      return RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false).hasMatch(lower);
    });
  }

  bool _isCompanyLine(String line) {
    final lower = line.toLowerCase();
    if (lower.length > 60) return false;
    if (lower.length < 3) return false;
    return _companyIndicators.any((indicator) {
      return RegExp(r'\b' + indicator + r'\b', caseSensitive: false).hasMatch(lower);
    });
  }

  bool _isAddressLine(String line) {
    final lower = line.toLowerCase();
    if (line.length > 80) return false;
    if (_zipRegex.hasMatch(line)) return true;
    if (_stateRegex.hasMatch(line)) return true;
    // A postal-code-like token combined with address wording => address.
    if (_intlPostalRegex.hasMatch(line)) {
      for (final kw in _addressKeywords) {
        if (RegExp(r'\b' + kw + r'\b', caseSensitive: false).hasMatch(lower)) {
          return true;
        }
      }
    }
    if (RegExp(r'^\d+\s').hasMatch(line)) {
      for (final kw in _addressKeywords) {
        if (RegExp(r'\b' + kw + r'\b', caseSensitive: false).hasMatch(lower)) return true;
      }
    }
    for (final kw in _addressKeywords) {
      if (RegExp(r'\b' + kw + r'\b', caseSensitive: false).hasMatch(lower)) return true;
    }
    return false;
  }

  String? _cleanName(String? name) {
    if (name == null) return null;
    return name
        .replaceAll(RegExp(r'^\s*[•·\-–—*•]+\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<BusinessCardModel> parseCard({
    required String ocrText,
  }) async {
    return parse(ocrText);
  }
}
