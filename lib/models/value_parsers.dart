/// أدوات مساعدة لتحويل القيم القادمة من SQLite أو Supabase بشكل آمن.
library;

const String epochIso = '1970-01-01T00:00:00.000Z';

double parseDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

bool parseBool(Object? value) =>
    value == true || value == 1 || value == '1' || value == 'true';

String nowUtcIso() => DateTime.now().toUtc().toIso8601String();

/// توحيد صيغة التاريخ (UTC ISO-8601) لتسهيل المقارنة بين الجهاز والسحابة.
String normalizeTimestamp(Object? value) {
  if (value == null) return epochIso;
  final parsed = DateTime.tryParse('$value');
  return parsed == null ? epochIso : parsed.toUtc().toIso8601String();
}

String? normalizeNullableTimestamp(Object? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse('$value');
  return parsed?.toUtc().toIso8601String();
}
