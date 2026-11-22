import 'package:material_ui/material_ui.dart';

import '../models/month_key.dart';
import '../theme/app_colors.dart';

/// شريط تحديد الشهر مع أزرار الشهر السابق والقادم.
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    this.onTapCurrent,
  });

  final MonthKey month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onTapCurrent;

  @override
  Widget build(BuildContext context) {
    final isCurrent = month.isCurrent;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          // في اتجاه RTL: الزر الأول يظهر يميناً (الشهر السابق).
          _NavButton(
            icon: Icons.chevron_right_rounded,
            label: 'شهر ${month.previous.month}',
            tooltip: 'الشهر السابق',
            onTap: onPrevious,
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppColors.radius),
              onTap: isCurrent ? null : onTapCurrent,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      month.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      isCurrent ? 'الشهر الحالي' : 'اضغط للعودة للشهر الحالي',
                      style: TextStyle(
                        fontSize: 11,
                        color: isCurrent ? AppColors.green : AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _NavButton(
            icon: Icons.chevron_left_rounded,
            label: 'شهر ${month.next.month}',
            tooltip: 'الشهر القادم',
            onTap: onNext,
            iconFirst: false,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.iconFirst = true,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool iconFirst;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: AppColors.primary, size: 26);
    final text = Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.secondary,
      ),
    );
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppColors.radius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: iconFirst ? [iconWidget, text] : [text, iconWidget],
          ),
        ),
      ),
    );
  }
}
