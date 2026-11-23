import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// على Android و iOS يُحفظ ملف التقرير في مجلد Reports على الجهاز.
Future<String?> saveReportToDevice(String fileName, Uint8List bytes) async {
  Directory? base;
  if (Platform.isAndroid) {
    base = await getExternalStorageDirectory();
  }
  base ??= await getApplicationDocumentsDirectory();
  final directory = Directory(p.join(base.path, 'Reports'));
  if (!directory.existsSync()) {
    await directory.create(recursive: true);
  }
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
