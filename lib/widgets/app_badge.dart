import 'package:material_ui/material_ui.dart';

import '../models/enums.dart';
import '../theme/app_colors.dart';

/// شارة ملونة صغيرة (Pill).
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  factory AppBadge.status(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return AppBadge(
          label: status.label,
          background: AppColors.green,
          foreground: Colors.white,
          icon: Icons.check_circle,
        );
      case PaymentStatus.unpaid:
        return AppBadge(
          label: status.label,
          background: AppColors.orange,
          foreground: Colors.white,
          icon: Icons.error_outline,
        );
      case PaymentStatus.hold:
        return AppBadge(
          label: status.label,
          background: AppColors.gold,
          foreground: AppColors.primary,
          icon: Icons.pause_circle_outline,
        );
    }
  }

  factory AppBadge.method(PaymentMethod method) => AppBadge(
        label: method.label,
        background: AppColors.secondary.withValues(alpha: 0.12),
        foreground: AppColors.secondary,
        icon: method == PaymentMethod.cash
            ? Icons.payments_outlined
            : Icons.account_balance_wallet_outlined,
      );

  factory AppBadge.advance() => const AppBadge(
        label: 'تحصيل مقدم من الشهر القادم',
        background: AppColors.gold,
        foreground: AppColors.primary,
        icon: Icons.fast_forward_rounded,
      );

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
