import 'package:web/web.dart' as web;

class SnapshotPersistence {
  Future<String?> read() async =>
      web.window.localStorage.getItem('daymaster.snapshot.v1');
  Future<void> write(String value) async {
    web.window.localStorage.setItem('daymaster.snapshot.v1', value);
  }
}
