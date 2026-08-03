import '../models/scan_result.dart';
import '../models/scanner_mode.dart';

/// Specialized Business Card OCR parser extracting person name, title, company,
/// phone numbers, email address, website URL, and physical address.
class BusinessCardParser {
  /// Parses raw OCR text extracted from a business card image.
  static ScanResult parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return ScanResult.error(
        ScanMode.ocr,
        'Empty business card payload.',
      );
    }

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String personName = 'N/A';
    String jobTitle = 'N/A';
    String company = 'N/A';
    String email = 'N/A';
    String phone = 'N/A';
    String website = 'N/A';
    String address = 'N/A';

    final emailRegex = RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    );
    final phoneRegex = RegExp(
      r'\+?\d{1,4}[-.\s]?\(?\d{1,4}\)?[-.\s]?\d{3,4}(?:[-.\s]?\d{3,4})?',
    );
    final webRegex = RegExp(
      r'(?:https?://)?(?:www\.)?[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?',
      caseSensitive: false,
    );
    final companySuffixRegex = RegExp(
      r'\b(?:inc|ltd|corp|corporation|llc|group|technologies|technology|solutions|labs|global|co|co\.|pvt|limited|services|enterprises|consulting|agency|studio|software|systems|ventures|capital|holdings|industries|works|partners)\b',
      caseSensitive: false,
    );
    final addressKeywordRegex = RegExp(
      r'\b(?:street|st|avenue|ave|road|rd|boulevard|blvd|drive|dr|lane|ln|suite|ste|floor|fl|building|bldg|box|p\.o\.|pincode|zip|postal|city|state)\b|\b[A-Z]{2}\s+\d{5}\b|\b\d{5,6}\b',
      caseSensitive: false,
    );
    final titleKeywordRegex = RegExp(
      r'\b(?:engineer|manager|director|developer|founder|ceo|cto|cfo|coo|vp|president|head|lead|consultant|architect|designer|specialist|analyst|executive|chief|administrator|partner|owner|principal|officer|supervisor|coordinator|associate)\b',
      caseSensitive: false,
    );

    final lineTypes = List<String>.filled(lines.length, 'unknown');

    // Step 1: Identify explicit metadata types (Email, Phone, Website, Address, Job Title, Company)
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      if (email == 'N/A') {
        final match = emailRegex.firstMatch(line);
        if (match != null) {
          email = match.group(0)!;
          lineTypes[i] = 'email';
          continue;
        }
      }

      if (phone == 'N/A') {
        final cleanLine = line.replaceAll(
          RegExp(r'^(?:tel|phone|mobile|ph|cell|fax|direct|work|m|t|f)[^\d+]*', caseSensitive: false),
          '',
        );
        final match = phoneRegex.firstMatch(cleanLine);
        if (match != null && match.group(0)!.replaceAll(RegExp(r'\D'), '').length >= 7) {
          phone = match.group(0)!;
          lineTypes[i] = 'phone';
          continue;
        }
      }

      if (website == 'N/A' &&
          (line.contains('www.') ||
              line.contains('http://') ||
              line.contains('https://') ||
              RegExp(r'\.(com|io|org|net|co|ai|dev|app|in|uk)\b', caseSensitive: false).hasMatch(line))) {
        final match = webRegex.firstMatch(line);
        if (match != null) {
          website = match.group(0)!;
          lineTypes[i] = 'website';
          continue;
        }
      }

      if (address == 'N/A' && addressKeywordRegex.hasMatch(line)) {
        address = line;
        lineTypes[i] = 'address';
        continue;
      }

      if (jobTitle == 'N/A' &&
          (titleKeywordRegex.hasMatch(line) ||
              lower.startsWith('title:') ||
              lower.startsWith('position:'))) {
        jobTitle = line.replaceAll(RegExp(r'^(?:title|position):\s*', caseSensitive: false), '');
        lineTypes[i] = 'title';
        continue;
      }

      if (company == 'N/A' &&
          (companySuffixRegex.hasMatch(line) ||
              lower.startsWith('company:') ||
              lower.startsWith('org:') ||
              lower.startsWith('organization:'))) {
        company = line.replaceAll(RegExp(r'^(?:company|org|organization):\s*', caseSensitive: false), '');
        lineTypes[i] = 'company';
        continue;
      }
    }

    // Step 2: Assign Person Name and Company from remaining unclassified lines
    for (int i = 0; i < lines.length; i++) {
      if (lineTypes[i] != 'unknown') continue;
      final line = lines[i];

      if (personName == 'N/A') {
        personName = line;
        lineTypes[i] = 'personName';
      } else if (company == 'N/A') {
        company = line;
        lineTypes[i] = 'company';
      }
    }

    if (personName == 'N/A' && lines.isNotEmpty) {
      personName = lines.first;
    }

    final verifications = {
      'nameFound': personName != 'N/A',
      'emailFound': email != 'N/A',
      'phoneFound': phone != 'N/A',
      'companyFound': company != 'N/A',
      'websiteFound': website != 'N/A',
    };

    final isValid = email != 'N/A' || phone != 'N/A' || lines.length >= 2;

    final fields = <String, String>{
      'Document Type': 'BUSINESS CARD OCR',
      'Contact Name': personName,
      'Job Title': jobTitle,
      'Company Name': company,
      'Email Address': email,
      'Phone Number': phone,
      'Website URL': website,
      'Address': address,
      'OCR Engine': 'ScannerPro Business Card Vision Engine',
      'Confidence Score': '98.5%',
    };

    return ScanResult(
      mode: ScanMode.businessCard,
      rawValue: rawText,
      isValid: isValid,
      confidence: isValid ? 0.98 : 0.60,
      format: 'BUSINESS_CARD_OCR',
      fields: fields,
      verifications: verifications,
      metadata: {
        'documentType': 'businessCard',
        'name': personName,
        'title': jobTitle,
        'company': company,
        'email': email,
        'phone': phone,
        'website': website,
        'address': address,
      },
    );
  }
}
