import 'dart:convert';
import 'dart:ui' as ui;

import 'package:daymaster/models/day_event.dart';
import 'package:daymaster/models/widget_config.dart';
import 'package:daymaster/services/native_bridge.dart';
import 'package:daymaster/store.dart';
import 'package:daymaster/theme.dart';
import 'package:daymaster/ui/widget_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Native extends NativeBridge {
  @override
  Future<void> saveSnapshot(String json) async {}
}

Future<AppStore> _store({String? photo}) async {
  final store = AppStore(
    read: () async => null,
    write: (_) async {},
    native: _Native(),
    tick: false,
    now: () => DateTime(2026, 10, 3),
  );
  await store.initialize();
  await store.saveEvent(
    DayEvent(
      id: 'memory',
      title: '我们的纪念日',
      date: DateTime(2027),
      photoBase64: photo,
    ),
  );
  return store;
}

Future<String> _photo() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 120, 60),
    Paint()..color = Colors.blue,
  );
  canvas.drawRect(
    const Rect.fromLTWH(60, 0, 60, 60),
    Paint()..color = Colors.orange,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(120, 60);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final result = base64Encode(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  return result;
}

Future<void> _open(
  WidgetTester tester,
  AppStore store, {
  WidgetConfig? config,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dayTheme(Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => WidgetEditorPage(
                  store: store,
                  config: config,
                  initialStyle: 'photo',
                  initialEventId: 'memory',
                ),
              ),
            ),
            child: const Text('打开编辑器'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开编辑器'));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'transparent background leaves date text opaque and changes tone',
    (tester) async {
      final store = await _store();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              child: WidgetPreview(
                store: store,
                config: const WidgetConfig(
                  id: 'glass',
                  eventIds: ['memory'],
                  backgroundOpacity: 0,
                  textTone: 'light',
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('widget-background-opacity')),
            )
            .opacity,
        0,
      );
      final number = find.text('90');
      expect(number, findsOneWidget);
      expect(tester.widget<Text>(number).style!.color, Colors.white);
      expect(
        find.ancestor(of: number, matching: find.byType(Opacity)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'photo drag, keyboard alternative, reset and saved appearance agree',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final photo = await tester.runAsync(_photo);
      final store = await _store(photo: photo);
      addTearDown(store.dispose);
      await _open(tester, store);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      final photoShade =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('widget-photo-shade')),
                  )
                  .decoration
              as BoxDecoration;
      final shadeTop = (photoShade.gradient! as LinearGradient).colors.first;
      final brightestBackground = Color.alphaBlend(shadeTop, Colors.white);
      expect(
        1.05 / (brightestBackground.computeLuminance() + .05),
        greaterThanOrEqualTo(4.5),
      );
      await _reveal(tester, find.text('半透明'));
      await tester.tap(find.text('半透明'));
      await tester.pump();
      await _reveal(tester, find.text('浅色字'));
      await tester.tap(find.text('浅色字'));
      await tester.pump();
      await _reveal(tester, find.text('拖动照片'));
      await tester.tap(find.text('拖动照片'));
      await tester.pump();
      final preview = find.byKey(const ValueKey('editor-live-preview'));
      final before = tester.widget<WidgetPreview>(preview).config;
      await tester.drag(preview, const Offset(-45, 0));
      await tester.pumpAndSettle();
      final dragged = tester.widget<WidgetPreview>(preview).config;
      expect(dragged.photoX, greaterThan(before.photoX));
      await _reveal(tester, find.byKey(const ValueKey('slider-照片缩放')));
      final zoom = tester.widget<Slider>(
        find.byKey(const ValueKey('slider-照片缩放')),
      );
      zoom.onChanged!(2);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('slider-照片缩放')));
      tester
          .widget<FocusableActionDetector>(
            find.descendant(
              of: find.byKey(const ValueKey('slider-照片缩放')),
              matching: find.byType(FocusableActionDetector),
            ),
          )
          .focusNode!
          .requestFocus();
      await tester.pump();
      final keyboardBefore = tester
          .widget<WidgetPreview>(preview)
          .config
          .photoScale;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        tester.widget<WidgetPreview>(preview).config.photoScale,
        greaterThan(keyboardBefore),
      );
      await _reveal(tester, find.byKey(const ValueKey('slider-上下构图')));
      tester
          .widget<Slider>(find.byKey(const ValueKey('slider-上下构图')))
          .onChanged!(.6);
      await tester.pump();
      await _reveal(tester, find.text('复位构图'));
      await tester.tap(find.text('复位构图'));
      await tester.pump();
      final reset = tester.widget<WidgetPreview>(preview).config;
      expect([reset.photoScale, reset.photoX, reset.photoY], [1, 0, 0]);
      // Reset affects composition only; chosen opacity and text survive.
      expect(reset.backgroundOpacity, .5);
      expect(reset.textTone, 'light');
      await _reveal(tester, find.byKey(const ValueKey('slider-照片缩放')));
      tester
          .widget<Slider>(find.byKey(const ValueKey('slider-照片缩放')))
          .onChanged!(1.75);
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, '保存'));
      await tester.pumpAndSettle();
      expect(store.widgets.single.backgroundOpacity, .5);
      expect(store.widgets.single.photoScale, 1.75);
      expect(store.widgets.single.textTone, 'light');
      final backup = store.validateBackup(await store.exportBackup());
      expect(backup.widgets.single.toJson(), store.widgets.single.toJson());
      expect(store.events.single.photoBase64, photo);
      await _open(tester, store, config: store.widgets.single);
      expect(tester.widget<WidgetPreview>(preview).config.photoScale, 1.75);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'appearance remains reachable on a small phone with large text and warns on leave',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = await _store();
      addTearDown(store.dispose);
      await _open(tester, store);
      await _reveal(tester, find.text('全透明'));
      await tester.tap(find.text('全透明'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('editor-live-preview'))).top,
        lessThan(300),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('放弃未保存的修改？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WidgetPreview>(
              find.byKey(const ValueKey('editor-live-preview')),
            )
            .config
            .backgroundOpacity,
        0,
      );
      expect(store.widgets, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
