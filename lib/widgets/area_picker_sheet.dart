import 'package:material_ui/material_ui.dart';

import '../models/saved_area.dart';
import '../services/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/arabic_utils.dart';

/// الزر المربع البرتقالي المميز لفتح نافذة المناطق المحفوظة.
class OrangeAreaButton extends StatelessWidget {
  const OrangeAreaButton({
    super.key,
    required this.onTap,
    this.tooltip = 'قائمة المناطق المحفوظة',
    this.hasActiveFilter = false,
  });

  final VoidCallback onTap;
  final String tooltip;
  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(AppColors.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppColors.radius),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.place_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const Positioned(
                  bottom: 8,
                  left: 8,
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
                if (hasActiveFilter)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// فتح النافذة المنبثقة (Modal Bottom Sheet) للمناطق المحفوظة مرتبة أبجدياً
/// مع عدد العملاء في كل منطقة وخانة فلترة بالحرف الأول في أعلاها.
Future<void> showAreaPickerSheet({
  required BuildContext context,
  required AppController controller,
  required ValueChanged<String?> onSelectArea,
  String? selectedArea,
  bool showClearFilterOption = false,
  bool allowDelete = false,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AreaPickerSheetBody(
      controller: controller,
      selectedArea: selectedArea,
      showClearFilterOption: showClearFilterOption,
      allowDelete: allowDelete,
      onSelectArea: (area) {
        Navigator.of(ctx).pop();
        onSelectArea(area);
      },
    ),
  );
}

class _AreaPickerSheetBody extends StatefulWidget {
  const _AreaPickerSheetBody({
    required this.controller,
    required this.onSelectArea,
    this.selectedArea,
    this.showClearFilterOption = false,
    this.allowDelete = false,
  });

  final AppController controller;
  final ValueChanged<String?> onSelectArea;
  final String? selectedArea;
  final bool showClearFilterOption;
  final bool allowDelete;

  @override
  State<_AreaPickerSheetBody> createState() => _AreaPickerSheetBodyState();
}

class _AreaPickerSheetBodyState extends State<_AreaPickerSheetBody> {
  final TextEditingController _filterController = TextEditingController();

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final query = _filterController.text.trim();
        final counts = widget.controller.areaCustomerCounts;
        final savedById = <String, SavedArea>{
          for (final a in widget.controller.savedAreas) a.name.trim(): a,
        };
        final allNames = widget.controller.sortedAreaNames;
        final filtered = allNames.where((name) {
          if (query.isEmpty) return true;
          return ArabicUtils.startsWithNormalized(name, query) ||
              ArabicUtils.containsNormalized(name, query);
        }).toList();

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.72,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.place_rounded,
                            color: AppColors.orange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'المناطق المحفوظة (${allNames.length})',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (widget.showClearFilterOption &&
                            widget.selectedArea != null)
                          TextButton.icon(
                            onPressed: () => widget.onSelectArea(null),
                            icon: const Icon(
                              Icons.filter_alt_off_rounded,
                              size: 18,
                              color: AppColors.orange,
                            ),
                            label: const Text(
                              'مسح الفلتر',
                              style: TextStyle(color: AppColors.orange),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // خانة الفلترة بالحرف الأول (مع تطبيع الألف أ/إ/آ/ا)
                    TextField(
                      controller: _filterController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'ابحث بالحرف الأول من المنطقة (أ / إ / ا)...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _filterController.clear();
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (widget.showClearFilterOption)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppColors.radius),
                          onTap: () => widget.onSelectArea(null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: widget.selectedArea == null
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : AppColors.background,
                              borderRadius:
                                  BorderRadius.circular(AppColors.radius),
                              border: Border.all(
                                color: widget.selectedArea == null
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.apps_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'كل المناطق (عرض الجميع)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    '${widget.controller.entries.length} عميل',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_off_outlined,
                                    size: 40,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    query.isEmpty
                                        ? 'لا توجد مناطق محفوظة بعد'
                                        : 'لا توجد منطقة تبدأ بـ «$query»',
                                    style: const TextStyle(
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                  if (query.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.orange,
                                      ),
                                      onPressed: () async {
                                        await widget.controller
                                            .addSavedArea(query);
                                        widget.onSelectArea(query);
                                      },
                                      icon: const Icon(Icons.add_location_alt),
                                      label: Text('حفظ واستخدام «$query»'),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final areaName = filtered[index];
                                final count = counts[areaName] ?? 0;
                                final isSelected =
                                    widget.selectedArea == areaName;
                                final savedArea = savedById[areaName];

                                return InkWell(
                                  borderRadius: BorderRadius.circular(
                                    AppColors.radius,
                                  ),
                                  onTap: () => widget.onSelectArea(areaName),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.orange
                                              .withValues(alpha: 0.12)
                                          : AppColors.background,
                                      borderRadius: BorderRadius.circular(
                                        AppColors.radius,
                                      ),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.orange
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          size: 18,
                                          color: isSelected
                                              ? AppColors.orange
                                              : AppColors.secondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            areaName,
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: isSelected
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: count > 0
                                                ? AppColors.primary
                                                    .withValues(alpha: 0.1)
                                                : AppColors.border,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Text(
                                            '$count عميل',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        if (widget.allowDelete &&
                                            savedArea != null) ...[
                                          const SizedBox(width: 6),
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            tooltip: 'حذف المنطقة',
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppColors.orange,
                                              size: 20,
                                            ),
                                            onPressed: () => widget.controller
                                                .deleteSavedArea(savedArea.id),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// حقل إدخال المنطقة مع فلترة تلقائية بالحرف الأول (تطبيع الألف أ/إ/آ/ا)
/// وبجانبه على اليسار الزر المربع البرتقالي لاختيار منطقة من المناطق المحفوظة.
class AreaAutocompleteField extends StatefulWidget {
  const AreaAutocompleteField({
    super.key,
    required this.controller,
    required this.appController,
    this.labelText = 'المنطقة / المكان',
    this.hintText = 'مثال: مدينة نصر أو عباس العقاد',
    this.onAreaSelected,
    this.trailingAction,
  });

  final TextEditingController controller;
  final AppController appController;
  final String labelText;
  final String hintText;
  final ValueChanged<String>? onAreaSelected;
  final Widget? trailingAction;

  @override
  State<AreaAutocompleteField> createState() => _AreaAutocompleteFieldState();
}

class _AreaAutocompleteFieldState extends State<AreaAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (mounted) {
      setState(() => _showSuggestions = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    _focusNode.dispose();
    super.dispose();
  }

  void _select(String area) {
    widget.controller.text = area;
    widget.controller.selection = TextSelection.collapsed(offset: area.length);
    setState(() => _showSuggestions = false);
    _focusNode.unfocus();
    widget.onAreaSelected?.call(area);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appController,
      builder: (context, _) {
        final query = widget.controller.text.trim();
        final allAreas = widget.appController.sortedAreaNames;
        final counts = widget.appController.areaCustomerCounts;
        final matches = query.isEmpty
            ? const <String>[]
            : allAreas
                .where(
                  (area) =>
                      area != query &&
                      (ArabicUtils.startsWithNormalized(area, query) ||
                          ArabicUtils.containsNormalized(area, query)),
                )
                .take(5)
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() => _showSuggestions = true),
                    decoration: InputDecoration(
                      labelText: widget.labelText,
                      hintText: widget.hintText,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OrangeAreaButton(
                  tooltip: 'اختيار من المناطق المحفوظة',
                  onTap: () => showAreaPickerSheet(
                    context: context,
                    controller: widget.appController,
                    selectedArea: query.isEmpty ? null : query,
                    onSelectArea: (picked) {
                      if (picked != null) _select(picked);
                    },
                  ),
                ),
                if (widget.trailingAction != null) ...[
                  const SizedBox(width: 8),
                  widget.trailingAction!,
                ],
              ],
            ),
            if (_showSuggestions && matches.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppColors.radius),
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.5),
                  ),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final area in matches)
                      ActionChip(
                        avatar: const Icon(
                          Icons.place_rounded,
                          size: 15,
                          color: AppColors.orange,
                        ),
                        backgroundColor: AppColors.background,
                        label: Text(
                          '$area (${counts[area] ?? 0})',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        onPressed: () => _select(area),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
