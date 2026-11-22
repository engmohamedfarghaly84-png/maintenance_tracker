import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// معرف عشوائي جديد (UUID v4).
String newId() => _uuid.v4();

/// معرف ثابت لسجل الصيانة الشهري المولد تلقائياً لعميل معين،
/// حتى لا تتكرر السجلات عند التوليد من أكثر من جهاز.
String generatedEntryId(String customerId, String monthKey) =>
    _uuid.v5(Namespace.url.value, 'entry:$customerId:$monthKey');

/// معرف ثابت لتسوية شهر معين لكل مهندس.
String settlementId(String userId, String monthKey) =>
    _uuid.v5(Namespace.url.value, 'settlement:$userId:$monthKey');
