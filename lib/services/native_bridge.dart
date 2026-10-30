import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeBridge {
  static const channel = MethodChannel('daymaster/native');
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<void> saveSnapshot(String json) async {
    if (supported) {
      await channel.invokeMethod<bool>('saveSnapshot', {'json': json});
    }
  }

  Future<bool> requestPinWidget(String id) async =>
      supported &&
      (await channel.invokeMethod<bool>('requestPinWidget', {'configId': id}) ??
          false);
  Future<bool> requestNotifications() async =>
      supported &&
      (await channel.invokeMethod<bool>('requestNotifications') ?? false);
  Future<String?> getLaunchEventId() async =>
      supported ? channel.invokeMethod<String>('getLaunchEventId') : null;
  void onOpenEvent(void Function(String) callback) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'openEvent' && call.arguments is Map) {
        final id = (call.arguments as Map)['id'];
        if (id is String) callback(id);
      }
    });
  }
}
