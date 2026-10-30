import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'models/day_event.dart';
import 'models/widget_config.dart';
import 'services/native_bridge.dart';
import 'services/persistence.dart';

class BackupData {
  const BackupData({
    required this.events,
    required this.widgets,
    required this.themeMode,
  });
  final List<DayEvent> events;
  final List<WidgetConfig> widgets;
  final String themeMode;
}

class AppStore extends ChangeNotifier {
  AppStore({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
    NativeBridge? native,
    DateTime Function()? now,
    bool tick = true,
  }) : native = native ?? NativeBridge(),
       now = now ?? DateTime.now {
    final persistence = SnapshotPersistence();
    _read = read ?? persistence.read;
    _write = write ?? persistence.write;
    if (tick) {
      _timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => notifyListeners(),
      );
    }
  }
  late final Future<String?> Function() _read;
  late final Future<void> Function(String) _write;
  final NativeBridge native;
  final DateTime Function() now;
  Timer? _timer;
  List<DayEvent> _events = [];
  List<WidgetConfig> _widgets = [];
  String _themeMode = 'system';
  bool loading = true;
  String? error, nativeWarning;
  Future<void> _tail = Future.value();
  List<DayEvent> get events => List.unmodifiable(_events);
  List<WidgetConfig> get widgets => List.unmodifiable(_widgets);
  String get themeMode => _themeMode;
  DayEvent? eventById(String id) {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  Future<T> _serial<T>(Future<T> Function() job) {
    final result = _tail.then((_) => job());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> initialize() => _serial(() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final raw = await _read();
      if (raw != null) {
        final data = validateBackup(Uint8List.fromList(utf8.encode(raw)));
        _events = data.events;
        _widgets = data.widgets;
        _themeMode = data.themeMode;
      } else {
        _events = [];
        _widgets = [];
        _themeMode = 'system';
      }
      await _publish();
    } catch (e) {
      error = '读取本地记录失败。请重试；现有数据不会被覆盖。\n$e';
    }
    loading = false;
    notifyListeners();
  });

  Map<String, dynamic> _snapshot(
    List<DayEvent> events,
    List<WidgetConfig> widgets,
    String theme,
  ) => {
    'version': 1,
    'events': events.map((e) => e.toJson()).toList(),
    'widgets': widgets.map((e) => e.toJson()).toList(),
    'settings': {'themeMode': theme},
    'updatedAt': now().toIso8601String(),
  };

  Future<void> _publish() async {
    nativeWarning = null;
    try {
      await native.saveSnapshot(
        jsonEncode(_snapshot(_events, _widgets, _themeMode)),
      );
    } catch (_) {
      nativeWarning = '记录已保存在 App；系统小组件同步失败，返回 App 后可重试。';
    }
  }

  Future<void> refreshNative() => _serial(() async {
    if (error == null && !loading) {
      await _publish();
      notifyListeners();
    }
  });

  Future<void> _commit({
    List<DayEvent>? events,
    List<WidgetConfig>? widgets,
    String? theme,
  }) async {
    if (error != null || loading) throw StateError('本地数据尚未成功加载，请先重试');
    final nextEvents = events ?? _events;
    final nextWidgets = widgets ?? _widgets;
    final nextTheme = theme ?? _themeMode;
    final json = jsonEncode(_snapshot(nextEvents, nextWidgets, nextTheme));
    validateBackup(Uint8List.fromList(utf8.encode(json)));
    await _write(json);
    _events = List.unmodifiable(nextEvents);
    _widgets = List.unmodifiable(nextWidgets);
    _themeMode = nextTheme;
    await _publish();
    notifyListeners();
  }

  Future<void> saveEvent(DayEvent event) => _serial(() async {
    final valid = DayEvent.fromJson(event.toJson());
    final existing = _events.indexWhere((e) => e.id == valid.id);
    final next = [..._events];
    if (existing < 0) {
      next.add(valid);
    } else {
      next[existing] = valid;
    }
    final widgets = _widgets
        .map(
          (w) =>
              w.style == 'dual' &&
                  w.eventIds.first == valid.id &&
                  !valid.repeatYearly
              ? w.copyWith(style: 'number')
              : w,
        )
        .toList();
    await _commit(events: next, widgets: widgets);
  });

  Future<void> deleteEvent(String id) => _serial(() async {
    final widgets = <WidgetConfig>[];
    for (final widget in _widgets) {
      final ids = widget.eventIds.where((eventId) => eventId != id).toList();
      if (ids.isNotEmpty) widgets.add(widget.copyWith(eventIds: ids));
    }
    await _commit(
      events: _events.where((e) => e.id != id).toList(),
      widgets: widgets,
    );
  });

  Future<void> saveWidget(WidgetConfig widget) => _serial(() async {
    final valid = WidgetConfig.fromJson(widget.toJson());
    if (valid.eventIds.any((id) => eventById(id) == null)) {
      throw const FormatException('请重新选择小组件的日期');
    }
    if (valid.style == 'dual' &&
        !eventById(valid.eventIds.first)!.repeatYearly) {
      throw const FormatException('双日期组件需要开启每年重复');
    }
    final next = [..._widgets];
    final index = next.indexWhere((w) => w.id == valid.id);
    if (index < 0) {
      next.add(valid);
    } else {
      next[index] = valid;
    }
    await _commit(widgets: next);
  });

  Future<void> deleteWidget(String id) => _serial(
    () => _commit(widgets: _widgets.where((w) => w.id != id).toList()),
  );
  Future<void> setThemeMode(String value) => _serial(() async {
    if (!['system', 'light', 'dark'].contains(value)) {
      throw const FormatException('主题模式无效');
    }
    await _commit(theme: value);
  });

  Future<Uint8List> exportBackup() async {
    if (error != null || loading) throw StateError('无法导出尚未成功加载的数据');
    return Uint8List.fromList(
      utf8.encode(jsonEncode(_snapshot(_events, _widgets, _themeMode))),
    );
  }

  BackupData validateBackup(Uint8List bytes) {
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('备份超过20MB，请减少照片后重试');
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != 1 ||
          decoded['events'] is! List ||
          decoded['widgets'] is! List) {
        throw const FormatException('不是有效的 DayMaster v1 备份');
      }
      final eventRows = decoded['events'] as List;
      final widgetRows = decoded['widgets'] as List;
      if (eventRows.length > 2000 || widgetRows.length > 100) {
        throw const FormatException('备份记录数量超出支持范围');
      }
      final events = eventRows
          .map((e) => DayEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final widgets = widgetRows
          .map(
            (w) => WidgetConfig.fromJson(Map<String, dynamic>.from(w as Map)),
          )
          .toList();
      final eventIds = events.map((e) => e.id).toSet();
      final widgetIds = widgets.map((w) => w.id).toSet();
      if (eventIds.length != events.length ||
          widgetIds.length != widgets.length) {
        throw const FormatException('备份包含重复ID');
      }
      for (final widget in widgets) {
        if (widget.eventIds.any((id) => !eventIds.contains(id))) {
          throw const FormatException('备份的小组件引用了不存在的日期');
        }
        if (widget.style == 'dual' &&
            !events
                .firstWhere((e) => e.id == widget.eventIds.first)
                .repeatYearly) {
          throw const FormatException('双日期组件对应的记录必须每年重复');
        }
      }
      final settings = decoded['settings'];
      final theme = settings is Map ? settings['themeMode'] : null;
      if (!['system', 'light', 'dark'].contains(theme)) {
        throw const FormatException('备份主题设置无效');
      }
      return BackupData(
        events: List.unmodifiable(events),
        widgets: List.unmodifiable(widgets),
        themeMode: theme as String,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('备份内容不完整或格式错误');
    }
  }

  Future<void> restoreBackup(BackupData data, {required bool replace}) =>
      _serial(() async {
        final events = replace
            ? data.events
            : [
                ..._events,
                ...data.events.where(
                  (e) => !_events.any((old) => old.id == e.id),
                ),
              ];
        final widgets = replace
            ? data.widgets
            : [
                ..._widgets,
                ...data.widgets.where(
                  (w) => !_widgets.any((old) => old.id == w.id),
                ),
              ];
        final yearlyIds = events
            .where((event) => event.repeatYearly)
            .map((event) => event.id)
            .toSet();
        await _commit(
          events: events,
          widgets: widgets
              .map(
                (widget) =>
                    widget.style == 'dual' &&
                        !yearlyIds.contains(widget.eventIds.first)
                    ? widget.copyWith(style: 'number')
                    : widget,
              )
              .toList(),
          theme: replace ? data.themeMode : _themeMode,
        );
      });

  Future<void> seedExamples() => _serial(() async {
    final today = civilDate(now());
    final examples = [
      DayEvent(
        id: 'example-trip-v1',
        title: '下一次旅行',
        date: today.add(const Duration(days: 28)),
        category: '生活',
        emoji: '✈️',
        note: '示例日子，可编辑或删除。',
        colorHex: '#2864DC',
      ),
      DayEvent(
        id: 'example-anniversary-v1',
        title: '我们的纪念日',
        date: DateTime(today.year - 2, today.month, today.day),
        category: '纪念日',
        emoji: '💙',
        repeatYearly: true,
        inclusive: true,
        note: '示例日子：同时看看累计天数和下一次周年。',
        colorHex: '#BC486F',
      ),
      DayEvent(
        id: 'example-goal-v1',
        title: '迎接新的自己',
        date: today.add(const Duration(days: 100)),
        category: '目标',
        emoji: '🌱',
        colorHex: '#177B66',
      ),
      DayEvent(
        id: 'example-memory-v1',
        title: '值得记住的开始',
        date: today.subtract(const Duration(days: 365)),
        category: '生活',
        emoji: '📷',
        colorHex: '#253449',
      ),
    ];
    await _commit(
      events: [
        ..._events,
        ...examples.where((e) => !_events.any((old) => old.id == e.id)),
      ],
    );
  });

  Future<bool> requestPinWidget(String id) async {
    if (!_widgets.any((w) => w.id == id)) {
      throw const FormatException('请先保存组件配置');
    }
    await refreshNative();
    return native.requestPinWidget(id);
  }

  Future<bool> requestNotifications() async {
    final allowed = await native.requestNotifications();
    if (allowed) await refreshNative();
    return allowed;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
