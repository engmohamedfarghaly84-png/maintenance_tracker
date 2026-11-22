import 'package:material_ui/material_ui.dart';

import '../models/enums.dart';
import '../models/maintenance_entry.dart';
import '../services/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

/// شاشة إضافة / تعديل عميل.
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, required this.controller, this.existing});

  final AppController controller;
  final CustomerEntry? existing;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _area;
  late final TextEditingController _amount;
  late PaymentStatus _status;
  late PaymentMethod _method;
  late bool _isAdvance;
  bool _busy = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.customer.name ?? '');
    _area = TextEditingController(text: existing?.customer.area ?? '');
    _amount = TextEditingController(text: amountToInput(existing?.entry.amount ?? 0));
    _status = existing?.entry.status ?? PaymentStatus.unpaid;
    _method = existing?.entry.paymentMethod ?? PaymentMethod.cash;
    _isAdvance = existing?.entry.isAdvance ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await widget.controller.saveCustomerEntry(
        existing: widget.existing,
        name: _name.text.trim(),
        area: _area.text.trim(),
        amount: parseAmount(_amount.text),
        status: _status,
        method: _method,
        isAdvance: _isAdvance,
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'تم حفظ التعديلات' : 'تمت إضافة العميل'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showAppSnack(context, 'تعذر الحفظ: $error', color: AppColors.orange);
      }
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف العميل',
      message:
          'هل أنت متأكد من حذف العميل «${existing.customer.name}»؟\n'
          'سيتم حذفه من هذا الشهر والشهور القادمة مع الإبقاء على سجل الشهور السابقة.',
      confirmLabel: 'حذف',
      confirmColor: AppColors.orange,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await widget.controller.deleteCustomer(existing);
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('تم حذف العميل'), backgroundColor: AppColors.orange),
    );
  }

  @override
  Widget build(BuildContext context) {
    final month = widget.controller.month;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل بيانات العميل' : 'إضافة عميل جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'بيانات العميل',
              icon: Icons.storefront_rounded,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم العميل',
                      hintText: 'مثال: وان اليفن',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'يرجى إدخال اسم العميل' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _area,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'المنطقة / المكان',
                      hintText: 'مثال: مدينة نصر',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  NumberField(
                    controller: _amount,
                    label: 'قيمة الصيانة',
                    hint: 'مثال: 500',
                    icon: Icons.payments_outlined,
                    validator: (v) =>
                        parseAmount(v ?? '') <= 0 ? 'يرجى إدخال قيمة صيانة صحيحة' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'الدفع والاستحقاق',
              icon: Icons.receipt_long_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('حالة الدفع'),
                  SegmentedButton<PaymentStatus>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: PaymentStatus.paid,
                        label: Text('دفع'),
                        icon: Icon(Icons.check_circle_outline),
                      ),
                      ButtonSegment(
                        value: PaymentStatus.unpaid,
                        label: Text('لم يدفع'),
                        icon: Icon(Icons.error_outline),
                      ),
                      ButtonSegment(
                        value: PaymentStatus.hold,
                        label: Text('هولد'),
                        icon: Icon(Icons.pause_circle_outline),
                      ),
                    ],
                    selected: {_status},
                    onSelectionChanged: (s) => setState(() => _status = s.first),
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('طريقة الدفع'),
                  SegmentedButton<PaymentMethod>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: PaymentMethod.cash,
                        label: Text('كاش'),
                        icon: Icon(Icons.payments_outlined),
                      ),
                      ButtonSegment(
                        value: PaymentMethod.wallet,
                        label: Text('محفظة'),
                        icon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                    ],
                    selected: {_method},
                    onSelectionChanged: (s) => setState(() => _method = s.first),
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('شهر الاستحقاق'),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text('الشهر الحالي (${month.monthName})'),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('الشهر القادم (${month.next.monthName})'),
                      ),
                    ],
                    selected: {_isAdvance},
                    onSelectionChanged: (s) => setState(() {
                      _isAdvance = s.first;
                      if (_isAdvance) _status = PaymentStatus.paid;
                    }),
                  ),
                  if (_isAdvance) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppColors.radius),
                        border: Border.all(color: AppColors.gold),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fast_forward_rounded, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تحصيل مقدم: سيُحتسب هذا المبلغ ضمن حسابات ${month.label} '
                              'عن صيانة ${month.next.shortLabel}، ولن يظهر العميل كغير مدفوع في الشهر القادم.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('حفظ'),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.orange,
                      side: const BorderSide(color: AppColors.orange),
                    ),
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('حذف العميل'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
