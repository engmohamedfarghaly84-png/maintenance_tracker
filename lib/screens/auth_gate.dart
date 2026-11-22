import 'package:material_ui/material_ui.dart';

import '../services/app_controller.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// بوابة الدخول المحلية للتطبيق:
/// تطلب كلمة مرور التطبيق (الافتراضية 1234) ثم تفتح الشاشة الرئيسية مباشرةً
/// للعمل محلياً بالكامل على SQLite دون أي قيود.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _unlocked = false;
  AppController? _controller;

  void _handleUnlocked() {
    final controller = AppController(onLockApp: _handleLockApp)..init();
    setState(() {
      _controller?.dispose();
      _controller = controller;
      _unlocked = true;
    });
  }

  void _handleLockApp() {
    setState(() {
      _unlocked = false;
      _controller?.dispose();
      _controller = null;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_unlocked || controller == null) {
      return LoginScreen(onUnlocked: _handleUnlocked);
    }
    return HomeScreen(controller: controller);
  }
}
