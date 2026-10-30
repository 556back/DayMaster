import 'package:daymaster/models/day_event.dart';
import 'package:daymaster/models/widget_config.dart';
import 'package:daymaster/services/native_bridge.dart';
import 'package:daymaster/store.dart';
import 'package:daymaster/theme.dart';
import 'package:daymaster/ui/widget_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _WidgetNative extends NativeBridge {
  @override
  Future<void> saveSnapshot(String json) async {}
}

Future<AppStore> _store(DateTime today) async {
  final store = AppStore(
    read: () async => null,
    write: (_) async {},
    now: () => today,
    native: _WidgetNative(),
    tick: false,
  );
  await store.initialize();
  return store;
}

void main() {
  test(
    'all eight desktop styles round-trip, single styles reject multiple dates',
    () {
      expect(widgetStyleNames.length, 8);
      for (final style in widgetStyleNames.keys) {
        final config = WidgetConfig(
          id: 'config-$style',
          style: style,
          eventIds: const ['day'],
        );
        expect(WidgetConfig.fromJson(config.toJson()).style, style);
        final two = config.copyWith(eventIds: const ['day', 'other']).toJson();
        if (style == 'list') {
          expect(WidgetConfig.fromJson(two).eventIds.length, 2);
        } else {
          expect(() => WidgetConfig.fromJson(two), throwsFormatException);
        }
      }
    },
  );

  testWidgets(
    'all eight previews fit compact and large sizes with large text and long titles',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = await _store(DateTime(2200, 12, 31));
      addTearDown(store.dispose);
      await store.saveEvent(
        DayEvent(
          id: 'long-day',
          title: '这是一个想放在手机桌面上每天看见的特别重要的长标题日子',
          date: DateTime(1900),
        ),
      );
      for (final brightness in Brightness.values) {
        for (final style in widgetStyleNames.keys) {
          for (final size in [
            const Size(164, 164),
            const Size(340, 164),
            const Size(340, 320),
          ]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: dayTheme(brightness),
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: size.width,
                      child: WidgetPreview(
                        store: store,
                        config: WidgetConfig(
                          id: 'test-$style',
                          style: style,
                          eventIds: const ['long-day'],
                        ),
                        height: size.height,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '$brightness $style $size',
            );
          }
        }
      }
    },
  );

  testWidgets(
    'creative styles show current countdown and recover when the bound date is absent',
    (tester) async {
      final today = DateTime(2026, 10, 3);
      final store = await _store(today);
      addTearDown(store.dispose);
      await store.saveEvent(
        DayEvent(id: 'day', title: '下一次旅行', date: DateTime(2026, 10, 31)),
      );
      for (final style in ['ring', 'calendar', 'ticket', 'bloom']) {
        for (final ids in [
          const ['day'],
          const <String>[],
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: dayTheme(Brightness.light),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 164,
                    child: WidgetPreview(
                      store: store,
                      config: WidgetConfig(
                        id: 'test',
                        style: style,
                        eventIds: ids,
                      ),
                      height: 164,
                    ),
                  ),
                ),
              ),
            ),
          );
          if (ids.isEmpty) {
            expect(find.text('绑定记录后显示天数'), findsOneWidget);
          } else if (style == 'calendar') {
            expect(find.text('还有 28 天 · 10/31'), findsOneWidget);
          } else {
            expect(find.text('28'), findsOneWidget);
            expect(find.text('还有'), findsOneWidget);
          }
          expect(tester.takeException(), isNull, reason: '$style $ids');
        }
      }
    },
  );

  testWidgets(
    'calendar marks today and only the target that occurs in the current month',
    (tester) async {
      final store = await _store(DateTime(2026, 10, 3));
      addTearDown(store.dispose);
      await store.saveEvent(
        DayEvent(id: 'same-month', title: '旅行', date: DateTime(2026, 10, 10)),
      );
      await store.saveEvent(
        DayEvent(id: 'next-month', title: '旅行', date: DateTime(2026, 11, 10)),
      );
      for (final id in ['same-month', 'next-month']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 164,
                child: WidgetPreview(
                  store: store,
                  config: WidgetConfig(
                    id: 'calendar',
                    style: 'calendar',
                    eventIds: [id],
                  ),
                  height: 164,
                ),
              ),
            ),
          ),
        );
        expect(find.byKey(const ValueKey('calendar-today-3')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('calendar-target-10')),
          id == 'same-month' ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'each creative style saves a real selectable widget configuration',
    (tester) async {
      final store = await _store(DateTime(2026, 10, 3));
      addTearDown(store.dispose);
      await store.saveEvent(
        DayEvent(id: 'day', title: '我的日子', date: DateTime(2026, 10, 31)),
      );
      for (final style in ['ring', 'calendar', 'ticket', 'bloom']) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(style),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => WidgetEditorPage(
                        store: store,
                        initialStyle: style,
                        initialEventId: 'day',
                      ),
                    ),
                  ),
                  child: const Text('开始'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('开始'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('保存组件'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('保存组件'));
        await tester.pumpAndSettle();
        expect(store.widgets.last.style, style);
        expect(store.widgets.last.eventIds, const ['day']);
        expect(WidgetConfig.fromJson(store.widgets.last.toJson()).style, style);
        expect(tester.takeException(), isNull, reason: style);
      }
    },
  );
}
