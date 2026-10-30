import 'dart:convert';
import 'dart:ui';

import 'package:daymaster/models/day_event.dart';
import 'package:daymaster/models/photo_crop.dart';
import 'package:daymaster/models/widget_config.dart';
import 'package:daymaster/services/native_bridge.dart';
import 'package:daymaster/store.dart';
import 'package:flutter_test/flutter_test.dart';

class _AppearanceNative extends NativeBridge {
  String? snapshot;

  @override
  Future<void> saveSnapshot(String json) async => snapshot = json;
}

const _custom = WidgetConfig(
  id: 'photo-widget',
  style: 'photo',
  eventIds: ['day'],
  theme: 'ink',
  backgroundOpacity: 0.35,
  textTone: 'light',
  photoScale: 2.25,
  photoX: -0.7,
  photoY: 0.8,
  photoDim: 0.4,
);

void main() {
  test('older snapshots retain the original opaque centered appearance', () {
    final config = WidgetConfig.fromJson({
      'id': 'old',
      'style': 'photo',
      'eventIds': ['day'],
      'theme': 'blue',
    });
    expect(config.backgroundOpacity, 1);
    expect(config.textTone, 'auto');
    expect(config.photoScale, 1);
    expect(config.photoX, 0);
    expect(config.photoY, 0);
    expect(config.photoDim, 0.6);
    expect(WidgetConfig.fromJson(config.toJson()).toJson(), config.toJson());
  });

  test('appearance round-trips and survives edits to unrelated fields', () {
    final encoded = jsonDecode(jsonEncode(_custom.toJson()));
    final decoded = WidgetConfig.fromJson(encoded as Map<String, dynamic>);
    expect(decoded.toJson(), _custom.toJson());
    final changed = decoded.copyWith(style: 'number', eventIds: ['another']);
    expect(changed.toJson(), {
      ..._custom.toJson(),
      'style': 'number',
      'eventIds': ['another'],
    });
    final reset = _custom.copyWith(
      backgroundOpacity: 1,
      textTone: 'auto',
      photoScale: 1,
      photoX: 0,
      photoY: 0,
      photoDim: 0.6,
    );
    expect(
      reset.toJson(),
      const WidgetConfig(
        id: 'photo-widget',
        style: 'photo',
        eventIds: ['day'],
        theme: 'ink',
      ).toJson(),
    );
  });

  test('valid endpoints and integer numeric values are accepted', () {
    for (final values in [
      {
        'backgroundOpacity': 0,
        'photoScale': 1,
        'photoX': -1,
        'photoY': -1,
        'photoDim': 0,
        'textTone': 'dark',
      },
      {
        'backgroundOpacity': 1,
        'photoScale': 3,
        'photoX': 1,
        'photoY': 1,
        'photoDim': 0.85,
        'textTone': 'light',
      },
    ]) {
      final config = WidgetConfig.fromJson({..._custom.toJson(), ...values});
      for (final entry in values.entries) {
        expect(config.toJson()[entry.key], entry.value);
      }
    }
  });

  test(
    'provided corrupt appearance values fail rather than using defaults',
    () {
      const ranges = {
        'backgroundOpacity': [0.0, 1.0],
        'photoScale': [1.0, 3.0],
        'photoX': [-1.0, 1.0],
        'photoY': [-1.0, 1.0],
        'photoDim': [0.0, 0.85],
      };
      for (final entry in ranges.entries) {
        for (final invalid in [
          null,
          '0.5',
          true,
          <Object>[],
          double.nan,
          double.infinity,
          double.negativeInfinity,
          entry.value.first - 0.01,
          entry.value.last + 0.01,
        ]) {
          expect(
            () => WidgetConfig.fromJson({
              ..._custom.toJson(),
              entry.key: invalid,
            }),
            throwsFormatException,
            reason: '${entry.key}: $invalid',
          );
        }
      }
      for (final invalid in [null, '', 'system', 0, true]) {
        expect(
          () =>
              WidgetConfig.fromJson({..._custom.toJson(), 'textTone': invalid}),
          throwsFormatException,
        );
      }
      expect(
        () => WidgetConfig.fromJson({
          ..._custom.toJson(),
          'eventIds': ['a', 'b'],
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'appearance persists to disk, native snapshot, backup, and reload',
    () async {
      String? disk;
      final native = _AppearanceNative();
      final store = AppStore(
        read: () async => disk,
        write: (json) async => disk = json,
        native: native,
        tick: false,
      );
      addTearDown(store.dispose);
      await store.initialize();
      await store.saveEvent(
        DayEvent(
          id: 'day',
          title: '照片日子',
          date: DateTime(2026, 10, 3),
          photoBase64: base64Encode([1, 2, 3]),
        ),
      );
      await store.saveWidget(_custom);
      expect((jsonDecode(disk!) as Map)['widgets'], [_custom.toJson()]);
      expect((jsonDecode(native.snapshot!) as Map)['widgets'], [
        _custom.toJson(),
      ]);
      final backup = store.validateBackup(await store.exportBackup());
      expect(backup.widgets.single.toJson(), _custom.toJson());
      await store.saveWidget(_custom.copyWith(photoX: 0, photoScale: 1));
      await store.restoreBackup(backup, replace: true);
      expect(store.widgets.single.toJson(), _custom.toJson());
      final reloaded = AppStore(
        read: () async => disk,
        write: (_) async {},
        native: _AppearanceNative(),
        tick: false,
      );
      addTearDown(reloaded.dispose);
      await reloaded.initialize();
      expect(reloaded.error, isNull);
      expect(reloaded.widgets.single.toJson(), _custom.toJson());
    },
  );

  test('cover geometry matches centered, edge, and zoomed photo crops', () {
    const source = Size(400, 200);
    const viewport = Size(100, 100);
    expect(
      PhotoCrop.sourceRect(source, viewport, 1, 0, 0),
      const Rect.fromLTWH(100, 0, 200, 200),
    );
    expect(
      PhotoCrop.sourceRect(source, viewport, 1, -1, -1),
      const Rect.fromLTWH(0, 0, 200, 200),
    );
    expect(
      PhotoCrop.sourceRect(source, viewport, 1, 1, 1),
      const Rect.fromLTWH(200, 0, 200, 200),
    );
    expect(
      PhotoCrop.sourceRect(source, viewport, 2, 0, 0),
      const Rect.fromLTWH(150, 50, 100, 100),
    );
  });

  test('every aspect ratio, zoom, and alignment stays inside the image', () {
    for (final source in [
      const Size(400, 200),
      const Size(200, 400),
      const Size(200, 200),
    ]) {
      for (final viewport in [
        const Size(164, 164),
        const Size(340, 164),
        const Size(340, 320),
      ]) {
        for (final scale in [1.0, 1.7, 3.0]) {
          for (final x in [-1.0, 0.0, 1.0]) {
            for (final y in [-1.0, 0.0, 1.0]) {
              final rect = PhotoCrop.sourceRect(source, viewport, scale, x, y);
              expect(rect.left, greaterThanOrEqualTo(-1e-9));
              expect(rect.top, greaterThanOrEqualTo(-1e-9));
              expect(rect.right, lessThanOrEqualTo(source.width + 1e-9));
              expect(rect.bottom, lessThanOrEqualTo(source.height + 1e-9));
              expect(rect.width, greaterThan(0));
              expect(rect.height, greaterThan(0));
              expect(
                rect.width / rect.height,
                closeTo(viewport.width / viewport.height, 1e-9),
              );
            }
          }
        }
      }
    }
  });

  test(
    'drag follows the image, clamps at edges, and centers uncropped axes',
    () {
      const source = Size(400, 200);
      const viewport = Size(100, 100);
      final moved = PhotoCrop.panAlignment(
        source,
        viewport,
        1,
        const Offset(0, 0.7),
        const Offset(25, 30),
      );
      expect(moved, const Offset(-0.5, 0));
      expect(
        PhotoCrop.sourceRect(source, viewport, 1, moved.dx, moved.dy).left,
        50,
      );
      expect(
        PhotoCrop.panAlignment(
          source,
          viewport,
          2,
          Offset.zero,
          const Offset(1000, -1000),
        ),
        const Offset(-1, 1),
      );
      expect(
        PhotoCrop.panAlignment(
          const Size(200, 200),
          viewport,
          1,
          const Offset(1, 1),
          const Offset(10, 10),
        ),
        Offset.zero,
      );
    },
  );

  test('crop geometry rejects unsafe dimensions and nonfinite values', () {
    for (final source in [
      Size.zero,
      const Size(-1, 100),
      const Size(double.nan, 100),
      const Size(100, double.infinity),
      const Size(1e-308, 1e-308),
    ]) {
      expect(
        () => PhotoCrop.sourceRect(source, const Size(1e308, 1e308), 1, 0, 0),
        throwsArgumentError,
      );
    }
    for (final viewport in [Size.zero, const Size(100, double.nan)]) {
      expect(
        () => PhotoCrop.sourceRect(const Size(100, 100), viewport, 1, 0, 0),
        throwsArgumentError,
      );
    }
    for (final scale in [0.0, 3.1, double.nan, double.infinity]) {
      expect(
        () => PhotoCrop.sourceRect(
          const Size(100, 100),
          const Size(100, 100),
          scale,
          0,
          0,
        ),
        throwsArgumentError,
      );
    }
    for (final x in [-1.01, 1.01, double.nan, double.infinity]) {
      expect(
        () => PhotoCrop.sourceRect(
          const Size(100, 100),
          const Size(100, 100),
          1,
          x,
          0,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => PhotoCrop.panAlignment(
        const Size(100, 100),
        const Size(100, 100),
        1,
        Offset.zero,
        const Offset(double.nan, 0),
      ),
      throwsArgumentError,
    );
  });

  test(
    'pinch zoom preserves an off-center image point as the fingers move',
    () {
      const source = Size(400, 200);
      const viewport = Size(100, 100);
      const startFocal = Offset(20, 75);
      const nextFocal = Offset(30, 80);
      final next = PhotoCrop.transformAlignment(
        source,
        viewport,
        1,
        Offset.zero,
        2,
        startFocal,
        nextFocal,
      );
      final rect = PhotoCrop.sourceRect(source, viewport, 2, next.dx, next.dy);
      // The original point at (140, 150) must now sit under (30, 80).
      expect(rect.left, closeTo(110, 1e-9));
      expect(rect.top, closeTo(70, 1e-9));
      expect(
        rect.left + nextFocal.dx * rect.width / viewport.width,
        closeTo(140, 1e-9),
      );
      expect(
        rect.top + nextFocal.dy * rect.height / viewport.height,
        closeTo(150, 1e-9),
      );
      expect(next.dx, closeTo(-4 / 15, 1e-9));
      expect(next.dy, closeTo(0.4, 1e-9));
    },
  );

  test('a transform without zoom matches ordinary image dragging', () {
    const source = Size(400, 200);
    const viewport = Size(100, 100);
    const startFocal = Offset(35, 60);
    const alignment = Offset(0.2, -0.4);
    for (final scale in [1.0, 2.0, 3.0]) {
      for (final delta in [
        Offset.zero,
        const Offset(20, -15),
        const Offset(1000, -1000),
      ]) {
        final transformed = PhotoCrop.transformAlignment(
          source,
          viewport,
          scale,
          alignment,
          scale,
          startFocal,
          startFocal + delta,
        );
        final panned = PhotoCrop.panAlignment(
          source,
          viewport,
          scale,
          alignment,
          delta,
        );
        expect(transformed.dx, closeTo(panned.dx, 1e-9));
        expect(transformed.dy, closeTo(panned.dy, 1e-9));
      }
    }
  });

  test('pinch transforms clamp edges and reject invalid focal points', () {
    const source = Size(400, 200);
    const viewport = Size(100, 100);
    expect(
      PhotoCrop.transformAlignment(
        source,
        viewport,
        1,
        Offset.zero,
        3,
        const Offset(50, 50),
        const Offset(1000, -1000),
      ),
      const Offset(-1, 1),
    );
    expect(
      PhotoCrop.transformAlignment(
        const Size(200, 200),
        viewport,
        2,
        const Offset(-0.5, 0.5),
        1,
        const Offset(50, 50),
        const Offset(30, 70),
      ),
      Offset.zero,
    );
    for (final focal in [
      const Offset(double.nan, 0),
      const Offset(0, double.infinity),
    ]) {
      for (final start in [true, false]) {
        expect(
          () => PhotoCrop.transformAlignment(
            source,
            viewport,
            1,
            Offset.zero,
            2,
            start ? focal : Offset.zero,
            start ? Offset.zero : focal,
          ),
          throwsArgumentError,
        );
      }
    }
  });
}
