import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_controller.dart';
import '../services/supabase_config.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// يحدد الشاشة المعروضة حسب حالة الجلسة (الجلسة محفوظة تلقائياً).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _subscription;
  User? _user;
  AppController? _controller;

  @override
  void initState() {
    super.initState();
    final client = SupabaseConfig.clientOrNull;
    if (client == null) return;
    _setUser(client.auth.currentUser);
    _subscription = client.auth.onAuthStateChange.listen(
      (state) {
        final user = state.session?.user;
        if (user?.id != _user?.id && mounted) {
          setState(() => _setUser(user));
        }
      },
      onError: (Object _) {
        // أخطاء تجديد الجلسة بدون إنترنت لا تُخرج المستخدم.
      },
    );
  }

  void _setUser(User? user) {
    _user = user;
    _controller?.dispose();
    _controller = null;
    if (user != null) {
      _controller = AppController(userId: user.id, email: user.email ?? '')..init();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const LoginScreen();
    return HomeScreen(key: ValueKey(controller.userId), controller: controller);
  }
}
