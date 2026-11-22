/// حالة الدفع لسجل الصيانة.
enum PaymentStatus {
  paid('paid', 'دفع'),
  unpaid('unpaid', 'لم يدفع'),
  hold('hold', 'هولد');

  const PaymentStatus(this.code, this.label);

  final String code;
  final String label;

  static PaymentStatus fromCode(String? code) =>
      values.firstWhere((e) => e.code == code, orElse: () => PaymentStatus.unpaid);
}

/// طريقة الدفع.
enum PaymentMethod {
  cash('cash', 'كاش'),
  wallet('wallet', 'محفظة');

  const PaymentMethod(this.code, this.label);

  final String code;
  final String label;

  static PaymentMethod fromCode(String? code) =>
      values.firstWhere((e) => e.code == code, orElse: () => PaymentMethod.cash);
}

/// أساس احتساب عمولة المهندس.
enum CommissionBasis {
  total('total', 'من إجمالي الصيانة'),
  collected('collected', 'من المحصّل فقط');

  const CommissionBasis(this.code, this.label);

  final String code;
  final String label;

  static CommissionBasis fromCode(String? code) =>
      values.firstWhere((e) => e.code == code, orElse: () => CommissionBasis.total);
}
