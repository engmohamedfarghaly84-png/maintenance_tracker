import 'package:sqflite/sqflite.dart';

import '../models/customer.dart';
import '../models/engineer_settings.dart';
import '../models/enums.dart';
import '../models/ids.dart';
import '../models/maintenance_entry.dart';
import '../models/month_key.dart';
import '../models/saved_area.dart';
import '../models/settlement.dart';
import '../models/value_parsers.dart';
import '../utils/arabic_utils.dart';
import 'app_database.dart';

/// طبقة الوصول للبيانات المحلية. كل الاستعلامات معزولة بـ user_id.
class LocalRepository {
  LocalRepository({AppDatabase? database})
      : _appDatabase = database ?? AppDatabase.instance;

  /// المعرف المحلي الافتراضي عند العمل بدون حساب سحابي.
  static const String localUserId = 'local_engineer';

  /// نطاق الإعدادات العامة للتطبيق داخل جدول sync_meta.
  static const String appMetaScope = '_app_';
  static const String appPinKey = 'app_pin';
  static const String defaultAppPin = '1234';
  static const String customSupabaseUrlKey = 'supabase_url';
  static const String customSupabaseAnonKey = 'supabase_anon_key';

  final AppDatabase _appDatabase;

  Future<Database> get _db => _appDatabase.database;

  // ---------------------------------------------------------------------------
  // كلمة مرور التطبيق المحلية (PIN) وإعدادات التطبيق
  // ---------------------------------------------------------------------------

  Future<String> getAppPin() async {
    final saved = await getMeta(appMetaScope, appPinKey);
    final trimmed = saved?.trim() ?? '';
    return trimmed.isEmpty ? defaultAppPin : trimmed;
  }

  Future<void> setAppPin(String pin) async {
    await setMeta(appMetaScope, appPinKey, pin.trim());
  }

  /// نقل أي بيانات محلية مسجلة تحت [localUserId] إلى حساب المهندس السحابي عند تسجيل الدخول الاختياري.
  Future<void> adoptLocalData(String cloudUserId) async {
    if (cloudUserId.isEmpty || cloudUserId == localUserId) return;
    final db = await _db;
    await db.transaction((txn) async {
      for (final table in [
        DbTables.customers,
        DbTables.entries,
        DbTables.settlements,
      ]) {
        await txn.update(
          table,
          {'user_id': cloudUserId, 'dirty': 1},
          where: 'user_id = ?',
          whereArgs: [localUserId],
        );
      }

      await txn.update(
        DbTables.areas,
        {'user_id': cloudUserId},
        where: 'user_id = ?',
        whereArgs: [localUserId],
      );

      final localSettings = await txn.query(
        DbTables.settings,
        where: 'user_id = ?',
        whereArgs: [localUserId],
        limit: 1,
      );
      if (localSettings.isNotEmpty) {
        final cloudSettings = await txn.query(
          DbTables.settings,
          where: 'user_id = ?',
          whereArgs: [cloudUserId],
          limit: 1,
        );
        final localRow = Map<String, Object?>.from(localSettings.first);
        final localUpdated = normalizeTimestamp(localRow['updated_at']);
        if (cloudSettings.isEmpty || localUpdated != epochIso) {
          localRow['user_id'] = cloudUserId;
          localRow['dirty'] = 1;
          await txn.insert(
            DbTables.settings,
            localRow,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await txn.delete(
          DbTables.settings,
          where: 'user_id = ?',
          whereArgs: [localUserId],
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // إعدادات المهندس
  // ---------------------------------------------------------------------------

  Future<EngineerSettings> getSettings(String userId) async {
    final db = await _db;
    final rows = await db.query(
      DbTables.settings,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isNotEmpty) return EngineerSettings.fromDb(rows.first);

    final defaults = EngineerSettings.defaults(userId);
    await db.insert(
      DbTables.settings,
      {...defaults.toDb(), 'dirty': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return defaults;
  }

  Future<void> saveSettings(EngineerSettings settings) async {
    final db = await _db;
    await db.insert(
      DbTables.settings,
      {...settings.copyWith(updatedAt: nowUtcIso()).toDb(), 'dirty': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------------------------------------------------------------------
  // المناطق المحفوظة (Saved Areas)
  // ---------------------------------------------------------------------------

  /// جلب المناطق المحفوظة مرتبة أبجدياً (مع دمج أي منطقة موجودة لدى العملاء تلقائياً).
  Future<List<SavedArea>> getSavedAreas(String userId) async {
    final db = await _db;
    final rows = await db.query(
      DbTables.areas,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final areas = rows.map(SavedArea.fromDb).toList();
    final existingNames = areas.map((a) => a.name.trim()).toSet();

    // استخراج المناطق الموجودة لدى العملاء غير المحذوفين وإضافتها إن لم تكن محفوظة
    final customerRows = await db.query(
      DbTables.customers,
      columns: ['area'],
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId],
    );
    final now = nowUtcIso();
    for (final cRow in customerRows) {
      final areaName = ((cRow['area'] as String?) ?? '').trim();
      if (areaName.isNotEmpty && !existingNames.contains(areaName)) {
        existingNames.add(areaName);
        final newArea = SavedArea(
          id: newId(),
          userId: userId,
          name: areaName,
          createdAt: now,
        );
        await db.insert(
          DbTables.areas,
          newArea.toDb(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        areas.add(newArea);
      }
    }

    areas.sort((a, b) => ArabicUtils.compareNormalized(a.name, b.name));
    return areas;
  }

  /// إضافة منطقة جديدة إلى جدول المناطق المحفوظة (إذا لم تكن موجودة).
  Future<SavedArea?> addSavedArea(String userId, String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return null;
    final db = await _db;
    final existing = await db.query(
      DbTables.areas,
      where: 'user_id = ? AND name = ?',
      whereArgs: [userId, name],
      limit: 1,
    );
    if (existing.isNotEmpty) return SavedArea.fromDb(existing.first);

    final area = SavedArea(
      id: newId(),
      userId: userId,
      name: name,
      createdAt: nowUtcIso(),
    );
    await db.insert(
      DbTables.areas,
      area.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return area;
  }

  /// حذف منطقة محفوظة من جدول المناطق.
  Future<void> deleteSavedArea(String userId, String areaId) async {
    final db = await _db;
    await db.delete(
      DbTables.areas,
      where: 'id = ? AND user_id = ?',
      whereArgs: [areaId, userId],
    );
  }

  // ---------------------------------------------------------------------------
  // العملاء
  // ---------------------------------------------------------------------------

  Future<List<Customer>> getCustomers(
    String userId, {
    bool includeDeleted = false,
  }) async {
    final db = await _db;
    final rows = await db.query(
      DbTables.customers,
      where: includeDeleted ? 'user_id = ?' : 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId],
      orderBy: 'client_number ASC, created_at ASC',
    );
    return rows.map(Customer.fromDb).toList();
  }

  /// الرقم الأصلي (التسلسلي) التالي المقترح لعميل جديد.
  Future<int> getNextClientNumber(String userId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT MAX(client_number) AS max_num FROM ${DbTables.customers} '
      'WHERE user_id = ? AND is_deleted = 0',
      [userId],
    );
    final maxNum = rows.isEmpty ? 0 : parseInt(rows.first['max_num']);
    return maxNum + 1;
  }

  Future<void> saveCustomer(Customer customer) async {
    final db = await _db;
    await db.insert(
      DbTables.customers,
      {...customer.copyWith(updatedAt: nowUtcIso()).toDb(), 'dirty': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (customer.area.trim().isNotEmpty) {
      await addSavedArea(customer.userId, customer.area);
    }
  }

  /// حذف ناعم للعميل وسجلاته من الشهر المحدد وما بعده (مع الإبقاء على السجل التاريخي).
  Future<void> softDeleteCustomer(
    String userId,
    String customerId,
    String fromMonthKey,
  ) async {
    final db = await _db;
    final now = nowUtcIso();
    await db.transaction((txn) async {
      await txn.update(
        DbTables.customers,
        {'is_deleted': 1, 'updated_at': now, 'dirty': 1},
        where: 'id = ? AND user_id = ?',
        whereArgs: [customerId, userId],
      );
      await txn.update(
        DbTables.entries,
        {'is_deleted': 1, 'updated_at': now, 'dirty': 1},
        where:
            'user_id = ? AND customer_id = ? AND account_month >= ? AND is_deleted = 0',
        whereArgs: [userId, customerId, fromMonthKey],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // سجلات الصيانة وتصفير بداية الشهر
  // ---------------------------------------------------------------------------

  Future<List<MaintenanceEntry>> getEntriesForMonth(
    String userId,
    String monthKey,
  ) async {
    final db = await _db;
    final rows = await db.query(
      DbTables.entries,
      where: 'user_id = ? AND account_month = ? AND is_deleted = 0',
      whereArgs: [userId, monthKey],
      orderBy: 'created_at ASC',
    );
    return rows.map(MaintenanceEntry.fromDb).toList();
  }

  /// المتأخرات والهولد حتى الشهر المحدد.
  Future<List<MaintenanceEntry>> getOutstandingEntries(
    String userId,
    String upToMonthKey,
  ) async {
    final db = await _db;
    final rows = await db.query(
      DbTables.entries,
      where:
          'user_id = ? AND account_month <= ? AND is_deleted = 0 AND status != ?',
      whereArgs: [userId, upToMonthKey, PaymentStatus.paid.code],
      orderBy: 'account_month ASC, created_at ASC',
    );
    return rows.map(MaintenanceEntry.fromDb).toList();
  }

  Future<void> saveEntry(MaintenanceEntry entry) async {
    final db = await _db;
    await db.insert(
      DbTables.entries,
      {...entry.copyWith(updatedAt: nowUtcIso()).toDb(), 'dirty': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// تصفير حسابات العملاء لبداية شهر جديد:
  /// تحويل حالة الدفع لجميع العملاء في الشهر المحدد إلى «لم يدفع» وتصفير مبلغ السداد النقدي للشهر،
  /// مع الإبقاء على أسماء العملاء وأرقامهم الأصلية ومناطقهم وقيم صيانتهم كما هي.
  Future<void> resetMonthAccounts(String userId, String monthKey) async {
    final db = await _db;
    final now = nowUtcIso();
    await db.transaction((txn) async {
      await txn.update(
        DbTables.entries,
        {
          'status': PaymentStatus.unpaid.code,
          'is_advance': 0,
          'updated_at': now,
          'dirty': 1,
        },
        where: 'user_id = ? AND account_month = ? AND is_deleted = 0',
        whereArgs: [userId, monthKey],
      );

      await txn.update(
        DbTables.settlements,
        {
          'payment': 0,
          'approved': 0,
          'approved_at': null,
          'updated_at': now,
          'dirty': 1,
        },
        where: 'user_id = ? AND month = ?',
        whereArgs: [userId, monthKey],
      );
    });
  }

  /// عند التحصيل المقدم: إلغاء سجل الشهر القادم غير المدفوع لنفس العميل (إن وُجد).
  Future<void> removeUnpaidRegularEntry(
    String userId,
    String customerId,
    String monthKey,
  ) async {
    final db = await _db;
    await db.update(
      DbTables.entries,
      {'is_deleted': 1, 'updated_at': nowUtcIso(), 'dirty': 1},
      where: 'user_id = ? AND customer_id = ? AND account_month = ? '
          'AND is_advance = 0 AND status != ? AND is_deleted = 0',
      whereArgs: [userId, customerId, monthKey, PaymentStatus.paid.code],
    );
  }

  /// توليد سجلات الشهر تلقائياً لقائمة العملاء الثابتة (بحالة «لم يدفع»).
  Future<int> generateMonthEntries(String userId, MonthKey month) async {
    final db = await _db;
    final customers = await getCustomers(userId);
    if (customers.isEmpty) return 0;

    final existing = await db.query(
      DbTables.entries,
      columns: ['id', 'customer_id', 'account_month', 'is_advance', 'is_deleted'],
      where: 'user_id = ? AND (account_month = ? OR account_month = ?)',
      whereArgs: [userId, month.key, month.previous.key],
    );

    final existingIds = existing.map((r) => r['id'] as String).toSet();
    final customersWithEntry = existing
        .where(
          (r) =>
              r['account_month'] == month.key && !parseBool(r['is_deleted']),
        )
        .map((r) => r['customer_id'] as String)
        .toSet();
    final prepaidCustomers = existing
        .where(
          (r) =>
              r['account_month'] == month.previous.key &&
              parseBool(r['is_advance']) &&
              !parseBool(r['is_deleted']),
        )
        .map((r) => r['customer_id'] as String)
        .toSet();

    final now = nowUtcIso();
    final batch = db.batch();
    var created = 0;

    for (final customer in customers) {
      if (customer.startMonthKey.compareTo(month) > 0) continue;
      final id = generatedEntryId(customer.id, month.key);
      if (existingIds.contains(id) ||
          customersWithEntry.contains(customer.id) ||
          prepaidCustomers.contains(customer.id)) {
        continue;
      }
      final entry = MaintenanceEntry(
        id: id,
        userId: userId,
        customerId: customer.id,
        accountMonth: month.key,
        amount: customer.amount,
        status: PaymentStatus.unpaid,
        paymentMethod: customer.paymentMethod,
        createdAt: now,
        updatedAt: now,
      );
      batch.insert(
        DbTables.entries,
        {...entry.toDb(), 'dirty': 1},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      created++;
    }

    if (created > 0) await batch.commit(noResult: true);
    return created;
  }

  // ---------------------------------------------------------------------------
  // التسويات
  // ---------------------------------------------------------------------------

  Future<Settlement?> getSettlement(String userId, String monthKey) async {
    final db = await _db;
    final rows = await db.query(
      DbTables.settlements,
      where: 'user_id = ? AND month = ?',
      whereArgs: [userId, monthKey],
      limit: 1,
    );
    return rows.isEmpty ? null : Settlement.fromDb(rows.first);
  }

  Future<void> saveSettlement(Settlement settlement) async {
    final db = await _db;
    await db.insert(
      DbTables.settlements,
      {...settlement.toDb(), 'updated_at': nowUtcIso(), 'dirty': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------------------------------------------------------------------
  // بيانات المزامنة
  // ---------------------------------------------------------------------------

  Future<String?> getMeta(String userId, String key) async {
    final db = await _db;
    final rows = await db.query(
      DbTables.meta,
      columns: ['value'],
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String userId, String key, String? value) async {
    final db = await _db;
    await db.insert(
      DbTables.meta,
      {'user_id': userId, 'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> getRows(
    String table,
    String userId, {
    bool onlyDirty = false,
  }) async {
    final db = await _db;
    return db.query(
      table,
      where: onlyDirty ? 'user_id = ? AND dirty = 1' : 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> markClean(String table, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final db = await _db;
    final pk = DbTables.primaryKey(table);
    final batch = db.batch();
    for (final row in rows) {
      batch.update(
        table,
        {'dirty': 0},
        where: '$pk = ? AND updated_at = ?',
        whereArgs: [row[pk], row['updated_at']],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<bool> mergeRemoteRow(String table, Map<String, Object?> row) async {
    final db = await _db;
    final pk = DbTables.primaryKey(table);
    final local = await db.query(
      table,
      columns: ['updated_at', 'dirty'],
      where: '$pk = ?',
      whereArgs: [row[pk]],
      limit: 1,
    );

    if (local.isNotEmpty) {
      final localUpdated =
          DateTime.parse(normalizeTimestamp(local.first['updated_at']));
      final remoteUpdated =
          DateTime.parse(normalizeTimestamp(row['updated_at']));
      if (!remoteUpdated.isAfter(localUpdated)) return false;
    }

    await db.insert(
      table,
      {...row, 'dirty': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  Future<void> replaceAllForUser(
    String userId,
    Map<String, List<Map<String, Object?>>> data,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final table in DbTables.synced) {
        await txn.delete(table, where: 'user_id = ?', whereArgs: [userId]);
        for (final row in data[table] ?? const <Map<String, Object?>>[]) {
          await txn.insert(
            table,
            {...row, 'dirty': 0},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}
