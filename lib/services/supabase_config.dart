import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// إعدادات الاتصال بـ Supabase.
///
/// الطريقة الأولى (الأسهل): ضع القيم مباشرة في [_manualUrl] و [_manualAnonKey].
/// الطريقة الثانية: مررها وقت التشغيل/البناء:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxxx
///
/// تجد القيم في لوحة Supabase: Project Settings > API.
/// (استخدم المفتاح العام anon / publishable فقط، ولا تضع مفتاح service_role في التطبيق).
abstract final class SupabaseConfig {
  // ======================= ضع بياناتك هنا =======================
  static const String _manualUrl = 'YOUR_SUPABASE_URL';
  static const String _manualAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  // ===============================================================

  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// رابط مشروع Supabase.
  static String get supabaseUrl => _envUrl.isNotEmpty ? _envUrl : _manualUrl;

  /// المفتاح العام (Anon / Publishable Key).
  static String get supabaseAnonKey =>
      _envAnonKey.isNotEmpty ? _envAnonKey : _manualAnonKey;

  static bool _initialized = false;

  /// هل تم إدخال بيانات اتصال حقيقية؟
  static bool get isConfigured =>
      supabaseUrl.startsWith('http') &&
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY';

  /// هل تمت تهيئة Supabase بنجاح؟
  static bool get isReady => _initialized;

  /// تهيئة Supabase عند تشغيل التطبيق (الجلسة تُحفظ تلقائياً على الجهاز).
  static Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint('SupabaseConfig: لم يتم ضبط رابط ومفتاح Supabase بعد.');
      return;
    }
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

  /// عميل Supabase (null إذا لم تتم التهيئة).
  static SupabaseClient? get clientOrNull =>
      _initialized ? Supabase.instance.client : null;
}
