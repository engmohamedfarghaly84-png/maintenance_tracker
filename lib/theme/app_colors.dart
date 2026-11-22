import 'package:material_ui/material_ui.dart';

/// ألوان الهوية البصرية لتطبيق متابعة الصيانة.
abstract final class AppColors {
  /// الأساسي Navy (#0F2A4A): شريط العنوان والأزرار الرئيسية.
  static const Color primary = Color(0xFF0F2A4A);

  /// الثانوي Slate (#4A5A70): النصوص الفرعية والأيقونات.
  static const Color secondary = Color(0xFF4A5A70);

  /// الذهبي (#F4B73C): العمولة، شارة «هولد»، وشارة «تحصيل مقدم».
  static const Color gold = Color(0xFFF4B73C);

  /// البرتقالي (#E8590C): شارة «لم يدفع» وصافي المبلغ المستحق.
  static const Color orange = Color(0xFFE8590C);

  /// الأخضر (#16A34A): شارة «دفع» وبطاقة «المحصّل».
  static const Color green = Color(0xFF16A34A);

  /// الخلفية العامة (#F5F7FA).
  static const Color background = Color(0xFFF5F7FA);

  /// البطاقات البيضاء.
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = primary;
  static const Color textSecondary = secondary;
  static const Color border = Color(0xFFDDE3EC);

  /// نصف قطر حواف البطاقات.
  static const double radius = 12;
}
