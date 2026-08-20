# 架构

面向开发者。用户功能说明见 [指南](/guide/)。

## 总览

```
lib
  ├─ pages
  ├─ components
  ├─ controller
  ├─ custom_widgets
  ├─ field
  ├─ hive_manager
  │   ├─ adapters
  │   └─ models
  ├─ API
  └─ tools
     ├─ func
     └─ lrcTool
rust
   └─ src
       └─ api
           └─ bass

```

## 目录地图

| 路径                                       | 职责            |
|------------------------------------------|---------------|
| `lib/main.dart`、`lib/theme_manager.dart` | 入口、初始化，主题     |
| `lib/pages/`                             | 各个路由页         |
| `lib/components/`                        | 主要组件，页面，布局等   |
| `lib/custom_widgets/`                    | 自定义小组件        |
| `lib/field/`                             | 常量，标识符，键      |
| `lib/controller/`                        | 控制器，状态管理      |
| `lib/API/`                               | 网络API实现       |
| `lib/hive_manager/`                      | 数据持久化管理       |
| `lib/tools/`                             | 各种工具方法        |
| `lib/tools/lrcTool/`                     | 歌词工具，歌词解析，读取等 |
| `rust/src/api/`                          | rust暴露的api    |
| `rust/src/api/bass/`                     | 音频内核          |

## 从哪里开始改

| 目标 | 入口                                                                                                        |
|------|-----------------------------------------------------------------------------------------------------------|
| 应用启动、初始化与路由 | `lib/main.dart`                                                                                           |
| 曲库扫描与标签 | `rust/src/api/music_tag_tool.rs`、`lib/tools/func/sync_cache.dart`                                         |
| 播放、队列与输出 | `lib/controller/audio_ctrl.dart`、`lib/controller/lyric_ctrl.dart`                                         |
| 歌词解析 | `lib/tools/lrcTool/`                                                                                      |
| 在线歌词 | `lib/API/`                                                                                                |
| 播放页与歌词 UI | `lib/page/play_page.dart`、 `lib/components/lyrics_render.dart`                                            |
| 设置持久化 | `lib/hive_manager/`、`lib/controller/setting_ctrl.dart` 、`lib/controller/desktop_lyrics_setting_ctrl.dart` |

## 状态管理约定

- 全局配置：`SettingController.instance`，`DesktopLyricsSettingController.instance`
- 主题：`ThemeService.instance`
- 不额外引入新状态库

## 下一步

- [构建](/dev/build)
- 用户侧 FAQ：[常见问题](/guide/faq)