import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// خدمة تسجيل الدخول وإنشاء الحسابات عبر Supabase Auth.
abstract final class AuthService {
  static SupabaseClient get _client {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) {
      throw const AuthException(
        'لم يتم ضبط بيانات الربط مع Supabase في ملف supabase_config.dart',
      );
    }
    return client;
  }

  static User? get currentUser => SupabaseConfig.clientOrNull?.auth.currentUser;

  static Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// يعيد true إذا تم تسجيل الدخول مباشرة، و false إذا كان الحساب يحتاج تأكيد البريد.
  static Future<bool> signUp(String email, String password) async {
    final response = await _client.auth.signUp(email: email.trim(), password: password);
    return response.session != null;
  }

  static Future<void> signOut() async {
    await SupabaseConfig.clientOrNull?.auth.signOut();
  }

  /// ترجمة رسائل الخطأ الشائعة إلى العربية.
  static String friendlyMessage(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      }
      if (message.contains('already registered') || message.contains('already exists')) {
        return 'هذا البريد الإلكتروني مسجل بالفعل، يمكنك تسجيل الدخول مباشرة';
      }
      if (message.contains('email not confirmed')) {
        return 'يرجى تأكيد البريد الإلكتروني من الرسالة المرسلة إليك أولاً';
      }
      if (message.contains('password')) {
        return 'كلمة المرور ضعيفة، يجب ألا تقل عن 6 أحرف';
      }
      if (message.contains('rate limit')) {
        return 'محاولات كثيرة، يرجى المحاولة بعد قليل';
      }
      return error.message;
    }
    return 'تعذر الاتصال بالخادم، تحقق من اتصال الإنترنت';
  }
}
