import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// أسماء الجداول (متطابقة مع جداول Supabase).
abstract final class DbTables {
  static const String customers = 'customers';
  static const String entries = 'maintenance_entries';
  static const String settings = 'engineer_settings';
  static const String settlements = 'settlements';

  /// جدول المناطق المحفوظة محلياً.
  static const String areas = 'saved_areas';

  /// جدول محلي فقط لحفظ بيانات المزامنة (آخر رفع/سحب).
  static const String meta = 'sync_meta';

  /// الجداول المتزامنة مع السحابة بالترتيب الصحيح للرفع.
  static const List<String> synced = [customers, entries, settings, settlements];

  /// المفتاح الأساسي لكل جدول متزامن.
  static String primaryKey(String table) => table == settings ? 'user_id' : 'id';
}

/// قاعدة البيانات المحلية SQLite (Offline-First).
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _fileName = 'maintenance_tracker.db';
  static const int _version = 2;

  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _fileName),
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE ${DbTables.customers} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        client_number INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        area TEXT NOT NULL DEFAULT '',
        amount REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        start_month TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbTables.entries} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        account_month TEXT NOT NULL,
        is_advance INTEGER NOT NULL DEFAULT 0,
        amount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'unpaid',
        payment_method TEXT NOT NULL DEFAULT 'cash',
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbTables.settings} (
        user_id TEXT PRIMARY KEY,
        engineer_name TEXT NOT NULL DEFAULT '',
        base_salary REAL NOT NULL DEFAULT 0,
        commission_rate REAL NOT NULL DEFAULT 0,
        commission_basis TEXT NOT NULL DEFAULT 'total',
        dues_association REAL NOT NULL DEFAULT 0,
        dues_telecom REAL NOT NULL DEFAULT 0,
        dues_insurance REAL NOT NULL DEFAULT 0,
        carried_balance REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbTables.settlements} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        month TEXT NOT NULL,
        total_maintenance REAL NOT NULL DEFAULT 0,
        commission REAL NOT NULL DEFAULT 0,
        wallet_transfers REAL NOT NULL DEFAULT 0,
        salary_and_dues REAL NOT NULL DEFAULT 0,
        carried_in REAL NOT NULL DEFAULT 0,
        payment REAL NOT NULL DEFAULT 0,
        net_remaining REAL NOT NULL DEFAULT 0,
        approved INTEGER NOT NULL DEFAULT 0,
        approved_at TEXT,
        updated_at TEXT NOT NULL,
        dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbTables.areas} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbTables.meta} (
        user_id TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT,
        PRIMARY KEY (user_id, key)
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_customers_user ON ${DbTables.customers}(user_id)',
    );
    batch.execute(
      'CREATE INDEX idx_entries_user_month ON ${DbTables.entries}(user_id, account_month)',
    );
    batch.execute(
      'CREATE INDEX idx_settlements_user_month ON ${DbTables.settlements}(user_id, month)',
    );
    batch.execute(
      'CREATE INDEX idx_areas_user ON ${DbTables.areas}(user_id)',
    );

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE ${DbTables.customers} ADD COLUMN client_number INTEGER NOT NULL DEFAULT 1',
        );
      } catch (_) {}

      // ترقيم العملاء الحاليين تسلسلياً حسب تاريخ الإضافة
      final rows = await db.query(
        DbTables.customers,
        columns: ['id'],
        orderBy: 'created_at ASC',
      );
      for (var i = 0; i < rows.length; i++) {
        await db.update(
          DbTables.customers,
          {'client_number': i + 1},
          where: 'id = ?',
          whereArgs: [rows[i]['id']],
        );
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DbTables.areas} (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_areas_user ON ${DbTables.areas}(user_id)',
      );
    }
  }
}
