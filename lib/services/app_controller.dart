import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../database/local_repository.dart';
import '../models/customer.dart';
import '../models/engineer_settings.dart';
import '../models/enums.dart';
import '../models/ids.dart';
import '../models/maintenance_entry.dart';
import '../models/month_key.dart';
import '../models/saved_area.dart';
import '../models/settlement.dart';
import '../models/value_parsers.dart';
import '../utils/arabic_utils.dart';
import 'auth_service.dart';
import 'excel_export_service.dart';
import 'finance_calculator.dart';
import 'supabase_config.dart';
import 'sync_service.dart';

/// المتحكم الرئيسي لحالة التطبيق (يعمل محلياً بالكامل على SQLite، مع مزامنة سحابية اختيارية).
class AppController extends ChangeNotifier {
  AppController({
    String? userId,
    String? email,
    LocalRepository? repository,
    this.onLockApp,
  })  : _userId = userId ??
            AuthService.currentUser?.id ??
            LocalRepository.localUserId,
        _email = email ?? AuthService.currentUser?.email ?? '',
        repo = repository ?? LocalRepository() {
    sync = SyncService(repo);
  }

  String _userId;
  String _email;
  final LocalRepository repo;
  final VoidCallback? onLockApp;
  late final SyncService sync;
  final ExcelExportService _excel = ExcelExportService();

  MonthKey _month = MonthKey.now();
  bool _loading = true;
  bool _syncing = false;
  bool _disposed = false;
  int _loadToken = 0;
  List<CustomerEntry> _entries = const [];
  List<SavedArea> _savedAreas = const [];
  EngineerSettings? _settings;
  Settlement? _settlement;
  DateTime? _lastUpload;

  String get userId => _userId;
  String get email => _email;

  /// هل المهندس مسجل دخول في الحساب السحابي الاختياري؟
  bool get isCloudConnected =>
      SupabaseConfig.isReady &&
      AuthService.currentUser != null &&
      _userId != LocalRepository.localUserId;

  MonthKey get month => _month;
  bool get loading => _loading;
  bool get syncing => _syncing;
  List<CustomerEntry> get entries => _entries;
  List<SavedArea> get savedAreas => _savedAreas;
  EngineerSettings get settings =>
      _settings ?? EngineerSettings.defaults(_userId);
  Settlement? get settlement => _settlement;
  DateTime? get lastUpload => _lastUpload;

  MonthSummary get summary =>
      FinanceCalculator.summarize(_entries.map((e) => e.entry), settings);

  /// الباقي عليّ المستخدم في تسوية الشهر المعروض.
  double get carriedInForMonth => _settlement?.approved == true
      ? _settlement!.carriedIn
      : settings.carriedBalance;

  /// مبلغ السداد المحفوظ للشهر الحالي.
  double get currentMonthPayment => _settlement?.payment ?? 0;

  /// صافي التسوية النهائي للشهر الحالي (نفس الرقم المعروض في صفحة الإعدادات والتسوية).
  double get currentNetSettlement =>
      settlementBreakdown(currentMonthPayment).net;

  SettlementBreakdown settlementBreakdown(double payment) =>
      FinanceCalculator.settlement(
        summary: summary,
        settings: settings,
        carriedIn: carriedInForMonth,
        payment: payment,
      );

  /// حساب عدد العملاء في كل منطقة للشهر الحالي.
  Map<String, int> get areaCustomerCounts {
    final counts = <String, int>{};
    for (final area in _savedAreas) {
      counts[area.name] = 0;
    }
    for (final item in _entries) {
      final areaName = item.customer.area.trim();
      if (areaName.isNotEmpty) {
        counts[areaName] = (counts[areaName] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// قائمة أسماء المناطق المحفوظة والمستخدمة مرتبة أبجدياً.
  List<String> get sortedAreaNames {
    final names = <String>{
      for (final a in _savedAreas)
        if (a.name.trim().isNotEmpty) a.name.trim(),
      for (final e in _entries)
        if (e.customer.area.trim().isNotEmpty) e.customer.area.trim(),
    }.toList()
      ..sort(ArabicUtils.compareNormalized);
    return names;
  }

  // ---------------------------------------------------------------------------
  // التحميل والتنقل وتبديل الحساب السحابي الاختياري
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    final cloudUser = AuthService.currentUser;
    if (cloudUser != null) {
      _userId = cloudUser.id;
      _email = cloudUser.email ?? '';
      await repo.adoptLocalData(_userId);
    }
    await reload();
    if (isCloudConnected) {
      unawaited(_backgroundSync());
    }
  }

  Future<void> refreshCloudIdentity() async {
    final cloudUser = AuthService.currentUser;
    if (cloudUser != null) {
      await repo.adoptLocalData(cloudUser.id);
      _userId = cloudUser.id;
      _email = cloudUser.email ?? '';
      await reload();
      unawaited(_backgroundSync());
    } else {
      _userId = LocalRepository.localUserId;
      _email = '';
      await reload();
    }
  }

  Future<void> reload() async {
    final token = ++_loadToken;
    try {
      var generated = 0;
      if (_month.compareTo(MonthKey.now().next) <= 0) {
        generated = await repo.generateMonthEntries(_userId, _month);
      }
      final settings = await repo.getSettings(_userId);
      final customers = await repo.getCustomers(_userId, includeDeleted: true);
      final entries = await repo.getEntriesForMonth(_userId, _month.key);
      final settlement = await repo.getSettlement(_userId, _month.key);
      final savedAreas = await repo.getSavedAreas(_userId);
      final lastUpload =
          await repo.getMeta(_userId, SyncService.metaLastUpload);
      if (token != _loadToken || _disposed) return;

      final byId = {for (final c in customers) c.id: c};
      final joined = <CustomerEntry>[
        for (final e in entries)
          if (byId[e.customerId] != null)
            CustomerEntry(customer: byId[e.customerId]!, entry: e),
      ]..sort((a, b) {
          final areaCmp =
              ArabicUtils.compareNormalized(a.customer.area, b.customer.area);
          if (areaCmp != 0) return areaCmp;
          final numCmp =
              a.customer.clientNumber.compareTo(b.customer.clientNumber);
          if (numCmp != 0) return numCmp;
          return a.customer.createdAt.compareTo(b.customer.createdAt);
        });

      _settings = settings;
      _entries = joined;
      _savedAreas = savedAreas;
      _settlement = settlement;
      _lastUpload = lastUpload == null ? null : DateTime.tryParse(lastUpload);
      _loading = false;
      _notify();

      if (generated > 0) _scheduleSync();
    } catch (error) {
      debugPrint('AppController.reload error: $error');
      if (token == _loadToken) {
        _loading = false;
        _notify();
      }
    }
  }

  void goToPreviousMonth() => _setMonth(_month.previous);

  void goToNextMonth() => _setMonth(_month.next);

  void goToCurrentMonth() => _setMonth(MonthKey.now());

  void _setMonth(MonthKey month) {
    _month = month;
    _notify();
    unawaited(reload());
  }

  // ---------------------------------------------------------------------------
  // العملاء وسجلات الصيانة والتحصيل السريع والمناطق
  // ---------------------------------------------------------------------------

  Future<int> getNextClientNumber() => repo.getNextClientNumber(_userId);

  Future<void> saveCustomerEntry({
    CustomerEntry? existing,
    required int clientNumber,
    required String name,
    required String area,
    required double amount,
    required PaymentStatus status,
    required PaymentMethod method,
    required bool isAdvance,
  }) async {
    final now = nowUtcIso();
    final Customer customer;
    if (existing == null) {
      customer = Customer(
        id: newId(),
        userId: _userId,
        clientNumber: clientNumber,
        name: name,
        area: area,
        amount: amount,
        paymentMethod: method,
        startMonth: _month.key,
        createdAt: now,
        updatedAt: now,
      );
      await repo.saveCustomer(customer);
      await repo.saveEntry(
        MaintenanceEntry(
          id: isAdvance ? newId() : generatedEntryId(customer.id, _month.key),
          userId: _userId,
          customerId: customer.id,
          accountMonth: _month.key,
          isAdvance: isAdvance,
          amount: amount,
          status: status,
          paymentMethod: method,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      customer = existing.customer.copyWith(
        clientNumber: clientNumber,
        name: name,
        area: area,
        amount: amount,
        paymentMethod: method,
      );
      await repo.saveCustomer(customer);
      await repo.saveEntry(
        existing.entry.copyWith(
          amount: amount,
          status: status,
          paymentMethod: method,
          isAdvance: isAdvance,
        ),
      );
    }

    if (isAdvance) {
      await repo.removeUnpaidRegularEntry(_userId, customer.id, _month.next.key);
    }
    await _afterLocalChange();
  }

  /// تحصيل سريع بضغطة واحدة (كاش / محفظة) من بطاقة العميل في الشاشة الرئيسية.
  /// إذا كان العميل مدفوعاً بالفعل بنفس الطريقة، يعيده إلى «لم يدفع» لسهولة التراجع.
  Future<void> quickCollect(CustomerEntry item, PaymentMethod method) async {
    final isAlreadyPaidSameMethod =
        item.entry.status == PaymentStatus.paid &&
        item.entry.paymentMethod == method;
    final newStatus =
        isAlreadyPaidSameMethod ? PaymentStatus.unpaid : PaymentStatus.paid;

    await repo.saveEntry(
      item.entry.copyWith(
        status: newStatus,
        paymentMethod: method,
      ),
    );
    await repo.saveCustomer(
      item.customer.copyWith(paymentMethod: method),
    );
    await _afterLocalChange();
  }

  Future<void> deleteCustomer(CustomerEntry item) async {
    await repo.softDeleteCustomer(_userId, item.customer.id, _month.key);
    await _afterLocalChange();
  }

  /// إضافة منطقة جديدة في قاعدة بيانات المناطق المحفوظة.
  Future<void> addSavedArea(String name) async {
    await repo.addSavedArea(_userId, name);
    await reload();
  }

  /// حذف منطقة محفوظة من قاعدة البيانات.
  Future<void> deleteSavedArea(String areaId) async {
    await repo.deleteSavedArea(_userId, areaId);
    await reload();
  }

  // ---------------------------------------------------------------------------
  // الإعدادات والتسوية وتصفير بداية الشهر وكلمة مرور التطبيق
  // ---------------------------------------------------------------------------

  Future<void> saveSettings(EngineerSettings newSettings) async {
    final normalized = EngineerSettings(
      userId: _userId,
      engineerName: newSettings.engineerName,
      baseSalary: newSettings.baseSalary,
      commissionRate: newSettings.commissionRate,
      commissionBasis: newSettings.commissionBasis,
      duesAssociation: newSettings.duesAssociation,
      duesTelecom: newSettings.duesTelecom,
      duesInsurance: newSettings.duesInsurance,
      carriedBalance: newSettings.carriedBalance,
      updatedAt: newSettings.updatedAt,
    );
    _settings = normalized;
    await repo.saveSettings(normalized);
    await _afterLocalChange();
  }

  /// حفظ مبلغ السداد الشهري فوراً ليتطابق صافي التسوية في الشريط السفلي للشاشة الرئيسية.
  Future<void> updateMonthlyPayment(double payment) async {
    final breakdown = settlementBreakdown(payment);
    final now = nowUtcIso();
    final updated = Settlement(
      id: settlementId(_userId, _month.key),
      userId: _userId,
      month: _month.key,
      totalMaintenance: breakdown.totalMaintenance,
      commission: breakdown.commission,
      walletTransfers: breakdown.walletTransfers,
      salaryAndDues: breakdown.salaryAndDues,
      carriedIn: breakdown.carriedIn,
      payment: breakdown.payment,
      netRemaining: breakdown.net,
      approved: _settlement?.approved ?? false,
      approvedAt: _settlement?.approvedAt,
      updatedAt: now,
    );
    _settlement = updated;
    await repo.saveSettlement(updated);
    _notify();
    _scheduleSync();
  }

  /// تصفير حسابات العملاء (بداية شهر جديد).
  Future<void> resetMonthAccounts() async {
    await repo.resetMonthAccounts(_userId, _month.key);
    await _afterLocalChange();
  }

  Future<String> getAppPin() => repo.getAppPin();

  Future<void> updateAppPin(String newPin) => repo.setAppPin(newPin);

  /// اعتماد التسوية وترحيل صافي المتبقي إلى «الباقي عليّ» للشهر القادم.
  Future<double> approveSettlement(double payment) async {
    final breakdown = settlementBreakdown(payment);
    final now = nowUtcIso();
    await repo.saveSettlement(
      Settlement(
        id: settlementId(_userId, _month.key),
        userId: _userId,
        month: _month.key,
        totalMaintenance: breakdown.totalMaintenance,
        commission: breakdown.commission,
        walletTransfers: breakdown.walletTransfers,
        salaryAndDues: breakdown.salaryAndDues,
        carriedIn: breakdown.carriedIn,
        payment: breakdown.payment,
        netRemaining: breakdown.net,
        approved: true,
        approvedAt: now,
        updatedAt: now,
      ),
    );
    await repo.saveSettings(settings.copyWith(carriedBalance: breakdown.net));
    await _afterLocalChange();
    return breakdown.net;
  }

  // ---------------------------------------------------------------------------
  // المزامنة والنسخ الاحتياطي وتصدير Excel
  // ---------------------------------------------------------------------------

  Future<void> syncNow() async {
    if (!isCloudConnected) {
      await reload();
      return;
    }
    _setSyncing(true);
    try {
      await sync.syncNow(_userId);
      await reload();
    } on SyncException {
      rethrow;
    } catch (_) {
      throw const SyncException('تعذر المزامنة، تحقق من اتصال الإنترنت');
    } finally {
      _setSyncing(false);
    }
  }

  Future<DateTime> uploadNow() async {
    if (!isCloudConnected) {
      throw const SyncException(
        'يرجى تسجيل الدخول في قسم «الحساب السحابي والمزامنة» أسفل الصفحة أولاً',
      );
    }
    _setSyncing(true);
    try {
      final time = await sync.uploadAll(_userId);
      _lastUpload = time;
      _notify();
      return time;
    } finally {
      _setSyncing(false);
    }
  }

  Future<int> restoreFromCloud() async {
    if (!isCloudConnected) {
      throw const SyncException(
        'يرجى تسجيل الدخول في قسم «الحساب السحابي والمزامنة» أسفل الصفحة أولاً',
      );
    }
    _setSyncing(true);
    try {
      final count = await sync.restoreAll(_userId);
      await reload();
      return count;
    } finally {
      _setSyncing(false);
    }
  }

  Future<File> exportExcel() async {
    final currentSettings = await repo.getSettings(_userId);
    _settings = currentSettings;
    final customers = await repo.getCustomers(_userId, includeDeleted: true);
    final byId = {for (final c in customers) c.id: c};
    final outstanding =
        await repo.getOutstandingEntries(_userId, _month.key);
    final payment = _settlement?.payment ?? 0;
    final currentSummary = FinanceCalculator.summarize(
      _entries.map((e) => e.entry),
      currentSettings,
    );
    return _excel.export(
      ExcelReportData(
        month: _month,
        settings: currentSettings,
        entries: _entries,
        outstanding: [
          for (final e in outstanding)
            if (byId[e.customerId] != null)
              CustomerEntry(customer: byId[e.customerId]!, entry: e),
        ],
        summary: currentSummary,
        settlement: FinanceCalculator.settlement(
          summary: currentSummary,
          settings: currentSettings,
          carriedIn: _settlement?.approved == true
              ? _settlement!.carriedIn
              : currentSettings.carriedBalance,
          payment: payment,
        ),
        settlementApproved: _settlement?.approved ?? false,
      ),
    );
  }

  Future<void> signOutCloud() async {
    if (isCloudConnected) {
      try {
        await sync.syncNow(_userId).timeout(const Duration(seconds: 6));
      } catch (_) {}
    }
    await AuthService.signOut();
    await refreshCloudIdentity();
  }

  // ---------------------------------------------------------------------------

  Future<void> _afterLocalChange() async {
    await reload();
    _scheduleSync();
  }

  void _scheduleSync() {
    if (!isCloudConnected) return;
    sync.scheduleSync(_userId, onDone: (changed) {
      if (changed && !_disposed) unawaited(reload());
    });
  }

  Future<void> _backgroundSync() async {
    if (!isCloudConnected) return;
    _setSyncing(true);
    try {
      final changed = await sync.syncNow(_userId);
      if (changed) await reload();
    } catch (_) {
      // العمل بدون إنترنت: البيانات المحلية متاحة بالكامل.
    } finally {
      _setSyncing(false);
    }
  }

  void _setSyncing(bool value) {
    _syncing = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    sync.dispose();
    super.dispose();
  }
}
