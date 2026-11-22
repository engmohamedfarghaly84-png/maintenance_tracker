import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import '../services/supabase_config.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// شاشة تسجيل دخول المهندس / إنشاء حساب جديد.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool signUp}) async {
    if (!SupabaseConfig.isReady) {
      showAppSnack(
        context,
        'يرجى ضبط SUPABASE_URL و SUPABASE_ANON_KEY في ملف supabase_config.dart أولاً',
        color: AppColors.orange,
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      if (signUp) {
        final loggedIn = await AuthService.signUp(_email.text, _password.text);
        if (!mounted) return;
        if (!loggedIn) {
          showAppSnack(
            context,
            'تم إنشاء الحساب بنجاح. يرجى تأكيد البريد الإلكتروني ثم تسجيل الدخول',
            color: AppColors.green,
          );
        }
      } else {
        await AuthService.signIn(_email.text, _password.text);
      }
    } catch (error) {
      if (mounted) {
        showAppSnack(context, AuthService.friendlyMessage(error), color: AppColors.orange);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = SupabaseConfig.isReady;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.handyman_rounded, color: AppColors.gold, size: 48),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'متابعة الصيانة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const Text(
                    'تسجيل دخول المهندس',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 24),
                  if (!configured) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppColors.radius),
                        border: Border.all(color: AppColors.orange),
                      ),
                      child: const Text(
                        'لم يتم ضبط بيانات الربط مع Supabase بعد.\n'
                        'أدخل SUPABASE_URL و SUPABASE_ANON_KEY في الملف:\n'
                        'lib/services/supabase_config.dart',
                        style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'البريد الإلكتروني',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                              ),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                                if (!v.contains('@') || !v.contains('.')) {
                                  return 'صيغة البريد الإلكتروني غير صحيحة';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              textDirection: TextDirection.ltr,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (value) {
                                if ((value ?? '').length < 6) {
                                  return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _submit(signUp: false),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _busy ? null : () => _submit(signUp: false),
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: const Text('تسجيل الدخول'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => _submit(signUp: true),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('إنشاء حساب مهندس جديد'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'يتم حفظ الجلسة تلقائياً، وتعمل البيانات بدون إنترنت وتُزامن عند الاتصال.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
