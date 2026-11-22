import 'package:material_ui/material_ui.dart';

import '../models/maintenance_entry.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'app_badge.dart';

/// بطاقة عميل في قائمة المتابعة.
class CustomerCard extends StatelessWidget {
  const CustomerCard({super.key, required this.item, required this.onTap});

  final CustomerEntry item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final customer = item.customer;
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
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
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
                            const Icon(Icons.location_on_outlined, size: 15, color: AppColors.secondary),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                customer.area.isEmpty ? 'بدون منطقة' : customer.area,
                                style: const TextStyle(fontSize: 13, color: AppColors.secondary),
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
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  AppBadge.status(entry.status),
                  AppBadge.method(entry.paymentMethod),
                  if (entry.isAdvance) AppBadge.advance(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
