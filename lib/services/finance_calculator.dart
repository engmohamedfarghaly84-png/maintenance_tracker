import '../models/engineer_settings.dart';
import '../models/enums.dart';
import '../models/maintenance_entry.dart';

/// ملخص حسابات الشهر.
class MonthSummary {
  const MonthSummary({
    required this.collected,
    required this.uncollected,
    required this.commission,
    required this.commissionRate,
    required this.walletTransfers,
    required this.advanceCollected,
    required this.paidCount,
    required this.unpaidCount,
    required this.holdCount,
  });

  /// المحصّل (إجمالي الصيانة المدفوع).
  final double collected;

  /// غير المحصّل (لم يدفع + هولد).
  final double uncollected;
  final double commission;
  final double commissionRate;

  /// المدفوع عبر المحفظة (يُحوّل مباشرة ولا يكون مع المهندس).
  final double walletTransfers;

  /// تحصيل مقدم من الشهر القادم.
  final double advanceCollected;
  final int paidCount;
  final int unpaidCount;
  final int holdCount;

  double get total => collected + uncollected;

  /// الباقي بعد خصم العمولة من المحصّل.
  double get remainder => collected - commission;
}

/// تفاصيل تسوية الحساب الشهري.
class SettlementBreakdown {
  const SettlementBreakdown({
    required this.totalMaintenance,
    required this.commission,
    required this.walletTransfers,
    required this.baseSalary,
    required this.fixedDues,
    required this.carriedIn,
    required this.payment,
  });

  final double totalMaintenance;
  final double commission;
  final double walletTransfers;
  final double baseSalary;
  final double fixedDues;
  final double carriedIn;
  final double payment;

  double get salaryAndDues => baseSalary + fixedDues;

  /// صافي المتبقي النهائي =
  /// إجمالي الصيانات - العمولة - التحويلات عبر المحفظة - الراتب والمستحقات + الباقي عليّ - السداد
  double get net =>
      totalMaintenance - commission - walletTransfers - salaryAndDues + carriedIn - payment;
}

abstract final class FinanceCalculator {
  static MonthSummary summarize(
    Iterable<MaintenanceEntry> entries,
    EngineerSettings settings,
  ) {
    var collected = 0.0;
    var uncollected = 0.0;
    var wallet = 0.0;
    var advance = 0.0;
    var paid = 0, unpaid = 0, hold = 0;

    for (final entry in entries) {
      switch (entry.status) {
        case PaymentStatus.paid:
          collected += entry.amount;
          paid++;
          if (entry.paymentMethod == PaymentMethod.wallet) wallet += entry.amount;
          if (entry.isAdvance) advance += entry.amount;
        case PaymentStatus.unpaid:
          uncollected += entry.amount;
          unpaid++;
        case PaymentStatus.hold:
          uncollected += entry.amount;
          hold++;
      }
    }

    final base = settings.commissionBasis == CommissionBasis.total
        ? collected + uncollected
        : collected;

    return MonthSummary(
      collected: collected,
      uncollected: uncollected,
      commission: base * settings.commissionRate / 100,
      commissionRate: settings.commissionRate,
      walletTransfers: wallet,
      advanceCollected: advance,
      paidCount: paid,
      unpaidCount: unpaid,
      holdCount: hold,
    );
  }

  static SettlementBreakdown settlement({
    required MonthSummary summary,
    required EngineerSettings settings,
    required double carriedIn,
    required double payment,
  }) {
    return SettlementBreakdown(
      totalMaintenance: summary.collected,
      commission: summary.commission,
      walletTransfers: summary.walletTransfers,
      baseSalary: settings.baseSalary,
      fixedDues: settings.fixedDuesTotal,
      carriedIn: carriedIn,
      payment: payment,
    );
  }
}
