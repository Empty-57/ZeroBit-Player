# 安装

## 系统要求

| 项目 | 要求 |
|------|------|
| 系统 | **Windows 10 / 11**（官方支持范围） |
| 内存 | 建议 4GB 及以上 |
| 磁盘 | 约 100MB 可用空间 |
| 运行库 | 建议安装最新 Visual C++ 可再发行组件 |

Windows 7 / 8 等更旧系统**不在支持范围**。本软件基于 Flutter 桌面端，官方工具链本身就不覆盖 Win7/8，一般无法安装或无法稳定运行；请使用 Windows 10 或 11。

## 选择发行形态
有安装版和便携版两种选择。

- 安装版：下载后按照指引安装完成后即可使用
- 便携版：下载后解压到任意位置，双击 `zerobit_player.exe` 即可使用

所有用户数据和音频数据均保存在 `C:\Users\<用户名>\Documents\zerobit_config` 。

两者功能一致。从 [下载页](/download) 获取对应文件：安装版 `zerobit_player_setup.exe`，便携版 `zerobit_player.zip`。不要下载 Source code 源码归档。

优先用 **[GitHub Releases](https://github.com/Empty-57/ZeroBit-Player/releases)**。访问慢可到 [Gitee](https://gitee.com/empty-57/ZeroBit-Player/releases) 镜像，但那边自动同步往往很慢，**版本可能暂时对不齐**，以 GitHub / 本站更新日志为准更稳妥。

## 安装步骤
见 [下载页](/download)

## 更新版本
### 安装版
1. 完全退出旧版本
2. 运行新版安装程序覆盖安装
3. `C:\Users\<用户名>\Documents\zerobit_config` 内的用户数据不会受影响，新版本会自动读取，除非手动删除

### 便携版
1. 完全退出旧版本并删除整个程序目录
2. 将新版本解压到一个新目录
3.  `C:\Users\<用户名>\Documents\zerobit_config` 内的用户数据不会受影响，新版本会自动读取，除非手动删除

## 卸载
### 安装版
1. 完全退出 Pure Music
2. 运行软件目录下的 `unins000.exe`
3. 手动删除 `C:\Users\<用户名>\Documents\zerobit_config` ，也可以选择保留至下次安装时读取

### 便携版
退出后删除整个程序目录即可，手动删除 `C:\Users\<用户名>\Documents\zerobit_config` ，也可以选择保留至下次安装时读取。

## SmartScreen 与杀软

::: info 首次运行提示
Windows 可能弹出 SmartScreen。点击「更多信息」→「仍要运行」即可。
:::

部分杀软会误报。可将程序目录（安装版为安装目录）加入白名单。

## 从源码构建

源码不是发布版程序。开发环境、首次运行和打包方式见 [构建指南](/dev/build)。