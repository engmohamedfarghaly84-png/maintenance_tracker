import 'package:material_ui/material_ui.dart';

import '../models/maintenance_entry.dart';
import '../services/app_controller.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';
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

  AppController get _c => widget.controller;

  @override
  void dispose() {
    _scrollController.dispose();
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
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  children: [
                    MonthSelector(
                      month: _c.month,
                      onPrevious: _c.goToPreviousMonth,
                      onNext: _c.goToNextMonth,
                      onTapCurrent: _c.goToCurrentMonth,
                    ),
                    const SizedBox(height: 10),
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
                  ],
                ),
              ),
              // ===== الجزء الأوسط القابل للتمرير =====
              Expanded(child: _buildList()),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'إضافة عميل',
            onPressed: () => _openForm(),
            child: const Icon(Icons.add_rounded, size: 30),
          ),
          // ===== الجزء السفلي الثابت =====
          bottomNavigationBar: FooterSummary(summary: summary),
        );
      },
    );
  }

  Widget _buildList() {
    if (_c.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final entries = _c.entries;
    return RefreshIndicator(
      onRefresh: _manualRefreshOrSync,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        scrollbarOrientation: ScrollbarOrientation.right,
        child: entries.isEmpty
            ? ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 60),
                  Icon(
                    Icons.people_outline_rounded,
                    size: 64,
                    color: AppColors.secondary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'لا يوجد عملاء في هذا الشهر بعد\nاضغط زر (+) لإضافة عميل جديد',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: AppColors.secondary),
                  ),
                ],
              )
            : ListView.separated(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 4, 12, 90),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = entries[index];
                  return CustomerCard(item: item, onTap: () => _openForm(item));
                },
              ),
      ),
    );
  }
}
