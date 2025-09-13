<div align="center">
  <img src="assets/app_icon.ico" alt="logo" width=150 height=150>
</div>

<p align="center">Logo来源：阿里巴巴矢量图库</p>

# ZeroBit Player
一款基于flutter+rust的Material风格本地音乐播放器

![show](screenshot/7.png)

## 安装/快速开始
### 安装
[点击此处安装](https://github.com/Empty-57/ZeroBit-Player/releases/latest)
### 快速开始
- 安装Rust环境
- 安装Flutter SDK 版本>=3.7.2

### 安装依赖
```
flutter pub get
```

### 启动项目
```
flutter run
```

### 注意
编译后要把 BASS 库的 64 位的 `bass.dll`， `bassalac.dll`， `bassape.dll`， `bassdsd.dll`， `bassflac.dll`， `bassmidi.dll`， `bassopus.dll`， `basswasapi.dll`， `basswebm.dll`， `basswv.dll` 放在软件目录的 `BASS` 文件夹下

## 特性
- 支持自定义歌单
- 支持读写（部分）元数据
- 支持多种音频格式
- 支持读取本地歌词文件（暂不支持读取内嵌歌词）
- 支持从网络获取歌词数据
- 支持根据艺术家和专辑分类
- 使用 Material 3 风格
- 支持自定义主题色和自定义字体
- 支持动态主题色
- 支持SMTC

## 支持的音频格式
- .aac
- .ape
- .aiff
- .aif
- .flac
- .mp3
- .mp4 .m4a .m4b .m4p .m4v
- .mpc
- .opus
- .ogg
- .oga
- .spx
- .wav
- .wv

## 支持的歌词格式
- .qrc
- .yrc
- .lrc

## 关于歌词
默认会从音频相同的目录寻找同名的歌词文件，然后寻找同名的`.lrc`文件作为翻译数据，会优先寻找逐字歌词格式，如音频 `a.flac` 会先寻找 `a.qrc` 作为歌词数据，`a.lrc` 将会作为翻译数据（如果存在）
若都不存在，则需要手动从网络选择歌词</br>
若开启了自动下载选择的歌词，则会在选择歌词后，自动在音频同目录下创建原文文件和翻译文件（如果有）</br>

若选择了`.lrc`格式的歌词，会将相同时间戳的歌词行第一行作为原文，第二行作为翻译，若没有相同时间戳的歌词行，则会通过 ` / ` 分割歌词行，` / `前面的作为原文，` / `后面的作为翻译</br>
例如:</br>
```
[00:24.21]ちょっと魔がさしたんだ    这一行将会作为原文
[00:24.21]我是有点鬼迷心窍了       这一行将会作为翻译
```

```
[00:24.21]ちょっと魔がさしたんだ / 我是有点鬼迷心窍了     / 前面将会作为原文 / 后面将会作为翻译
```


通过输入歌曲信息，搜索更精确的歌词:</br>

![search](screenshot/5.png)

## 提交BUG或者PR
- 若提交BUG，请创建一个新的 issue，尽可能说明复现步骤并提供截图。
- 若提交PR，请检查代码是否有潜在隐患并尽量做一些优化。

## 感谢
[coriander_player](https://github.com/Ferry-200/coriander_player): 借鉴了UI设计</br>
[BASS](https://www.un4seen.com/): 播放器内核</br>
[Lofty](https://crates.io/crates/lofty): 读取音频元数据

## 软件截图
![search](screenshot/1.png)
![search](screenshot/2.png)
![search](screenshot/3.png)
![search](screenshot/4.png)
![search](screenshot/5.png)
![search](screenshot/6.png)
![search](screenshot/7.png)
![search](screenshot/8.png)
![search](screenshot/9.png)