import 'enums.dart';
import 'month_key.dart';
import 'value_parsers.dart';

/// عميل ثابت ضمن قائمة عملاء المهندس.
class Customer {
  const Customer({
    required this.id,
    required this.userId,
    required this.clientNumber,
    required this.name,
    required this.area,
    required this.amount,
    required this.paymentMethod,
    required this.startMonth,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final String userId;

  /// الرقم الأصلي (التسلسلي) للعميل (مثل 1 -> #1).
  final int clientNumber;
  final String name;
  final String area;

  /// قيمة الصيانة الشهرية الافتراضية بالجنيه.
  final double amount;
  final PaymentMethod paymentMethod;

  /// أول شهر يظهر فيه العميل (YYYY-MM).
  final String startMonth;
  final bool isDeleted;
  final String createdAt;
  final String updatedAt;

  MonthKey get startMonthKey => MonthKey.parse(startMonth);

  Customer copyWith({
    int? clientNumber,
    String? name,
    String? area,
    double? amount,
    PaymentMethod? paymentMethod,
    bool? isDeleted,
    String? updatedAt,
  }) {
    return Customer(
      id: id,
      userId: userId,
      clientNumber: clientNumber ?? this.clientNumber,
      name: name ?? this.name,
      area: area ?? this.area,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      startMonth: startMonth,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'user_id': userId,
        'client_number': clientNumber,
        'name': name,
        'area': area,
        'amount': amount,
        'payment_method': paymentMethod.code,
        'start_month': startMonth,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Customer.fromDb(Map<String, Object?> map) => Customer(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        clientNumber: parseInt(map['client_number'], fallback: 1),
        name: (map['name'] as String?) ?? '',
        area: (map['area'] as String?) ?? '',
        amount: parseDouble(map['amount']),
        paymentMethod: PaymentMethod.fromCode(map['payment_method'] as String?),
        startMonth: (map['start_month'] as String?) ?? MonthKey.now().key,
        isDeleted: parseBool(map['is_deleted']),
        createdAt: normalizeTimestamp(map['created_at']),
        updatedAt: normalizeTimestamp(map['updated_at']),
      );
}
