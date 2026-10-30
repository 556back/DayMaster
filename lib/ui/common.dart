import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/day_event.dart';
import '../theme.dart';

String dateLabel(DateTime date) => '${date.year}年${date.month}月${date.day}日';
String compactDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

void notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String errorMessage(Object error) =>
    '操作未完成：${error.toString().replaceFirst('Exception: ', '')}';

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool danger = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.maxWidth = 680});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class DayIcon extends StatelessWidget {
  const DayIcon(this.icon, {super.key});
  final IconData icon;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.description});
  final String title;
  final String? description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
      ],
    ),
  );
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.onAction,
  });
  final IconData icon;
  final String title, description, action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: .1),
            ),
          ),
          child: Icon(
            icon,
            size: 34,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onAction, child: Text(action)),
      ],
    ),
  );
}

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.onTap});
  final DayEvent event;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final status = event.status(now);
    final color = DayColors.fromHex(event.colorHex);
    final photo = eventPhoto(event);
    final hasPhoto = photo != null;
    final surface = Color.alphaBlend(
      color.withValues(alpha: theme.brightness == Brightness.dark ? .12 : .045),
      scheme.surface,
    );
    final a = color.computeLuminance(), b = surface.computeLuminance();
    final ratio = ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
    final accent = hasPhoto
        ? Colors.white
        : ratio >= 4.5
        ? color
        : scheme.onSurface;
    final foreground = hasPhoto ? Colors.white : scheme.onSurface;
    final muted = hasPhoto
        ? Colors.white.withValues(alpha: .85)
        : scheme.onSurfaceVariant;
    final number = status.days.toString();
    return Semantics(
      label:
          '${event.title}，${status.label}${status.days == 0 ? '' : '$number天'}，${dateLabel(event.date)}',
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: surface,
        child: Ink(
          decoration: BoxDecoration(
            image: hasPhoto
                ? DecorationImage(image: photo, fit: BoxFit.cover)
                : null,
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: hasPhoto
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .58),
                        Colors.black.withValues(alpha: .72),
                      ],
                    )
                  : null,
            ),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: hasPhoto
                                ? Colors.white.withValues(alpha: .16)
                                : color.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            event.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: foreground,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                event.category,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (event.pinned)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Icon(
                              Icons.push_pin_rounded,
                              size: 16,
                              color: accent,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: hasPhoto
                                  ? Colors.white.withValues(alpha: .14)
                                  : color.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              status.label,
                              style: TextStyle(
                                color: accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Spacer(),
                        if (status.days != 0) ...[
                          Flexible(
                            flex: 3,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                number,
                                style: TextStyle(
                                  fontSize: 64,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -2.5,
                                  color: accent,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              '天',
                              style: TextStyle(color: accent, fontSize: 14),
                            ),
                          ),
                        ] else
                          Icon(
                            Icons.celebration_outlined,
                            color: accent,
                            size: 46,
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(
                      height: 1,
                      color: hasPhoto
                          ? Colors.white.withValues(alpha: .2)
                          : color.withValues(alpha: .12),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Icon(
                          event.repeatYearly
                              ? Icons.autorenew_rounded
                              : Icons.calendar_today_outlined,
                          size: 14,
                          color: muted,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            event.repeatYearly
                                ? '${compactDate(event.date)} · 每年纪念'
                                : compactDate(event.date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: muted,
                        ),
                      ],
                    ),
                    if (event.repeatYearly)
                      Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: Text(
                          '自这一天已 ${event.elapsedDays(now)} 天',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bounded home variant of the date card; the full list uses EventCard.
class FeaturedEventCard extends StatelessWidget {
  const FeaturedEventCard({
    super.key,
    required this.event,
    required this.now,
    required this.onTap,
  });
  final DayEvent event;
  final DateTime now;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final photo = eventPhoto(event);
    final status = event.status(now);
    final foreground = photo != null ? Colors.white : scheme.onSurface;
    final muted = photo != null
        ? Colors.white.withValues(alpha: .85)
        : scheme.onSurfaceVariant;
    final accent = photo != null ? Colors.white : scheme.primary;
    return Semantics(
      button: true,
      label:
          '${event.title}，${status.label}${status.days == 0 ? '' : '${status.days}天'}，${dateLabel(status.nextDate)}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(28),
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: dark ? .1 : .055),
          scheme.surface,
        ),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.primary.withValues(alpha: .1)),
            borderRadius: BorderRadius.circular(28),
            image: photo == null
                ? null
                : DecorationImage(image: photo, fit: BoxFit.cover),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: photo == null
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .58),
                        Colors.black.withValues(alpha: .75),
                      ],
                    ),
            ),
            child: InkWell(
              onTap: onTap,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final compact = constraints.maxHeight < 240 * scale;
                  final title = Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 16 : 21,
                      height: 1.35,
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                  final counter = Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            status.days == 0 ? '今天' : '${status.days}',
                            style: TextStyle(
                              fontSize: compact ? 56 : 104,
                              height: 1,
                              letterSpacing: -3,
                              fontWeight: FontWeight.w600,
                              color: accent,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (status.days != 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 10, bottom: 8),
                          child: Text(
                            '天',
                            style: TextStyle(fontSize: 16, color: accent),
                          ),
                        ),
                    ],
                  );
                  final date = Text(
                    compactDate(status.nextDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: muted),
                  );
                  if (compact) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: constraints.maxWidth * .48,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    title,
                                    const SizedBox(height: 8),
                                    Text(
                                      status.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: muted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    date,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: counter),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              event.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                event.pinned
                                    ? '置顶日子'
                                    : status.isPast
                                    ? '值得记住'
                                    : '最近的期待',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ),
                            Icon(
                              event.pinned
                                  ? Icons.push_pin_rounded
                                  : Icons.north_east_rounded,
                              size: 16,
                              color: muted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        title,
                        const SizedBox(height: 12),
                        Text(
                          status.days == 0 ? '就是今天' : status.label,
                          style: TextStyle(fontSize: 14, color: muted),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: counter,
                          ),
                        ),
                        Divider(
                          color: foreground.withValues(alpha: .12),
                          height: 1,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: date),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: muted,
                            ),
                          ],
                        ),
                      ],
                    ),
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

ImageProvider? eventPhoto(DayEvent? event) {
  if (event?.photoBase64 == null) return null;
  try {
    return MemoryImage(base64Decode(event!.photoBase64!));
  } catch (_) {
    return null;
  }
}

void revealFormError(ScrollController controller) {
  if (controller.hasClients) {
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }
}
