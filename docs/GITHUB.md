# 发布到 GitHub

当前目录尚未初始化 Git。以下操作由你执行；仓库首次公开版本统一为 **1.0.0**。

## 1. 创建空仓库

登录 GitHub，点击右上角「+ → New repository」，仓库名可填 `DayMaster`，选择 **Public**。不要勾选自动创建 README、.gitignore 或 License；项目已经包含这些文件。

## 2. 提交并上传源码

在项目目录打开 PowerShell：

```powershell
cd D:\Projects\DayMaster
git init -b main
git add --dry-run .
```

检查预览列表：应包含源码、测试、文档、`LICENSE` 和 `NOTICE`，不应包含 `.tooling`、`build`、`.dart_tool`、本地 SDK 路径或签名文件。然后运行：

```powershell
git add .
git status --short
git commit -m "Release DayMaster 1.0.0"
git remote add origin https://github.com/YOUR_NAME/DayMaster.git
git push -u origin main
```

把 `YOUR_NAME` 换成你的 GitHub 用户名。首次使用 Git 如提示缺少身份，先配置后重新提交：

```powershell
git config user.name "你的署名"
git config user.email "你的 GitHub 提交邮箱"
```

邮箱可使用 GitHub「Settings → Emails」提供的 noreply 地址。HTTPS 登录按 Git 凭据管理器的浏览器提示完成；如提示密码，应使用 Personal Access Token，而不是 GitHub 登录密码。

## 3. 发布 1.0.0

```powershell
git tag -a v1.0.0 -m "DayMaster 1.0.0"
git push origin v1.0.0
```

在仓库「Releases → Draft a new release」选择 `v1.0.0`，标题填 `DayMaster 1.0.0`。简单写明首个正式版本及主要功能；按 [构建说明](BUILDING.md) 生成正式签名 APK，再拖入附件。点击「Publish release」完成发布。源码压缩包由 GitHub 自动提供，无需上传 `build` 文件夹。

## 后续修改

```powershell
git add .
git commit -m "说明本次修改"
git push
```

对外发布新版本时递增版本号和构建号，创建新标签。`LICENSE` 和适用的 `NOTICE` 归属声明需要随再分发保留，依赖声明仍由 Flutter 构建产物携带。

参考：[GitHub 官方上传教程](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github)、[GitHub Release 说明](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)。
