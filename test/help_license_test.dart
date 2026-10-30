import 'package:daymaster/app_info.dart';
import 'package:daymaster/services/native_bridge.dart';
import 'package:daymaster/store.dart';
import 'package:daymaster/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Native extends NativeBridge {
  @override
  Future<void> saveSnapshot(String json) async {}
}

Future<AppStore> _store() async {
  final store = AppStore(
    read: () async => null,
    write: (_) async {},
    native: _Native(),
    tick: false,
  );
  await store.initialize();
  return store;
}

void main() {
  testWidgets('home help opens and scrolls on a small phone with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = await _store();
    addTearDown(store.dispose);
    await tester.pumpWidget(DayMasterApp(store: store));
    await tester.tap(find.byTooltip('使用说明'));
    await tester.pumpAndSettle();
    expect(find.text('1. 添加日子'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('5. 备份与恢复'), 400);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('one-screen-home')), findsOneWidget);
  });

  testWidgets('settings shows 1.0.0 and loads the bundled project license', (
    tester,
  ) async {
    final store = await _store();
    addTearDown(store.dispose);
    await tester.pumpWidget(DayMasterApp(store: store));
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置与备份'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('项目许可'), 300);
    await tester.ensureVisible(find.text('项目许可'));
    await tester.pumpAndSettle();
    expect(find.text('版本 $appVersion'), findsOneWidget);
    await tester.tap(find.text('项目许可'));
    await tester.pumpAndSettle();
    expect(find.text('$appName 1.0.0'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            (widget.data?.contains('Copyright 2026 DayMaster contributors') ??
                false),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Apache License 2.0'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            (widget.data?.contains('TERMS AND CONDITIONS FOR USE') ?? false),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
