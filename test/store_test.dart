import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:daymaster/models/day_event.dart';
import 'package:daymaster/models/widget_config.dart';
import 'package:daymaster/services/native_bridge.dart';
import 'package:daymaster/store.dart';

class NoNative extends NativeBridge {
  bool fail = false;
  @override
  Future<void> saveSnapshot(String json) async {
    if (fail) throw StateError('native');
  }
}

void main() {
  test('disk failure preserves saved state and retry works', () async {
    var reject = false;
    String? disk;
    final s = AppStore(
      read: () async => disk,
      write: (v) async {
        if (reject) throw StateError('full');
        disk = v;
      },
      native: NoNative(),
      tick: false,
    );
    addTearDown(s.dispose);
    await s.initialize();
    final e = DayEvent(id: 'a', title: '旅行', date: DateTime(2026, 11, 1));
    await s.saveEvent(e);
    reject = true;
    await expectLater(s.saveEvent(e.copyWith(title: '错误修改')), throwsStateError);
    expect(s.events.single.title, '旅行');
    reject = false;
    await s.saveEvent(e.copyWith(title: '已保存'));
    expect(s.events.single.title, '已保存');
    expect(
      s
          .validateBackup(Uint8List.fromList(utf8.encode(disk!)))
          .events
          .single
          .title,
      '已保存',
    );
  });
  test('queued mutations preserve both; deletion cleans widget refs', () async {
    final s = AppStore(
      read: () async => null,
      write: (_) async {},
      native: NoNative(),
      tick: false,
    );
    addTearDown(s.dispose);
    await s.initialize();
    await Future.wait([
      s.saveEvent(DayEvent(id: 'a', title: 'A', date: DateTime(2026, 1, 1))),
      s.saveEvent(DayEvent(id: 'b', title: 'B', date: DateTime(2026, 2, 1))),
    ]);
    expect(s.events.length, 2);
    await s.saveWidget(
      const WidgetConfig(id: 'w', style: 'list', eventIds: ['a', 'b']),
    );
    await s.deleteEvent('a');
    expect(s.widgets.single.eventIds, ['b']);
    await s.deleteEvent('b');
    expect(s.widgets, isEmpty);
  });
  test('backup includes photos; merge preserves existing edits', () async {
    final s = AppStore(
      read: () async => null,
      write: (_) async {},
      native: NoNative(),
      tick: false,
    );
    addTearDown(s.dispose);
    await s.initialize();
    final e = DayEvent(
      id: 'photo',
      title: '原始',
      date: DateTime(2024, 2, 29),
      repeatYearly: true,
      photoBase64: base64Encode([1, 2, 3]),
    );
    await s.saveEvent(e);
    await s.saveWidget(
      const WidgetConfig(id: 'dual', style: 'dual', eventIds: ['photo']),
    );
    final backup = s.validateBackup(await s.exportBackup());
    expect(backup.events.single.photoBase64, e.photoBase64);
    await s.saveEvent(e.copyWith(title: '保留修改'));
    await s.restoreBackup(backup, replace: false);
    expect(s.events.single.title, '保留修改');
    await s.restoreBackup(backup, replace: true);
    expect(s.events.single.title, '原始');
  });
  test(
    'merge restores records and downgrades conflicting dual widget',
    () async {
      final s = AppStore(
        read: () async => null,
        write: (_) async {},
        native: NoNative(),
        tick: false,
      );
      addTearDown(s.dispose);
      await s.initialize();
      final annual = DayEvent(
        id: 'annual',
        title: '备份名称',
        date: DateTime(2024, 2, 29),
        repeatYearly: true,
      );
      await s.saveEvent(annual);
      await s.saveEvent(
        DayEvent(id: 'other', title: '另一个日子', date: DateTime(2027, 1, 1)),
      );
      await s.saveWidget(
        const WidgetConfig(
          id: 'dual-merge',
          style: 'dual',
          eventIds: ['annual'],
        ),
      );
      final backup = s.validateBackup(await s.exportBackup());
      await s.deleteEvent('other');
      await s.deleteWidget('dual-merge');
      await s.saveEvent(annual.copyWith(title: '本地修改', repeatYearly: false));
      await s.restoreBackup(backup, replace: false);
      expect(s.eventById('annual')!.title, '本地修改');
      expect(s.eventById('annual')!.repeatYearly, false);
      expect(s.eventById('other'), isNotNull);
      expect(s.widgets.single.id, 'dual-merge');
      expect(s.widgets.single.style, 'number');
    },
  );
  test('corrupt load never overwrites the stored data', () async {
    var writes = 0;
    final s = AppStore(
      read: () async => 'corrupt',
      write: (_) async {
        writes++;
      },
      native: NoNative(),
      tick: false,
    );
    addTearDown(s.dispose);
    await s.initialize();
    expect(s.error, isNotNull);
    await expectLater(
      s.saveEvent(DayEvent(id: 'a', title: 'A', date: DateTime(2026, 1, 1))),
      throwsStateError,
    );
    expect(writes, 0);
  });
  test('native failure is surfaced without losing saved data', () async {
    final n = NoNative()..fail = true;
    String? disk;
    final s = AppStore(
      read: () async => null,
      write: (v) async {
        disk = v;
      },
      native: n,
      tick: false,
    );
    addTearDown(s.dispose);
    await s.initialize();
    await s.saveEvent(
      DayEvent(id: 'a', title: 'A', date: DateTime(2026, 1, 1)),
    );
    expect(disk, isNotNull);
    expect(s.nativeWarning, isNotNull);
    expect(s.events.length, 1);
  });
  test('invalid references and duplicate IDs fail validation', () async {
    final s = AppStore(
      read: () async => null,
      write: (_) async {},
      native: NoNative(),
      tick: false,
    );
    addTearDown(s.dispose);
    await s.initialize();
    await expectLater(
      s.saveWidget(const WidgetConfig(id: 'w', eventIds: ['missing'])),
      throwsFormatException,
    );
    final e = DayEvent(
      id: 'dup',
      title: 'A',
      date: DateTime(2026, 1, 1),
    ).toJson();
    final backup = {
      'version': 1,
      'events': [e, e],
      'widgets': [],
      'settings': {'themeMode': 'system'},
    };
    expect(
      () =>
          s.validateBackup(Uint8List.fromList(utf8.encode(jsonEncode(backup)))),
      throwsFormatException,
    );
  });
}
