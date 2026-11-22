/// يمثل شهراً محاسبياً (سنة + شهر) بصيغة مفتاح `YYYY-MM`.
class MonthKey implements Comparable<MonthKey> {
  const MonthKey(this.year, this.month);

  factory MonthKey.fromDate(DateTime date) => MonthKey(date.year, date.month);

  factory MonthKey.now() => MonthKey.fromDate(DateTime.now());

  factory MonthKey.parse(String key) {
    final parts = key.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null && month >= 1 && month <= 12) {
        return MonthKey(year, month);
      }
    }
    return MonthKey.now();
  }

  final int year;
  final int month;

  static const List<String> arabicMonthNames = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  String get key => '$year-${month.toString().padLeft(2, '0')}';

  String get monthName => arabicMonthNames[month - 1];

  /// مثال: شهر 11 - نوفمبر 2026
  String get label => 'شهر $month - $monthName $year';

  /// مثال: نوفمبر 2026
  String get shortLabel => '$monthName $year';

  MonthKey get next => month == 12 ? MonthKey(year + 1, 1) : MonthKey(year, month + 1);

  MonthKey get previous =>
      month == 1 ? MonthKey(year - 1, 12) : MonthKey(year, month - 1);

  bool get isCurrent => this == MonthKey.now();

  @override
  int compareTo(MonthKey other) =>
      year != other.year ? year.compareTo(other.year) : month.compareTo(other.month);

  @override
  bool operator ==(Object other) =>
      other is MonthKey && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => key;
}
