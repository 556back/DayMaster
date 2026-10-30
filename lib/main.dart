import 'package:flutter/material.dart';

import 'store.dart';
import 'ui/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  AppLifecycleListener(onResume: () => store.refreshNative());
  runApp(DayMasterApp(store: store));
  await store.initialize();
  void openEvent(String id) {
    if (store.eventById(id) == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => EventDetailPage(store: store, eventId: id),
        ),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  store.native.onOpenEvent(openEvent);
  try {
    final id = await store.native.getLaunchEventId();
    if (id != null) openEvent(id);
  } catch (_) {
    /* App remains usable if the system deep link is unavailable. */
  }
}
