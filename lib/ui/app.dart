import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app_info.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';
import 'event_pages.dart';
import 'event_list_page.dart';
import 'home_today_page.dart';
import 'help_page.dart';
import 'settings_page.dart';
import 'widget_pages.dart';
export 'event_pages.dart' show EventDetailPage;

final appNavigatorKey = GlobalKey<NavigatorState>();

class DayMasterApp extends StatelessWidget {
  const DayMasterApp({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => MaterialApp(
      title: appName,
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: dayTheme(Brightness.light),
      darkTheme: dayTheme(Brightness.dark),
      themeMode: switch (store.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: _HomeShell(store: store),
    ),
  );
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({required this.store});
  final AppStore store;
  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _tab = 0;
  void _add() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _tab == 0
          ? EventEditorPage(store: widget.store)
          : WidgetEditorPage(store: widget.store),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: PageWidth(
          maxWidth: 520,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DayColors.blue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '日子',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 23,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '使用说明',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const HelpPage()),
                ),
                icon: const Icon(Icons.help_outline_rounded),
              ),
              PopupMenuButton<String>(
                tooltip: '更多',
                icon: Badge(
                  isLabelVisible: store.nativeWarning != null,
                  child: const Icon(Icons.more_horiz_rounded),
                ),
                onSelected: (value) {
                  if (value == 'status') {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('组件更新状态'),
                        content: Text(store.nativeWarning ?? '组件已更新。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('知道了'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => value == 'days'
                            ? AllDaysPage(store: store)
                            : SettingsPage(store: store),
                      ),
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'days', child: Text('全部日子')),
                  const PopupMenuItem(value: 'settings', child: Text('设置与备份')),
                  if (store.nativeWarning != null)
                    const PopupMenuItem(value: 'status', child: Text('组件更新状态')),
                ],
              ),
            ],
          ),
        ),
      ),
      body: store.loading
          ? const Center(child: CircularProgressIndicator())
          : store.error != null
          ? Center(
              child: SingleChildScrollView(
                child: EmptyMessage(
                  icon: Icons.cloud_off_rounded,
                  title: '本地记录未能读取',
                  description: store.error!,
                  action: '重新读取',
                  onAction: () => store.initialize(),
                ),
              ),
            )
          : SafeArea(
              top: false,
              bottom: false,
              child: IndexedStack(
                index: _tab,
                children: [
                  HomeTodayPage(store: store),
                  WidgetLibraryPage(store: store),
                ],
              ),
            ),
      floatingActionButton: _tab == 1 && store.error == null && !store.loading
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('创建组件'),
            )
          : null,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (tab) => setState(() => _tab = tab),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: '日子',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.widgets_outlined),
                    selectedIcon: Icon(Icons.widgets_rounded),
                    label: '小组件',
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
