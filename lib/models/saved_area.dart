import 'value_parsers.dart';

/// منطقة محفوظة في قاعدة بيانات المناطق المحلية.
class SavedArea {
  const SavedArea({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String createdAt;

  Map<String, Object?> toDb() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'created_at': createdAt,
      };

  factory SavedArea.fromDb(Map<String, Object?> map) => SavedArea(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: (map['name'] as String?) ?? '',
        createdAt: normalizeTimestamp(map['created_at']),
      );
}
