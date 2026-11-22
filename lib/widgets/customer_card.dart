import 'package:material_ui/material_ui.dart';

import '../models/enums.dart';
import '../models/maintenance_entry.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'app_badge.dart';

/// بطاقة عميل في قائمة المتابعة:
/// - تعرض الرقم الأصلي كشارة رقمية واضحة بجانب اسم العميل (مثل #1).
/// - نظيفة بدون أي أزرار أو أيقونات واتساب.
/// - تحتوي على أزرار تحصيل سريع بضغطة واحدة (كاش / محفظة) فقط.
class CustomerCard extends StatelessWidget {
  const CustomerCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onQuickCollect,
  });

  final CustomerEntry item;
  final VoidCallback onTap;
  final ValueChanged<PaymentMethod> onQuickCollect;

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final customer = item.customer;
    final isPaidCash = entry.status == PaymentStatus.paid &&
        entry.paymentMethod == PaymentMethod.cash;
    final isPaidWallet = entry.status == PaymentStatus.paid &&
        entry.paymentMethod == PaymentMethod.wallet;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radius),
        side: BorderSide(
          color: entry.isAdvance ? AppColors.gold : AppColors.border,
          width: entry.isAdvance ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // شارة الرقم الأصلي للعميل (#1)
                  Container(
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#${customer.clientNumber}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                customer.area.isEmpty ? 'بدون منطقة' : customer.area,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.secondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoney(entry.amount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const Text(
                        'قيمة الصيانة',
                        style: TextStyle(fontSize: 11, color: AppColors.secondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AppBadge.status(entry.status),
                        AppBadge.method(entry.paymentMethod),
                        if (entry.isAdvance) AppBadge.advance(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // أزرار التحصيل السريع بضغطة واحدة (كاش / محفظة)
                  _QuickCollectButton(
                    label: 'كاش',
                    icon: Icons.payments_outlined,
                    active: isPaidCash,
                    onTap: () => onQuickCollect(PaymentMethod.cash),
                  ),
                  const SizedBox(width: 6),
                  _QuickCollectButton(
                    label: 'محفظة',
                    icon: Icons.account_balance_wallet_outlined,
                    active: isPaidWallet,
                    onTap: () => onQuickCollect(PaymentMethod.wallet),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCollectButton extends StatelessWidget {
  const _QuickCollectButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.green : AppColors.background;
    final fg = active ? Colors.white : AppColors.primary;
    final border = active ? AppColors.green : AppColors.border;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.check_circle_rounded : icon,
                size: 14,
                color: fg,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
