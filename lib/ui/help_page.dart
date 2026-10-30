import 'package:flutter/material.dart';

import 'common.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('使用说明')),
    body: PageWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: const [
          _HelpSection(
            title: '1. 添加日子',
            text: '点击首页「添加日子」，填写名称和日期后保存。生日、纪念日可开启「每年重复」，也可以添加照片、备注和分类。',
          ),
          _HelpSection(
            title: '2. 查看与管理',
            text: '首页显示置顶或临近的日子。点击卡片查看详情、编辑或删除；「全部日子」可以搜索、筛选和按分类查看。',
          ),
          _HelpSection(
            title: '3. 添加桌面组件',
            text:
                '进入「小组件」，选择样式和日子，调整配色、透明度或照片构图后保存，再点击「添加到桌面」。\n\n'
                'Android：也可长按桌面空白处 → 小组件 → 日子，添加时选择已保存的配置。\n\n'
                'iPhone：长按主屏幕 → 编辑 → 添加小组件 → 日子；添加后长按组件，编辑并选择配置。锁屏可在「自定」中添加精简组件。\n\n'
                '网页版可预览样式；系统桌面组件需要安装手机 App。实际尺寸与刷新时间由系统决定。壁纸截图仅用于预览。',
          ),
          _HelpSection(
            title: '4. 日期与提醒',
            text:
                '按设备当地的公历日期计算：未来倒数、过去累计，当天显示「就是今天」。「当天为第 1 天」只影响累计天数。每年重复的 2 月 29 日在平年按 2 月 28 日计算。\n\n'
                '编辑日子时可以设置提醒。允许通知后，在对应日期上午 9 点提醒；实际送达受系统权限和省电设置影响。网页版不提供系统提醒。',
          ),
          _HelpSection(
            title: '5. 备份与恢复',
            text:
                '右上角「更多」→「设置与备份」→「导出备份」，保存包含日子、照片和组件配置的 JSON 文件。\n\n'
                '换设备时选择「恢复备份」。「合并恢复」保留现有同 ID 记录；手机端「替换全部」会先要求保存当前备份。\n\n'
                '数据保存在当前设备或浏览器，没有云同步。卸载 App、清理网站数据或换机前，请先导出备份。',
          ),
        ],
      ),
    ),
  );
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.text});
  final String title, text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(height: 1.7)),
      ],
    ),
  );
}
