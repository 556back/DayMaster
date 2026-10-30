import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SnapshotPersistence {
  Future<File> _file() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/daymaster.json');
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  Future<void> write(String value) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(value, flush: true);
    await temporary.rename(file.path);
  }
}
