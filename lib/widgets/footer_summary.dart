import 'package:material_ui/material_ui.dart';

import '../services/finance_calculator.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// الملخص السفلي الثابت للشاشة الرئيسية.
class FooterSummary extends StatelessWidget {
  const FooterSummary({super.key, required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.radius)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _line('إجمالي الصيانة المدفوع', summary.collected, AppColors.green),
              const SizedBox(height: 4),
              _line('المتبقي غير المدفوع', summary.uncollected, AppColors.orange),
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _box(
                      title: 'العمولة (${formatNumber(summary.commissionRate)}%)',
                      value: summary.commission,
                      background: AppColors.gold,
                      foreground: AppColors.primary,
                      icon: Icons.workspace_premium_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _box(
                      title: 'الباقي',
                      value: summary.remainder,
                      background: AppColors.primary,
                      foreground: Colors.white,
                      icon: Icons.account_balance_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ),
        Text(
          formatMoney(value),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  Widget _box({
    required String title,
    required double value,
    required Color background,
    required Color foreground,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: foreground),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    formatMoney(value),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
