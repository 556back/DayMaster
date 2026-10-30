import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/day_event.dart';
import '../models/widget_config.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';
import 'photo_processing.dart';
import 'widget_pages.dart';

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({
    super.key,
    required this.store,
    required this.eventId,
  });
  final AppStore store;
  final String eventId;
  Future<void> _delete(BuildContext context, DayEvent event) async {
    if (!await confirmAction(
      context,
      title: '删除这个日子？',
      message: '“${event.title}”将被删除，关联的小组件也会移除这条记录。',
      action: '删除日子',
      danger: true,
    )) {
      return;
    }
    try {
      await store.deleteEvent(event.id);
      if (context.mounted) {
        notify(context, '日子已删除');
        Navigator.pop(context);
      }
    } catch (error) {
      if (context.mounted) notify(context, errorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final event = store.eventById(eventId);
      if (event == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('日子详情')),
          body: EmptyMessage(
            icon: Icons.event_busy_rounded,
            title: '这个日子已被移除',
            description: '返回列表，查看其他记录。',
            action: '返回日子',
            onAction: () => Navigator.pop(context),
          ),
        );
      }
      final next = event.nextOccurrence(DateTime.now());
      return Scaffold(
        appBar: AppBar(
          title: const Text('日子详情'),
          actions: [
            IconButton(
              tooltip: '编辑日子',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => EventEditorPage(store: store, event: event),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: PageWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              WidgetPreview(
                store: store,
                config: WidgetConfig(
                  id: 'detail-preview',
                  style: event.photoBase64 == null ? 'number' : 'photo',
                  eventIds: [event.id],
                  theme: switch (event.colorHex.toUpperCase()) {
                    '#BC486F' => 'rose',
                    '#177B66' => 'green',
                    '#253449' => 'ink',
                    _ => 'blue',
                  },
                ),
                height: 270,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => WidgetEditorPage(
                          store: store,
                          initialEventId: event.id,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.widgets_rounded),
                    label: const Text('做成小组件'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await store.saveEvent(
                          event.copyWith(pinned: !event.pinned),
                        );
                        if (context.mounted) {
                          notify(context, event.pinned ? '已取消置顶' : '已置顶');
                        }
                      } catch (error) {
                        if (context.mounted) {
                          notify(context, errorMessage(error));
                        }
                      }
                    },
                    icon: Icon(
                      event.pinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                    ),
                    label: Text(event.pinned ? '取消置顶' : '置顶日子'),
                  ),
                ],
              ),
              const SectionTitle('关于这一天'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const DayIcon(Icons.event_rounded),
                      title: Text(dateLabel(event.date)),
                      subtitle: const Text('最初的日期'),
                    ),
                    const Divider(height: 1, indent: 74, endIndent: 18),
                    ListTile(
                      leading: const DayIcon(Icons.folder_outlined),
                      title: Text(event.category),
                      subtitle: const Text('分类'),
                    ),
                    if (event.repeatYearly)
                      ListTile(
                        leading: const DayIcon(Icons.repeat_rounded),
                        title: Text('下一次 · ${dateLabel(next)}'),
                        subtitle: const Text('每年重复，保留最初日期'),
                      ),
                    ListTile(
                      leading: const DayIcon(Icons.numbers_rounded),
                      title: Text(event.inclusive ? '当天为第 1 天' : '当天为 0 天'),
                      subtitle: const Text('第 1 天模式仅影响累计天数'),
                    ),
                    if (event.reminderDays != null)
                      ListTile(
                        leading: const DayIcon(Icons.notifications_outlined),
                        title: Text(
                          event.reminderDays == 0
                              ? '当天提醒'
                              : '提前 ${event.reminderDays} 天提醒',
                        ),
                        subtitle: const Text('当地时间上午 9 点，送达可能受系统节电影响'),
                      ),
                  ],
                ),
              ),
              if (event.note.isNotEmpty) ...[
                const SectionTitle('留下的话'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SelectableText(
                      event.note,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(height: 1.8),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _delete(context, event),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('删除日子'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class EventEditorPage extends StatefulWidget {
  const EventEditorPage({super.key, required this.store, this.event});
  final AppStore store;
  final DayEvent? event;
  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _titleFocus = FocusNode();
  late final TextEditingController _title, _note;
  late DateTime _date;
  late String _category, _emoji, _color;
  late bool _repeat, _inclusive, _pinned;
  String? _photo, _error;
  int? _reminder;
  bool _dirty = false, _allowPop = false, _busy = false, _photoBusy = false;
  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _title = TextEditingController(text: event?.title ?? '');
    _note = TextEditingController(text: event?.note ?? '');
    final now = DateTime.now();
    _date = event?.date ?? DateTime(now.year, now.month, now.day);
    _category = event?.category ?? '生活';
    _emoji = event?.emoji ?? '✨';
    _color = event?.colorHex ?? '#2864DC';
    _repeat = event?.repeatYearly ?? false;
    _inclusive = event?.inclusive ?? false;
    _pinned = event?.pinned ?? false;
    _photo = event?.photoBase64;
    _reminder = event?.reminderDays;
    _title.addListener(_changed);
    _note.addListener(_changed);
  }

  void _changed() {
    if (mounted) {
      setState(() {
        _dirty = true;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _titleFocus.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_busy || _photoBusy) return;
    if (await confirmAction(
      context,
      title: '放弃未保存的修改？',
      message: '返回后，这次输入的内容不会保留。',
      action: '放弃修改',
    )) {
      if (!mounted) return;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: '选择要记住的日期',
      cancelText: '取消',
      confirmText: '选择',
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
      _changed();
    }
  }

  Future<void> _pickEmoji() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('为日子选一个图标', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children:
                    const [
                          '✨',
                          '🎂',
                          '🎉',
                          '❤️',
                          '💍',
                          '🏠',
                          '✈️',
                          '🌊',
                          '🌸',
                          '🎓',
                          '📚',
                          '💼',
                          '🏆',
                          '🎯',
                          '🌱',
                          '🐾',
                          '🎵',
                          '🎄',
                        ]
                        .map(
                          (emoji) => SizedBox(
                            width: 48,
                            height: 48,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, emoji),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _emoji = picked);
      _changed();
    }
  }

  Future<void> _pickPhoto() async {
    setState(() {
      _photoBusy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) throw Exception('照片未能读取，请重新选择。');
      final photo = await prepareEventPhoto(bytes);
      if (mounted) {
        setState(() {
          _photo = photo;
          _dirty = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error));
        revealFormError(_scroll);
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _photoBusy) return;
    if (_title.text.trim().isEmpty || !_form.currentState!.validate()) {
      _form.currentState!.validate();
      revealFormError(_scroll);
      _titleFocus.requestFocus();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_reminder != null && !await widget.store.requestNotifications()) {
        throw Exception('提醒权限尚未开启。请在手机设置中允许通知，然后重试；你的输入已保留。');
      }
      final event = DayEvent(
        id: widget.event?.id ?? newId(),
        title: _title.text.trim(),
        date: _date,
        category: _category,
        emoji: _emoji,
        colorHex: _color,
        note: _note.text.trim(),
        photoBase64: _photo,
        repeatYearly: _repeat,
        inclusive: _inclusive,
        pinned: _pinned,
        reminderDays: _reminder,
        createdAt: widget.event?.createdAt,
      );
      await widget.store.saveEvent(event);
      if (!mounted) return;
      setState(() => _allowPop = true);
      notify(context, '日子已保存');
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error));
        revealFormError(_scroll);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>{
      '生活',
      '生日',
      '纪念日',
      '学习',
      '工作',
      _category,
    }.toList();
    final dualLinked =
        widget.event != null &&
        widget.store.widgets.any(
          (config) =>
              config.style == 'dual' &&
              config.eventIds.contains(widget.event!.id),
        );
    final image = _photo == null ? null : MemoryImage(base64Decode(_photo!));
    return PopScope<Object?>(
      canPop: _allowPop || (!_dirty && !_busy && !_photoBusy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.event == null ? '添加日子' : '编辑日子'),
          actions: [
            TextButton(
              onPressed: _busy || _photoBusy ? null : _save,
              child: Text(_busy ? '保存中' : '保存'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: PageWidth(
          child: Form(
            key: _form,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                AbsorbPointer(
                  absorbing: _busy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 22),
                        child: SectionTitle('记住这一天'),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton(
                            onPressed: _pickEmoji,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(60, 60),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              _emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _title,
                              focusNode: _titleFocus,
                              maxLength: 70,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: '日子名称',
                                hintText: '例如：我们的结婚纪念日',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? '给这个日子起个名字'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          minVerticalPadding: 14,
                          leading: const DayIcon(Icons.calendar_month_rounded),
                          title: const Text('日期'),
                          subtitle: Text(dateLabel(_date)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(16),
                        menuMaxHeight: 280,
                        elevation: 3,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        initialValue: _category,
                        decoration: const InputDecoration(labelText: '分类'),
                        items: categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _category = value);
                            _changed();
                          }
                        },
                      ),
                      const SectionTitle('计算与提醒'),
                      Card(
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('每年重复'),
                              subtitle: Text(
                                dualLinked
                                    ? '关闭后，关联周年组件会改为大数字'
                                    : '生日和纪念日，会一直保留最初的日期',
                              ),
                              value: _repeat,
                              onChanged: (value) {
                                setState(() => _repeat = value);
                                _changed();
                              },
                            ),
                            if (_repeat && _date.month == 2 && _date.day == 29)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Text('2 月 29 日在非闰年按 2 月 28 日纪念。'),
                              ),
                            const Divider(height: 1, indent: 18, endIndent: 18),
                            SwitchListTile(
                              title: const Text('当天为第 1 天'),
                              subtitle: const Text('仅用于累计天数，倒数仍以当天为 0 天'),
                              value: _inclusive,
                              onChanged: (value) {
                                setState(() => _inclusive = value);
                                _changed();
                              },
                            ),
                            const Divider(height: 1, indent: 18, endIndent: 18),
                            SwitchListTile(
                              title: const Text('置顶日子'),
                              subtitle: const Text('在日子列表中优先显示'),
                              value: _pinned,
                              onChanged: (value) {
                                setState(() => _pinned = value);
                                _changed();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(16),
                        menuMaxHeight: 280,
                        elevation: 3,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        initialValue: _reminder ?? -1,
                        decoration: const InputDecoration(
                          labelText: '事件提醒',
                          helperText: '上午 9 点提醒，保存时申请通知权限',
                        ),
                        items: const [
                          DropdownMenuItem(value: -1, child: Text('不提醒')),
                          DropdownMenuItem(value: 0, child: Text('当天提醒')),
                          DropdownMenuItem(value: 1, child: Text('提前 1 天')),
                          DropdownMenuItem(value: 3, child: Text('提前 3 天')),
                          DropdownMenuItem(value: 7, child: Text('提前 7 天')),
                        ],
                        onChanged: (value) {
                          setState(
                            () => _reminder = value == -1 ? null : value,
                          );
                          _changed();
                        },
                      ),
                      const SectionTitle('让日子有自己的样子'),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children:
                            const {
                                  '#2864DC': '晴空蓝',
                                  '#BC486F': '玫瑰粉',
                                  '#177B66': '薄荷绿',
                                  '#946B27': '麦穗金',
                                  '#7453AF': '丁香紫',
                                  '#253449': '墨黑',
                                }.entries
                                .map(
                                  (entry) => Tooltip(
                                    message: entry.value,
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: IconButton(
                                        tooltip: entry.value,
                                        onPressed: () {
                                          setState(() => _color = entry.key);
                                          _changed();
                                        },
                                        style: IconButton.styleFrom(
                                          backgroundColor: DayColors.fromHex(
                                            entry.key,
                                          ),
                                        ),
                                        icon: Icon(
                                          _color == entry.key
                                              ? Icons.check_rounded
                                              : Icons.circle,
                                          color: _color == entry.key
                                              ? Colors.white
                                              : Colors.transparent,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 18),
                      if (image != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image(
                              image: image,
                              height: 170,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _photoBusy ? null : _pickPhoto,
                            icon: _photoBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_photo_alternate_outlined,
                                  ),
                            label: Text(
                              _photoBusy
                                  ? '正在处理照片'
                                  : _photo == null
                                  ? '添加照片'
                                  : '更换照片',
                            ),
                          ),
                          if (_photo != null)
                            TextButton(
                              onPressed: () {
                                setState(() => _photo = null);
                                _changed();
                              },
                              child: const Text('移除照片'),
                            ),
                        ],
                      ),
                      const SectionTitle('留下的话'),
                      TextFormField(
                        controller: _note,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          hintText: '给未来的自己，或给这一天留句话',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy || _photoBusy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('保存日子'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
