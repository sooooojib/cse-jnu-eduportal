class BangladeshiPhoneResult {
  final bool isValid;
  final String raw;
  final String national; // 01XXXXXXXXX
  final String international; // +8801XXXXXXXXX
  final String whatsAppNumber; // 8801XXXXXXXXX
  final String operator;
  final String? error;

  const BangladeshiPhoneResult({
    required this.isValid,
    required this.raw,
    this.national = '',
    this.international = '',
    this.whatsAppNumber = '',
    this.operator = 'Unknown',
    this.error,
  });

  @override
  String toString() =>
      'BangladeshiPhoneResult(isValid: $isValid, national: $national, operator: $operator, error: $error)';
}

/// Authoritative utility for validating, formatting and normalizing
/// Bangladeshi mobile phone numbers across all authorized operators.
class BangladeshiPhoneUtils {
  BangladeshiPhoneUtils._();

  static const Map<String, String> operatorPrefixMap = {
    '013': 'Grameenphone',
    '017': 'Grameenphone',
    '014': 'Banglalink',
    '019': 'Banglalink',
    '016': 'Robi',
    '018': 'Robi',
    '015': 'Teletalk',
  };

  /// Strips formatting characters, spaces, dashes, parentheses.
  /// Retains only digits and an optional leading '+'.
  static String clean(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw.replaceAll(RegExp(r'[^0-9+]'), '').trim();
  }

  /// Authoritatively validates and normalizes any Bangladeshi phone input.
  static BangladeshiPhoneResult normalize(String? raw) {
    final cleaned = clean(raw);

    if (cleaned.isEmpty) {
      return BangladeshiPhoneResult(
        isValid: false,
        raw: raw ?? '',
        error: 'Phone number is empty.',
      );
    }

    // Strip leading '+'
    var digits = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;

    // Handle 880 or 88 country code
    if (digits.startsWith('880')) {
      digits = digits.substring(2); // Retain 01XXXXXXXXX
    } else if (digits.startsWith('88') && digits.length == 13) {
      digits = digits.substring(2);
    }

    if (digits.length != 11 || !digits.startsWith('01')) {
      return BangladeshiPhoneResult(
        isValid: false,
        raw: raw ?? '',
        error: 'Bangladeshi mobile number must be 11 digits starting with 01 (e.g. 017XXXXXXXX).',
      );
    }

    final prefix = digits.substring(0, 3);
    final operator = operatorPrefixMap[prefix];

    if (operator == null) {
      return BangladeshiPhoneResult(
        isValid: false,
        raw: raw ?? '',
        error: 'Invalid operator prefix "$prefix". Supported operators: 013, 014, 015, 016, 017, 018, 019.',
      );
    }

    final national = digits;
    final international = '+88$digits';
    final whatsAppNumber = '88$digits';

    return BangladeshiPhoneResult(
      isValid: true,
      raw: raw ?? '',
      national: national,
      international: international,
      whatsAppNumber: whatsAppNumber,
      operator: operator,
    );
  }

  /// Convenience check whether the given string is a valid BD mobile number.
  static bool isValid(String? raw) => normalize(raw).isValid;

  /// Returns 8801XXXXXXXXX suitable for wa.me deep links, or null if invalid.
  static String? toWhatsAppNumber(String? raw) {
    final res = normalize(raw);
    return res.isValid ? res.whatsAppNumber : null;
  }

  /// Returns standard formatted display number: 01712-345678
  static String formatDisplay(String? raw) {
    final res = normalize(raw);
    if (!res.isValid) return raw ?? '';
    final n = res.national;
    return '${n.substring(0, 5)}-${n.substring(5)}';
  }
}
