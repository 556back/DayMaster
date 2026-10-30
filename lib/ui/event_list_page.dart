import 'package:flutter/material.dart';

import '../store.dart';
import 'common.dart';
import 'event_pages.dart';

class AllDaysPage extends StatelessWidget {
  const AllDaysPage({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('全部日子')),
      body: _AllDaysBody(store: store),
      floatingActionButton: FloatingActionButton.extended(
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
  );
}

class _AllDaysBody extends StatefulWidget {
  const _AllDaysBody({required this.store});
  final AppStore store;
  @override
  State<_AllDaysBody> createState() => _AllDaysBodyState();
}

class _AllDaysBodyState extends State<_AllDaysBody> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _filter = '全部', _category = '全部分类';
  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
    _search.clear();
    _filter = '全部';
    _category = '全部分类';
    _searchFocus.requestFocus();
  });
  @override
  Widget build(BuildContext context) {
    final now = widget.store.now();
    final query = _search.text.trim().toLowerCase();
    final all = widget.store.events;
    final categories = <String>{'全部分类', ...all.map((e) => e.category)}.toList();
    final category = categories.contains(_category) ? _category : '全部分类';
    final events =
        all.where((event) {
          final status = event.status(now);
          return (query.isEmpty ||
                  ('${event.title} ${event.note}').toLowerCase().contains(
                    query,
                  )) &&
              (category == '全部分类' || event.category == category) &&
              (_filter == '全部' ||
                  (_filter == '将来' ? !status.isPast : status.isPast));
        }).toList()..sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          final aStatus = a.status(now), bStatus = b.status(now);
          if (aStatus.isPast != bStatus.isPast) return aStatus.isPast ? 1 : -1;
          return aStatus.days.compareTo(bStatus.days);
        });
    return PageWidth(
      maxWidth: 1100,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          TextField(
            controller: _search,
            focusNode: _searchFocus,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '搜索日子或备注',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除搜索',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _search.clear();
                        _searchFocus.requestFocus();
                      }),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: ['全部', '将来', '过去']
                .map(
                  (value) => Padding(
                    padding: EdgeInsets.zero,
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 40),
                        child: Text(
                          value,
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      selected: _filter == value,
                      onSelected: (_) => setState(() => _filter = value),
                    ),
                  ),
                )
                .toList(),
          ),
          if (categories.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories
                    .map(
                      (value) => Padding(
                        padding: const EdgeInsets.only(right: 8, top: 8),
                        child: FilterChip(
                          showCheckmark: false,
                          label: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: value.runes.length > 2
                                  ? value.runes.length * 16.0
                                  : 40.0,
                            ),
                            child: Text(
                              value,
                              maxLines: 1,
                              softWrap: false,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          selected: category == value,
                          onSelected: (_) => setState(() => _category = value),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 20),
          if (all.isNotEmpty && events.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Text(
                    '我的日子',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    '${events.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if (MediaQuery.sizeOf(context).width >= 380 &&
                      MediaQuery.textScalerOf(context).scale(1) < 1.5)
                    Text(
                      '置顶优先 · 按天数排序',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          if (all.isEmpty)
            EmptyMessage(
              icon: Icons.favorite_border_rounded,
              title: '把重要的日子留下来',
              description: '添加生日、纪念日或期待的日期。',
              action: '添加第一个日子',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => EventEditorPage(store: widget.store),
                ),
              ),
            )
          else if (events.isEmpty)
            EmptyMessage(
              icon: Icons.search_off_rounded,
              title: '没有找到这样的日子',
              description: '换个关键词，或查看全部日期。',
              action: '清除搜索与筛选',
              onAction: _clear,
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
                  children: events
                      .map(
                        (event) => SizedBox(
                          width: width,
                          child: EventCard(
                            event: event,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => EventDetailPage(
                                  store: widget.store,
                                  eventId: event.id,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}
