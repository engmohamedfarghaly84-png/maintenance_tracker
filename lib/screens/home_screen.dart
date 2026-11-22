import 'package:material_ui/material_ui.dart';

import '../models/enums.dart';
import '../models/maintenance_entry.dart';
import '../services/app_controller.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';
import '../utils/arabic_utils.dart';
import '../widgets/area_picker_sheet.dart';
import '../widgets/common.dart';
import '../widgets/customer_card.dart';
import '../widgets/footer_summary.dart';
import '../widgets/month_selector.dart';
import '../widgets/summary_card.dart';
import 'customer_form_screen.dart';
import 'settings_screen.dart';

/// الشاشة الرئيسية: العملاء والمتابعة.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  /// فلتر المنطقة المختارة من الزر البرتقالي (null = كل المناطق).
  String? _selectedAreaFilter;

  /// فلتر حالة الدفع السريع (null = الكل).
  PaymentStatus? _selectedStatusFilter;

  AppController get _c => widget.controller;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm([CustomerEntry? item]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerFormScreen(controller: _c, existing: item),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SettingsScreen(controller: _c)),
    );
  }

  Future<void> _manualRefreshOrSync() async {
    try {
      await _c.syncNow();
      if (!mounted) return;
      showAppSnack(
        context,
        _c.isCloudConnected
            ? 'تمت المزامنة مع السحابة بنجاح'
            : 'تم تحديث البيانات المحلية بنجاح',
        color: AppColors.green,
      );
    } on SyncException catch (e) {
      if (mounted) showAppSnack(context, e.message, color: AppColors.orange);
    }
  }

  void _openAreaFilterSheet() {
    showAreaPickerSheet(
      context: context,
      controller: _c,
      selectedArea: _selectedAreaFilter,
      showClearFilterOption: true,
      onSelectArea: (area) => setState(() => _selectedAreaFilter = area),
    );
  }

  List<CustomerEntry> _filteredEntries() {
    final rawQuery = _searchController.text.trim();
    final cleanNumQuery = rawQuery.replaceAll('#', '').trim();

    return _c.entries.where((item) {
      if (_selectedAreaFilter != null &&
          item.customer.area.trim() != _selectedAreaFilter) {
        return false;
      }
      if (_selectedStatusFilter != null &&
          item.entry.status != _selectedStatusFilter) {
        return false;
      }
      if (rawQuery.isEmpty) return true;

      final numberStr = item.customer.clientNumber.toString();
      if (cleanNumQuery.isNotEmpty &&
          ArabicUtils.normalize(numberStr) ==
              ArabicUtils.normalize(cleanNumQuery)) {
        return true;
      }
      if (ArabicUtils.containsNormalized(item.customer.name, rawQuery)) {
        return true;
      }
      if (ArabicUtils.containsNormalized(item.customer.area, rawQuery)) {
        return true;
      }
      if (ArabicUtils.containsNormalized('#$numberStr', rawQuery)) {
        return true;
      }
      return false;
    }).toList();
  }

  /// تجميع العملاء حسب المنطقة مرتبة أبجدياً، وداخل كل منطقة مرتبين بالرقم الأصلي.
  List<_AreaGroup> _groupByArea(List<CustomerEntry> list) {
    final map = <String, List<CustomerEntry>>{};
    for (final item in list) {
      final area = item.customer.area.trim().isEmpty
          ? 'بدون منطقة'
          : item.customer.area.trim();
      map.putIfAbsent(area, () => <CustomerEntry>[]).add(item);
    }

    final areaNames = map.keys.toList()..sort(ArabicUtils.compareNormalized);
    return [
      for (final area in areaNames)
        _AreaGroup(
          areaName: area,
          items: map[area]!
            ..sort(
              (a, b) =>
                  a.customer.clientNumber.compareTo(b.customer.clientNumber),
            ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final summary = _c.summary;
        final name = _c.settings.engineerName.trim();
        return Scaffold(
          appBar: AppBar(
            title: Column(
              children: [
                const Text('العملاء والمتابعة'),
                if (name.isNotEmpty)
                  Text(
                    'م/ $name',
                    style: const TextStyle(fontSize: 12, color: AppColors.gold),
                  ),
              ],
            ),
            actions: [
              if (_c.isCloudConnected)
                _c.syncing
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : IconButton(
                        tooltip: 'مزامنة مع السحابة',
                        icon: const Icon(Icons.cloud_sync_rounded),
                        onPressed: _manualRefreshOrSync,
                      ),
              IconButton(
                tooltip: 'الإعدادات والتسوية والنسخ الاحتياطي',
                icon: const Icon(Icons.settings_rounded),
                onPressed: _openSettings,
              ),
            ],
          ),
          body: Column(
            children: [
              // ===== الجزء العلوي الثابت =====
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  children: [
                    MonthSelector(
                      month: _c.month,
                      onPrevious: _c.goToPreviousMonth,
                      onNext: _c.goToNextMonth,
                      onTapCurrent: _c.goToCurrentMonth,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            title: 'المحصّل',
                            value: summary.collected,
                            color: AppColors.green,
                            icon: Icons.check_circle_rounded,
                            subtitle: '${summary.paidCount} عميل',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SummaryCard(
                            title: 'غير المحصّل',
                            value: summary.uncollected,
                            color: AppColors.orange,
                            icon: Icons.pending_actions_rounded,
                            subtitle:
                                '${summary.unpaidCount} لم يدفع • ${summary.holdCount} هولد',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // شريط البحث الموحد + الزر البرتقالي للمناطق المحفوظة على اليسار
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText:
                                    'بحث باسم العميل أو المنطقة أو الرقم (#1)...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.clear_rounded),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OrangeAreaButton(
                          tooltip: 'فلترة حسب المناطق المحفوظة',
                          hasActiveFilter: _selectedAreaFilter != null,
                          onTap: _openAreaFilterSheet,
                        ),
                      ],
                    ),
                    if (_selectedAreaFilter != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.orange),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.place_rounded,
                              size: 16,
                              color: AppColors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'المنطقة: $_selectedAreaFilter',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () =>
                                  setState(() => _selectedAreaFilter = null),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // أزرار الفلترة السريعة لحالة الدفع (الكل، لم يدفع، تم الدفع، هولد)
                    _buildStatusFilterBar(summary),
                  ],
                ),
              ),
              // ===== الجزء الأوسط القابل للتمرير =====
              Expanded(child: _buildGroupedList()),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'إضافة عميل',
            onPressed: () => _openForm(),
            child: const Icon(Icons.add_rounded, size: 30),
          ),
          // ===== الجزء السفلي الثابت =====
          bottomNavigationBar: FooterSummary(
            summary: summary,
            netSettlement: _c.currentNetSettlement,
          ),
        );
      },
    );
  }

  Widget _buildStatusFilterBar(dynamic summary) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatusFilterChip(
            label: 'الكل (${_c.entries.length})',
            selected: _selectedStatusFilter == null,
            activeColor: AppColors.primary,
            onTap: () => setState(() => _selectedStatusFilter = null),
          ),
          const SizedBox(width: 6),
          _StatusFilterChip(
            label: 'لم يدفع (${_c.summary.unpaidCount})',
            selected: _selectedStatusFilter == PaymentStatus.unpaid,
            activeColor: AppColors.orange,
            onTap: () =>
                setState(() => _selectedStatusFilter = PaymentStatus.unpaid),
          ),
          const SizedBox(width: 6),
          _StatusFilterChip(
            label: 'تم الدفع (${_c.summary.paidCount})',
            selected: _selectedStatusFilter == PaymentStatus.paid,
            activeColor: AppColors.green,
            onTap: () =>
                setState(() => _selectedStatusFilter = PaymentStatus.paid),
          ),
          const SizedBox(width: 6),
          _StatusFilterChip(
            label: 'هولد (${_c.summary.holdCount})',
            selected: _selectedStatusFilter == PaymentStatus.hold,
            activeColor: AppColors.gold,
            activeTextColor: AppColors.primary,
            onTap: () =>
                setState(() => _selectedStatusFilter = PaymentStatus.hold),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    if (_c.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _filteredEntries();
    final groups = _groupByArea(filtered);

    return RefreshIndicator(
      onRefresh: _manualRefreshOrSync,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        scrollbarOrientation: ScrollbarOrientation.right,
        child: groups.isEmpty
            ? ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 50),
                  const Icon(
                    Icons.people_outline_rounded,
                    size: 60,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _c.entries.isEmpty
                        ? 'لا يوجد عملاء في هذا الشهر بعد\nاضغط زر (+) لإضافة عميل جديد'
                        : 'لا توجد نتائج مطابقة للبحث أو الفلتر المحدد',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              )
            : ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 4, 12, 90),
                itemCount: groups.length,
                itemBuilder: (context, groupIndex) {
                  final group = groups[groupIndex];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // عنوان المنطقة كفاصل بخط رفيع وأنيق
                      _AreaHeaderDivider(
                        areaName: group.areaName,
                        count: group.items.length,
                      ),
                      for (final item in group.items) ...[
                        CustomerCard(
                          item: item,
                          onTap: () => _openForm(item),
                          onQuickCollect: (method) =>
                              _c.quickCollect(item, method),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _AreaGroup {
  const _AreaGroup({required this.areaName, required this.items});

  final String areaName;
  final List<CustomerEntry> items;
}

/// عنوان المنطقة الفاصل بخط رفيع وأنيق فوق عملاء كل منطقة.
class _AreaHeaderDivider extends StatelessWidget {
  const _AreaHeaderDivider({required this.areaName, required this.count});

  final String areaName;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.place_outlined,
            size: 16,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 6),
          Text(
            areaName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: AppColors.primary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(
              color: AppColors.border,
              thickness: 0.8,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
    this.activeTextColor = Colors.white,
  });

  final String label;
  final bool selected;
  final Color activeColor;
  final Color activeTextColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? activeColor : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? activeColor : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? activeTextColor : AppColors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}
