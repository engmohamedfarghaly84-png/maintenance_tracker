import 'package:sqflite/sqflite.dart';

/// على المنصات غير الويب (Android / iOS) نستخدم مصنع sqflite الافتراضي.
void configureDatabaseFactory() {}

Future<String> resolveDatabasesPath() => getDatabasesPath();
