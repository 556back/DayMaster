import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:daymaster/ui/photo_processing.dart';

import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymaster/models/day_event.dart';
import 'package:daymaster/models/widget_config.dart';
import 'package:daymaster/store.dart';
import 'package:daymaster/services/native_bridge.dart';
import 'package:daymaster/theme.dart';
import 'package:daymaster/ui/app.dart';
import 'package:daymaster/ui/widget_pages.dart';

class UiNative extends NativeBridge {
  @override
  Future<void> saveSnapshot(String json) async {}
}

Future<AppStore> makeStore({DateTime Function()? now}) async {
  final store = AppStore(
    read: () async => null,
    write: (_) async {},
    tick: false,
    native: UiNative(),
    now: now,
  );
  await store.initialize();
  return store;
}

void main() {
  testWidgets(
    'empty home keeps a large add target and mutable widget status is safe',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = await makeStore();
      addTearDown(store.dispose);
      store.nativeWarning = '系统组件尚未更新';
      await tester.pumpWidget(DayMasterApp(store: store));
      expect(
        tester.getRect(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      store.nativeWarning = null;
      await tester.tap(find.text('组件更新状态'));
      await tester.pumpAndSettle();
      expect(find.text('组件已更新。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'home stays one screen with many days on small phones and large text',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = await makeStore(now: () => DateTime(2026, 10, 3));
      addTearDown(store.dispose);
      await store.saveEvent(
        DayEvent(
          id: 'focus',
          title: '最重要的长标题纪念日一直留在首页',
          date: DateTime(2027, 1, 1),
          pinned: true,
        ),
      );
      for (var i = 0; i < 12; i++) {
        await store.saveEvent(
          DayEvent(
            id: 'day-$i',
            title: '其他日子 $i',
            date: DateTime(2026, 10, 4 + i),
          ),
        );
      }
      for (final size in [
        const Size(320, 568),
        const Size(320, 740),
        const Size(360, 740),
        const Size(390, 844),
      ]) {
        await tester.binding.setSurfaceSize(size);
        for (final scale in [1.0, 1.4, 1.49, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          for (final mode in ['light', 'dark']) {
            await store.setThemeMode(mode);
            await tester.pumpWidget(DayMasterApp(store: store));
            await tester.pumpAndSettle();
            final home = find.byKey(const ValueKey('one-screen-home'));
            expect(
              find.descendant(of: home, matching: find.byType(Scrollable)),
              findsNothing,
            );
            expect(find.text('最重要的长标题纪念日一直留在首页'), findsOneWidget);
            expect(find.byType(TextField), findsNothing);
            expect(
              tester.getBottomLeft(find.text('添加日子')).dy,
              lessThan(tester.getTopLeft(find.byType(NavigationBar)).dy),
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '$size $scale $mode',
            );
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      }
    },
  );
  testWidgets('all days remains reachable and back restores the fixed home', (
    tester,
  ) async {
    final store = await makeStore(now: () => DateTime(2026, 10, 3));
    addTearDown(store.dispose);
    await store.saveEvent(
      DayEvent(id: 'near', title: '最近的旅行', date: DateTime(2026, 10, 4)),
    );
    await store.saveEvent(
      DayEvent(id: 'far', title: '远处的期待', date: DateTime(2027)),
    );
    await tester.pumpWidget(DayMasterApp(store: store));
    expect(find.text('最近的旅行'), findsOneWidget);
    await tester.tap(find.text('全部日子'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '远处');
    await tester.pump();
    expect(find.text('远处的期待'), findsOneWidget);
    expect(find.text('最近的旅行'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('one-screen-home')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    '320px home and library remain usable with large text in both themes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = await makeStore();
      addTearDown(store.dispose);
      await store.saveEvent(
        DayEvent(
          id: 'responsive-day',
          title: '这是属于我们的一个特别重要的长标题纪念日',
          date: DateTime(1900),
          category: '一段很长的导入分类名称',
          pinned: true,
        ),
      );
      for (final mode in ['light', 'dark']) {
        await store.setThemeMode(mode);
        await tester.pumpWidget(DayMasterApp(store: store));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$mode home');
        await tester.ensureVisible(find.text('这是属于我们的一个特别重要的长标题纪念日'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$mode event card');
        await tester.tap(find.text('小组件'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$mode library');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets('360px create then edit a day, preserving the owning list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await makeStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(DayMasterApp(store: store));
    expect(find.text('把重要的日子留下来'), findsOneWidget);
    await tester.ensureVisible(find.text('添加第一个日子'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加第一个日子'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '我们的第一天');

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.events.single.title, '我们的第一天');
    expect(find.text('我们的第一天'), findsOneWidget);
    await tester.tap(find.text('我们的第一天'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑日子'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '我们的纪念日');

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.events.single.title, '我们的纪念日');
    expect(find.text('日子详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('discard confirmation keeps an unsaved draft on cancel', (
    tester,
  ) async {
    final store = await makeStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(DayMasterApp(store: store));
    await tester.ensureVisible(find.text('添加第一个日子'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加第一个日子'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '还没保存的旅行');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的修改？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('还没保存的旅行'), findsOneWidget);
    expect(store.events, isEmpty);
  });
  testWidgets('search no results exposes immediate clear action', (
    tester,
  ) async {
    final store = await makeStore();
    addTearDown(store.dispose);
    await store.saveEvent(
      DayEvent(
        id: 'search-example',
        title: '期待旅行',
        date: DateTime.now().add(const Duration(days: 30)),
      ),
    );
    await tester.pumpWidget(DayMasterApp(store: store));
    await tester.tap(find.text('全部日子'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '不存在的标题');
    await tester.pump();
    expect(find.text('没有找到这样的日子'), findsOneWidget);
    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pump();
    expect(find.text('期待旅行'), findsOneWidget);
  });
  testWidgets('small widget previews fit 164px in light and dark themes', (
    tester,
  ) async {
    final store = await makeStore();
    addTearDown(store.dispose);
    await store.saveEvent(
      DayEvent(
        id: 'preview-example',
        title: '结婚纪念日',
        date: DateTime(2020, 2, 29),
        repeatYearly: true,
      ),
    );
    for (final brightness in Brightness.values) {
      for (final style in ['number', 'photo', 'dual', 'list']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: dayTheme(brightness),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 164,
                  child: WidgetPreview(
                    store: store,
                    config: WidgetConfig(
                      id: 'preview-config',
                      style: style,
                      eventIds: const ['preview-example'],
                    ),
                    height: 164,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$brightness $style');
      }
    }
  });
  testWidgets('failed persistence retains the editor input', (tester) async {
    final store = AppStore(
      read: () async => null,
      write: (_) async => throw Exception('存储不可用'),
      tick: false,
      native: UiNative(),
    );
    await store.initialize();
    addTearDown(store.dispose);
    await tester.pumpWidget(DayMasterApp(store: store));
    await tester.ensureVisible(find.text('添加第一个日子'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加第一个日子'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '重试也要保留的日子');

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('存储不可用'), findsOneWidget);
    expect(find.text('重试也要保留的日子'), findsOneWidget);
    expect(store.events, isEmpty);
  });
  testWidgets('360px create a widget and persist a new theme', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await makeStore();
    addTearDown(store.dispose);
    final event = DayEvent(
      id: 'widget-day',
      title: '每年的这一天',
      date: DateTime(2020, 5, 20),
      repeatYearly: true,
    );
    await store.saveEvent(event);
    await tester.pumpWidget(DayMasterApp(store: store));
    await tester.tap(find.text('小组件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('大数字'));
    await tester.pumpAndSettle();
    final record = find.text('${event.emoji} ${event.title}');
    await tester.ensureVisible(record);
    await tester.pumpAndSettle();
    await tester.tap(record);
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.widgets.single.eventIds, ['widget-day']);
    await tester.scrollUntilVisible(
      find.text('编辑'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('玫瑰粉'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('玫瑰粉'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.widgets.single.theme, 'rose');
    expect(tester.takeException(), isNull);
  });
  testWidgets('390px filters keep both Chinese characters and brand blue', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await makeStore();
    addTearDown(store.dispose);
    const longCategory = '一段很长的导入分类名称';
    await store.saveEvent(
      DayEvent(
        id: 'filter-category',
        title: '分类宽度验收',
        date: DateTime.now(),
        category: longCategory,
      ),
    );
    await tester.pumpWidget(DayMasterApp(store: store));
    await tester.tap(find.text('全部日子'));
    await tester.pumpAndSettle();
    for (final label in ['全部', '将来', '过去']) {
      final text = find.text(label);
      expect(text, findsOneWidget);
      expect(tester.getSize(text).width, greaterThanOrEqualTo(40));
      final widget = tester.widget<Text>(text);
      expect(widget.maxLines, 1);
      expect(widget.softWrap, false);
    }
    expect(tester.getSize(find.text('全部分类')).width, greaterThanOrEqualTo(64));
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byType(FilterChip),
              matching: find.text(longCategory),
            ),
          )
          .width,
      greaterThanOrEqualTo(longCategory.runes.length * 16),
    );
    expect(dayTheme(Brightness.light).colorScheme.primary, DayColors.blue);
    expect(dayTheme(Brightness.light).colorScheme.onPrimary, Colors.white);
    expect(tester.takeException(), isNull);
  });
  testWidgets('164px long title and six digits keep the unit readable', (
    tester,
  ) async {
    final store = await makeStore(now: () => DateTime(2200, 12, 31));
    addTearDown(store.dispose);
    await store.saveEvent(
      DayEvent(
        id: 'long-preview',
        title: '这是属于我们的一个特别重要的长标题纪念日',
        date: DateTime(1900),
      ),
    );
    final count = store.events.single.status(store.now()).days.toString();
    expect(count.length, 6);
    for (final brightness in Brightness.values) {
      for (final style in ['number', 'photo']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: dayTheme(brightness),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 164,
                  child: WidgetPreview(
                    store: store,
                    config: WidgetConfig(
                      id: 'long-widget',
                      style: style,
                      eventIds: const ['long-preview'],
                    ),
                    height: 164,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text(count), findsOneWidget);
        final unit = find.text('天');
        expect(
          tester.widget<Text>(unit).style?.fontSize,
          greaterThanOrEqualTo(12),
        );
        expect(tester.getSize(unit).height, greaterThanOrEqualTo(12));
        expect(
          find.ancestor(of: unit, matching: find.byType(FittedBox)),
          findsNothing,
        );
        expect(tester.takeException(), isNull, reason: '$brightness $style');
      }
    }
  });
  testWidgets('event card exposes one semantic button that opens details', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final store = await makeStore();
    addTearDown(store.dispose);
    await store.saveEvent(
      DayEvent(
        id: 'accessible-day',
        title: '可访问的日子',
        date: DateTime.now().add(const Duration(days: 9)),
      ),
    );
    await tester.pumpWidget(DayMasterApp(store: store));
    final card = find.bySemanticsLabel(RegExp('可访问的日子'));
    expect(card, findsOneWidget);
    final node = tester.getSemantics(card);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(find.text('日子详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  test(
    'real PNG preserves aspect ratio and fits the 1200px boundary',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 2400, 1200),
        ui.Paint()..color = const ui.Color(0xFF2864DC),
      );
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 1200, 1200),
        ui.Paint()..color = const ui.Color(0xFFBC486F),
      );
      final picture = recorder.endRecording();
      final original = await picture.toImage(2400, 1200);
      final Uint8List input;
      try {
        final data = (await original.toByteData(
          format: ui.ImageByteFormat.png,
        ))!;
        input = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        original.dispose();
        picture.dispose();
      }
      final output = base64Decode(await prepareEventPhoto(input));
      expect(output.length, lessThanOrEqualTo(maxPhotoBytes));
      final codec = await ui.instantiateImageCodec(output);
      try {
        final frame = await codec.getNextFrame();
        try {
          expect(frame.image.width, 1200);
          expect(frame.image.height, 600);
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    },
  );
  test('high detail PNG shrinks until its encoded bytes fit one MiB', () async {
    const size = 900;
    final random = math.Random(42);
    final pixels = Uint8List(size * size * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = random.nextInt(256);
      pixels[i + 1] = random.nextInt(256);
      pixels[i + 2] = random.nextInt(256);
      pixels[i + 3] = 255;
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: size,
      height: size,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final originalCodec = await descriptor.instantiateCodec();
    final Uint8List input;
    try {
      final frame = await originalCodec.getNextFrame();
      try {
        final data = (await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!;
        input = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        frame.image.dispose();
      }
    } finally {
      originalCodec.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
    expect(input.length, greaterThan(maxPhotoBytes));
    final output = base64Decode(await prepareEventPhoto(input));
    expect(output.length, lessThanOrEqualTo(maxPhotoBytes));
    final codec = await ui.instantiateImageCodec(output);
    try {
      final frame = await codec.getNextFrame();
      try {
        expect(frame.image.width, lessThan(size));
        expect(frame.image.height, frame.image.width);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  });
  test('empty and oversized photo input is rejected before decoding', () async {
    await expectLater(prepareEventPhoto(Uint8List(0)), throwsException);
    await expectLater(
      prepareEventPhoto(Uint8List(maxPhotoInputBytes + 1)),
      throwsException,
    );
  });
}
