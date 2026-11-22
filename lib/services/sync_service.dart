import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/local_repository.dart';
import '../models/value_parsers.dart';
import 'supabase_config.dart';

/// استثناء برسالة عربية جاهزة للعرض.
class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// مزامنة البيانات المحلية مع Supabase (رفع التغييرات ثم سحب الجديد).
class SyncService {
  SyncService(this._repo);

  final LocalRepository _repo;

  static const Set<String> _boolColumns = {'is_deleted', 'is_advance', 'approved'};
  static const Set<String> _timestampColumns = {'created_at', 'updated_at'};
  static const String metaLastUpload = 'last_upload';
  static const int _pageSize = 1000;

  Timer? _debounce;
  Future<bool>? _running;

  SupabaseClient _clientFor(String userId) {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) {
      throw const SyncException('لم يتم ضبط بيانات الربط مع Supabase بعد');
    }
    if (client.auth.currentUser?.id != userId) {
      throw const SyncException('انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى');
    }
    return client;
  }

  /// جدولة مزامنة تلقائية بعد أي تعديل محلي.
  void scheduleSync(String userId, {void Function(bool changed)? onDone}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () async {
      try {
        final changed = await syncNow(userId);
        onDone?.call(changed);
      } catch (_) {
        // بدون إنترنت: تبقى التغييرات محفوظة محلياً وتُرفع لاحقاً.
      }
    });
  }

  /// مزامنة فورية. تعيد true إذا وصلت بيانات جديدة من السحابة.
  Future<bool> syncNow(String userId) {
    final running = _running;
    if (running != null) return running;
    final future = _sync(userId);
    _running = future;
    return future.whenComplete(() => _running = null);
  }

  Future<bool> _sync(String userId) async {
    final client = _clientFor(userId);
    await _push(client, userId, onlyDirty: true);
    return _pull(client, userId);
  }

  /// رفع كافة البيانات فوراً إلى السحابة.
  Future<DateTime> uploadAll(String userId) async {
    final client = _clientFor(userId);
    await _run(() => _push(client, userId, onlyDirty: false));
    final now = DateTime.now();
    await _repo.setMeta(userId, metaLastUpload, now.toUtc().toIso8601String());
    return now;
  }

  /// استرجاع كافة بيانات المهندس من السحابة واستبدال البيانات المحلية.
  Future<int> restoreAll(String userId) async {
    final client = _clientFor(userId);
    return _run(() async {
      final data = <String, List<Map<String, Object?>>>{};
      var total = 0;
      for (final table in DbTables.synced) {
        final remote = await _fetch(client, table, userId, null);
        data[table] = remote.map((row) => _toLocal(row)).toList();
        total += remote.length;
        final maxTs = _maxTimestamp(data[table]!, null);
        if (maxTs != null) await _repo.setMeta(userId, _pullKey(table), maxTs);
      }
      await _repo.replaceAllForUser(userId, data);
      return total;
    });
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SyncException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SyncException('خطأ من قاعدة بيانات السحابة: ${e.message}');
    } on AuthException catch (e) {
      throw SyncException('خطأ في الجلسة: ${e.message}');
    } catch (_) {
      throw const SyncException('تعذر الاتصال بالسحابة، تحقق من اتصال الإنترنت');
    }
  }

  Future<void> _push(
    SupabaseClient client,
    String userId, {
    required bool onlyDirty,
  }) async {
    for (final table in DbTables.synced) {
      final rows = await _repo.getRows(table, userId, onlyDirty: onlyDirty);
      if (rows.isEmpty) continue;
      for (var i = 0; i < rows.length; i += 500) {
        final chunk = rows.sublist(i, i + 500 > rows.length ? rows.length : i + 500);
        await client
            .from(table)
            .upsert(chunk.map(_toRemote).toList(), onConflict: DbTables.primaryKey(table));
      }
      await _repo.markClean(table, rows);
    }
  }

  Future<bool> _pull(SupabaseClient client, String userId) async {
    var changed = false;
    for (final table in DbTables.synced) {
      final since = await _repo.getMeta(userId, _pullKey(table));
      final remote = await _fetch(client, table, userId, since);
      if (remote.isEmpty) continue;
      final localRows = remote.map((row) => _toLocal(row)).toList();
      for (final row in localRows) {
        if (await _repo.mergeRemoteRow(table, row)) changed = true;
      }
      final maxTs = _maxTimestamp(localRows, since);
      if (maxTs != null) await _repo.setMeta(userId, _pullKey(table), maxTs);
    }
    return changed;
  }

  Future<List<Map<String, dynamic>>> _fetch(
    SupabaseClient client,
    String table,
    String userId,
    String? since,
  ) async {
    final all = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      var query = client.from(table).select().eq('user_id', userId);
      if (since != null) query = query.gt('updated_at', since);
      final page = await query
          .order('updated_at', ascending: true)
          .range(from, from + _pageSize - 1);
      all.addAll(page);
      if (page.length < _pageSize) break;
      from += _pageSize;
    }
    return all;
  }

  String _pullKey(String table) => 'last_pull_$table';

  String? _maxTimestamp(List<Map<String, Object?>> rows, String? current) {
    var max = current == null ? null : DateTime.tryParse(current);
    for (final row in rows) {
      final ts = DateTime.tryParse('${row['updated_at']}');
      if (ts != null && (max == null || ts.isAfter(max))) max = ts;
    }
    return max?.toUtc().toIso8601String();
  }

  Map<String, Object?> _toRemote(Map<String, Object?> row) {
    final result = <String, Object?>{};
    row.forEach((key, value) {
      if (key == 'dirty') return;
      result[key] = _boolColumns.contains(key) ? parseBool(value) : value;
    });
    return result;
  }

  Map<String, Object?> _toLocal(Map<String, dynamic> row) {
    final result = <String, Object?>{};
    row.forEach((key, value) {
      if (_boolColumns.contains(key)) {
        result[key] = parseBool(value) ? 1 : 0;
      } else if (_timestampColumns.contains(key)) {
        result[key] = normalizeTimestamp(value);
      } else if (key == 'approved_at') {
        result[key] = normalizeNullableTimestamp(value);
      } else if (value is num) {
        result[key] = value.toDouble();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  void dispose() {
    _debounce?.cancel();
  }
}
