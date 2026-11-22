import 'enums.dart';
import 'value_parsers.dart';

/// إعدادات المهندس المالية.
class EngineerSettings {
  const EngineerSettings({
    required this.userId,
    required this.engineerName,
    required this.baseSalary,
    required this.commissionRate,
    required this.commissionBasis,
    required this.duesAssociation,
    required this.duesTelecom,
    required this.duesInsurance,
    required this.carriedBalance,
    required this.updatedAt,
  });

  factory EngineerSettings.defaults(String userId) => EngineerSettings(
        userId: userId,
        engineerName: '',
        baseSalary: 0,
        commissionRate: 0,
        commissionBasis: CommissionBasis.total,
        duesAssociation: 0,
        duesTelecom: 0,
        duesInsurance: 0,
        carriedBalance: 0,
        updatedAt: epochIso,
      );

  final String userId;
  final String engineerName;
  final double baseSalary;

  /// نسبة العمولة %.
  final double commissionRate;
  final CommissionBasis commissionBasis;

  /// جمعية.
  final double duesAssociation;

  /// اتصالات.
  final double duesTelecom;

  /// تأمين.
  final double duesInsurance;

  /// الباقي عليّ (رصيد مرحل من الشهور السابقة).
  final double carriedBalance;
  final String updatedAt;

  double get fixedDuesTotal => duesAssociation + duesTelecom + duesInsurance;

  double get salaryAndDues => baseSalary + fixedDuesTotal;

  EngineerSettings copyWith({
    String? engineerName,
    double? baseSalary,
    double? commissionRate,
    CommissionBasis? commissionBasis,
    double? duesAssociation,
    double? duesTelecom,
    double? duesInsurance,
    double? carriedBalance,
    String? updatedAt,
  }) {
    return EngineerSettings(
      userId: userId,
      engineerName: engineerName ?? this.engineerName,
      baseSalary: baseSalary ?? this.baseSalary,
      commissionRate: commissionRate ?? this.commissionRate,
      commissionBasis: commissionBasis ?? this.commissionBasis,
      duesAssociation: duesAssociation ?? this.duesAssociation,
      duesTelecom: duesTelecom ?? this.duesTelecom,
      duesInsurance: duesInsurance ?? this.duesInsurance,
      carriedBalance: carriedBalance ?? this.carriedBalance,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDb() => {
        'user_id': userId,
        'engineer_name': engineerName,
        'base_salary': baseSalary,
        'commission_rate': commissionRate,
        'commission_basis': commissionBasis.code,
        'dues_association': duesAssociation,
        'dues_telecom': duesTelecom,
        'dues_insurance': duesInsurance,
        'carried_balance': carriedBalance,
        'updated_at': updatedAt,
      };

  factory EngineerSettings.fromDb(Map<String, Object?> map) => EngineerSettings(
        userId: map['user_id'] as String,
        engineerName: (map['engineer_name'] as String?) ?? '',
        baseSalary: parseDouble(map['base_salary']),
        commissionRate: parseDouble(map['commission_rate']),
        commissionBasis: CommissionBasis.fromCode(map['commission_basis'] as String?),
        duesAssociation: parseDouble(map['dues_association']),
        duesTelecom: parseDouble(map['dues_telecom']),
        duesInsurance: parseDouble(map['dues_insurance']),
        carriedBalance: parseDouble(map['carried_balance']),
        updatedAt: normalizeTimestamp(map['updated_at']),
      );
}
