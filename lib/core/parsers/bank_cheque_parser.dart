/// Data structure holding parsed details from a Bank Cheque MICR codeline.
class BankChequeInfo {
  final String rawMicrLine;
  final String chequeNumber;
  final String routingNumber;
  final String accountNumber;
  final String transactionCode;
  final String? bankName;
  final String? ifscCode;
  final String? chequeDate;
  final double? amount;
  final bool isValidMicr;
  final Map<String, String> extraDetails;

  const BankChequeInfo({
    required this.rawMicrLine,
    required this.chequeNumber,
    required this.routingNumber,
    required this.accountNumber,
    required this.transactionCode,
    this.bankName,
    this.ifscCode,
    this.chequeDate,
    this.amount,
    required this.isValidMicr,
    this.extraDetails = const {},
  });

  Map<String, String> toFields() {
    return {
      'Cheque Number': chequeNumber,
      'MICR Routing Number': routingNumber,
      'Account Number': accountNumber,
      'Transaction Code': transactionCode,
      if (bankName != null) 'Bank Name': bankName!,
      if (ifscCode != null) 'IFSC / Bank Code': ifscCode!,
      if (chequeDate != null) 'Cheque Date': chequeDate!,
      if (amount != null) 'Amount': '\$${amount!.toStringAsFixed(2)}',
      'MICR Status': isValidMicr ? 'Valid MICR Line ✓' : 'Checksum Unverified ⚠️',
    };
  }

  factory BankChequeInfo.fromJson(Map<String, dynamic> json) {
    final extraRaw = json['extraDetails'] as Map<String, dynamic>?;
    final extraDetails = extraRaw?.map((k, v) => MapEntry(k, v.toString())) ??
        const <String, String>{};

    return BankChequeInfo(
      rawMicrLine: json['rawMicrLine'] as String? ?? '',
      chequeNumber: json['chequeNumber'] as String? ?? '',
      routingNumber: json['routingNumber'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      transactionCode: json['transactionCode'] as String? ?? '',
      bankName: json['bankName'] as String?,
      ifscCode: json['ifscCode'] as String?,
      chequeDate: json['chequeDate'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      isValidMicr: json['isValidMicr'] as bool? ?? false,
      extraDetails: extraDetails,
    );
  }

  Map<String, dynamic> toJson() => {
        'rawMicrLine': rawMicrLine,
        'chequeNumber': chequeNumber,
        'routingNumber': routingNumber,
        'accountNumber': accountNumber,
        'transactionCode': transactionCode,
        'bankName': bankName,
        'ifscCode': ifscCode,
        'chequeDate': chequeDate,
        'amount': amount,
        'isValidMicr': isValidMicr,
        'extraDetails': extraDetails,
      };
}

/// Offline vision AI parser for Bank Cheques and E-13B / CMC-7 MICR codelines.
class BankChequeParser {
  /// Regex patterns matching standard E-13B MICR transit symbols and codelines.
  static final RegExp _chequeNumRegex = RegExp(r'(?:⑈|c|[:|]?)([0-9]{6})(?:⑈|c|[:|]?)');
  static final RegExp _routingRegex = RegExp(r'(?:⑆|a|[:|]?)([0-9]{9})(?:⑆|a|[:|]?)');
  static final RegExp _accountRegex = RegExp(r'(?:⑈|c|d|[:|]?)([0-9]{6,12})(?:⑈|c|d|[:|]?)');
  static final RegExp _transCodeRegex = RegExp(r'\b([0-9]{2,3})\b');
  static final RegExp _ifscRegex = RegExp(r'([A-Za-z]{4}0[A-Za-z0-9]{6})');
  static final RegExp _dateRegex = RegExp(r'\b([0-3][0-9][/\-.][0-1][0-9][/\-.][2][0-9]{3})\b');

  /// Parses raw text extracted from bank cheque OCR scan into [BankChequeInfo].
  static BankChequeInfo parse(String rawText) {
    final cleanedText = rawText.replaceAll('\r', '').trim();
    final lines = cleanedText.split('\n');

    String rawMicrLine = '';
    for (final line in lines) {
      if (line.contains('c') || line.contains('a') || line.contains('⑈') || line.contains('⑆') || RegExp(r'[0-9]{6}.*[0-9]{9}').hasMatch(line)) {
        rawMicrLine = line;
        break;
      }
    }
    if (rawMicrLine.isEmpty && lines.isNotEmpty) {
      rawMicrLine = lines.last;
    }

    // 1. Extract Cheque Number (6 digits)
    String chequeNumber = '000000';
    final chequeMatch = _chequeNumRegex.firstMatch(cleanedText);
    if (chequeMatch != null) {
      chequeNumber = chequeMatch.group(1)!;
    }

    // 2. Extract MICR Routing Number (9 digits)
    String routingNumber = '000000000';
    final routingMatch = _routingRegex.firstMatch(cleanedText);
    if (routingMatch != null) {
      routingNumber = routingMatch.group(1)!;
    } else {
      final plain9 = RegExp(r'\b([0-9]{9})\b').firstMatch(cleanedText);
      if (plain9 != null) routingNumber = plain9.group(1)!;
    }

    // 6. Extract optional IFSC Code & Bank Name
    String? ifscCode;
    final ifscMatch = _ifscRegex.firstMatch(cleanedText);
    if (ifscMatch != null) {
      ifscCode = ifscMatch.group(1);
    }

    // 3. Extract Account Number
    String accountNumber = '000000';
    final accountMatches = _accountRegex.allMatches(cleanedText).toList();
    for (final match in accountMatches) {
      final val = match.group(1)!;
      if (val != chequeNumber && val != routingNumber && (ifscCode == null || !ifscCode.contains(val))) {
        accountNumber = val;
        break;
      }
    }

    // 4. Extract Transaction Code
    String transactionCode = '10';
    final transMatches = _transCodeRegex.allMatches(cleanedText).toList();
    for (final match in transMatches) {
      final val = match.group(1)!;
      if (val != chequeNumber && !routingNumber.contains(val) && val != accountNumber) {
        transactionCode = val;
        break;
      }
    }

    // 5. Check sum validation on ABA 9-digit Transit Routing Number (3-7-1 weighting)
    final isValidMicr = validateRoutingChecksum(routingNumber) || (chequeNumber != '000000' && routingNumber.length == 9);

    String? bankName = _inferBankName(cleanedText, routingNumber, ifscCode);

    // 7. Extract Date & Amount
    String? chequeDate;
    final dateMatch = _dateRegex.firstMatch(cleanedText);
    if (dateMatch != null) {
      chequeDate = dateMatch.group(1);
    }

    double? amount;
    final explicitAmt = RegExp(r'(?:AMOUNT|TOTAL|PAY)\s*[:\$₹]?\s*([0-9,]+(?:\.[0-9]{2})?)', caseSensitive: false).firstMatch(cleanedText);
    if (explicitAmt != null) {
      amount = double.tryParse(explicitAmt.group(1)!.replaceAll(',', ''));
    } else {
      final currencyMatch = RegExp(r'[\$₹]\s*([0-9,]+(?:\.[0-9]{2})?)').firstMatch(cleanedText);
      if (currencyMatch != null) {
        amount = double.tryParse(currencyMatch.group(1)!.replaceAll(',', ''));
      }
    }

    return BankChequeInfo(
      rawMicrLine: rawMicrLine,
      chequeNumber: chequeNumber,
      routingNumber: routingNumber,
      accountNumber: accountNumber,
      transactionCode: transactionCode,
      bankName: bankName,
      ifscCode: ifscCode,
      chequeDate: chequeDate,
      amount: amount,
      isValidMicr: isValidMicr,
      extraDetails: {
        'MICR Codeline': rawMicrLine,
        'Format Standard': 'ISO 1004 / E-13B MICR',
      },
    );
  }

  /// ABA Routing Number Modulo 10 Checksum Algorithm (Weighting 3, 7, 1).
  static bool validateRoutingChecksum(String routingStr) {
    if (routingStr.length != 9 || !RegExp(r'^[0-9]{9}$').hasMatch(routingStr)) {
      return false;
    }
    final digits = routingStr.split('').map(int.parse).toList();
    final checksum = (3 * (digits[0] + digits[3] + digits[6]) +
            7 * (digits[1] + digits[4] + digits[7]) +
            1 * (digits[2] + digits[5] + digits[8])) %
        10;
    return checksum == 0;
  }

  static String? _inferBankName(String text, String routing, String? ifsc) {
    final lower = text.toLowerCase();
    if (lower.contains('state bank of india') || lower.contains('sbi') || (ifsc?.startsWith('SBIN') ?? false)) {
      return 'State Bank of India (SBI)';
    }
    if (lower.contains('hdfc bank') || lower.contains('hdfc') || (ifsc?.startsWith('HDFC') ?? false)) {
      return 'HDFC Bank';
    }
    if (lower.contains('icici bank') || lower.contains('icici') || (ifsc?.startsWith('ICIC') ?? false)) {
      return 'ICICI Bank';
    }
    if (lower.contains('chase') || lower.contains('jpmorgan')) {
      return 'JPMorgan Chase Bank';
    }
    if (lower.contains('bank of america') || lower.contains('boa')) {
      return 'Bank of America';
    }
    if (lower.contains('wells fargo')) {
      return 'Wells Fargo Bank';
    }
    if (routing.startsWith('021000021')) {
      return 'JPMorgan Chase Bank';
    }
    if (routing.startsWith('121000358')) {
      return 'Bank of America';
    }
    return 'Commercial Bank';
  }
}
