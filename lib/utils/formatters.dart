import 'package:intl/intl.dart';

final NumberFormat _moneyFormat = NumberFormat('#,##0.##', 'en');

/// تنسيق المبلغ بالجنيه المصري. مثال: 1,250 ج.م
String formatMoney(double value) => '${_moneyFormat.format(value)} ج.م';

/// تنسيق رقم بدون عملة.
String formatNumber(double value) => _moneyFormat.format(value);

/// تنسيق التاريخ والوقت. مثال: 2026/11/22 - 06:30 م
String formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final date = DateFormat('yyyy/MM/dd', 'en').format(local);
  final time = DateFormat('hh:mm', 'en').format(local);
  final period = local.hour < 12 ? 'ص' : 'م';
  return '$date - $time $period';
}

/// تحويل النص المدخل إلى رقم (يدعم الأرقام العربية والفواصل).
double parseAmount(String input) {
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final char in input.trim().split('')) {
    final index = arabicDigits.indexOf(char);
    if (index >= 0) {
      buffer.write(index);
    } else if (char == '٫') {
      buffer.write('.');
    } else if (char != ',' && char != '٬') {
      buffer.write(char);
    }
  }
  return double.tryParse(buffer.toString()) ?? 0;
}

/// عرض الرقم في حقل الإدخال بدون أصفار زائدة.
String amountToInput(double value) {
  if (value == 0) return '';
  return value == value.roundToDouble() ? value.toInt().toString() : value.toString();
}
