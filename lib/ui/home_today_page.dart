import 'package:flutter/material.dart';

import '../models/day_event.dart';
import '../store.dart';
import 'common.dart';
import 'event_list_page.dart';
import 'event_pages.dart';

class HomeTodayPage extends StatelessWidget {
  const HomeTodayPage({super.key, required this.store});
  final AppStore store;

  void _open(BuildContext context, DayEvent event) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => EventDetailPage(store: store, eventId: event.id),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final now = store.now();
    final scheme = Theme.of(context).colorScheme;
    final events = store.events.toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final sa = a.status(now), sb = b.status(now);
        if (sa.isPast != sb.isPast) return sa.isPast ? 1 : -1;
        final days = sa.days.compareTo(sb.days);
        return days != 0 ? days : a.createdAt.compareTo(b.createdAt);
      });
    final weekday = const ['一', '二', '三', '四', '五', '六', '日'][now.weekday - 1];
    return PageWidth(
      maxWidth: 520,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final recentLimit = scale >= 1.5
                ? 0
                : constraints.maxHeight > 560
                ? 2
                : constraints.maxHeight > 480
                ? 1
                : 0;
            final recent = events.skip(1).take(recentLimit).toList();
            return Column(
              key: const ValueKey('one-screen-home'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${now.month}月${now.day}日 · 星期$weekday',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AllDaysPage(store: store),
                        ),
                      ),
                      child: const Text('全部日子'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: events.isEmpty
                      ? _HomeEmpty(
                          onAdd: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => EventEditorPage(store: store),
                            ),
                          ),
                        )
                      : FeaturedEventCard(
                          event: events.first,
                          now: now,
                          onTap: () => _open(context, events.first),
                        ),
                ),
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 8),
                    child: Text(
                      '也在惦记',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < recent.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                          _RecentDay(
                            event: recent[i],
                            now: now,
                            onTap: () => _open(context, recent[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (events.isNotEmpty)
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => EventEditorPage(store: store),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('添加日子'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeEmpty extends StatelessWidget {
  const _HomeEmpty({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .5),
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 46,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '把重要的日子留下来',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: onAdd,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('添加第一个日子', maxLines: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecentDay extends StatelessWidget {
  const _RecentDay({
    required this.event,
    required this.now,
    required this.onTap,
  });
  final DayEvent event;
  final DateTime now;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final status = event.status(now);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label:
          '${event.title}，${status.label}${status.days == 0 ? '' : '${status.days}天'}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(event.emoji, style: const TextStyle(fontSize: 23)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    status.days == 0
                        ? '就是今天'
                        : '${status.label} ${status.days} 天',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
