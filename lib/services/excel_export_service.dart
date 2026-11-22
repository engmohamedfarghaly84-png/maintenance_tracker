import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/engineer_settings.dart';
import '../models/enums.dart';
import '../models/maintenance_entry.dart';
import '../models/month_key.dart';
import '../utils/formatters.dart';
import 'finance_calculator.dart';

/// البيانات اللازمة لتوليد تقرير Excel الشهري.
class ExcelReportData {
  const ExcelReportData({
    required this.month,
    required this.settings,
    required this.entries,
    required this.outstanding,
    required this.summary,
    required this.settlement,
    required this.settlementApproved,
  });

  final MonthKey month;
  final EngineerSettings settings;
  final List<CustomerEntry> entries;
  final List<CustomerEntry> outstanding;
  final MonthSummary summary;
  final SettlementBreakdown settlement;
  final bool settlementApproved;
}

/// توليد ملف Excel منسق من اليمين لليسار بثلاث ورقات.
class ExcelExportService {
  static const String sheetSummary = 'الرئيسية والتسوية';
  static const String sheetLog = 'سجل العملاء والصيانة';
  static const String sheetOverdue = 'المتأخرات والهولد';

  static const String _navy = '#0F2A4A';
  static const String _slate = '#4A5A70';
  static const String _gold = '#F4B73C';
  static const String _orange = '#E8590C';
  static const String _green = '#16A34A';
  static const String _light = '#F5F7FA';
  static const String _white = '#FFFFFF';
  static const String _borderColor = '#DDE3EC';

  Future<File> export(ExcelReportData data) async {
    final excel = xl.Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, sheetSummary);

    final summarySheet = excel[sheetSummary];
    final logSheet = excel[sheetLog];
    final overdueSheet = excel[sheetOverdue];
    for (final sheet in [summarySheet, logSheet, overdueSheet]) {
      sheet.isRTL = true;
    }

    _buildSummarySheet(summarySheet, data);
    _buildLogSheet(logSheet, data);
    _buildOverdueSheet(overdueSheet, data);
    excel.setDefaultSheet(sheetSummary);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('تعذر إنشاء ملف Excel');
    }

    final directory = await _reportsDirectory();
    final stamp = DateTime.now();
    final fileName = 'maintenance_${data.month.key}_'
        '${stamp.year}${_two(stamp.month)}${_two(stamp.day)}_'
        '${_two(stamp.hour)}${_two(stamp.minute)}${_two(stamp.second)}.xlsx';
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Directory> _reportsDirectory() async {
    Directory? base;
    if (Platform.isAndroid) {
      base = await getExternalStorageDirectory();
    }
    base ??= await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(base.path, 'Reports'));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  // ---------------------------------------------------------------------------
  // الورقة 1: الرئيسية والتسوية
  // ---------------------------------------------------------------------------
  void _buildSummarySheet(xl.Sheet sheet, ExcelReportData data) {
    sheet.setColumnWidth(0, 42);
    sheet.setColumnWidth(1, 24);

    var row = 0;
    _title(sheet, row++, 2, 'تقرير الصيانة - ${data.month.label}');
    final name = data.settings.engineerName.isEmpty ? '-' : data.settings.engineerName;
    _pair(sheet, row++, 'اسم المهندس', xl.TextCellValue(name));
    _pair(sheet, row++, 'تاريخ التصدير', xl.TextCellValue(formatDateTime(DateTime.now())));
    row++;

    _sectionHeader(sheet, row++, 2, 'ملخص الشهر');
    final s = data.summary;
    _pair(sheet, row++, 'إجمالي الصيانة', _num(s.total));
    _pair(sheet, row++, 'المحصّل (إجمالي الصيانة المدفوع)', _num(s.collected), valueColor: _green);
    _pair(sheet, row++, 'غير المحصّل (المتبقي غير المدفوع)', _num(s.uncollected), valueColor: _orange);
    _pair(sheet, row++, 'منها تحصيل مقدم من الشهر القادم', _num(s.advanceCollected), valueColor: _gold);
    _pair(
      sheet,
      row++,
      'العمولة (${formatNumber(s.commissionRate)}% ${data.settings.commissionBasis.label})',
      _num(s.commission),
      valueColor: _gold,
    );
    _pair(sheet, row++, 'الباقي بعد العمولة', _num(s.remainder));
    _pair(sheet, row++, 'عدد العملاء (دفع / لم يدفع / هولد)',
        xl.TextCellValue('${s.paidCount} / ${s.unpaidCount} / ${s.holdCount}'));
    row++;

    _sectionHeader(sheet, row++, 2, 'تسوية الحساب الشهري');
    final b = data.settlement;
    _pair(sheet, row++, 'إجمالي الصيانات المحصّلة', _num(b.totalMaintenance));
    _pair(sheet, row++, '(-) العمولة', _num(b.commission));
    _pair(sheet, row++, '(-) التحويلات عبر المحفظة', _num(b.walletTransfers));
    _pair(sheet, row++, '(-) الراتب الأساسي', _num(b.baseSalary));
    _pair(sheet, row++, '(-) جمعية', _num(data.settings.duesAssociation));
    _pair(sheet, row++, '(-) اتصالات', _num(data.settings.duesTelecom));
    _pair(sheet, row++, '(-) تأمين', _num(data.settings.duesInsurance));
    _pair(sheet, row++, '(+) الباقي عليّ (مرحّل)', _num(b.carriedIn));
    _pair(sheet, row++, '(-) السداد', _num(b.payment));

    final labelStyle = _style(bg: _orange, fg: _white, bold: true, size: 13);
    _cell(sheet, 0, row, xl.TextCellValue('صافي المتبقي النهائي'), labelStyle);
    _cell(sheet, 1, row, _num(b.net), labelStyle);
    row++;
    _pair(
      sheet,
      row,
      'حالة التسوية',
      xl.TextCellValue(data.settlementApproved ? 'معتمدة ومرحّلة' : 'غير معتمدة بعد'),
    );
  }

  // ---------------------------------------------------------------------------
  // الورقة 2: سجل العملاء والصيانة
  // ---------------------------------------------------------------------------
  void _buildLogSheet(xl.Sheet sheet, ExcelReportData data) {
    const headers = ['م', 'اسم العميل', 'المنطقة / المكان', 'قيمة الصيانة (ج.م)', 'حالة الدفع', 'طريقة الدفع', 'ملاحظة'];
    const widths = [6.0, 28.0, 24.0, 18.0, 14.0, 14.0, 30.0];
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
    _title(sheet, 0, headers.length, 'سجل العملاء والصيانة - ${data.month.label}');
    _headerRow(sheet, 1, headers);

    var row = 2;
    for (var i = 0; i < data.entries.length; i++) {
      final item = data.entries[i];
      final zebra = i.isEven ? _white : _light;
      final base = _style(bg: zebra);
      _cell(sheet, 0, row, xl.IntCellValue(i + 1), _style(bg: zebra, align: xl.HorizontalAlign.Center));
      _cell(sheet, 1, row, xl.TextCellValue(item.customer.name), _style(bg: zebra, bold: true));
      _cell(sheet, 2, row, xl.TextCellValue(item.customer.area), base);
      _cell(sheet, 3, row, _num(item.entry.amount), base);
      _cell(sheet, 4, row, xl.TextCellValue(item.entry.status.label), _statusStyle(item.entry.status));
      _cell(sheet, 5, row, xl.TextCellValue(item.entry.paymentMethod.label), base);
      _cell(
        sheet,
        6,
        row,
        xl.TextCellValue(item.entry.isAdvance ? 'تحصيل مقدم من الشهر القادم' : ''),
        item.entry.isAdvance ? _style(bg: _gold, fg: _navy, bold: true) : base,
      );
      row++;
    }

    final totalStyle = _style(bg: _navy, fg: _white, bold: true);
    _cell(sheet, 0, row, xl.TextCellValue(''), totalStyle);
    _cell(sheet, 1, row, xl.TextCellValue('الإجمالي'), totalStyle);
    _cell(sheet, 2, row, xl.TextCellValue('${data.entries.length} عميل'), totalStyle);
    _cell(sheet, 3, row, _num(data.summary.total), totalStyle);
    _cell(sheet, 4, row, xl.TextCellValue('المحصّل: ${formatNumber(data.summary.collected)}'), totalStyle);
    _cell(sheet, 5, row, xl.TextCellValue(''), totalStyle);
    _cell(sheet, 6, row, xl.TextCellValue('غير المحصّل: ${formatNumber(data.summary.uncollected)}'), totalStyle);
  }

  // ---------------------------------------------------------------------------
  // الورقة 3: المتأخرات والهولد
  // ---------------------------------------------------------------------------
  void _buildOverdueSheet(xl.Sheet sheet, ExcelReportData data) {
    const headers = ['م', 'الشهر', 'اسم العميل', 'المنطقة / المكان', 'المبلغ (ج.م)', 'الحالة'];
    const widths = [6.0, 22.0, 28.0, 24.0, 16.0, 14.0];
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
    _title(sheet, 0, headers.length, 'المتأخرات والهولد حتى ${data.month.label}');
    _headerRow(sheet, 1, headers);

    var row = 2;
    var total = 0.0;
    for (var i = 0; i < data.outstanding.length; i++) {
      final item = data.outstanding[i];
      final zebra = i.isEven ? _white : _light;
      final base = _style(bg: zebra);
      _cell(sheet, 0, row, xl.IntCellValue(i + 1), _style(bg: zebra, align: xl.HorizontalAlign.Center));
      _cell(sheet, 1, row, xl.TextCellValue(MonthKey.parse(item.entry.accountMonth).label), base);
      _cell(sheet, 2, row, xl.TextCellValue(item.customer.name), _style(bg: zebra, bold: true));
      _cell(sheet, 3, row, xl.TextCellValue(item.customer.area), base);
      _cell(sheet, 4, row, _num(item.entry.amount), base);
      _cell(sheet, 5, row, xl.TextCellValue(item.entry.status.label), _statusStyle(item.entry.status));
      total += item.entry.amount;
      row++;
    }

    if (data.outstanding.isEmpty) {
      _cell(sheet, 0, row, xl.TextCellValue('لا توجد متأخرات أو حالات هولد'), _style(fg: _green, bold: true));
      sheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        xl.CellIndex.indexByColumnRow(columnIndex: headers.length - 1, rowIndex: row),
      );
      return;
    }

    final totalStyle = _style(bg: _orange, fg: _white, bold: true);
    _cell(sheet, 0, row, xl.TextCellValue(''), totalStyle);
    _cell(sheet, 1, row, xl.TextCellValue('إجمالي المتأخرات'), totalStyle);
    _cell(sheet, 2, row, xl.TextCellValue('${data.outstanding.length} سجل'), totalStyle);
    _cell(sheet, 3, row, xl.TextCellValue(''), totalStyle);
    _cell(sheet, 4, row, _num(total), totalStyle);
    _cell(sheet, 5, row, xl.TextCellValue(''), totalStyle);
  }

  // ---------------------------------------------------------------------------
  // أدوات التنسيق
  // ---------------------------------------------------------------------------
  static String _two(int v) => v.toString().padLeft(2, '0');

  xl.CellValue _num(double value) =>
      value == value.roundToDouble() ? xl.IntCellValue(value.toInt()) : xl.DoubleCellValue(value);

  xl.Border get _border => xl.Border(
        borderStyle: xl.BorderStyle.Thin,
        borderColorHex: xl.ExcelColor.fromHexString(_borderColor),
      );

  xl.CellStyle _style({
    String? bg,
    String fg = _navy,
    bool bold = false,
    int size = 11,
    xl.HorizontalAlign align = xl.HorizontalAlign.Right,
  }) {
    return xl.CellStyle(
      backgroundColorHex: bg == null ? xl.ExcelColor.none : xl.ExcelColor.fromHexString(bg),
      fontColorHex: xl.ExcelColor.fromHexString(fg),
      bold: bold,
      fontSize: size,
      fontFamily: 'Cairo',
      horizontalAlign: align,
      verticalAlign: xl.VerticalAlign.Center,
      leftBorder: _border,
      rightBorder: _border,
      topBorder: _border,
      bottomBorder: _border,
    );
  }

  xl.CellStyle _statusStyle(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return _style(bg: _green, fg: _white, bold: true, align: xl.HorizontalAlign.Center);
      case PaymentStatus.unpaid:
        return _style(bg: _orange, fg: _white, bold: true, align: xl.HorizontalAlign.Center);
      case PaymentStatus.hold:
        return _style(bg: _gold, fg: _navy, bold: true, align: xl.HorizontalAlign.Center);
    }
  }

  void _cell(xl.Sheet sheet, int col, int row, xl.CellValue value, xl.CellStyle style) {
    sheet.updateCell(
      xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      value,
      cellStyle: style,
    );
  }

  void _title(xl.Sheet sheet, int row, int columns, String text) {
    final style = _style(bg: _navy, fg: _white, bold: true, size: 14, align: xl.HorizontalAlign.Center);
    for (var c = 0; c < columns; c++) {
      _cell(sheet, c, row, xl.TextCellValue(c == 0 ? text : ''), style);
    }
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      xl.CellIndex.indexByColumnRow(columnIndex: columns - 1, rowIndex: row),
      customValue: xl.TextCellValue(text),
    );
  }

  void _sectionHeader(xl.Sheet sheet, int row, int columns, String text) {
    final style = _style(bg: _slate, fg: _white, bold: true, size: 12);
    for (var c = 0; c < columns; c++) {
      _cell(sheet, c, row, xl.TextCellValue(c == 0 ? text : ''), style);
    }
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      xl.CellIndex.indexByColumnRow(columnIndex: columns - 1, rowIndex: row),
      customValue: xl.TextCellValue(text),
    );
  }

  void _headerRow(xl.Sheet sheet, int row, List<String> headers) {
    final style = _style(bg: _slate, fg: _white, bold: true, align: xl.HorizontalAlign.Center);
    for (var c = 0; c < headers.length; c++) {
      _cell(sheet, c, row, xl.TextCellValue(headers[c]), style);
    }
  }

  void _pair(xl.Sheet sheet, int row, String label, xl.CellValue value, {String? valueColor}) {
    _cell(sheet, 0, row, xl.TextCellValue(label), _style(bg: _light, bold: true));
    _cell(sheet, 1, row, value, _style(fg: valueColor ?? _navy, bold: valueColor != null));
  }
}
