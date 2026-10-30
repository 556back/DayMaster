import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_info.dart';
import '../store.dart';
import 'common.dart';
import 'help_page.dart';
import 'project_license_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});
  final AppStore store;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;
  String? _error;
  Future<bool> _saveBackup() async {
    final bytes = await widget.store.exportBackup();
    final date = compactDate(DateTime.now());
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '保存日子备份',
      fileName: 'daymaster-backup-$date.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    if (kIsWeb) {
      if (mounted) notify(context, '已发起备份下载，请检查下载文件。');
      return true;
    }
    return path != null;
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await _saveBackup();
      if (mounted && !kIsWeb) {
        notify(context, saved ? '备份已导出，包含记录、照片和组件设置。' : '已取消导出');
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return;
      final Uint8List? bytes = result.files.single.bytes;
      if (bytes == null) throw Exception('备份文件未能读取，请重新选择。');
      final backup = widget.store.validateBackup(bytes);
      if (!mounted) return;
      var replace = false;
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('恢复日子备份'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已检查备份：${backup.events.length} 个日子，${backup.widgets.length} 份组件。',
                  ),
                  const SizedBox(height: 16),
                  RadioGroup<bool>(
                    groupValue: replace,
                    onChanged: (value) =>
                        setDialogState(() => replace = value ?? false),
                    child: Column(
                      children: [
                        const RadioListTile<bool>(
                          value: false,
                          title: Text('合并恢复'),
                          subtitle: Text('添加新记录，保留现有同 ID 的内容'),
                        ),
                        RadioListTile<bool>(
                          value: true,
                          enabled: !kIsWeb,
                          title: const Text('替换全部'),
                          subtitle: const Text('先导出当前备份，再用这份备份替换'),
                        ),
                      ],
                    ),
                  ),
                  if (kIsWeb) const Text('网页预览支持合并恢复。完整替换请在手机 App 中完成。'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, replace),
                child: Text(replace ? '先备份再替换' : '合并恢复'),
              ),
            ],
          ),
        ),
      );
      if (choice == null) return;
      if (choice) {
        final backedUp = await _saveBackup();
        if (!backedUp) {
          if (mounted) notify(context, '当前备份未保存，已取消替换。');
          return;
        }
      }
      await widget.store.restoreBackup(backup, replace: choice);
      if (mounted) {
        notify(context, choice ? '备份已恢复，已保留替换前的备份。' : '备份已合并，现有记录已保留。');
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _examples() async {
    if (!await confirmAction(
      context,
      title: '载入示例日子？',
      message: '添加 4 条示例日子，可随时编辑或删除。',
      action: '载入示例',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.seedExamples();
      if (mounted) notify(context, '示例已载入，可返回日子列表查看。');
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _theme(String theme) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.setThemeMode(theme);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => PopScope<Object?>(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('设置与备份')),
        body: PageWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const DayIcon(Icons.calendar_month_rounded),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '我的日子',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${widget.store.events.length} 个日子 · ${widget.store.widgets.length} 份组件',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SectionTitle('外观'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const {'system': '跟随系统', 'light': '浅色', 'dark': '深色'}
                    .entries
                    .map(
                      (entry) => ChoiceChip(
                        avatar: Icon(switch (entry.key) {
                          'light' => Icons.light_mode_outlined,
                          'dark' => Icons.dark_mode_outlined,
                          _ => Icons.brightness_auto_outlined,
                        }, size: 18),
                        showCheckmark: false,
                        label: Text(entry.value),
                        selected: widget.store.themeMode == entry.key,
                        onSelected: _busy ? null : (_) => _theme(entry.key),
                      ),
                    )
                    .toList(),
              ),
              const SectionTitle('备份与恢复'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const DayIcon(Icons.download_outlined),
                      title: const Text('导出备份'),
                      subtitle: const Text('包含日子、照片和组件配置'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _busy ? null : _export,
                    ),
                    const Divider(height: 1, indent: 74, endIndent: 18),
                    ListTile(
                      leading: const DayIcon(Icons.restore_rounded),
                      title: const Text('恢复备份'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _busy ? null : _import,
                    ),
                  ],
                ),
              ),
              const SectionTitle('开始体验'),
              Card(
                child: ListTile(
                  leading: const DayIcon(Icons.auto_awesome_outlined),
                  title: const Text('载入示例日子'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _busy ? null : _examples,
                ),
              ),
              const SectionTitle('关于日子'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appName,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text('版本 $appVersion'),
                    ],
                  ),
                ),
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const DayIcon(Icons.help_outline_rounded),
                      title: const Text('使用说明'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const HelpPage(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 74, endIndent: 18),
                    ListTile(
                      leading: const DayIcon(Icons.description_outlined),
                      title: const Text('项目许可'),
                      subtitle: const Text('Apache License 2.0'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ProjectLicensePage(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
