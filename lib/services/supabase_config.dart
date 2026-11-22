import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/local_repository.dart';

/// إعدادات الاتصال بـ Supabase (اختيارية للمزامنة السحابية).
///
/// يعمل التطبيق بالكامل محلياً على SQLite بدون الحاجة لإعداد Supabase.
/// لتفعيل المزامنة السحابية الاختيارية، يمكنك وضع الرابط والمفتاح هنا أو إدخالهما من داخل إعدادات التطبيق.
abstract final class SupabaseConfig {
  // ======================= ضع بياناتك هنا (اختياري) =======================
  static const String _manualUrl = 'YOUR_SUPABASE_URL';
  static const String _manualAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  // =======================================================================

  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String? _runtimeUrl;
  static String? _runtimeAnonKey;
  static bool _initialized = false;

  /// رابط مشروع Supabase.
  static String get supabaseUrl {
    if ((_runtimeUrl ?? '').trim().isNotEmpty) return _runtimeUrl!.trim();
    return _envUrl.isNotEmpty ? _envUrl : _manualUrl;
  }

  /// المفتاح العام (Anon / Publishable Key).
  static String get supabaseAnonKey {
    if ((_runtimeAnonKey ?? '').trim().isNotEmpty) return _runtimeAnonKey!.trim();
    return _envAnonKey.isNotEmpty ? _envAnonKey : _manualAnonKey;
  }

  /// هل تم إدخال بيانات اتصال حقيقية؟
  static bool get isConfigured =>
      supabaseUrl.startsWith('http') &&
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY';

  /// هل تمت تهيئة Supabase بنجاح؟
  static bool get isReady => _initialized;

  /// تهيئة Supabase عند تشغيل التطبيق (إن وُجدت بيانات ربط).
  static Future<void> initialize() async {
    try {
      final repo = LocalRepository();
      _runtimeUrl = await repo.getMeta(
        LocalRepository.appMetaScope,
        LocalRepository.customSupabaseUrlKey,
      );
      _runtimeAnonKey = await repo.getMeta(
        LocalRepository.appMetaScope,
        LocalRepository.customSupabaseAnonKey,
      );
    } catch (_) {}

    if (!isConfigured || _initialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _initialized = true;
    } catch (error) {
      debugPrint('SupabaseConfig: فشل تهيئة Supabase: $error');
    }
  }

  /// حفظ بيانات الربط من داخل التطبيق وتهيئة Supabase فوراً.
  static Future<bool> saveCustomCredentials({
    required String url,
    required String anonKey,
  }) async {
    final cleanUrl = url.trim();
    final cleanKey = anonKey.trim();
    final repo = LocalRepository();
    await repo.setMeta(
      LocalRepository.appMetaScope,
      LocalRepository.customSupabaseUrlKey,
      cleanUrl,
    );
    await repo.setMeta(
      LocalRepository.appMetaScope,
      LocalRepository.customSupabaseAnonKey,
      cleanKey,
    );
    _runtimeUrl = cleanUrl;
    _runtimeAnonKey = cleanKey;

    if (_initialized) return true;
    if (!isConfigured) return false;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _initialized = true;
      return true;
    } catch (error) {
      debugPrint('SupabaseConfig.saveCustomCredentials error: $error');
      return false;
    }
  }

  /// عميل Supabase (null إذا لم تتم التهيئة).
  static SupabaseClient? get clientOrNull =>
      _initialized ? Supabase.instance.client : null;
}
