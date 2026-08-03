import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  group('BankChequeParser & MICR Codeline Unit Tests', () {
    test('1. Parses E-13B MICR Codeline with Cheque #, Routing #, Account #, Trans Code', () {
      const rawText = '''
c000123c 123456789a 001234c 10
PAY TO THE ORDER OF: John Doe
AMOUNT: \$1,250.00
DATE: 15/08/2026
BANK: JPMorgan Chase Bank
''';

      final chequeInfo = BankChequeParser.parse(rawText);

      expect(chequeInfo.chequeNumber, equals('000123'));
      expect(chequeInfo.routingNumber, equals('123456789'));
      expect(chequeInfo.accountNumber, equals('001234'));
      expect(chequeInfo.transactionCode, equals('10'));
      expect(chequeInfo.chequeDate, equals('15/08/2026'));
      expect(chequeInfo.amount, equals(1250.00));
      expect(chequeInfo.isValidMicr, isTrue);
    });

    test('2. Validates ABA Routing Number Modulo 10 Checksum', () {
      expect(BankChequeParser.validateRoutingChecksum('123456789'), isFalse);
      // Valid ABA routing number: 021000021 (JPMorgan Chase)
      // (3*0 + 7*2 + 1*1 + 3*0 + 7*0 + 1*0 + 3*0 + 7*2 + 1*1) = (14 + 1 + 14 + 1) = 30 -> 30 % 10 = 0 -> True
      expect(BankChequeParser.validateRoutingChecksum('021000021'), isTrue);
    });

    test('3. Parses Indian Bank Cheque with IFSC and SBI Bank Mapping', () {
      const rawText = '''
c123456c sbin0001234a 987654c 31
STATE BANK OF INDIA
BRANCH: BANGALORE MAIN
DATE: 20/08/2026
''';

      final chequeInfo = BankChequeParser.parse(rawText);

      expect(chequeInfo.chequeNumber, equals('123456'));
      expect(chequeInfo.accountNumber, equals('987654'));
      expect(chequeInfo.bankName, contains('State Bank of India'));
      expect(chequeInfo.chequeDate, equals('20/08/2026'));
    });

    test('4. Correctly classifies Bank Cheque document category via DocumentClassifier', () {
      const rawText = 'c000123c 123456789a 001234c 10 PAY TO THE ORDER OF ACME CORP';
      final result = DocumentClassifier.classify(rawText, mode: ScanMode.cheque);

      expect(result.category, equals(DocumentCategory.cheque));
      expect(result.confidence, greaterThanOrEqualTo(0.95));
      expect(result.detectedKeywords, contains('CHEQUE'));
    });
  });
}
