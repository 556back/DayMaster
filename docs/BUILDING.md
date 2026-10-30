# 构建说明

## 环境

- Flutter（Dart ≥ 3.13.0），本项目使用 Flutter 3.47.6 / Dart 3.13.5 验证。
- Android：JDK 17 或更高版本、Android SDK，先运行 `flutter doctor` 完成环境检查。
- iOS：macOS、Xcode，最低部署版本 iOS 17.0。

源码不包含 Flutter SDK、Android SDK、依赖缓存或签名文件。Windows 脚本优先使用本地 `.tooling`，不存在时使用 PATH 中的 Flutter。

## Android 测试包

```sh
flutter pub get
flutter build apk --debug --split-per-abi
```

Windows 也可以运行 `pwsh -File scripts/build-android.ps1`。产物在 `build/app/outputs/flutter-apk/`：

- `app-arm64-v8a-debug.apk`：大多数 Android 手机。
- `app-armeabi-v7a-debug.apk`：较旧的 32 位手机。
- `app-x86_64-debug.apk`：模拟器。

Windows 脚本加 `-Universal` 可生成通用测试包。Debug 包用于测试。

## Android 正式包

准备自己的签名密钥，例如运行以下命令（交互输入密码，妥善保存密钥）：

```sh
keytool -genkeypair -v -keystore daymaster-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias daymaster
```

将密钥移到源码目录以外，在 `android/key.properties` 填入自己的值：

```properties
storeFile=C:/keys/daymaster-release.jks
storePassword=你的密钥库密码
keyAlias=daymaster
keyPassword=你的密钥密码
```

`storeFile` 使用绝对路径；Windows 路径建议使用 `/`。签名文件和 `key.properties` 已被 Git 忽略。项目不会用调试密钥代替正式签名。

```sh
flutter build apk --release --split-per-abi
```

Windows 也可运行 `pwsh -File scripts/build-android.ps1 -Release`。将生成的 `app-arm64-v8a-release.apk` 等文件附在 GitHub Release。需要上传应用商店时运行 `flutter build appbundle --release`。

## iOS

在 Mac 上运行 `flutter pub get`，打开 `ios/Runner.xcworkspace`：

1. 为 Runner 与 DayMasterWidgets 选择自己的签名团队。
2. 按自己的开发者账号修改 Bundle Identifier。
3. 为两个 Target 配置相同 App Group；默认是 `group.com.daymaster.daymaster`。如需修改，同步更新两份 entitlements 和 Swift 中的共享组标识。
4. 运行 `bash scripts/verify-ios.sh` 验证模拟器构建与测试，再用 Xcode Archive 生成发行包。

可用 `IOS_TEST_DESTINATION` 指定模拟器。Windows 无法完成 iOS 编译与签名。两端的系统小组件、通知送达、跨日刷新和备份文件导入导出，需要在真机检查。

## Web

```sh
flutter build web --no-web-resources-cdn
python scripts/preview.py --port 5173
```

浏览器打开 `http://127.0.0.1:5173`。也可以运行 `flutter run -d chrome`，或在 Windows 用 `pwsh -File scripts/dev.ps1` 开发预览。更换访问地址会使用另一份浏览器存储。

## 版本

首个正式版本为 **1.0.0**，构建号 **1**。发布时使用标签 `v1.0.0`。后续更新同时维护 `pubspec.yaml` 和 `lib/app_info.dart`，并递增构建号。数据快照中的 `version: 1` 是数据协议版本。
