import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../models/engineer_settings.dart';
import '../models/enums.dart';
import '../services/app_controller.dart';
import '../services/finance_calculator.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/area_picker_sheet.dart';
import '../widgets/common.dart';
import 'cloud_auth_screen.dart';

/// صفحة «الإعدادات والتسوية والنسخ الاحتياطي».
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _salary;
  late final TextEditingController _rate;
  late final TextEditingController _assoc;
  late final TextEditingController _telecom;
  late final TextEditingController _insurance;
  late final TextEditingController _carried;
  late final TextEditingController _payment;
  late final TextEditingController _areaInput;
  late final TextEditingController _newPin;
  late CommissionBasis _basis;
  Timer? _autoSaveTimer;
  Timer? _paymentSaveTimer;
  bool _busy = false;
  bool _obscurePin = true;

  AppController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    final s = _c.settings;
    _name = TextEditingController(text: s.engineerName);
    _salary = TextEditingController(text: amountToInput(s.baseSalary));
    _rate = TextEditingController(text: amountToInput(s.commissionRate));
    _assoc = TextEditingController(text: amountToInput(s.duesAssociation));
    _telecom = TextEditingController(text: amountToInput(s.duesTelecom));
    _insurance = TextEditingController(text: amountToInput(s.duesInsurance));
    _carried = TextEditingController(text: amountToInput(s.carriedBalance));
    _payment = TextEditingController(
      text: amountToInput(_c.settlement?.payment ?? 0),
    );
    _areaInput = TextEditingController();
    _newPin = TextEditingController();
    _basis = s.commissionBasis;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _paymentSaveTimer?.cancel();
    for (final c in [
      _name,
      _salary,
      _rate,
      _assoc,
      _telecom,
      _insurance,
      _carried,
      _payment,
      _areaInput,
      _newPin,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  EngineerSettings _draftSettings() => _c.settings.copyWith(
        engineerName: _name.text.trim(),
        baseSalary: parseAmount(_salary.text),
        commissionRate: parseAmount(_rate.text),
        commissionBasis: _basis,
        duesAssociation: parseAmount(_assoc.text),
        duesTelecom: parseAmount(_telecom.text),
        duesInsurance: parseAmount(_insurance.text),
        carriedBalance: parseAmount(_carried.text),
      );

  /// حفظ تلقائي فوري في SQLite عند أي تعديل في اسم المهندس أو الإعدادات.
  void _onSettingsChanged() {
    setState(() {});
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_c.saveSettings(_draftSettings()));
    });
  }

  /// حفظ مبلغ السداد فوراً ليتطابق رقم «الباقي» في الشريط السفلي للشاشة الرئيسية.
  void _onPaymentChanged() {
    setState(() {});
    _paymentSaveTimer?.cancel();
    _paymentSaveTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_c.updateMonthlyPayment(parseAmount(_payment.text)));
    });
  }

  void _syncFieldsFromSettings() {
    final s = _c.settings;
    _name.text = s.engineerName;
    _salary.text = amountToInput(s.baseSalary);
    _rate.text = amountToInput(s.commissionRate);
    _assoc.text = amountToInput(s.duesAssociation);
    _telecom.text = amountToInput(s.duesTelecom);
    _insurance.text = amountToInput(s.duesInsurance);
    _carried.text = amountToInput(s.carriedBalance);
    _payment.text = amountToInput(_c.settlement?.payment ?? 0);
    _basis = s.commissionBasis;
  }

  Future<void> _saveSettings({bool silent = false}) async {
    _autoSaveTimer?.cancel();
    _paymentSaveTimer?.cancel();
    await _c.saveSettings(_draftSettings());
    await _c.updateMonthlyPayment(parseAmount(_payment.text));
    if (!silent && mounted) {
      showAppSnack(
        context,
        'تم حفظ إعدادات المهندس محلياً بنجاح',
        color: AppColors.green,
      );
    }
  }

  Future<void> _addArea() async {
    final name = _areaInput.text.trim();
    if (name.isEmpty) {
      showAppSnack(
        context,
        'يرجى كتابة اسم المنطقة أولاً',
        color: AppColors.orange,
      );
      return;
    }
    await _c.addSavedArea(name);
    _areaInput.clear();
    if (mounted) {
      showAppSnack(
        context,
        'تم حفظ المنطقة «$name» بنجاح',
        color: AppColors.green,
      );
    }
  }

  Future<void> _resetMonthAccounts() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'تصفير حسابات العملاء (بداية شهر جديد)',
      message:
          'سيتم تحويل حالة الدفع لجميع العملاء في (${_c.month.label}) إلى «لم يدفع» وتصفير مبلغ السداد النقدي للشهر، مع الإبقاء على أسماء العملاء وأرقامهم الأصلية ومناطقهم وقيم صيانتهم كما هي.\n\nهل تريد المتابعة؟',
      confirmLabel: 'تصفير الحسابات',
      confirmColor: AppColors.orange,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await _c.resetMonthAccounts();
      _payment.clear();
      if (mounted) {
        showAppSnack(
          context,
          'تم تصفير حسابات العملاء لبداية شهر جديد بنجاح',
          color: AppColors.green,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeAppPin() async {
    final pin = _newPin.text.trim();
    if (pin.isEmpty) {
      showAppSnack(
        context,
        'يرجى إدخال كلمة المرور الجديدة للتطبيق',
        color: AppColors.orange,
      );
      return;
    }
    await _c.updateAppPin(pin);
    _newPin.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
      showAppSnack(
        context,
        'تم تغيير كلمة مرور التطبيق بنجاح',
        color: AppColors.green,
      );
    }
  }

  Future<void> _approveSettlement(SettlementBreakdown b) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'اعتماد التسوية وترحيل المتبقي',
      message:
          'سيتم اعتماد تسوية ${_c.month.label} وترحيل صافي المتبقي النهائي '
          '(${formatMoney(b.net)}) كرصيد «الباقي عليّ» للشهر القادم '
          '(${_c.month.next.shortLabel}).',
      confirmLabel: 'اعتماد وترحيل',
      confirmColor: AppColors.orange,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await _saveSettings(silent: true);
      final net = await _c.approveSettlement(parseAmount(_payment.text));
      _carried.text = amountToInput(net);
      if (mounted) {
        showAppSnack(
          context,
          'تم اعتماد التسوية وترحيل ${formatMoney(net)} للشهر القادم',
          color: AppColors.green,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCloudAuth() async {
    await _saveSettings(silent: true);
    if (!mounted) return;
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CloudAuthScreen(controller: _c),
      ),
    );
    if (connected == true && mounted) {
      _syncFieldsFromSettings();
      setState(() {});
    }
  }

  Future<void> _uploadCloud() async {
    if (!_c.isCloudConnected) {
      await _openCloudAuth();
      if (!_c.isCloudConnected) return;
    }
    setState(() => _busy = true);
    try {
      await _saveSettings(silent: true);
      final time = await _c.uploadNow();
      if (mounted) {
        showAppSnack(
          context,
          'تم رفع كافة البيانات على السحابة بنجاح (${formatDateTime(time)})',
          color: AppColors.green,
        );
      }
    } on SyncException catch (e) {
      if (mounted) showAppSnack(context, e.message, color: AppColors.orange);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _busy = true);
    try {
      await _saveSettings(silent: true);
      final file = await _c.exportExcel();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (sheetCtx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.table_view_rounded,
                      color: AppColors.green,
                      size: 28,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تم حفظ ملف Excel على الجهاز بنجاح',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  file.path,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                  ),
                  onPressed: () async {
                    Navigator.of(sheetCtx).pop();
                    await SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(file.path)],
                        text: 'تقرير الصيانة - ${_c.month.label}',
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('مشاركة الملف (واتساب / تطبيقات أخرى)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'تعذر تصدير ملف Excel: $error',
          color: AppColors.orange,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreCloud() async {
    if (!_c.isCloudConnected) {
      await _openCloudAuth();
      if (!_c.isCloudConnected || !mounted) return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'استرجاع البيانات من السحابة',
      message:
          'سيتم سحب كافة بياناتك وإعداداتك من السحابة واستبدال البيانات المحفوظة على الهاتف الحالي.',
      confirmLabel: 'استرجاع الآن',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      final count = await _c.restoreFromCloud();
      _syncFieldsFromSettings();
      if (mounted) {
        showAppSnack(
          context,
          'تم استرجاع البيانات من السحابة بنجاح ($count سجل)',
          color: AppColors.green,
        );
      }
    } on SyncException catch (e) {
      if (mounted) showAppSnack(context, e.message, color: AppColors.orange);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOutCloud() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'تسجيل الخروج من السحابة',
      message:
          'سيتم فصل الحساب السحابي (${_c.email}) مع استمرار عمل التطبيق محلياً بالكامل.',
      confirmLabel: 'فصل الحساب السحابي',
      confirmColor: AppColors.orange,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await _c.signOutCloud();
      _syncFieldsFromSettings();
      if (mounted) {
        showAppSnack(
          context,
          'تم تسجيل الخروج من الحساب السحابي',
          color: AppColors.green,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _lockApp() async {
    await _saveSettings(silent: true);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    _c.onLockApp?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final draft = _draftSettings();
        final summary = FinanceCalculator.summarize(
          _c.entries.map((e) => e.entry),
          draft,
        );
        final carriedIn = _c.settlement?.approved == true
            ? _c.settlement!.carriedIn
            : draft.carriedBalance;
        final breakdown = FinanceCalculator.settlement(
          summary: summary,
          settings: draft,
          carriedIn: carriedIn,
          payment: parseAmount(_payment.text),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('الإعدادات والتسوية والنسخ الاحتياطي'),
            actions: [
              if (_c.onLockApp != null)
                IconButton(
                  tooltip: 'قفل التطبيق',
                  icon: const Icon(Icons.lock_outline_rounded),
                  onPressed: _busy ? null : _lockApp,
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildEngineerSection(),
              const SizedBox(height: 14),
              _buildAreasSection(),
              const SizedBox(height: 14),
              _buildSettlementSection(breakdown),
              const SizedBox(height: 14),
              _buildResetMonthSection(),
              const SizedBox(height: 14),
              _buildBackupSection(),
              const SizedBox(height: 14),
              _buildAppPinSection(),
              const SizedBox(height: 14),
              _buildOptionalCloudAccountSection(),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. إعدادات المهندس (تُحفظ محلياً في SQLite فوراً)
  // ---------------------------------------------------------------------------
  Widget _buildEngineerSection() {
    return SectionCard(
      title: 'إعدادات المهندس',
      icon: Icons.engineering_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            onChanged: (_) => _onSettingsChanged(),
            decoration: const InputDecoration(
              labelText: 'اسم المهندس',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NumberField(
                  controller: _salary,
                  label: 'الراتب الأساسي',
                  onChanged: (_) => _onSettingsChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NumberField(
                  controller: _rate,
                  label: 'نسبة العمولة',
                  suffix: '%',
                  onChanged: (_) => _onSettingsChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const FieldLabel('احتساب العمولة'),
          SegmentedButton<CommissionBasis>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: CommissionBasis.total,
                label: Text('من إجمالي الصيانة'),
              ),
              ButtonSegment(
                value: CommissionBasis.collected,
                label: Text('من المحصّل فقط'),
              ),
            ],
            selected: {_basis},
            onSelectionChanged: (s) {
              _basis = s.first;
              _onSettingsChanged();
            },
          ),
          const SizedBox(height: 14),
          const FieldLabel('المستحقات الثابتة'),
          Row(
            children: [
              Expanded(
                child: NumberField(
                  controller: _assoc,
                  label: 'جمعية',
                  onChanged: (_) => _onSettingsChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberField(
                  controller: _telecom,
                  label: 'اتصالات',
                  onChanged: (_) => _onSettingsChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberField(
                  controller: _insurance,
                  label: 'تأمين',
                  onChanged: (_) => _onSettingsChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          NumberField(
            controller: _carried,
            label: 'الباقي عليّ (الرصيد المرحل من الشهور السابقة)',
            icon: Icons.history_rounded,
            onChanged: (_) => _onSettingsChanged(),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _busy ? null : _saveSettings,
            icon: const Icon(Icons.save_rounded),
            label: const Text('حفظ إعدادات المهندس'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. قاعدة بيانات المناطق المحفوظة + فلترة الحرف الأول + الزر البرتقالي
  // ---------------------------------------------------------------------------
  Widget _buildAreasSection() {
    final areas = _c.savedAreas;
    final counts = _c.areaCustomerCounts;
    return SectionCard(
      title: 'المناطق المحفوظة (${areas.length})',
      icon: Icons.place_rounded,
      iconColor: AppColors.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AreaAutocompleteField(
            controller: _areaInput,
            appController: _c,
            labelText: 'المنطقة (إضافة أو بحث بالحرف الأول أ/إ/ا)',
            hintText: 'اكتب اسم المنطقة أو اختر من الزر البرتقالي',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _addArea,
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('حفظ المنطقة'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  side: const BorderSide(color: AppColors.orange),
                ),
                onPressed: () => showAreaPickerSheet(
                  context: context,
                  controller: _c,
                  allowDelete: true,
                  onSelectArea: (picked) {
                    if (picked != null) {
                      setState(() => _areaInput.text = picked);
                    }
                  },
                ),
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text('إدارة القائمة'),
              ),
            ],
          ),
          if (areas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final area in areas)
                  InputChip(
                    backgroundColor: AppColors.background,
                    label: Text(
                      '${area.name} (${counts[area.name] ?? 0})',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    onPressed: () => setState(() => _areaInput.text = area.name),
                    deleteIconColor: AppColors.orange,
                    onDeleted: () => _c.deleteSavedArea(area.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. تسوية الحساب الشهري
  // ---------------------------------------------------------------------------
  Widget _buildSettlementSection(SettlementBreakdown b) {
    final approved = _c.settlement?.approved ?? false;
    return SectionCard(
      title: 'تسوية الحساب الشهري (${_c.month.shortLabel})',
      icon: Icons.calculate_rounded,
      iconColor: AppColors.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _calcRow('صيانات المهندس المحصّلة', b.totalMaintenance, sign: '+'),
          _calcRow('العمولة', b.commission, sign: '-', color: AppColors.gold),
          if (b.walletTransfers > 0)
            _calcRow('التحويلات عبر المحفظة', b.walletTransfers, sign: '-'),
          _calcRow('عليك', b.dueBeforeDues, sign: '='),
          _calcRow('الراتب والمستحقات الثابتة', b.salaryAndDues, sign: '-'),
          _calcRow('عليك بعد المستحقات', b.dueAfterDues, sign: '='),
          _calcRow('قديم / الرصيد المرحل', b.carriedIn, sign: '+'),
          _calcRow(
            'متبقي عليك قبل السداد',
            b.totalDueBeforePayment,
            sign: '=',
            color: AppColors.orange,
          ),
          const Divider(height: 22),
          NumberField(
            controller: _payment,
            label: 'السداد',
            icon: Icons.paid_outlined,
            onChanged: (_) => _onPaymentChanged(),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(AppColors.radius),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'صافي المتبقي النهائي (متبقي عليك)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        'مطابق تماماً لبطاقة «الباقي» في الشاشة الرئيسية',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(b.net),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
                ),
              ],
            ),
          ),
          if (approved) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.verified_rounded, color: AppColors.green, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'تم اعتماد تسوية هذا الشهر وترحيلها (يمكنك إعادة الاعتماد بعد التعديل)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.primary,
            ),
            onPressed: _busy ? null : () => _approveSettlement(b),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('اعتماد وترحيل المتبقي للشهر القادم'),
          ),
        ],
      ),
    );
  }

  Widget _calcRow(
    String label,
    double value, {
    required String sign,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              sign,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.secondary),
            ),
          ),
          Text(
            formatMoney(value),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. تصفير حسابات العملاء (بداية شهر جديد)
  // ---------------------------------------------------------------------------
  Widget _buildResetMonthSection() {
    return SectionCard(
      title: 'بداية شهر جديد',
      icon: Icons.restart_alt_rounded,
      iconColor: AppColors.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'يقوم هذا الزر بتحويل حالة الدفع لجميع العملاء في الشهر المحدد إلى «لم يدفع» وتصفير مبلغ السداد النقدي للشهر، مع الإبقاء على أسماء العملاء وأرقامهم الأصلية ومناطقهم وقيم صيانتهم كما هي.',
            style: TextStyle(fontSize: 12.5, color: AppColors.secondary),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: _busy ? null : _resetMonthAccounts,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('تصفير حسابات العملاء (بداية شهر جديد)'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. الحفظ والنسخ الاحتياطي والتصدير
  // ---------------------------------------------------------------------------
  Widget _buildBackupSection() {
    final lastUpload = _c.lastUpload;
    return SectionCard(
      title: 'الحفظ والنسخ الاحتياطي والتصدير',
      icon: Icons.cloud_done_rounded,
      iconColor: AppColors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppColors.radius),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lastUpload == null
                        ? 'آخر رفع ناجح: لم يتم الرفع السحابي بعد'
                        : 'آخر رفع ناجح: ${formatDateTime(lastUpload)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _busy ? null : _uploadCloud,
            icon: const Icon(Icons.cloud_upload_rounded),
            label: const Text('رفع على السحابة الآن'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: _busy ? null : _exportExcel,
            icon: const Icon(Icons.table_view_rounded),
            label: const Text('حفظ نسخة على الجهاز (Excel)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restoreCloud,
            icon: const Icon(Icons.cloud_download_rounded),
            label: const Text('استرجاع البيانات من السحابة'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. تغيير كلمة مرور التطبيق (PIN) محلياً
  // ---------------------------------------------------------------------------
  Widget _buildAppPinSection() {
    return SectionCard(
      title: 'كلمة مرور التطبيق (PIN)',
      icon: Icons.pin_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _newPin,
            obscureText: _obscurePin,
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(
              labelText: 'كلمة المرور الجديدة للتطبيق',
              hintText: 'الافتراضية: 1234',
              prefixIcon: const Icon(Icons.lock_reset_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePin ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _changeAppPin,
            icon: const Icon(Icons.check_rounded),
            label: const Text('تحديث كلمة مرور التطبيق'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. الحساب السحابي والمزامنة (اختياري)
  // ---------------------------------------------------------------------------
  Widget _buildOptionalCloudAccountSection() {
    final connected = _c.isCloudConnected;
    return SectionCard(
      title: 'الحساب السحابي والمزامنة (اختياري)',
      icon: Icons.cloud_outlined,
      iconColor: AppColors.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppColors.radius),
            ),
            child: Row(
              children: [
                Icon(
                  connected
                      ? Icons.cloud_done_rounded
                      : Icons.offline_pin_rounded,
                  color: connected ? AppColors.green : AppColors.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    connected
                        ? 'متصل بالحساب السحابي:\n${_c.email}'
                        : 'التطبيق يعمل محلياً بالكامل على جهازك بدون الحاجة لحساب سحابي. يمكنك تسجيل الدخول السحابي اختيارياً إذا رغبت في تفعيل الرفع والاسترجاع السحابي.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!connected)
            OutlinedButton.icon(
              onPressed: _busy ? null : _openCloudAuth,
              icon: const Icon(Icons.cloud_sync_rounded),
              label: const Text('تسجيل الدخول / إنشاء حساب سحابي (Supabase)'),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orange,
                side: const BorderSide(color: AppColors.orange),
              ),
              onPressed: _busy ? null : _signOutCloud,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('تسجيل الخروج من الحساب السحابي'),
            ),
        ],
      ),
    );
  }
}
