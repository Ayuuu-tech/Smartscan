import 'package:flutter_test/flutter_test.dart';
import 'package:smartscan/core/utils/card_utils.dart';

void main() {
  group('Luhn check', () {
    test('accepts valid card numbers', () {
      expect(CardUtils.luhnCheck('4111111111111111'), isTrue); // Visa test
      expect(CardUtils.luhnCheck('5500005555555559'), isTrue); // MC test
      expect(CardUtils.luhnCheck('378282246310005'), isTrue); // Amex test
    });

    test('rejects invalid numbers', () {
      expect(CardUtils.luhnCheck('4111111111111112'), isFalse);
      expect(CardUtils.luhnCheck('1234'), isFalse);
      expect(CardUtils.luhnCheck('abcd1111'), isFalse);
    });
  });

  group('Brand detection', () {
    test('detects major networks', () {
      expect(CardUtils.detectBrand('4111111111111111'), CardBrand.visa);
      expect(CardUtils.detectBrand('5500005555555559'), CardBrand.mastercard);
      expect(CardUtils.detectBrand('378282246310005'), CardBrand.amex);
      expect(CardUtils.detectBrand('6521111111111117'), CardBrand.rupay);
    });
  });

  group('Formatting', () {
    test('groups in fours', () {
      expect(CardUtils.formatNumber('4111111111111111'),
          '4111 1111 1111 1111');
    });
    test('masks all but last four', () {
      expect(CardUtils.maskNumber('4111111111111111'), '•••• •••• •••• 1111');
    });
  });

  group('OCR parsing', () {
    test('extracts number, expiry and name from card OCR text', () {
      const ocr = '''
SOME BANK
PLATINUM
4111 1111 1111 1111
VALID THRU 08/29
YASH SHARMA
''';
      final parsed = CardOcrParser.parse(ocr);
      expect(parsed.number, '4111111111111111');
      expect(parsed.expiryMonth, 8);
      expect(parsed.expiryYear, 2029);
      expect(parsed.cardholderName, 'YASH SHARMA');
      expect(parsed.title, 'Some Bank Platinum');
    });

    test('detects issuer from mixed-case text and full phrases', () {
      expect(CardOcrParser.parse('State Bank of India\nGlobal Debit').title,
          'SBI');
      expect(CardOcrParser.parse('idfc first bank\n4111').title,
          'IDFC First Bank');
      expect(
          CardOcrParser.parse('Punjab National Bank Platinum').title,
          'Punjab National Bank Platinum');
    });

    test('does not match issuer inside larger words', () {
      // "MAXIS" must not match AXIS.
      expect(CardOcrParser.parse('MAXIS TELECOM').title, isNull);
    });

    test('detects known issuer and product name', () {
      const ocr = '''
HDFC BANK
MILLENNIA
DEBIT CARD
''';
      final parsed = CardOcrParser.parse(ocr);
      expect(parsed.title, 'HDFC Bank Millennia');
    });

    test('merged front+back text still parses (details on the back)', () {
      // Front: bank branding only. Back: number, expiry, name.
      const merged = '''
ICICI BANK
CORAL
VISA

AUTHORIZED SIGNATURE
4111 1111 1111 1111
VALID THRU 11/28
YASH SHARMA
CVV 123
''';
      final parsed = CardOcrParser.parse(merged);
      expect(parsed.title, 'ICICI Bank Coral');
      expect(parsed.number, '4111111111111111');
      expect(parsed.expiryMonth, 11);
      expect(parsed.expiryYear, 2028);
      expect(parsed.cardholderName, 'YASH SHARMA');
    });

    test('prefers the line below expiry over text above the number', () {
      const ocr = '''
ENJOY SHOPPING
4111 1111 1111 1111
VALID THRU 08/29
YASH SHARMA
''';
      expect(CardOcrParser.parse(ocr).cardholderName, 'YASH SHARMA');
    });

    test('rejects text above the card number when no name is below', () {
      const ocr = '''
ENJOY SHOPPING
4111 1111 1111 1111
VALID THRU 08/29
''';
      expect(CardOcrParser.parse(ocr).cardholderName, isNull);
    });

    test('never picks issuer, network or back-of-card phrases as the name',
        () {
      const ocr = '''
KOTAK MAHINDRA
4111 1111 1111 1111
VALID THRU 08/29
CUSTOMER CARE
AUTHORIZED SIGNATURE
NOT TRANSFERABLE
''';
      expect(CardOcrParser.parse(ocr).cardholderName, isNull);
    });

    test('extracts labeled CVV from the back', () {
      const ocr = '''
4111 1111 1111 1111
VALID THRU 08/29
CVV: 123
''';
      expect(CardOcrParser.parse(ocr).cvv, '123');
    });

    test('extracts standalone 3-digit signature-panel CVV', () {
      const ocr = '''
AUTHORIZED SIGNATURE
842
4111 1111 1111 1111
VALID THRU 08/29
''';
      expect(CardOcrParser.parse(ocr).cvv, '842');
    });

    test('does not mistake PAN groups or expiry for the CVV', () {
      const ocr = '''
4111 1111 1111 1111
VALID THRU 08/29
''';
      expect(CardOcrParser.parse(ocr).cvv, isNull);
    });

    test('repairs OCR digit-lookalikes (O→0, I→1, S→5, B→8)', () {
      // 4111111111111111 misread on an embossed card.
      const ocr = '''
4II1 1111 1111 111I
VALID THRU 08/29
''';
      expect(CardOcrParser.parse(ocr).number, '4111111111111111');
    });

    test('joins a PAN split across two lines', () {
      const ocr = '''
4111 1111
1111 1111
VALID THRU 08/29
''';
      expect(CardOcrParser.parse(ocr).number, '4111111111111111');
    });

    test('rejects implausible expiry years (OCR noise)', () {
      const ocr = '''
4111 1111 1111 1111
01/99
''';
      // 2099 is outside any real card's validity window.
      expect(CardOcrParser.parse(ocr).expiryYear, isNull);
    });

    test('finds a mixed-case printed name below the expiry', () {
      const ocr = '''
4111 1111 1111 1111
VALID THRU 08/29
Yash Sharma
''';
      expect(CardOcrParser.parse(ocr).cardholderName, 'YASH SHARMA');
    });

    test('ignores digit runs failing Luhn', () {
      final parsed = CardOcrParser.parse('1234 5678 9012 3456');
      expect(parsed.number, isNull);
    });

    test('picks the later date when valid-from is also printed', () {
      final parsed =
          CardOcrParser.parse('4111111111111111\n01/24    08/29');
      expect(parsed.expiryMonth, 8);
      expect(parsed.expiryYear, 2029);
    });
  });
}
