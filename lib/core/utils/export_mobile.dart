import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportData(String content, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content, flush: true);
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'HerbaScan export: $filename',
  );
}
