import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_info.dart';
import 'common.dart';

class ProjectLicensePage extends StatefulWidget {
  const ProjectLicensePage({super.key});

  @override
  State<ProjectLicensePage> createState() => _ProjectLicensePageState();
}

class _ProjectLicensePageState extends State<ProjectLicensePage> {
  late Future<List<String>> _documents = _load();

  Future<List<String>> _load() => Future.wait([
    rootBundle.loadString('NOTICE'),
    rootBundle.loadString('LICENSE'),
  ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('项目许可')),
    body: PageWidth(
      child: FutureBuilder<List<String>>(
        future: _documents,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() => _documents = _load()),
                child: const Text('许可未能加载，点击重试'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                '$appName $appVersion',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                '本项目采用 Apache License 2.0。允许使用、修改与再分发；再分发时须保留许可、版权和适用的归属声明，并在修改过的文件中注明变更。完整条款以以下英文许可为准。',
                style: TextStyle(height: 1.7),
              ),
              const SectionTitle('版权与项目归属'),
              SelectableText(snapshot.data![0]),
              const SectionTitle('Apache License 2.0'),
              SelectableText(
                snapshot.data![1],
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
            ],
          );
        },
      ),
    ),
  );
}
