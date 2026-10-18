
# 架构

面向开发者。用户功能说明见 [指南](/guide/)。

## 总览

项目采用 **Feature-First（业务特性聚合）+ Core（底层基建）** 架构，将高内聚的业务模块与底层驱动彻底分离：

```
lib/
  ├─ core/                  # 全局底座：常量、存储、主题、平台、网络、通用小组件
  │   ├─ constants/         # 路由、常量、键名与枚举
  │   ├─ platform/          # 桌面端平台特性 (托盘、窗口控制、任务栏)
  │   ├─ theme/             # 主题色彩与样式管理器
  │   ├─ network/           # API 网络请求与版本检查
  │   ├─ storage/           # Hive 存储、LRU/绘制缓存
  │   │   ├─ adapters/      # Hive 适配器
  │   │   └─ models/        # 缓存数据模型
  │   ├─ utils/             # 全局工具函数、扩展与日志
  │   └─ widgets/           # 全局通用原子组件 (卡片、按钮、弹窗等)
  │       └─ buttons/
  ├─ features/              # 业务特性模块 (Controller + Page + 专属组件)
  │   ├─ player/            # 播放控制、播放大页、底栏、FFT 频谱
  │   ├─ lyrics/            # 歌词渲染、解析引擎、桌面歌词服务
  │   │   ├─ parsers/       # KRC/QRC 解密与 LRC 解析
  │   │   └─ widgets/       # 逐字/画布渲染组件
  │   ├─ library/           # 本地曲库 (单曲/专辑/歌手/文件夹预览与标签修改)
  │   │   └─ widgets/
  │   ├─ playlist/          # 歌单管理
  │   ├─ statistics/        # 听歌数据统计、习惯图表与热力图
  │   ├─ setting/           # 设置中心与配置项面板
  │   └─ navigation/        # 主框架侧边栏
  ├─ src/rust/              # flutter_rust_bridge 自动生成的 Dart 侧绑定
  │   └─ api/
  └─ main.dart              # 应用入口与初始化
rust/
  └─ src/
      └─ api/               # Rust 暴露给 Flutter 的 API (标签解析、SMTC 等)
          └─ bass/          # BASS 音频内核与 WASAPI 底层封装
```

## 目录地图

| 路径                       | 职责                                                                  |
|:---------------------------|:----------------------------------------------------------------------|
| `lib/main.dart`            | 应用入口点、全局初始化与生命周期                                      |
| `lib/core/constants/`      | 路由表 (`app_routes.dart`)、常量定义、枚举及键名                      |
| `lib/core/platform/`       | 桌面平台服务（系统托盘、任务栏缩略图、毛玻璃底色、窗口控制器）        |
| `lib/core/theme/`          | 全局主题与动态取色样式 (`theme_manager.dart`、`style_manager.dart`)   |
| `lib/core/network/`        | 网络请求 (`apis.dart`)、版本检查与 桌面歌词 WebSocket 通信模型        |
| `lib/core/storage/`        | Hive 持久化、及适配器模型                                             |
| `lib/core/utils/`          | 通用工具（日志 `logger`、时间格式化、模糊匹配、缓存管理、通用 Mixin） |
| `lib/core/widgets/`        | 全局通用小组件（AppCard、Dialog、Buttons、滚动条动效等）              |
| `lib/features/player/`     | 播放核心：音频控制器 (`audio_ctrl`)、播放页、迷你底栏、FFT 频谱采集   |
| `lib/features/lyrics/`     | 歌词完整系统：渲染组件、KRC/QRC 解密与解析器、桌面歌词服务端          |
| `lib/features/library/`    | 本地曲库：音乐/专辑/歌手/文件夹总览、详情页、音频标签编辑器           |
| `lib/features/playlist/`   | 用户歌单与播放队列管理                                                |
| `lib/features/statistics/` | 听歌数据统计：热力图、听歌习惯分析、排行榜                            |
| `lib/features/setting/`    | 设置模块：页面布局与各分类配置项组件                                  |
| `lib/features/navigation/` | 主框架侧边栏导航组件                                                  |
| `lib/src/rust/`            | FRB 自动生成的 Dart 桥接绑定层                                        |
| `rust/src/api/`            | Rust 原生层对外暴露的 API（音频标签提取、SMTC等）                     |
| `rust/src/api/bass/`       | BASS 音频核心引擎、设备输出与 WASAPI 驱动                             |

## 从哪里开始改

| 目标                             | 入口文件 / 推荐目录                                                                                                                                        |
|:---------------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| **应用启动、初始化与路由**       | `lib/main.dart`、`lib/core/constants/app_routes.dart`                                                                                                      |
| **系统托盘与桌面窗口**           | `lib/core/platform/tray.dart`、`lib/core/platform/window_ctrl.dart`                                                                                        |
| **曲库扫描、缓存与标签修改**     | `rust/src/api/music_tag_tool.rs`、`lib/core/storage/sync_cache.dart`、`lib/features/library/controller/music_cache_ctrl.dart`                              |
| **播放控制、队列与音频输出**     | `lib/features/player/controller/audio_ctrl.dart`、`rust/src/api/bass/`                                                                                     |
| **音频频谱与可视化 (FFT)**       | `lib/features/player/tools/fft_feed.dart`、`lib/features/player/widgets/spectrogram_widget.dart`                                                           |
| **歌词解析与解密 (KRC/QRC/LRC)** | `lib/features/lyrics/parsers/` (`parse_lyrics.dart`、`krc_decryptor.dart` 等)                                                                              |
| **歌词逻辑与桌面独立歌词**       | `lib/features/lyrics/controller/lyric_ctrl.dart`、`lib/features/lyrics/server/desktop_lyrics_server.dart`                                                  |
| **播放页与歌词渲染 UI**          | `lib/features/player/views/play_page.dart`、`lib/features/lyrics/widgets/lyrics_render.dart`                                                               |
| **在线歌词与网络通信**           | `lib/core/network/apis.dart`                                                                                                                               |
| **听歌数据统计与图表**           | `lib/features/statistics/controller/statistics_ctrl.dart`、`lib/features/statistics/widgets/`                                                              |
| **设置偏好与持久化存储**         | `lib/core/storage/hive_boxes.dart`、`lib/features/setting/controller/setting_ctrl.dart`、`lib/features/lyrics/controller/desktop_lyrics_setting_ctrl.dart` |

## 状态管理约定

- 全局配置：`SettingController.instance`，`DesktopLyricsSettingController.instance`
- 主题：`ThemeService.instance`
- 不额外引入新状态库

## 下一步

- [构建](/dev/build)
- 用户侧 FAQ：[常见问题](/guide/faq)