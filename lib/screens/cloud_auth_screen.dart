import 'package:material_ui/material_ui.dart';

import '../services/app_controller.dart';
import '../services/auth_service.dart';
import '../services/supabase_config.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// شاشة اختيارية لتسجيل الدخول أو إنشاء حساب سحابي (Supabase) للمزامنة والنسخ الاحتياطي.
class CloudAuthScreen extends StatefulWidget {
  const CloudAuthScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CloudAuthScreen> createState() => _CloudAuthScreenState();
}

class _CloudAuthScreenState extends State<CloudAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final TextEditingController _urlController;
  late final TextEditingController _anonKeyController;

  bool _busy = false;
  bool _obscure = true;
  bool _showServerConfig = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: SupabaseConfig.isConfigured ? SupabaseConfig.supabaseUrl : '',
    );
    _anonKeyController = TextEditingController(
      text: SupabaseConfig.isConfigured ? SupabaseConfig.supabaseAnonKey : '',
    );
    _showServerConfig = !SupabaseConfig.isReady;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _urlController.dispose();
    _anonKeyController.dispose();
    super.dispose();
  }

  Future<bool> _ensureSupabaseReady() async {
    if (SupabaseConfig.isReady && !_showServerConfig) return true;
    final url = _urlController.text.trim();
    final key = _anonKeyController.text.trim();
    if (url.isNotEmpty && key.isNotEmpty) {
      final ok = await SupabaseConfig.saveCustomCredentials(
        url: url,
        anonKey: key,
      );
      if (ok) return true;
    }
    if (SupabaseConfig.isReady) return true;
    if (mounted) {
      setState(() => _showServerConfig = true);
      showAppSnack(
        context,
        'يرجى إدخال رابط مشروع Supabase والمفتاح العام (Anon Key) أولاً',
        color: AppColors.orange,
      );
    }
    return false;
  }

  Future<void> _submit({required bool signUp}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final ready = await _ensureSupabaseReady();
      if (!ready) return;

      if (signUp) {
        final loggedIn = await AuthService.signUp(_email.text, _password.text);
        if (!mounted) return;
        if (!loggedIn) {
          showAppSnack(
            context,
            'تم إنشاء الحساب بنجاح. يرجى تأكيد البريد الإلكتروني ثم تسجيل الدخول',
            color: AppColors.green,
          );
          return;
        }
      } else {
        await AuthService.signIn(_email.text, _password.text);
      }

      await widget.controller.refreshCloudIdentity();
      if (!mounted) return;
      showAppSnack(
        context,
        'تم ربط الحساب السحابي ومزامنة البيانات بنجاح',
        color: AppColors.green,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          AuthService.friendlyMessage(error),
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
      appBar: AppBar(title: const Text('الحساب السحابي والمزامنة (اختياري)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'تسجيل الدخول / إنشاء حساب سحابي',
            icon: Icons.cloud_sync_rounded,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'هذا الحساب اختياري تماماً ويُستخدم فقط لرفع نسخة احتياطية على السحابة أو استرجاع بياناتك عند تغيير الهاتف. سيتم نقل كافة بياناتك المحلية الحالية تلقائياً إلى حسابك عند تسجيل الدخول.',
                    style: TextStyle(fontSize: 13, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
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
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور السحابية',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').length < 6) {
                        return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => setState(
                        () => _showServerConfig = !_showServerConfig,
                      ),
                      icon: Icon(
                        _showServerConfig
                            ? Icons.expand_less_rounded
                            : Icons.settings_ethernet_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _showServerConfig
                            ? 'إخفاء إعدادات خادم Supabase'
                            : 'إعدادات رابط ومفتاح Supabase',
                      ),
                    ),
                  ),
                  if (_showServerConfig) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _urlController,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'SUPABASE_URL',
                        hintText: 'https://xxxx.supabase.co',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _anonKeyController,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'SUPABASE_ANON_KEY',
                        hintText: 'eyJhbGciOi...',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
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
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _submit(signUp: true),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('إنشاء حساب مهندس جديد'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
