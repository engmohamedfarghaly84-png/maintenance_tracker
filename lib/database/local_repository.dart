import 'package:sqflite/sqflite.dart';

import '../models/customer.dart';
import '../models/engineer_settings.dart';
import '../models/enums.dart';
import '../models/ids.dart';
import '../models/maintenance_entry.dart';
import '../models/month_key.dart';
import '../models/settlement.dart';
import '../models/value_parsers.dart';
import 'app_database.dart';

/// طبقة الوصول للبيانات المحلية. كل الاستعلامات معزولة بـ user_id.
class LocalRepository {
  LocalRepository({AppDatabase? database})
      : _appDatabase = database ?? AppDatabase.instance;

  final AppDatabase _appDatabase;

  Future<Database> get _db => _appDatabase.database;

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

    // إعدادات افتراضية بتاريخ قديم حتى لا تطغى على بيانات السحابة عند الاسترجاع.
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
      orderBy: 'created_at ASC',
    );
    return rows.map(Customer.fromDb).toList();
  }

  Future<void> saveCustomer(Customer customer) async {
    final db = await _db;
    await db.insert(
      DbTables.customers,
      {...customer.copyWith(updatedAt: nowUtcIso()).toDb(), 'dirty': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
  // سجلات الصيانة
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
  /// يتم تخطي العميل الذي سدد هذا الشهر مقدماً في الشهر السابق.
  /// يعيد عدد السجلات الجديدة.
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
        .where((r) => r['account_month'] == month.key && !parseBool(r['is_deleted']))
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

  /// تعليم الصفوف كمرفوعة (فقط إذا لم تتغير منذ الرفع).
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

  /// دمج صف قادم من السحابة (الأحدث يفوز). يعيد true إذا تم تطبيق التغيير.
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
      final localUpdated = DateTime.parse(normalizeTimestamp(local.first['updated_at']));
      final remoteUpdated = DateTime.parse(normalizeTimestamp(row['updated_at']));
      // آخر تعديل يفوز: لا نستبدل نسخة محلية أحدث (أو مساوية) للنسخة السحابية.
      if (!remoteUpdated.isAfter(localUpdated)) return false;
    }

    await db.insert(
      table,
      {...row, 'dirty': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  /// استبدال كافة بيانات المهندس المحلية ببيانات السحابة.
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
