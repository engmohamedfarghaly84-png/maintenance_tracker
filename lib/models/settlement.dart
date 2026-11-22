import 'value_parsers.dart';

/// تسوية الحساب الشهري المعتمدة.
class Settlement {
  const Settlement({
    required this.id,
    required this.userId,
    required this.month,
    required this.totalMaintenance,
    required this.commission,
    required this.walletTransfers,
    required this.salaryAndDues,
    required this.carriedIn,
    required this.payment,
    required this.netRemaining,
    required this.approved,
    required this.updatedAt,
    this.approvedAt,
  });

  final String id;
  final String userId;
  final String month;
  final double totalMaintenance;
  final double commission;
  final double walletTransfers;
  final double salaryAndDues;

  /// الباقي عليّ المرحل إلى هذا الشهر.
  final double carriedIn;

  /// السداد.
  final double payment;

  /// صافي المتبقي النهائي.
  final double netRemaining;
  final bool approved;
  final String? approvedAt;
  final String updatedAt;

  Map<String, Object?> toDb() => {
        'id': id,
        'user_id': userId,
        'month': month,
        'total_maintenance': totalMaintenance,
        'commission': commission,
        'wallet_transfers': walletTransfers,
        'salary_and_dues': salaryAndDues,
        'carried_in': carriedIn,
        'payment': payment,
        'net_remaining': netRemaining,
        'approved': approved ? 1 : 0,
        'approved_at': approvedAt,
        'updated_at': updatedAt,
      };

  factory Settlement.fromDb(Map<String, Object?> map) => Settlement(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        month: map['month'] as String,
        totalMaintenance: parseDouble(map['total_maintenance']),
        commission: parseDouble(map['commission']),
        walletTransfers: parseDouble(map['wallet_transfers']),
        salaryAndDues: parseDouble(map['salary_and_dues']),
        carriedIn: parseDouble(map['carried_in']),
        payment: parseDouble(map['payment']),
        netRemaining: parseDouble(map['net_remaining']),
        approved: parseBool(map['approved']),
        approvedAt: normalizeNullableTimestamp(map['approved_at']),
        updatedAt: normalizeTimestamp(map['updated_at']),
      );
}
