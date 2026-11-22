import 'customer.dart';
import 'enums.dart';
import 'value_parsers.dart';

/// سجل صيانة شهري لعميل داخل شهر محاسبي معين.
class MaintenanceEntry {
  const MaintenanceEntry({
    required this.id,
    required this.userId,
    required this.customerId,
    required this.accountMonth,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
    this.isAdvance = false,
    this.isDeleted = false,
  });

  final String id;
  final String userId;
  final String customerId;

  /// الشهر المحاسبي الذي يُحتسب فيه المبلغ (YYYY-MM).
  final String accountMonth;

  /// تحصيل مقدم عن الشهر القادم (يُحتسب ضمن الشهر الحالي).
  final bool isAdvance;
  final double amount;
  final PaymentStatus status;
  final PaymentMethod paymentMethod;
  final bool isDeleted;
  final String createdAt;
  final String updatedAt;

  bool get isPaid => status == PaymentStatus.paid;

  MaintenanceEntry copyWith({
    double? amount,
    PaymentStatus? status,
    PaymentMethod? paymentMethod,
    bool? isAdvance,
    bool? isDeleted,
    String? updatedAt,
  }) {
    return MaintenanceEntry(
      id: id,
      userId: userId,
      customerId: customerId,
      accountMonth: accountMonth,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isAdvance: isAdvance ?? this.isAdvance,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'user_id': userId,
        'customer_id': customerId,
        'account_month': accountMonth,
        'is_advance': isAdvance ? 1 : 0,
        'amount': amount,
        'status': status.code,
        'payment_method': paymentMethod.code,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory MaintenanceEntry.fromDb(Map<String, Object?> map) => MaintenanceEntry(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        customerId: map['customer_id'] as String,
        accountMonth: map['account_month'] as String,
        isAdvance: parseBool(map['is_advance']),
        amount: parseDouble(map['amount']),
        status: PaymentStatus.fromCode(map['status'] as String?),
        paymentMethod: PaymentMethod.fromCode(map['payment_method'] as String?),
        isDeleted: parseBool(map['is_deleted']),
        createdAt: normalizeTimestamp(map['created_at']),
        updatedAt: normalizeTimestamp(map['updated_at']),
      );
}

/// ربط سجل الصيانة ببيانات العميل للعرض.
class CustomerEntry {
  const CustomerEntry({required this.customer, required this.entry});

  final Customer customer;
  final MaintenanceEntry entry;
}
