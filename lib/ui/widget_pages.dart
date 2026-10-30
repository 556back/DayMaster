import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/day_event.dart';
import '../models/widget_config.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';
import 'event_pages.dart';
import 'photo_processing.dart';
import 'widget_appearance.dart';

const widgetStyleNames = {
  'number': '大数字',
  'photo': '照片纪念卡',
  'dual': '周年双日期',
  'list': '日子列表',
  'ring': '年轮',
  'calendar': '月历',
  'ticket': '日子车票',
  'bloom': '花开日子',
};
const widgetThemeNames = {
  'blue': '晴空蓝',
  'rose': '玫瑰粉',
  'green': '薄荷绿',
  'ink': '墨黑',
};

Future<void> addWidgetToPhone(
  BuildContext context,
  AppStore store,
  WidgetConfig config,
) async {
  try {
    if (!kIsWeb && await store.requestPinWidget(config.id)) {
      if (context.mounted) notify(context, '已打开系统添加确认，请完成添加。');
      return;
    }
    if (!context.mounted) return;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final text = kIsWeb
        ? '当前是网页预览。请在手机 App 中保存同样的配置，再通过手机的组件菜单添加。\n\nAndroid：长按桌面空白处 → 小组件 → 日子。\niPhone：长按主屏幕 → 编辑 → 添加小组件 → 日子。锁屏也可在自定中添加。'
        : ios
        ? '主屏幕：长按空白处 → 编辑 → 添加小组件 → 搜索「日子」，选择尺寸并添加。长按组件 → 编辑小组件，可选择刚保存的配置。\n\n锁屏：长按锁屏 → 自定 → 添加小组件 → 日子。锁屏采用精简样式。'
        : '长按桌面空白处 → 小组件 → 日子，选择需要的尺寸并拖到桌面。添加时选择刚保存的组件配置。\n\n不同手机的入口名称可能略有不同。';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('把日子放到手机上'),
        content: SingleChildScrollView(child: Text(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  } catch (error) {
    if (context.mounted) notify(context, errorMessage(error));
  }
}

class WidgetPreview extends StatelessWidget {
  const WidgetPreview({
    super.key,
    required this.store,
    required this.config,
    this.height = 180,
    this.exampleEvents,
    this.onPhotoChanged,
    this.wallpaperPreview = true,
  });
  final AppStore store;
  final WidgetConfig config;
  final double height;
  final List<DayEvent>? exampleEvents;
  final ValueChanged<WidgetConfig>? onPhotoChanged;
  final bool wallpaperPreview;
  @override
  Widget build(BuildContext context) {
    final events =
        exampleEvents ??
        config.eventIds.map(store.eventById).whereType<DayEvent>().toList();
    final event = events.isEmpty ? null : events.first;
    final color = DayColors.widgetColor(config.theme);
    final photo = config.style == 'photo' ? event?.photoBase64 : null;
    final isPhoto = config.style == 'photo';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = config.textTone == 'light'
        ? Colors.white
        : config.textTone == 'dark'
        ? DayColors.text
        : isPhoto
        ? Colors.white
        : dark
        ? Color.lerp(color, Colors.white, .55)!
        : color;
    final background = config.textTone == 'light'
        ? Color.lerp(color, DayColors.darkBackground, .8)!
        : config.textTone == 'dark'
        ? Color.lerp(color, Colors.white, .94)!
        : isPhoto
        ? color
        : dark
        ? Color.lerp(color, DayColors.darkBackground, .8)!
        : Color.lerp(color, Colors.white, .94)!;
    final today = civilDate(store.now());
    final status = event?.status(today);
    final title = event == null ? '选择一个日子' : '${event.emoji} ${event.title}';
    return Semantics(
      label:
          '${widgetStyleNames[config.style] ?? '小组件'}预览，$title'
          '${status == null ? '' : '，${status.label} ${status.days} 天，${compactDate(status.nextDate)}'}',
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: wallpaperPreview && config.backgroundOpacity < 1
                ? (foreground.computeLuminance() > .5
                      ? DayColors.darkBackground
                      : DayColors.softBlue)
                : null,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: color.withValues(
                  alpha: (dark ? .08 : .10) * config.backgroundOpacity,
                ),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: WidgetSurface(
            config: config,
            background: background,
            foreground: foreground,
            photo: photo,
            onPhotoChanged: onPhotoChanged,
            child: Container(
              padding: EdgeInsets.all(height <= 180 ? 14 : 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final small = constraints.maxWidth < 210;
                  final labelStyle = TextStyle(
                    color: foreground,
                    fontSize: small ? 13 : 15,
                    fontWeight: FontWeight.w700,
                  );
                  if (event == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widgetStyleNames[config.style] ?? '小组件',
                          style: labelStyle,
                        ),
                        const Spacer(),
                        Icon(
                          Icons.calendar_month_rounded,
                          color: foreground,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '绑定记录后显示天数',
                          style: TextStyle(color: foreground, fontSize: 12),
                        ),
                      ],
                    );
                  }
                  if ([
                    'ring',
                    'calendar',
                    'ticket',
                    'bloom',
                  ].contains(config.style)) {
                    return _CreativePreview(
                      style: config.style,
                      event: event,
                      today: today,
                      color: foreground,
                      small: small,
                      backgroundOpacity: config.backgroundOpacity,
                    );
                  }
                  if (config.style == 'list') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('重要的日子', style: labelStyle),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: events.take(height > 230 ? 5 : 3).map((
                              item,
                            ) {
                              final itemStatus = item.status(today);
                              final count = itemStatus.days;
                              return Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.emoji} ${item.title}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: foreground,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        itemStatus.label == '就是今天'
                                            ? '今天'
                                            : '${itemStatus.isPast ? '+' : ''}$count 天',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: foreground,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );
                  }
                  if (config.style == 'dual') {
                    final elapsed = event.elapsedDays(today);
                    final remaining = status!.days;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        ),
                        const Spacer(),
                        if (small) ...[
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '已经 $elapsed 天',
                              style: TextStyle(
                                color: foreground,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            remaining == 0 ? '周年就是今天' : '距周年 $remaining 天',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: foreground, fontSize: 13),
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: _CountBlock(
                                  label: '已经',
                                  number: elapsed,
                                  color: foreground,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 52,
                                color: foreground.withValues(
                                  alpha: .2 * config.backgroundOpacity,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _CountBlock(
                                  label: '距离下一次周年',
                                  number: remaining,
                                  color: foreground,
                                ),
                              ),
                            ],
                          ),
                        const Spacer(),
                        Text(
                          '始于 ${compactDate(event.date)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground.withValues(alpha: .9),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    );
                  }
                  final count = status!.days.toString();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: small ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                      SizedBox(height: small ? 6 : 10),
                      Text(
                        status.label,
                        style: TextStyle(
                          color: foreground,
                          fontSize: small ? 12 : 14,
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: status.label == '就是今天'
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '✦',
                                    style: TextStyle(
                                      fontSize: 54,
                                      color: foreground,
                                    ),
                                  ),
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          count,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: foreground,
                                            fontSize: small
                                                ? 56
                                                : height > 230
                                                ? 92
                                                : 72,
                                            height: 1,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -2,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: Text(
                                        '天',
                                        style: TextStyle(
                                          color: foreground,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        compactDate(status.nextDate),
                        style: TextStyle(
                          color: foreground.withValues(alpha: .9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreativePreview extends StatelessWidget {
  const _CreativePreview({
    required this.style,
    required this.event,
    required this.today,
    required this.color,
    required this.small,
    required this.backgroundOpacity,
  });
  final String style;
  final DayEvent event;
  final DateTime today;
  final Color color;
  final bool small;
  final double backgroundOpacity;

  Widget _text(String text, {double size = 12, bool bold = false}) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: color,
      fontSize: size,
      height: 1.2,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    ),
  );

  Widget _number(int days, {double size = 48}) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$days',
            style: TextStyle(
              color: color,
              fontSize: size,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
      const SizedBox(width: 4),
      Padding(padding: const EdgeInsets.only(bottom: 3), child: _text('天')),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final status = event.status(today);
    final title = '${event.emoji} ${event.title}';
    final target = compactDate(status.nextDate);
    final decorationColor = color.withValues(alpha: backgroundOpacity);
    if (style == 'calendar') {
      final calendar = _MonthGrid(
        today: today,
        target: status.nextDate,
        color: color,
        backgroundOpacity: backgroundOpacity,
      );
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text(title, bold: true, size: small ? 12 : 15),
          if (!small) ...[
            const Spacer(),
            _text(status.label),
            const SizedBox(height: 5),
            _number(status.days),
            const Spacer(),
            _text(target),
          ] else
            _text(
              '${status.label == '就是今天' ? '就是今天' : '${status.label} ${status.days} 天'} · ${status.nextDate.month}/${status.nextDate.day}',
            ),
        ],
      );
      return small
          ? Column(
              children: [
                Expanded(child: calendar),
                const SizedBox(height: 6),
                details,
              ],
            )
          : Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 18),
                Expanded(child: calendar),
              ],
            );
    }
    if (style == 'ticket') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.confirmation_number_outlined,
                color: decorationColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(child: _text('日子车票', bold: true)),
            ],
          ),
          const SizedBox(height: 5),
          _text(title, size: small ? 12 : 15, bold: true),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _text(status.label),
                      const SizedBox(height: 3),
                      Flexible(
                        child: _number(status.days, size: small ? 40 : 58),
                      ),
                    ],
                  ),
                ),
                if (!small)
                  Icon(
                    Icons.north_east_rounded,
                    color: decorationColor,
                    size: 34,
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 10,
            width: double.infinity,
            child: CustomPaint(painter: _TicketRulePainter(decorationColor)),
          ),
          _text('${event.repeatYearly ? '下一次' : '日期'} $target'),
        ],
      );
    }
    if (style == 'ring') {
      final yearDays = dayDifference(
        DateTime(today.year),
        DateTime(today.year + 1),
      );
      final ordinal = dayDifference(DateTime(today.year), today) + 1;
      final progress = ordinal / yearDays;
      return Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _text(title, bold: true, size: small ? 12 : 15),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final diameter = math.min(
                  constraints.maxHeight,
                  constraints.maxWidth,
                );
                return Center(
                  child: SizedBox.square(
                    dimension: diameter,
                    child: CustomPaint(
                      painter: _YearRingPainter(decorationColor, progress),
                      child: Padding(
                        padding: EdgeInsets.all(diameter * .18),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _text(status.label),
                            const SizedBox(height: 3),
                            Flexible(
                              child: _number(
                                status.days,
                                size: small ? 32 : 52,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          _text('${today.year} 年进度 ${(progress * 100).floor()}%'),
          if (!small) ...[const SizedBox(height: 4), _text(target)],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text(title, bold: true, size: small ? 12 : 15),
        const SizedBox(height: 4),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _BloomPainter(decorationColor)),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _text(status.label),
                    const SizedBox(height: 6),
                    _number(status.days, size: small ? 40 : 64),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _text(target),
      ],
    );
  }
}

class _YearRingPainter extends CustomPainter {
  const _YearRingPainter(this.color, this.progress);
  final Color color;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = rect.deflate(4);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: .12 * color.a);
    canvas.drawOval(circle, paint);
    paint.color = color;
    canvas.drawArc(circle, -math.pi / 2, 2 * math.pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(_YearRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}

class _BloomPainter extends CustomPainter {
  const _BloomPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) / 2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final paint = Paint()..color = color.withValues(alpha: .09 * color.a);
    for (var petal = 0; petal < 8; petal++) {
      canvas.save();
      canvas.rotate(petal * math.pi / 4);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -radius * .45),
          width: radius * .72,
          height: radius * 1.08,
        ),
        paint,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BloomPainter oldDelegate) => oldDelegate.color != color;
}

class _TicketRulePainter extends CustomPainter {
  const _TicketRulePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .32 * color.a)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, 5),
        Offset(math.min(x + 3, size.width), 5),
        paint,
      );
    }
    paint.color = color.withValues(alpha: .12 * color.a);
    canvas.drawCircle(const Offset(0, 5), 4, paint);
    canvas.drawCircle(Offset(size.width, 5), 4, paint);
  }

  @override
  bool shouldRepaint(_TicketRulePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.today,
    required this.target,
    required this.color,
    required this.backgroundOpacity,
  });
  final DateTime today, target;
  final Color color;
  final double backgroundOpacity;
  @override
  Widget build(BuildContext context) {
    final first = DateTime(today.year, today.month);
    final dayCount = DateTime(today.year, today.month + 1, 0).day;
    final offset = first.weekday - 1;
    final rows = ((offset + dayCount) / 7).ceil();
    final inMonth = target.year == today.year && target.month == today.month;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${today.month} 月',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${today.year}',
                style: TextStyle(color: color, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: ['一', '二', '三', '四', '五', '六', '日']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 9,
                          color: color.withValues(alpha: .7),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Column(
              children: List.generate(
                rows,
                (row) => Expanded(
                  child: Row(
                    children: List.generate(7, (column) {
                      final day = row * 7 + column - offset + 1;
                      if (day < 1 || day > dayCount) {
                        return const Expanded(child: SizedBox());
                      }
                      final isToday = day == today.day;
                      final isTarget = inMonth && day == target.day;
                      return Expanded(
                        child: Center(
                          child: Container(
                            key: ValueKey(
                              isTarget
                                  ? 'calendar-target-$day'
                                  : isToday
                                  ? 'calendar-today-$day'
                                  : 'calendar-day-$day',
                            ),
                            constraints: const BoxConstraints(minWidth: 15),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? color.withValues(alpha: backgroundOpacity)
                                  : isTarget
                                  ? color.withValues(
                                      alpha: .10 * backgroundOpacity,
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(5),
                              border: isTarget
                                  ? Border.all(
                                      color: color.withValues(
                                        alpha: backgroundOpacity,
                                      ),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: isToday && backgroundOpacity >= .5
                                    ? (color.computeLuminance() > .5
                                          ? DayColors.darkBackground
                                          : Colors.white)
                                    : color,
                                fontSize: 9,
                                height: 1,
                                fontWeight: isToday || isTarget
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBlock extends StatelessWidget {
  const _CountBlock({
    required this.label,
    required this.number,
    required this.color,
  });
  final String label;
  final int number;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: color, fontSize: 12)),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$number 天',
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class WidgetLibraryPage extends StatelessWidget {
  const WidgetLibraryPage({super.key, required this.store});
  final AppStore store;
  Future<void> _delete(BuildContext context, WidgetConfig config) async {
    if (!await confirmAction(
      context,
      title: '删除这个组件配置？',
      message: '日子记录会保留。已放到桌面的这个组件将提示重新配置。',
      action: '删除组件',
      danger: true,
    )) {
      return;
    }
    try {
      await store.deleteWidget(config.id);
      if (context.mounted) notify(context, '组件配置已删除');
    } catch (error) {
      if (context.mounted) notify(context, errorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) => PageWidth(
    maxWidth: 560,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        const SectionTitle('选择样式'),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 290 ? 2 : 1;
            final cardWidth =
                (constraints.maxWidth - (columns - 1) * 12) / columns;
            final cards = widgetStyleNames.entries
                .map(
                  (entry) => SizedBox(
                    width: cardWidth,
                    child: _WidgetStyleCard(
                      store: store,
                      style: entry.key,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => WidgetEditorPage(
                            store: store,
                            initialStyle: entry.key,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList();
            return Wrap(spacing: 12, runSpacing: 18, children: cards);
          },
        ),
        const SectionTitle('我的组件'),
        if (store.widgets.isEmpty)
          EmptyMessage(
            icon: Icons.widgets_outlined,
            title: '还没有小组件',
            description: '选择样式，创建后添加到桌面。',
            action: '创建第一个组件',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => WidgetEditorPage(store: store),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: store.widgets.map((config) {
                  final event = config.eventIds.isEmpty
                      ? null
                      : store.eventById(config.eventIds.first);
                  return SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WidgetPreview(store: store, config: config),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    event?.title ?? '尚未绑定日子',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: '组件操作',
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _delete(context, config);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('删除组件'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              '${widgetStyleNames[config.style] ?? ''} · ${widgetThemeNames[config.theme] ?? ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () =>
                                      addWidgetToPhone(context, store, config),
                                  icon: const Icon(
                                    Icons.add_to_home_screen_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('添加到手机'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => WidgetEditorPage(
                                        store: store,
                                        config: config,
                                      ),
                                    ),
                                  ),
                                  child: const Text('编辑'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    ),
  );
}

class _WidgetStyleCard extends StatelessWidget {
  const _WidgetStyleCard({
    required this.store,
    required this.style,
    required this.onTap,
  });
  final AppStore store;
  final String style;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = switch (style) {
      'photo' || 'ticket' => 'ink',
      'dual' || 'bloom' => 'rose',
      'list' || 'ring' => 'green',
      _ => 'blue',
    };
    final today = civilDate(store.now());
    final eligible = store.events
        .where((event) => style != 'dual' || event.repeatYearly)
        .toList();
    final examples = eligible.isNotEmpty
        ? eligible.take(style == 'list' ? 3 : 1).toList()
        : [
            DayEvent(
              id: 'gallery-example',
              title: style == 'dual' || style == 'bloom' ? '相遇纪念日' : '期待下一次旅行',
              emoji: style == 'dual' || style == 'bloom' ? '♡' : '✈',
              date: style == 'dual'
                  ? DateTime(today.year - 3, today.month, today.day)
                  : today.add(const Duration(days: 28)),
              repeatYearly: style == 'dual',
            ),
            if (style == 'list') ...[
              DayEvent(
                id: 'gallery-birthday',
                title: '生日',
                emoji: '🎂',
                date: today.add(const Duration(days: 65)),
              ),
              DayEvent(
                id: 'gallery-memory',
                title: '相遇',
                emoji: '♡',
                date: today.subtract(const Duration(days: 520)),
              ),
            ],
          ];
    return Semantics(
      button: true,
      label: '创建${widgetStyleNames[style]}组件',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: WidgetPreview(
                  store: store,
                  config: WidgetConfig(
                    id: 'gallery-$style',
                    style: style,
                    eventIds: const [],
                    theme: theme,
                  ),
                  height: 164,
                  exampleEvents: examples,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widgetStyleNames[style]!,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              if (eligible.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 3, 4, 0),
                  child: Text(
                    '示例预览',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WidgetEditorPage extends StatefulWidget {
  const WidgetEditorPage({
    super.key,
    required this.store,
    this.config,
    this.initialEventId,
    this.initialStyle,
  });
  final AppStore store;
  final WidgetConfig? config;
  final String? initialEventId, initialStyle;
  @override
  State<WidgetEditorPage> createState() => _WidgetEditorPageState();
}

class _WidgetEditorPageState extends State<WidgetEditorPage> {
  late String _style, _theme;
  late List<String> _ids;
  late WidgetConfig _appearance;
  final _scroll = ScrollController();
  String _size = '中';
  String _wallpaperTone = 'light';
  ImageProvider? _wallpaper;
  String? _error;
  bool _dirty = false,
      _allowPop = false,
      _busy = false,
      _wallpaperBusy = false,
      _cropMode = false;
  @override
  void initState() {
    super.initState();
    _style = widget.config?.style ?? widget.initialStyle ?? 'number';
    _theme = widget.config?.theme ?? 'blue';
    _ids = [...?widget.config?.eventIds];
    _appearance =
        widget.config ?? WidgetConfig(id: newId(), eventIds: const []);
    if (_appearance.textTone == 'light') _wallpaperTone = 'dark';
    if (widget.config == null && widget.initialEventId != null) {
      _ids = [widget.initialEventId!];
    }
    if (_style == 'dual') {
      _ids.removeWhere(
        (id) => widget.store.eventById(id)?.repeatYearly != true,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_busy || _wallpaperBusy) return;
    if (await confirmAction(
      context,
      title: '放弃未保存的修改？',
      message: '这次组件设置不会保留。',
      action: '放弃修改',
    )) {
      if (!mounted) return;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    }
  }

  void _changeStyle(String style) => setState(() {
    _style = style;
    _dirty = true;
    _error = null;
    _cropMode = false;
    if (style != 'list' && _ids.length > 1) _ids = [_ids.first];
    if (style == 'dual') {
      _ids.removeWhere(
        (id) => widget.store.eventById(id)?.repeatYearly != true,
      );
    }
  });
  void _select(String id, bool selected) {
    if (selected && _style == 'list' && _ids.length >= 5) {
      notify(context, '一个列表组件最多放 5 个日子');
      return;
    }
    setState(() {
      if (_style == 'list') {
        if (selected) {
          if (!_ids.contains(id)) _ids.add(id);
        } else {
          _ids.remove(id);
        }
      } else {
        if (_ids.isEmpty || _ids.first != id) {
          _appearance = _appearance.copyWith(
            photoScale: 1,
            photoX: 0,
            photoY: 0,
          );
          _cropMode = false;
        }
        _ids = [id];
      }
      _dirty = true;
      _error = null;
    });
  }

  void _changeAppearance(WidgetConfig config) => setState(() {
    _appearance = config;
    _dirty = true;
    _error = null;
  });

  Future<void> _pickWallpaper() async {
    if (_wallpaperBusy || _busy) return;
    setState(() => _wallpaperBusy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) throw Exception('壁纸未能读取，请重新选择。');
      final photo = await prepareEventPhoto(bytes);
      if (mounted) {
        setState(() => _wallpaper = MemoryImage(base64Decode(photo)));
      }
    } catch (error) {
      if (mounted) notify(context, errorMessage(error));
    } finally {
      if (mounted) setState(() => _wallpaperBusy = false);
    }
  }

  Widget _previewStage(WidgetConfig config, double height) => Column(
    children: [
      Container(
        key: const ValueKey('wallpaper-preview'),
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _wallpaperTone == 'dark'
                ? const [Color(0xFF192B42), Color(0xFF456077)]
                : const [Color(0xFFEAF1FF), Color(0xFFCDDDE8)],
          ),
          image: _wallpaper == null
              ? null
              : DecorationImage(image: _wallpaper!, fit: BoxFit.cover),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _size == '小' || _size == '大' ? height : 340,
            ),
            child: WidgetPreview(
              key: const ValueKey('editor-live-preview'),
              store: widget.store,
              config: config,
              wallpaperPreview: false,
              height: height,
              onPhotoChanged: _cropMode && !_busy && !_wallpaperBusy
                  ? _changeAppearance
                  : null,
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Wrap(
          spacing: 8,
          children: ['小', '中', '大']
              .map(
                (size) => ChoiceChip(
                  label: Text('$size尺寸'),
                  selected: _size == size,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _size = size),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );

  List<Widget> _appearanceControls(DayEvent? selected) => [
    const SectionTitle('适配桌面壁纸'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in const {'light': '浅色壁纸', 'dark': '深色壁纸'}.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: _wallpaper == null && _wallpaperTone == entry.key,
            onSelected: (_) => setState(() {
              _wallpaperTone = entry.key;
              _wallpaper = null;
            }),
          ),
        OutlinedButton.icon(
          onPressed: _wallpaperBusy ? null : _pickWallpaper,
          icon: const Icon(Icons.wallpaper_outlined, size: 18),
          label: Text(
            _wallpaperBusy
                ? '读取中'
                : _wallpaper == null
                ? '预览我的壁纸'
                : '更换预览壁纸',
          ),
        ),
      ],
    ),
    const SizedBox(height: 8),
    Text('壁纸或桌面截图仅用于预览。', style: Theme.of(context).textTheme.bodySmall),
    const SizedBox(height: 16),
    AppearanceSlider(
      label: '背景不透明度',
      value: _appearance.backgroundOpacity,
      valueLabel: '${(_appearance.backgroundOpacity * 100).round()}%',
      onChanged: (value) =>
          _changeAppearance(_appearance.copyWith(backgroundOpacity: value)),
    ),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton(
          onPressed: () =>
              _changeAppearance(_appearance.copyWith(backgroundOpacity: 0)),
          child: const Text('全透明'),
        ),
        TextButton(
          onPressed: () =>
              _changeAppearance(_appearance.copyWith(backgroundOpacity: .5)),
          child: const Text('半透明'),
        ),
        TextButton(
          onPressed: () =>
              _changeAppearance(_appearance.copyWith(backgroundOpacity: 1)),
          child: const Text('不透明'),
        ),
      ],
    ),
    const SizedBox(height: 8),
    const Text('文字颜色'),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in const {
          'auto': '跟随主题',
          'light': '浅色字',
          'dark': '深色字',
        }.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: _appearance.textTone == entry.key,
            onSelected: (_) =>
                _changeAppearance(_appearance.copyWith(textTone: entry.key)),
          ),
      ],
    ),
    if (_style == 'photo' && selected?.photoBase64 != null) ...[
      const SectionTitle('照片构图', description: '每份组件单独调整，不改变日子的原始照片。'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(() => _cropMode = !_cropMode),
            icon: Icon(
              _cropMode ? Icons.check_rounded : Icons.open_with_rounded,
              size: 18,
            ),
            label: Text(_cropMode ? '完成拖动' : '拖动照片'),
          ),
          TextButton.icon(
            onPressed: () => _changeAppearance(
              _appearance.copyWith(photoScale: 1, photoX: 0, photoY: 0),
            ),
            icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
            label: const Text('复位构图'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_cropMode)
        Text(
          '在上方预览中拖动；双指捏合或滚轮缩放。也可以用下方滑杆调整。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      const SizedBox(height: 12),
      AppearanceSlider(
        label: '照片缩放',
        value: _appearance.photoScale,
        min: 1,
        max: 3,
        divisions: 40,
        valueLabel: '${(_appearance.photoScale * 100).round()}%',
        onChanged: (value) =>
            _changeAppearance(_appearance.copyWith(photoScale: value)),
      ),
      AppearanceSlider(
        label: '左右构图',
        value: _appearance.photoX,
        min: -1,
        max: 1,
        valueLabel: _appearance.photoX.abs() < .01
            ? '居中'
            : '${_appearance.photoX < 0 ? '偏左' : '偏右'} ${(_appearance.photoX.abs() * 100).round()}%',
        onChanged: (value) =>
            _changeAppearance(_appearance.copyWith(photoX: value)),
      ),
      AppearanceSlider(
        label: '上下构图',
        value: _appearance.photoY,
        min: -1,
        max: 1,
        valueLabel: _appearance.photoY.abs() < .01
            ? '居中'
            : '${_appearance.photoY < 0 ? '偏上' : '偏下'} ${(_appearance.photoY.abs() * 100).round()}%',
        onChanged: (value) =>
            _changeAppearance(_appearance.copyWith(photoY: value)),
      ),
      AppearanceSlider(
        label: '文字遮罩',
        value: _appearance.photoDim,
        max: .85,
        divisions: 85,
        valueLabel: '${(_appearance.photoDim * 100).round()}%',
        onChanged: (value) =>
            _changeAppearance(_appearance.copyWith(photoDim: value)),
      ),
    ],
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _changeAppearance(
          _appearance.copyWith(
            backgroundOpacity: 1,
            textTone: 'auto',
            photoScale: 1,
            photoX: 0,
            photoY: 0,
            photoDim: .6,
          ),
        ),
        icon: const Icon(Icons.restart_alt_rounded, size: 18),
        label: const Text('恢复默认外观'),
      ),
    ),
  ];

  Future<void> _save() async {
    if (_busy || _wallpaperBusy) return;
    if (_ids.isEmpty) {
      setState(() => _error = '先选择要展示的日子');
      revealFormError(_scroll);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.saveWidget(
        _appearance.copyWith(
          style: _style,
          eventIds: List.of(_ids),
          theme: _theme,
        ),
      );
      if (!mounted) return;
      setState(() => _allowPop = true);
      notify(
        context,
        widget.config == null ? '组件配置已保存，可添加到手机' : '组件已保存，桌面组件将同步更新',
      );
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final events = widget.store.events
          .where((event) => _style != 'dual' || event.repeatYearly)
          .toList();
      final preview = _appearance.copyWith(
        style: _style,
        eventIds: _ids,
        theme: _theme,
      );
      final selected = _ids.isEmpty ? null : widget.store.eventById(_ids.first);
      return PopScope<Object?>(
        canPop: _allowPop || (!_dirty && !_busy && !_wallpaperBusy),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.config == null ? '创建小组件' : '编辑小组件'),
            actions: [
              TextButton(
                onPressed: _busy || _wallpaperBusy ? null : _save,
                child: Text(_busy ? '保存中' : '保存'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: PageWidth(
            maxWidth: 560,
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  _previewStage(
                    preview,
                    math.min(
                      _size == '大' ? 260.0 : 164.0,
                      constraints.maxHeight * .34,
                    ),
                  ),
                  Expanded(
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
                        ExcludeFocus(
                          excluding: _busy || _wallpaperBusy,
                          child: AbsorbPointer(
                            absorbing: _busy || _wallpaperBusy,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionTitle('组件样式'),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: widgetStyleNames.entries
                                      .map(
                                        (entry) => ChoiceChip(
                                          showCheckmark: false,
                                          label: Text(entry.value),
                                          selected: _style == entry.key,
                                          onSelected: (_) =>
                                              _changeStyle(entry.key),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SectionTitle('配色'),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: widgetThemeNames.entries
                                      .map(
                                        (entry) => ChoiceChip(
                                          showCheckmark: false,
                                          avatar: Icon(
                                            Icons.circle,
                                            color: DayColors.widgetColor(
                                              entry.key,
                                            ),
                                            size: 16,
                                          ),
                                          label: Text(entry.value),
                                          selected: _theme == entry.key,
                                          onSelected: (_) => setState(() {
                                            _theme = entry.key;
                                            _dirty = true;
                                          }),
                                        ),
                                      )
                                      .toList(),
                                ),
                                SectionTitle(
                                  '展示哪些日子',
                                  description: _style == 'list'
                                      ? '按选择顺序展示，最多 5 个；小尺寸显示前 3 个。'
                                      : _style == 'dual'
                                      ? '周年双日期只展示已开启「每年重复」的日子。'
                                      : '选择一条日期记录。',
                                ),
                                if (events.isEmpty)
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _style == 'dual'
                                                ? '还没有每年重复的日子'
                                                : '还没有日期记录',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _style == 'dual'
                                                ? '在日子编辑页开启「每年重复」，再回来创建周年组件。'
                                                : '先添加一个日子，才能把它做成组件。',
                                          ),
                                          const SizedBox(height: 12),
                                          TextButton.icon(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder: (_) => EventEditorPage(
                                                  store: widget.store,
                                                ),
                                              ),
                                            ),
                                            icon: const Icon(Icons.add_rounded),
                                            label: const Text('添加日子'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Card(
                                    child: _style == 'list'
                                        ? Column(
                                            children: events
                                                .map(
                                                  (event) => CheckboxListTile(
                                                    value: _ids.contains(
                                                      event.id,
                                                    ),
                                                    onChanged: (selected) =>
                                                        _select(
                                                          event.id,
                                                          selected ?? false,
                                                        ),
                                                    title: Text(
                                                      '${event.emoji} ${event.title}',
                                                    ),
                                                    subtitle: Text(
                                                      compactDate(event.date),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          )
                                        : RadioGroup<String>(
                                            groupValue: _ids.isEmpty
                                                ? null
                                                : _ids.first,
                                            onChanged: (id) {
                                              if (id != null) _select(id, true);
                                            },
                                            child: Column(
                                              children: events
                                                  .map(
                                                    (
                                                      event,
                                                    ) => RadioListTile<String>(
                                                      value: event.id,
                                                      title: Text(
                                                        '${event.emoji} ${event.title}',
                                                      ),
                                                      subtitle: Text(
                                                        compactDate(event.date),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ),
                                  ),
                                if (_style == 'photo' &&
                                    selected != null &&
                                    selected.photoBase64 == null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('为这个日子加一张照片，照片就会显示在组件背景中。'),
                                        TextButton.icon(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) => EventEditorPage(
                                                store: widget.store,
                                                event: selected,
                                              ),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.add_photo_alternate_outlined,
                                          ),
                                          label: const Text('为日子添加照片'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ..._appearanceControls(selected),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _busy || _wallpaperBusy ? null : _save,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: const Text('保存组件'),
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
    },
  );
}
