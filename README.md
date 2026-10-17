# PureBili

一个 **无推荐、无广告、无购买入口** 的第三方 Bilibili 本地客户端，采用 iOS 26 Liquid Glass 风格设计。
技术栈：Flutter 3.27+ / Dart 3.6+，播放器 media_kit (libmpv)。一套代码覆盖 **Windows / macOS / Android / iOS / iPadOS**。

> 非官方项目，仅供学习交流，请遵守 Bilibili 用户协议。

## 功能

- 扫码登录（Cookie 本地持久化）
- 关注：关注 UP 主的视频更新，纯时间线
- 搜索：视频搜索 + 5 种排序，支持直接粘贴 BV 号；只显示自己的搜索历史
- 播放：DASH 音视频、画质切换、倍速、弹幕（滚动/顶/底）、全屏、分P、播放进度上报
  - 快捷键：空格 播放/暂停，←/→ ±5s，F 全屏，D 弹幕，Esc 退出全屏
- 互动：点赞（长按一键三连）、投币、收藏到收藏夹、稍后再看、关注 UP
- 评论：热门/最新、楼中楼、发表与回复、评论点赞
- 消息：回复我的、@我的、收到的赞
- 我的：历史记录、稍后再看、收藏夹、UP 主空间投稿、默认画质/弹幕设置
- 布局：窄屏悬浮玻璃 Tab Bar，宽屏（≥900px）玻璃侧边栏，视频页≥1000px 时评论分栏

## 已剔除

首页推荐、热门/排行榜、相关推荐、热搜/搜索发现、广告与推广、商城/会员购/充电/付费视频购买、评论和简介中的商品链接。

实现方式有两层（`lib/api/purify.dart`）：
1. **网络层白名单**：白名单之外的接口请求会被直接拦截，推荐和购买类接口永远不会被调用。
2. **内容过滤**：动态只保留普通视频投稿，搜索结果去掉推广和付费内容，文本中的商品链接会被删除。

## 构建安装包（四端）

### 方式一：GitHub Actions 一次出齐四端（推荐，不用装任何东西）
把代码推到 GitHub 仓库，`.github/workflows/build-all.yml` 会自动构建，完成后在 Actions 页面下载：

| 产物 | 平台 | 说明 |
| --- | --- | --- |
| PureBili-windows-x64 | Windows 10/11 | 解压后运行 purebili.exe |
| PureBili-android-apk | Android | 不知道选哪个就装 app-release.apk（通用包）；arm64-v8a 适合绝大多数手机 |
| PureBili-macos | macOS | 未签名：首次打开请右键 → 打开，或执行 `xattr -cr purebili.app` |
| PureBili-ios-unsigned | iOS / iPadOS | 未签名 IPA，需要用 AltStore / Sideloadly / TrollStore 自签安装 |

### 方式二：本地构建
- **Windows**：装 Flutter 3.27+ 和 Visual Studio 2022（勾选「使用 C++ 的桌面开发」），双击 `build_windows.bat`。
- **Android**：装 Flutter、Android SDK、JDK 17，运行 `./build.sh android`。
- **macOS**：在 Mac 上装 Flutter 和 Xcode，运行 `./build.sh macos`。
- **iOS / iPadOS**：在 Mac 上装 Flutter 和 Xcode，运行 `./build.sh ios`。

脚本会先用 `flutter create` 生成平台目录，再执行 `tool/patch_platforms.dart` 补齐网络权限：Android 的 INTERNET 权限、macOS 沙盒的网络权限、iOS/macOS 的 ATS 配置。

## 尚未实现

私信、图文动态、直播、番剧/影视、离线缓存、发送弹幕。

## 目录结构

```
lib/
  api/    bili.dart（接口） wbi.dart（WBI 签名） purify.dart（净化层） models.dart
  core/   prefs.dart（本地设置）
  ui/     theme.dart glass.dart（Liquid Glass 组件） video_list.dart
  pages/  shell / following / search / messages / me / library / space / video / player_view / danmaku_layer / comments / login
```
