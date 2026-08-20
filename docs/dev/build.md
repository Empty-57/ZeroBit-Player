# 构建

## 环境

| 工具 | 要求                                         |
|------|--------------------------------------------|
| Flutter | ≥ 3.44.2                                   |
| Dart | 随 Flutter 安装，版本需 ≥ 3.12.2                  |
| Rust | stable ≥1.92.0                                  |
| Visual Studio | 安装“使用 C++ 的桌面开发”，包含 Windows SDK 与 CMake 工具 |
| flutter_rust_bridge_codegen | 仅在修改 Rust 暴露 API 时需要，版本使用 2.11.1           |

先确认基础环境：

```powershell
flutter config --enable-windows-desktop
flutter doctor -v
cargo --version
```

若 `flutter doctor -v` 中 Windows toolchain 不全，先补齐再继续。

## 首次运行

在仓库根目录执行：

```powershell
flutter pub get
flutter run -d windows
```

然后在 `Debug` 目录下新建 `BASSDLL` 目录，将以下dll文件复制进去：

 - `bass.dll`
 - `bassalac.dll`
 - `bassape.dll`
 - `bassdsd.dll`
 - `bassflac.dll`
 - `bassmidi.dll`
 - `bassopus.dll`
 - `basswasapi.dll`
 - `basswebm.dll`
 - `basswv.dll`
 - `bass_fx.dll`

然后在 `Debug` 目录新建 `desktop_lyrics` 目录，将 [`Zerobit Player Desktop Lyrics`](https://github.com/Empty-57/zerobit_player_desktop_lyrics) 编译后的内容复制进去。

`Profile` 和 `Release` 目录也执行一样的操作。

首次运行会同时编译 Flutter、Windows runner 与 Rust crate，通常比后续构建慢。

## 日常开发

| 改动 | 接下来做什么 |
|------|--------------|
| Dart / Flutter | 保存后热重载；涉及初始化时重新启动 |
| Rust 函数内部实现 | 停止应用后重新运行，Cargokit 会重新编译 Rust |
| `rust/src/api/` 的函数签名或类型 | 重新生成 FRB 绑定，再运行应用 |
| `pubspec.yaml` | 执行 `flutter pub get` |

Debug 构建：

```powershell
flutter build windows --debug
```

产物在 `build/windows/x64/runner/Debug/`。运行时要保留整个目录结构，必须包含 `desktop_lyrics` 和 `BASSDLL` 目录以及其下的所有内容。

## 修改 Rust API

安装与项目匹配的 codegen：

```powershell
cargo install flutter_rust_bridge_codegen --version 2.11.1 --locked
flutter_rust_bridge_codegen generate
flutter pub get
flutter run -d windows
```

只有暴露函数的签名、参数或返回类型变化时才需要重新生成。`lib/src/rust/` 与 `rust/src/frb_generated.rs` 是生成文件，不要手动修改。

## Release 构建

普通 Release 构建：

```powershell
flutter build windows --release
```

产物在 `build/windows/x64/runner/Release/`，发布包必须包含 `desktop_lyrics` 和 `BASSDLL` 目录以及其下的所有内容。

## 常见构建问题

**`flutter doctor` 提示缺少 Windows 工具链**  
在 Visual Studio Installer 中补装“使用 C++ 的桌面开发”、Windows SDK 与 CMake 工具。

**找不到 `cargo` 或 Rust 编译失败**  
确认 stable 工具链已安装，`cargo --version` 可执行，再删除失败的临时构建并重试。

**FRB 生成失败或生成后类型不一致**  
确认 Dart 依赖、Rust crate 与 codegen 都是 2.11.1，再从仓库根目录执行 `flutter_rust_bridge_codegen generate`。

**能编译，但播放或桌面歌词不可用** 
检查 `desktop_lyrics` 和 `BASSDLL` 目录及其内容是否完整。

## 提交前

```powershell
flutter analyze
flutter test
```

并进行性能和稳定性测试