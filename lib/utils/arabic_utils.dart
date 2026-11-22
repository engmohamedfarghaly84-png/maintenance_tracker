/// أدوات تطبيع النصوص العربية والفلترة بالحرف الأول (مع توحيد الألف أ/إ/آ/ا).
abstract final class ArabicUtils {
  /// تطبيع النص العربي لتوحيد همزات الألف (أ، إ، آ، ٱ -> ا) والتاء المربوطة والياء والأرقام.
  static String normalize(String input) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    final buffer = StringBuffer();
    for (final ch in input.trim().toLowerCase().split('')) {
      final digitIdx = arabicDigits.indexOf(ch);
      if (digitIdx >= 0) {
        buffer.write(digitIdx);
        continue;
      }
      switch (ch) {
        case 'أ':
        case 'إ':
        case 'آ':
        case 'ٱ':
          buffer.write('ا');
        case 'ة':
          buffer.write('ه');
        case 'ى':
          buffer.write('ي');
        case 'ؤ':
          buffer.write('و');
        case 'ئ':
          buffer.write('ي');
        // تجاهل التشكيل والمد
        case '\u0640':
        case '\u064B':
        case '\u064C':
        case '\u064D':
        case '\u064E':
        case '\u064F':
        case '\u0650':
        case '\u0651':
        case '\u0652':
          break;
        default:
          buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// هل يبدأ النص [target] بالحرف أو المقطع [query] بعد تطبيع الألف؟
  static bool startsWithNormalized(String target, String query) {
    final normQuery = normalize(query);
    if (normQuery.isEmpty) return true;
    final normTarget = normalize(target);
    return normTarget.startsWith(normQuery);
  }

  /// هل يحتوي النص [target] على [query] بعد التطبيع؟
  static bool containsNormalized(String target, String query) {
    final normQuery = normalize(query);
    if (normQuery.isEmpty) return true;
    final normTarget = normalize(target);
    return normTarget.contains(normQuery);
  }

  /// مقارنة نصين أبجدياً بعد التطبيع.
  static int compareNormalized(String a, String b) {
    final na = normalize(a);
    final nb = normalize(b);
    final cmp = na.compareTo(nb);
    return cmp != 0 ? cmp : a.compareTo(b);
  }
}
