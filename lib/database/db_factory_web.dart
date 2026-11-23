import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// على الويب نستخدم SQLite عبر WebAssembly مع تخزين دائم في IndexedDB داخل المتصفح،
/// ليعمل التطبيق بدون إنترنت على الآيفون بعد أول تحميل.
void configureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}

Future<String> resolveDatabasesPath() async => '/maintenance_tracker_db';
