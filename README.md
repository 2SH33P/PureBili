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

## 构建 Windows 版

**方式一：本地构建**
1. 安装 [Flutter](https://docs.flutter.dev/get-started/install/windows)（3.27 或更新）。
2. 安装 Visual Studio 2022，并勾选「使用 C++ 的桌面开发」工作负载。
3. 双击 `build_windows.bat`。
4. 产物在 `build\windows\x64\runner\Release\purebili.exe`，同时生成 `PureBili-windows-x64.zip`（发给别人时要发整个 Release 文件夹）。

**方式二：GitHub Actions 云端构建（不用装任何东西）**
把代码推送到 GitHub 仓库，`.github/workflows/build-windows.yml` 会自动构建。构建完成后在 Actions 页面下载 `PureBili-windows-x64`。

## 其他平台

```bash
flutter create --platforms=windows,android,ios,macos --org com.purebili --project-name purebili .
flutter pub get
flutter build apk --release      # Android
flutter build ios --release      # iOS / iPadOS（需 macOS + Xcode）
flutter build macos --release    # macOS
```

macOS 需在 `macos/Runner/*.entitlements` 中添加 `com.apple.security.network.client = true`。

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
