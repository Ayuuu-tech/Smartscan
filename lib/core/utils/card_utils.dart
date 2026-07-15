import 'package:flutter/material.dart';

/// Card network detected from the number's BIN prefix.
enum CardBrand { visa, mastercard, rupay, amex, discover, diners, jcb, maestro, unknown }

extension CardBrandLabel on CardBrand {
  String get label {
    switch (this) {
      case CardBrand.visa:
        return 'VISA';
      case CardBrand.mastercard:
        return 'Mastercard';
      case CardBrand.rupay:
        return 'RuPay';
      case CardBrand.amex:
        return 'AMEX';
      case CardBrand.discover:
        return 'Discover';
      case CardBrand.diners:
        return 'Diners Club';
      case CardBrand.jcb:
        return 'JCB';
      case CardBrand.maestro:
        return 'Maestro';
      case CardBrand.unknown:
        return 'CARD';
    }
  }
}

class CardUtils {
  CardUtils._();

  /// Standard Luhn checksum — true when [number] (digits only) is a valid PAN.
  static bool luhnCheck(String number) {
    if (number.length < 12 || number.length > 19) return false;
    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      final code = number.codeUnitAt(i);
      if (code < 0x30 || code > 0x39) return false;
      int digit = code - 0x30;
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  static String digitsOnly(String input) => input.replaceAll(RegExp(r'\D'), '');

  /// Detect the card network from BIN ranges. RuPay is checked before
  /// Discover/JCB because their ranges overlap (60/65/35 prefixes).
  static CardBrand detectBrand(String number) {
    final n = digitsOnly(number);
    if (n.isEmpty) return CardBrand.unknown;

    if (n.startsWith('4')) return CardBrand.visa;
    if (RegExp(r'^3[47]').hasMatch(n)) return CardBrand.amex;
    if (RegExp(r'^(508[5-9]|60|65|81|82|35[3-4])').hasMatch(n) && _looksIndian(n)) {
      return CardBrand.rupay;
    }
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(n)) return CardBrand.mastercard;
    if (RegExp(r'^(6011|64[4-9]|65)').hasMatch(n)) return CardBrand.discover;
    if (RegExp(r'^(50|5[6-8]|6)').hasMatch(n)) return CardBrand.maestro;
    if (RegExp(r'^3(0[0-5]|[68])').hasMatch(n)) return CardBrand.diners;
    if (RegExp(r'^35').hasMatch(n)) return CardBrand.jcb;
    return CardBrand.unknown;
  }

  // RuPay shares 60/65 space with Discover; treat well-known RuPay BIN
  // starts as RuPay. Heuristic — good enough for a visual badge.
  static bool _looksIndian(String n) {
    const ruPayStarts = ['508', '606', '607', '608', '652', '653', '81', '82'];
    return ruPayStarts.any(n.startsWith);
  }

  /// "4111111111111111" → "4111 1111 1111 1111" (AMEX: 4-6-5).
  static String formatNumber(String number, {CardBrand? brand}) {
    final n = digitsOnly(number);
    final b = brand ?? detectBrand(n);
    final groups = <String>[];
    if (b == CardBrand.amex || b == CardBrand.diners) {
      const splits = [4, 10];
      int start = 0;
      for (final s in splits) {
        if (n.length <= s) break;
        groups.add(n.substring(start, s));
        start = s;
      }
      groups.add(n.substring(start.clamp(0, n.length)));
      return groups.where((g) => g.isNotEmpty).join(' ');
    }
    for (int i = 0; i < n.length; i += 4) {
      groups.add(n.substring(i, (i + 4).clamp(0, n.length)));
    }
    return groups.join(' ');
  }

  /// "•••• •••• •••• 4242"
  static String maskNumber(String number) {
    final n = digitsOnly(number);
    if (n.length < 4) return '••••';
    final last4 = n.substring(n.length - 4);
    return '•••• •••• •••• $last4';
  }

  /// Gradient used for a card visual, keyed off the stored base color.
  static LinearGradient cardGradient(int colorValue) {
    final base = Color(colorValue);
    final hsl = HSLColor.fromColor(base);
    final darker =
        hsl.withLightness((hsl.lightness - 0.16).clamp(0.0, 1.0)).toColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [base, darker],
    );
  }

  /// Preset colors offered in the entry form.
  static const List<int> presetColors = [
    0xFF1F2A44, // navy
    0xFF5B2C6F, // plum
    0xFF117A65, // teal
    0xFF7B241C, // maroon
    0xFFB9770E, // amber
    0xFF34495E, // slate
    0xFF6C3483, // violet
    0xFF196F3D, // green
    0xFF212121, // black
    0xFFE36A26, // brand orange
  ];
}

/// Result of parsing OCR text from a photographed payment card.
class ScannedCardData {
  final String? number;
  final int? expiryMonth;
  final int? expiryYear;
  final String? cardholderName;

  /// Bank / issuer name detected on the card, e.g. "HDFC Bank".
  final String? title;

  /// 3-4 digit security code read from the back (when present).
  final String? cvv;

  const ScannedCardData({
    this.number,
    this.expiryMonth,
    this.expiryYear,
    this.cardholderName,
    this.title,
    this.cvv,
  });

  bool get hasNumber => number != null;
}

/// Extracts PAN / expiry / name from raw OCR text of a card photo.
class CardOcrParser {
  CardOcrParser._();

  /// Known issuers, longest/most-specific phrase first. Matched with word
  /// boundaries against the whole OCR text, so partial words never match.
  static const List<(String, String)> _knownIssuers = [
    ('STATE BANK OF INDIA', 'SBI'),
    ('STANDARD CHARTERED', 'Standard Chartered'),
    ('PUNJAB NATIONAL', 'Punjab National Bank'),
    ('BANK OF BARODA', 'Bank of Baroda'),
    ('BANK OF MAHARASHTRA', 'Bank of Maharashtra'),
    ('BANK OF INDIA', 'Bank of India'),
    ('INDIAN OVERSEAS', 'Indian Overseas Bank'),
    ('SOUTH INDIAN BANK', 'South Indian Bank'),
    ('KARUR VYSYA', 'Karur Vysya Bank'),
    ('CENTRAL BANK', 'Central Bank of India'),
    ('UNION BANK', 'Union Bank of India'),
    ('AMERICAN EXPRESS', 'American Express'),
    ('AU SMALL', 'AU Small Finance Bank'),
    ('YES BANK', 'Yes Bank'),
    ('FEDERAL BANK', 'Federal Bank'),
    ('INDIAN BANK', 'Indian Bank'),
    ('HDFC', 'HDFC Bank'),
    ('ICICI', 'ICICI Bank'),
    ('AXIS', 'Axis Bank'),
    ('KOTAK', 'Kotak Bank'),
    ('IDFC', 'IDFC First Bank'),
    ('INDUSIND', 'IndusInd Bank'),
    ('CANARA', 'Canara Bank'),
    ('BANDHAN', 'Bandhan Bank'),
    ('EQUITAS', 'Equitas Bank'),
    ('UJJIVAN', 'Ujjivan Bank'),
    ('CITIBANK', 'Citi'),
    ('CITI', 'Citi'),
    ('HSBC', 'HSBC'),
    ('IDBI', 'IDBI Bank'),
    ('DBS', 'DBS Bank'),
    ('RBL', 'RBL Bank'),
    ('AMEX', 'American Express'),
    ('ONECARD', 'OneCard'),
    ('SLICE', 'Slice'),
    ('PAYTM', 'Paytm Payments Bank'),
    ('SBI', 'SBI'),
    ('PNB', 'Punjab National Bank'),
    ('UCO', 'UCO Bank'),
  ];

  /// Card product words often printed under the bank name; appended to the
  /// title when found, e.g. "HDFC Bank Millennia".
  static const List<String> _productWords = [
    'MILLENNIA', 'REGALIA', 'INFINIA', 'MONEYBACK', 'PLATINUM', 'TITANIUM',
    'SIGNATURE', 'CORAL', 'AMAZE', 'SAPPHIRO', 'RUBYX', 'MAGNUS', 'NEO',
    'FLIPKART', 'AMAZON', 'SWIGGY', 'SIMPLYCLICK', 'SIMPLYSAVE', 'PULSE',
    'ELITE', 'PRIME', 'CASHBACK', 'MILES', 'SELECT', 'WEALTH', 'ACE',
  ];

  /// Characters ML Kit commonly mistakes for digits on embossed cards.
  static const Map<String, String> _digitLookalikes = {
    'O': '0', 'o': '0', 'Q': '0', 'D': '0',
    'I': '1', 'l': '1', '|': '1',
    'Z': '2', 'z': '2',
    'S': '5', 's': '5',
    'B': '8',
    'G': '6',
  };

  static String _repairDigits(String raw) {
    final b = StringBuffer();
    for (final ch in raw.split('')) {
      b.write(_digitLookalikes[ch] ?? ch);
    }
    return b.toString();
  }

  /// Finds a Luhn-valid PAN with three passes of increasing tolerance:
  /// 1. clean digit runs; 2. runs contaminated with digit-lookalike
  /// letters (O→0, I→1 …), repaired then re-checked; 3. the number split
  /// across two adjacent lines (common with embossed cards).
  static String? _findPan(String ocrText, List<String> lines) {
    // Pass 1: clean digit runs.
    final panPattern = RegExp(r'(?:\d[ \-]?){12,19}');
    for (final match in panPattern.allMatches(ocrText)) {
      final candidate = CardUtils.digitsOnly(match.group(0)!);
      if (CardUtils.luhnCheck(candidate)) return candidate;
    }

    // Pass 2: repair OCR lookalikes, then re-check.
    final fuzzyPattern = RegExp(r'(?:[0-9OoQDIl|ZzSsBG][ \-]?){12,23}');
    for (final match in fuzzyPattern.allMatches(ocrText)) {
      final repaired =
          CardUtils.digitsOnly(_repairDigits(match.group(0)!));
      if (repaired.length >= 12 &&
          repaired.length <= 19 &&
          CardUtils.luhnCheck(repaired)) {
        return repaired;
      }
    }

    // Pass 3: PAN split across two adjacent lines.
    for (var i = 0; i < lines.length - 1; i++) {
      final a = CardUtils.digitsOnly(_repairDigits(lines[i]));
      final b = CardUtils.digitsOnly(_repairDigits(lines[i + 1]));
      if (a.length < 4 || b.length < 4) continue;
      final joined = a + b;
      if (joined.length >= 12 &&
          joined.length <= 19 &&
          CardUtils.luhnCheck(joined)) {
        return joined;
      }
    }
    return null;
  }

  static ScannedCardData parse(String ocrText) {
    int? expMonth;
    int? expYear;
    String? name;
    String? title;

    final rawLines = ocrText.split('\n').map((l) => l.trim()).toList();
    final pan = _findPan(ocrText, rawLines);

    // Expiry: MM/YY or MM/YYYY, prefer one following VALID THRU / EXPIRES.
    final expPattern = RegExp(r'(0[1-9]|1[0-2])\s*/\s*(\d{4}|\d{2})');
    final expMatches = expPattern.allMatches(ocrText).toList();
    if (expMatches.isNotEmpty) {
      // If multiple dates (valid-from + valid-thru), take the latest.
      DateTime? best;
      final nowYear = DateTime.now().year;
      for (final m in expMatches) {
        final mm = int.parse(m.group(1)!);
        var yy = int.parse(m.group(2)!);
        if (yy < 100) yy += 2000;
        // Cards are issued for at most ~10 years; anything outside this
        // window is OCR noise (phone numbers, member-since dates…).
        if (yy < nowYear - 6 || yy > nowYear + 15) continue;
        final dt = DateTime(yy, mm);
        if (best == null || dt.isAfter(best)) {
          best = dt;
          expMonth = mm;
          expYear = yy;
        }
      }
    }

    // Bank / issuer: match known issuer phrases anywhere in the text
    // (word-bounded, so "AXIS" won't match inside "MAXIS"). OCR often reads
    // logos in mixed case or with the product on the same line — matching
    // the whole text is far more forgiving than line-by-line.
    final upperText = ocrText.toUpperCase();
    for (final (phrase, display) in _knownIssuers) {
      final pattern =
          RegExp('\\b${phrase.replaceAll(' ', '\\s+')}\\b');
      if (pattern.hasMatch(upperText)) {
        title = display;
        break;
      }
    }
    // Fallback for unknown issuers: shortest line that mentions BANK,
    // e.g. "SOME BANK" or "SOME BANK LTD".
    if (title == null) {
      String? best;
      for (final rawLine in upperText.split('\n')) {
        final line = rawLine.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (line.length < 4 || line.length > 32) continue;
        if (!RegExp(r'\bBANK\b').hasMatch(line)) continue;
        if (RegExp(r'\d').hasMatch(line)) continue;
        if (best == null || line.length < best.length) best = line;
      }
      if (best != null) title = _titleCase(best);
    }
    if (title != null) {
      // Per-line so "AUTHORIZED SIGNATURE" on the back is never taken as
      // the "Signature" card product.
      outer:
      for (final line in upperText.split('\n')) {
        if (line.contains('AUTHORIZED') || line.contains('AUTHORISED')) {
          continue;
        }
        for (final p in _productWords) {
          if (RegExp('\\b$p\\b').hasMatch(line)) {
            title = '$title ${_titleCase(p)}';
            break outer;
          }
        }
      }
    }

    // ── CVV ─────────────────────────────────────────────────────────────
    // Prefer an explicit label ("CVV 123", "CVC: 1234"). Fall back to a
    // standalone 3-digit line — that's how it's printed on the signature
    // panel. PAN groups are 4 digits and expiry contains "/", so a lone
    // 3-digit line is almost always the security code.
    String? cvv;
    final cvvLabeled =
        RegExp(r'(?:CVV|CVC|CSC)\D{0,3}(\d{3,4})').firstMatch(upperText);
    if (cvvLabeled != null) {
      cvv = cvvLabeled.group(1);
    } else {
      for (final rawLine in ocrText.split('\n')) {
        final line = rawLine.trim();
        if (RegExp(r'^\d{3}$').hasMatch(line)) {
          cvv = line;
          break;
        }
      }
    }

    // ── Cardholder name ────────────────────────────────────────────────
    // On a physical card the name is embossed/printed directly BELOW the
    // number and expiry. Instead of taking the first uppercase line
    // anywhere (old behaviour — easily fooled by marketing text), collect
    // candidates and score them by position relative to the PAN/expiry.
    final lines = ocrText.split('\n').map((l) => l.trim()).toList();

    int panLine = -1;
    int expLine = -1;
    for (var i = 0; i < lines.length; i++) {
      final digits = CardUtils.digitsOnly(lines[i]);
      if (pan != null &&
          panLine == -1 &&
          digits.length >= 8 &&
          pan.contains(digits)) {
        panLine = i;
      }
      if (expMonth != null &&
          expLine == -1 &&
          RegExp('0?$expMonth\\s*/').hasMatch(lines[i]) &&
          expPattern.hasMatch(lines[i])) {
        expLine = i;
      }
    }

    const stopWords = {
      'BANK', 'VALID', 'THRU', 'FROM', 'EXPIRES', 'EXPIRY', 'DEBIT', 'CREDIT',
      'CARD', 'VISA', 'MASTERCARD', 'RUPAY', 'MAESTRO', 'ELECTRON', 'MASTER',
      'PLATINUM', 'GOLD', 'TITANIUM', 'CLASSIC', 'WORLD', 'SIGNATURE',
      'BUSINESS', 'GLOBAL', 'INTERNATIONAL', 'ELECTRONIC', 'USE', 'ONLY',
      'MONTH', 'YEAR', 'SINCE', 'MEMBER', 'AUTHORIZED', 'AUTHORISED',
      'CONTACTLESS', 'CHIP', 'SECURE', 'CUSTOMER', 'CARE', 'HELPLINE',
      'TOLL', 'FREE', 'CALL', 'TRANSFERABLE', 'ISSUED', 'PROPERTY',
      'REWARD', 'REWARDS', 'OFFER', 'SALE', 'ATM', 'PIN', 'CVV', 'GOOD',
      'NOT', 'THE', 'THIS', 'FOR', 'AND', 'YOUR', 'FOUND', 'RETURN',
      'PLEASE', 'SERVICES', 'SERVICE', 'LIMITED', 'LTD', 'INDIA', 'PVT',
    };
    final namePattern = RegExp(r"^[A-Z][A-Z .']{2,27}[A-Z]$");
    final knownIssuerWords = _knownIssuers
        .expand((e) => e.$1.split(' '))
        .toSet();
    final productWordSet = _productWords.toSet();

    int bestScore = -1;
    for (var i = 0; i < lines.length; i++) {
      // Uppercase before matching: printed (non-embossed) cards OCR the
      // name in mixed case.
      final line =
          lines[i].replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
      if (!namePattern.hasMatch(line)) continue;
      final words = line.split(' ');
      // Names are 2-4 words, every word purely alphabetic and ≥2 chars
      // (initials like "K." allowed via the dot).
      if (words.length < 2 || words.length > 4) continue;
      if (words.any((w) => w.replaceAll(RegExp(r"[.']"), '').isEmpty)) {
        continue;
      }
      if (words.any((w) => stopWords.contains(w))) continue;
      if (words.any(productWordSet.contains)) continue;
      // Skip the issuer line ("HDFC BANK" etc.).
      if (words.every(knownIssuerWords.contains)) continue;

      var score = 0;
      // Right after the expiry line — the classic position.
      if (expLine != -1 && i > expLine && i - expLine <= 2) score += 4;
      // Below the card number.
      if (panLine != -1 && i > panLine && i - panLine <= 4) score += 3;
      // Above the number/expiry is where marketing text lives.
      if (panLine != -1 && i < panLine) score -= 2;
      if (expLine != -1 && i < expLine) score -= 2;

      if (score > bestScore) {
        bestScore = score;
        name = line;
      }
    }
    // Only trust a positionless match if we had no positional anchors at
    // all (e.g. OCR merged everything onto odd lines).
    if (bestScore < 0 && (panLine != -1 || expLine != -1)) {
      name = null;
    }

    return ScannedCardData(
      number: pan,
      expiryMonth: expMonth,
      expiryYear: expYear,
      cardholderName: name,
      title: title,
      cvv: cvv,
    );
  }

  static String _titleCase(String input) => input
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
