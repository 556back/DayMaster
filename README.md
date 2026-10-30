# 日子 · DayMaster

记录过去，期待未来。一个无需登录的日期记录与桌面小组件 App，使用 Flutter 开发，支持 Android、iOS 和 Web 预览。

**当前版本：1.0.0**，作为首个正式版本。

## 能做什么

- 生日、纪念日、未来倒数与过去累计，支持每年重复。
- 分类、搜索、置顶、备注和照片。
- 八种小组件样式，可调整配色、透明度和照片构图。
- 本地通知、深浅主题，以及包含照片和组件配置的备份。

## 怎么用

1. 在首页添加日子，填写名称和日期后保存。
2. 点击日子查看、编辑，或进入「全部日子」搜索和筛选。
3. 在「小组件」选择样式、绑定日子并保存，再添加到手机桌面。
4. 在「更多 → 设置与备份」导出或恢复备份。

首页右上角 **?** 可打开完整使用说明。数据保存在当前设备或浏览器；卸载、清理数据或换机前，请先备份。Web 版不提供系统桌面组件和通知。

## 本地运行

已验证环境：Flutter 3.47.6 / Dart 3.13.5。Dart 最低版本为 3.13.0。

```sh
flutter pub get
flutter run -d chrome
```

```sh
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
```

Android APK、正式签名与 iOS 构建见 [构建说明](docs/BUILDING.md)。手机系统组件与通知仍需真机验证；iOS 需在 macOS/Xcode 下编译。

## 开源许可

采用 [Apache License 2.0](LICENSE)。允许使用、修改、商业使用和再分发；再分发时须保留许可、版权和适用的 [项目归属声明](NOTICE)，并注明修改过的文件。项目名称与标识不代表对二开项目的背书。依赖组件遵循各自的许可。

[GitHub 发布教程](docs/GITHUB.md) · [原生组件数据协议](docs/native-contract.md)
