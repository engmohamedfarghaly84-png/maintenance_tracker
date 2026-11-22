import 'package:material_ui/material_ui.dart';

import '../database/local_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// شاشة البداية: الدخول بكلمة مرور التطبيق فقط (الافتراضية 1234).
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onUnlocked,
    this.repository,
  });

  final VoidCallback onUnlocked;
  final LocalRepository? repository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  late final LocalRepository _repo;
  bool _busy = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? LocalRepository();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  String _normalizeDigits(String input) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    final buffer = StringBuffer();
    for (final ch in input.trim().split('')) {
      final idx = arabicDigits.indexOf(ch);
      buffer.write(idx >= 0 ? idx : ch);
    }
    return buffer.toString();
  }

  Future<void> _unlock() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final savedPin = _normalizeDigits(await _repo.getAppPin());
      final enteredPin = _normalizeDigits(_password.text);
      if (!mounted) return;
      if (enteredPin == savedPin) {
        widget.onUnlocked();
      } else {
        showAppSnack(
          context,
          'كلمة مرور التطبيق غير صحيحة',
          color: AppColors.orange,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
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
                      child: const Icon(
                        Icons.handyman_rounded,
                        color: AppColors.gold,
                        size: 48,
                      ),
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
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              autofocus: true,
                              keyboardType: TextInputType.visiblePassword,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                              decoration: InputDecoration(
                                labelText: 'كلمة مرور التطبيق',
                                hintText: 'الافتراضية: 1234',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'يرجى إدخال كلمة مرور التطبيق';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _unlock(),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: _busy ? null : _unlock,
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
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'يعمل التطبيق بالكامل محلياً بدون إنترنت، ويمكنك تغيير كلمة المرور من الإعدادات.',
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
