import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/audio_ctrl_btn.dart';
import 'package:zerobit_player/components/blur_background.dart';
import 'package:zerobit_player/components/covers.dart';
import 'package:zerobit_player/components/lyric/lyrics_render.dart';
import 'package:zerobit_player/components/play_page/control_bar.dart';
import 'package:zerobit_player/components/play_page/play_page_constant.dart';
import 'package:zerobit_player/components/play_page/spectrogram_widget.dart';
import 'package:zerobit_player/components/window_ctrl_bar.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/lyric_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/controller/user_playlist_ctrl.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:zerobit_player/custom_widgets/scroll_text.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/theme_manager.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/func_extension.dart';
import 'package:zerobit_player/tools/func/general_style.dart';
import 'package:zerobit_player/tools/paint_cache.dart';

const LinearGradient _lyricsFadeGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[
    Colors.transparent,
    Colors.black,
    Colors.black,
    Colors.transparent,
  ],
  stops: <double>[0.0, 0.2, 0.8, 1.0],
);

final GradientShaderCache _lyricsFadeShaderCache = GradientShaderCache(
  maxSize: 4,
);

class _LyricsSide extends StatelessWidget {
  const _LyricsSide();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return RepaintBoundary(
      child: ShaderMask(
        shaderCallback: (rect) {
          return _lyricsFadeShaderCache.shader(
            gradient: _lyricsFadeGradient,
            rect: rect,
          );
        },
        blendMode: BlendMode.dstIn,
        child: SizedBox(width: width / 2, child: const LyricsRender()),
      ),
    );
  }
}

class _ScrollTextWidget extends StatelessWidget {
  final String text;
  final TextStyle style;
  final StrutStyle strutStyle;
  const _ScrollTextWidget({
    required this.text,
    required this.style,
    required this.strutStyle,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollText(
      text: text,
      style: style,
      velocity: 50.0,
      delayBefore: const Duration(milliseconds: 500),
      pauseBetween: const Duration(milliseconds: 1000),
      strutStyle: strutStyle,
    );
  }
}

// --- 封面金属 3D 效果 ---

/// 最大倾斜角（弧度），约 9°
const double _coverMaxTilt = 0.16;

/// 悬停时封面的放大比例
const double _coverHoverScale = 1.03;

/// 倾斜/高光的缓动系数，越大越跟手
const double _coverEase = 0.18;

/// 缓动到这个阈值内就认为动画结束，停掉 ticker
const double _coverSettleEpsilon = 0.002;

/// 带 Steam 风格金属 3D 效果的封面。
///
/// 鼠标悬停时封面朝指针方向做透视倾斜，同时一层金属高光
/// （跟随指针的柔光 + 斜向镜面光带 + 边缘反光）扫过表面，
/// 移开后自动回正。未悬停时变换为单位矩阵、ticker 不运行，开销为零。
class _MetalCover extends StatefulWidget {
  const _MetalCover({required this.size, required this.cacheResolution});

  /// 封面边长（逻辑像素）
  final double size;

  /// 解码分辨率，避免大图占内存
  final int cacheResolution;

  @override
  State<_MetalCover> createState() => _MetalCoverState();
}

class _MetalCoverState extends State<_MetalCover>
    with SingleTickerProviderStateMixin {
  /// 指针移动是离散事件，直接跟随会一跳一跳，用 ticker 做指数缓动
  late final Ticker _ticker;

  /// 指针在封面内的归一化位置，(-1,-1) 左上角 ~ (1,1) 右下角
  Offset _pointer = Offset.zero;

  /// 指针目标位置，_pointer 向它缓动
  Offset _target = Offset.zero;

  /// 悬停强度 0~1，驱动高光和阴影的淡入淡出
  double _hover = 0;

  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _keepTicking() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration _) {
    final targetHover = _isHovering ? 1.0 : 0.0;
    final targetPointer = _isHovering ? _target : Offset.zero;

    final nextHover = _hover + (targetHover - _hover) * _coverEase;
    final nextPointer = Offset.lerp(_pointer, targetPointer, _coverEase)!;

    final settled =
        (nextHover - targetHover).abs() < _coverSettleEpsilon &&
        (nextPointer - targetPointer).distance < _coverSettleEpsilon;

    setState(() {
      _hover = settled ? targetHover : nextHover;
      _pointer = settled ? targetPointer : nextPointer;
    });

    if (settled) _ticker.stop();
  }

  void _setHovering(bool value) {
    if (_isHovering == value) return;
    _isHovering = value;
    _keepTicking();
  }

  @override
  Widget build(BuildContext context) {
    final AudioController audioController = AudioController.instance;
    final nx = _pointer.dx;
    final ny = _pointer.dy;

    // 指针所在的那一侧朝观察者抬起，形成「卡片跟着鼠标转」的透视感
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(ny * _coverMaxTilt * _hover)
      ..rotateY(-nx * _coverMaxTilt * _hover);

    return MouseRegion(
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      onHover: (event) {
        final half = widget.size / 2;
        _target = Offset(
          ((event.localPosition.dx - half) / half).clamp(-1.0, 1.0),
          ((event.localPosition.dy - half) / half).clamp(-1.0, 1.0),
        );
        _keepTicking();
      },
      child: Transform(
        transform: transform,
        alignment: Alignment.center,
        child: Transform.scale(
          scale: 1 + (_coverHoverScale - 1) * _hover,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: _borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2 + 0.25 * _hover),
                  offset: Offset(0, 2 + 10 * _hover),
                  blurRadius: 8 + 24 * _hover,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: _borderRadius,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SignalBuilder(
                      builder: (context) {
                        final cover = audioController.currentCover.value;
                        return AnimatedSwitcher(
                          duration: 300.ms,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: Tween(begin: 0.5, end: 1.0).animate(anim),
                            child: ScaleTransition(
                              scale: Tween(begin: 1.15, end: 1.0).animate(anim),
                              child: child,
                            ),
                          ),
                          // 显式给宽高：AnimatedSwitcher 内部的 Stack 是 loose
                          // 约束，不给尺寸的话小封面图不会铺满
                          child: Image.memory(
                            cover,
                            key: ValueKey(cover),
                            width: widget.size,
                            height: widget.size,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            cacheWidth: widget.cacheResolution,
                            cacheHeight: widget.cacheResolution,
                          ),
                        );
                      },
                    ),
                    IgnorePointer(
                      child: _MetalGlare(pointer: _pointer, intensity: _hover),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 金属高光层，叠在封面之上，靠混合模式做出反光质感。
class _MetalGlare extends StatelessWidget {
  const _MetalGlare({required this.pointer, required this.intensity});

  /// 指针归一化位置，(-1,-1) ~ (1,1)
  final Offset pointer;

  /// 悬停强度 0~1，为 0 时整层不可见
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final nx = pointer.dx;
    final ny = pointer.dy;
    final a = intensity;

    // 镜面光带沿左上→右下扫动，指针越靠右下，光带越靠右下
    final band = (0.5 + (nx + ny) * 0.25).clamp(0.22, 0.78);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 柔光：跟着指针走的大范围高光，overlay 让亮处更亮、暗处更沉
        DecoratedBox(
          decoration: BoxDecoration(
            backgroundBlendMode: BlendMode.overlay,
            gradient: RadialGradient(
              center: Alignment(nx * 0.9, ny * 0.9),
              radius: 1.1,
              colors: [
                Colors.white.withValues(alpha: 0.45 * a),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        // 镜面光带：一道窄亮带，screen 叠出金属特有的高光条
        DecoratedBox(
          decoration: BoxDecoration(
            backgroundBlendMode: BlendMode.screen,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.55 * a),
                Colors.white.withValues(alpha: 0.55 * a),
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0),
              ],
              stops: [0, band - 0.13, band - 0.04, band + 0.04, band + 0.13, 1],
            ),
          ),
        ),
        // 边缘反光：让封面看起来是一块有厚度的金属牌
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: _borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08 + 0.22 * a),
              width: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverSide extends StatefulWidget {
  final double coverSize;
  final TextStyle titleStyle;
  final TextStyle subTitleStyle;

  const _CoverSide({
    required this.coverSize,
    required this.titleStyle,
    required this.subTitleStyle,
  });

  @override
  State<_CoverSide> createState() => _CoverSideState();
}

class _CoverSideState extends State<_CoverSide> {
  final _isHeadHover = signal(false);

  @override
  void dispose() {
    _isHeadHover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AudioController audioController = AudioController.instance;
    final titleStrut = StrutStyle(
      fontSize: widget.titleStyle.fontSize,
      forceStrutHeight: true,
    );
    final subTitleStrut = StrutStyle(
      fontSize: widget.subTitleStyle.fontSize,
      forceStrutHeight: true,
    );
    final width = MediaQuery.sizeOf(context).width;

    return SizedBox(
      width: width / 2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'playingCover',
            child: _MetalCover(
              size: widget.coverSize,
              cacheResolution: cacheResolution,
            ),
          ),
          Container(
            width: widget.coverSize - 24,
            margin: const EdgeInsets.only(top: 24),
            child: MouseRegion(
              onEnter: (_) {
                if (mounted) _isHeadHover.value = true;
              },
              onExit: (_) {
                if (mounted) _isHeadHover.value = false;
              },
              child: SignalBuilder(
                builder: (context) {
                  final title = audioController.currentMetadata.value.title;
                  final artistAndAlbum =
                      "${audioController.currentMetadata.value.artist} - ${audioController.currentMetadata.value.album}";
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      _isHeadHover.value
                          ? _ScrollTextWidget(
                              text: title,
                              style: widget.titleStyle,
                              strutStyle: titleStrut,
                            )
                          : Text(
                              title,
                              style: widget.titleStyle,
                              softWrap: false,
                              strutStyle: titleStrut,
                              overflow: TextOverflow.fade,
                              maxLines: 1,
                              textAlign: TextAlign.left,
                            ),
                      _isHeadHover.value
                          ? _ScrollTextWidget(
                              text: artistAndAlbum,
                              style: widget.subTitleStyle,
                              strutStyle: subTitleStrut,
                            )
                          : Text(
                              artistAndAlbum,
                              style: widget.subTitleStyle,
                              softWrap: false,
                              strutStyle: subTitleStrut,
                              overflow: TextOverflow.fade,
                              maxLines: 1,
                              textAlign: TextAlign.left,
                            ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 主视图 ---
class PlayPage extends StatefulWidget {
  const PlayPage({super.key});

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  late final ScrollController _playQueueScrollController;
  late final MenuController _menuController;
  late final MenuController _playQueueMenuController;

  ThemeService get _themeService => ThemeService.instance;
  AudioController get _audioController => AudioController.instance;
  LyricController get _lyricController => LyricController.instance;
  SettingController get _settingController => SettingController.instance;
  MusicCacheController get _musicCacheController =>
      MusicCacheController.instance;
  UserPlayListController get _userPlayListController =>
      UserPlayListController.instance;

  // 0: 默认（封面+歌词）, 1: 仅封面, 2: 封面+详情, 3: 仅歌词
  final _coverViewMode = signal(0);
  final _isBarHover = signal(false);
  final _isCoverViewModeBarHover = signal(false);

  @override
  void initState() {
    super.initState();
    _playQueueScrollController = ScrollController();
    _menuController = MenuController();
    _playQueueMenuController = MenuController();
  }

  @override
  void dispose() {
    _menuController.close();
    _playQueueMenuController.close();
    _playQueueScrollController.dispose();
    _coverViewMode.dispose();
    _isBarHover.dispose();
    _isCoverViewModeBarHover.dispose();
    super.dispose();
  }

  Widget _createMenuIconBtn({
    String? toolTip,
    IconData? icon,
    required void Function() fn,
  }) {
    return CustomBtn(
      fn: fn,
      btnHeight: 28,
      btnWidth: 28,
      tooltip: toolTip,
      icon: icon,
      contentColor: _themeService.darkTheme.colorScheme.onSecondaryContainer,
      mainAxisAlignment: MainAxisAlignment.center,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 2),
    );
  }

  Widget _createMenuBtn({
    required String text,
    IconData? icon,
    required void Function() fn,
    String? toolTip,
  }) {
    return CustomBtn(
      fn: fn,
      btnHeight: PlayPageConstant.menuBtnHeight,
      btnWidth: PlayPageConstant.menuBtnWidth,
      radius: PlayPageConstant.menuBtnRadius,
      icon: icon,
      label: text,
      tooltip: toolTip,
      contentColor: _themeService.darkTheme.colorScheme.onSecondaryContainer,
      mainAxisAlignment: MainAxisAlignment.start,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _createInfoBar({
    required String text,
    required ColorScheme darkColorScheme,
    required void Function() addFn,
    required void Function() decFn,
  }) {
    return Container(
      height: 36,
      color: darkColorScheme.surfaceContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 4,
          children: [
            Expanded(
              child: Text(
                text,
                style: generalTextStyle(
                  size: 'md',
                  color:
                      _themeService.darkTheme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _createMenuIconBtn(
              toolTip: '增大',
              icon: PhosphorIconsLight.plus,
              fn: addFn.throttle(ms: 500),
            ),
            _createMenuIconBtn(
              toolTip: '减小',
              icon: PhosphorIconsLight.minus,
              fn: decFn.throttle(ms: 500),
            ),
          ],
        ),
      ),
    );
  }

  SubmenuButton _createdSubmenuBtn({
    required String text,
    required ColorScheme darkColorScheme,
    required List<Widget> menuChildren,
    Widget? leadingIcon,
  }) {
    return SubmenuButton(
      submenuIcon: const WidgetStatePropertyAll(SizedBox.shrink()),
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      leadingIcon: leadingIcon,
      menuStyle: MenuStyle(
        alignment: Alignment.topRight,
        backgroundColor: WidgetStatePropertyAll(
          darkColorScheme.surfaceContainer.withValues(alpha: 0.6),
        ),
      ),
      menuChildren: menuChildren,
      child: Text(
        text,
        style: generalTextStyle(
          size: 'md',
          color: _themeService.darkTheme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  List<Widget> _getMenuItem(
    MenuController menuController,
    ColorScheme darkColorScheme,
    Signal<MusicCache> currentMetadata,
  ) {
    final Widget divider = Divider(
      color: darkColorScheme.primary.withValues(alpha: 0.8),
      height: 0.5,
      thickness: 0.5,
    );

    return [
      SignalBuilder(
        builder: (context) => _createInfoBar(
          text: "字号 ${_settingController.lrcFontSize.value}",
          darkColorScheme: darkColorScheme,
          addFn: () {
            if (_settingController.lrcFontSize.value <
                SettingController.lrcFontSizeMax) {
              batch(() {
                _settingController.lrcFontSize.value++;
                _audioController.lyricRenderRevision.value++;
                _lyricController.springController?.cachedScreenHeight = 0.0;
              });
              _settingController.putCache(isSaveFolders: false);
            }
          },
          decFn: () {
            if (_settingController.lrcFontSize.value >
                SettingController.lrcFontSizeMin) {
              batch(() {
                _settingController.lrcFontSize.value--;
                _audioController.lyricRenderRevision.value++;
                _lyricController.springController?.cachedScreenHeight = 0.0;
              });
              _settingController.putCache(isSaveFolders: false);
            }
          },
        ),
      ),
      SignalBuilder(
        builder: (context) => _createInfoBar(
          text: "字重 ${_settingController.lrcFontWeight.value * 100 + 100}",
          darkColorScheme: darkColorScheme,
          addFn: () {
            if (_settingController.lrcFontWeight.value <
                SettingController.lrcFontWeightMax) {
              batch(() {
                _settingController.lrcFontWeight.value++;
                _audioController.lyricRenderRevision.value++;
              });
              _settingController.putCache(isSaveFolders: false);
            }
          },
          decFn: () {
            if (_settingController.lrcFontWeight.value >
                SettingController.lrcFontWeightMin) {
              batch(() {
                _settingController.lrcFontWeight.value--;
                _audioController.lyricRenderRevision.value++;
              });
              _settingController.putCache(isSaveFolders: false);
            }
          },
        ),
      ),
      divider,
      SignalBuilder(
        builder: (context) {
          final album = currentMetadata.value.album;
          final albumWithLetter =
              _musicCacheController.getLetter(str: album) + album;
          final router = GoRouter.of(context);
          return _createMenuBtn(
            fn: () {
              final extra = {
                'pathList':
                    _musicCacheController.albumItemsDict[albumWithLetter],
                'title': album,
                'operateArea': OperateArea.albumDetails,
              };
              menuController.close();
              SchedulerBinding.instance.addPostFrameCallback((_) {
                router.replace(AppRoutes.details, extra: extra);
              });
            },
            text: album,
            icon: PhosphorIconsLight.vinylRecord,
            toolTip: '跳转到 "$album"',
          );
        },
      ),
      SignalBuilder(
        builder: (context) {
          final artistList = currentMetadata.value.artist.split('/');
          final artistFirst = artistList.first;
          final artistFirstWithLetter =
              _musicCacheController.getLetter(str: artistFirst) + artistFirst;
          final router = GoRouter.of(context);
          if (artistList.length == 1) {
            return _createMenuBtn(
              fn: () {
                final extra = {
                  'pathList': _musicCacheController
                      .artistItemsDict[artistFirstWithLetter],
                  'title': artistFirst,
                  'operateArea': OperateArea.artistDetails,
                };
                menuController.close();
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  router.replace(AppRoutes.details, extra: extra);
                });
              },
              text: artistFirst,
              icon: PhosphorIconsLight.userFocus,
              toolTip: '跳转到 "$artistFirst"',
            );
          }
          if (artistList.length > 1) {
            return _createdSubmenuBtn(
              text: '查看艺术家',
              darkColorScheme: darkColorScheme,
              leadingIcon: Icon(
                PhosphorIconsLight.userFocus,
                size: getIconSize(size: 'md'),
              ),
              menuChildren: artistList.map((v) {
                return MenuItemButton(
                  onPressed: () {
                    final extra = {
                      'pathList':
                          _musicCacheController
                              .artistItemsDict[_musicCacheController.getLetter(
                                str: v,
                              ) +
                              v],
                      'title': v,
                      'operateArea': OperateArea.artistDetails,
                    };
                    menuController.close();
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      router.replace(AppRoutes.details, extra: extra);
                    });
                  },
                  child: Center(child: Text(v)),
                );
              }).toList(),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      divider,
      _createdSubmenuBtn(
        text: '添加到歌单',
        darkColorScheme: darkColorScheme,
        leadingIcon: Icon(
          PhosphorIconsLight.plus,
          size: getIconSize(size: 'md'),
        ),
        menuChildren: _userPlayListController.allUserKey.map((v) {
          return MenuItemButton(
            onPressed: () {
              _userPlayListController.addToAudioList(
                metadata: currentMetadata.value,
                userKey: v,
              );
            },
            child: Center(child: Text(v.split('_')[0])),
          );
        }).toList(),
      ),
    ];
  }

  // 0: 默认（封面+歌词）, 1: 仅封面, 2: 封面+详情, 3: 仅歌词
  Widget _buildBtn(String tip, IconData icon, int id, Color? mixColor) {
    return GenIconBtn(
      tooltip: tip,
      icon: icon,
      size: 36,
      iconSize: 20,
      color: mixColor,
      fn: () {
        _coverViewMode.value = id;
      },
    );
  }

  Widget _buildMetadataColumn(MusicCache metadata, TextStyle style) {
    final items = [
      "标题：${metadata.title}",
      "艺术家：${metadata.artist}",
      "专辑：${metadata.album}",
      "流派：${metadata.genre}",
      "时长：${formatTime(totalSeconds: metadata.duration)}",
      "比特率：${metadata.bitrate ?? "UNKNOWN"}kbps",
      "采样率：${metadata.sampleRate ?? "UNKNOWN"}hz",
      "音轨号：${metadata.trackNumber}",
      "位深度：${metadata.bitDepth}",
      "通道数：${metadata.channels}",
      "路径：${metadata.path}",
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        for (final text in items)
          Text(text, style: style, maxLines: text.startsWith("路径") ? 5 : 1),
      ],
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      context.pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    double coverSize = (width * 0.3).clamp(300, 500);
    final halfWidth = width / 2;
    final darkColorScheme = _themeService.darkTheme.colorScheme;
    final primaryColor = darkColorScheme.primary;

    final mixColor = Color.lerp(primaryColor, Colors.white, 0.3);
    final mixSubColor = Color.lerp(
      primaryColor.withValues(alpha: 0.8),
      Colors.white,
      0.3,
    );

    final activeTrackCover = mixColor ?? primaryColor;
    final inactiveTrackCover =
        mixColor?.withValues(alpha: 0.2) ?? primaryColor.withValues(alpha: 0.2);

    final timeCurrentStyle = generalTextStyle(
      ctx: context,
      size: '2xl',
      color: mixColor,
      weight: FontWeight.w100,
    );
    final timeTotalStyle = generalTextStyle(
      ctx: context,
      size: 'md',
      weight: FontWeight.w100,
      color: mixSubColor,
    );
    final titleStyle = generalTextStyle(
      ctx: context,
      size: '2xl',
      color: mixColor,
      weight: FontWeight.w600,
    );
    final subTitleStyle = generalTextStyle(
      ctx: context,
      size: 'md',
      color: mixSubColor,
      weight: FontWeight.w100,
    );

    final spectrogramBarGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        activeTrackCover.withValues(alpha: 0.0),
        activeTrackCover.withValues(alpha: 0.2),
        activeTrackCover.withValues(alpha: 0.5),
      ],
      stops: [0.0, 0.45, 1.0],
    );
    final spectrogramBarLength = AudioController.bassDataFFT512 * 0.5625; // 144
    final spectrogramBarWidth =
        (width * PlayPageConstant.spectrogramWidthFactor) /
        spectrogramBarLength;
    final spectrogramPaddingWidth =
        width * PlayPageConstant.spectrogramWidthFactorDiff;

    final settingController = _settingController;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: ExcludeSemantics(
        child: BlurWithCoverBackground(
          cover: _audioController.currentSmallCover,
          useGradient: false,
          sigma: 256,
          useMask: true,
          radius: 0,
          meshEnable: true,
          onlyDarkMode: true,
          isPlayPage: true,
          child: Container(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainer.withValues(alpha: 0.0),
            child: Column(
              children: [
                const WindowControllerBar(
                  isNestedRoute: false,
                  showLogo: false,
                  useCaretDown: true,
                  useSearch: false,
                  useThemeSwitch: false,
                  onlyDarkMode: true,
                  useBlur: false,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onSecondaryTapDown: (details) =>
                              _menuController.isOpen
                              ? _menuController.close()
                              : _menuController.open(
                                  position: details.localPosition,
                                ),
                          child: MenuAnchor(
                            consumeOutsideTap: true,
                            controller: _menuController,
                            style: MenuStyle(
                              backgroundColor: WidgetStatePropertyAll(
                                darkColorScheme.surfaceContainer.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                            menuChildren: _getMenuItem(
                              _menuController,
                              darkColorScheme,
                              _audioController.currentMetadata,
                            ),
                            child: Stack(
                              children: [
                                SignalBuilder(
                                  builder: (context) {
                                    final mode = _coverViewMode.value;
                                    final metadata =
                                        _audioController.currentMetadata.value;

                                    final coverOffsetInHalf =
                                        (halfWidth - coverSize) / 2;
                                    final detailWidth = halfWidth - 100;

                                    final (
                                      lyricsRight,
                                      lyricsOpacity,
                                    ) = switch (mode) {
                                      0 || 3 => (0.0, 1.0),
                                      _ => (-halfWidth, 0.0),
                                    };

                                    final coverLeft = switch (mode) {
                                      0 => coverOffsetInHalf, // 居中于左半区
                                      1 => (width - coverSize) / 2, // 居中于全屏
                                      3 => -halfWidth, // 移出左侧屏幕
                                      _ =>
                                        halfWidth + coverOffsetInHalf, // 居中于右半区
                                    };

                                    final detailLeft = (mode == 2)
                                        ? detailWidth / 4
                                        : -halfWidth;

                                    final lyricsWidth = (mode == 3)
                                        ? width
                                        : halfWidth;

                                    Widget buildAnimatedSide({
                                      double? left,
                                      double? right,
                                      required double width,
                                      required Widget child,
                                    }) {
                                      return AnimatedPositioned(
                                        duration: 300.ms,
                                        curve: Curves.fastOutSlowIn,
                                        top: 0,
                                        bottom: 0,
                                        left: left,
                                        right: right,
                                        width: width,
                                        child: child,
                                      );
                                    }

                                    final detailTextStyle = titleStyle.copyWith(
                                      fontWeight: FontWeight.w100,
                                      fontSize: titleStyle.fontSize! - 3,
                                    );

                                    return Stack(
                                      children: [
                                        // --- 歌词侧 ---
                                        buildAnimatedSide(
                                          right: lyricsRight,
                                          width: lyricsWidth,
                                          child: AnimatedOpacity(
                                            opacity: lyricsOpacity,
                                            duration: 100.ms,
                                            child: const _LyricsSide(),
                                          ),
                                        ),

                                        // --- 封面侧 ---
                                        buildAnimatedSide(
                                          left: coverLeft,
                                          width: coverSize,
                                          child: _CoverSide(
                                            coverSize: coverSize,
                                            titleStyle: titleStyle,
                                            subTitleStyle: subTitleStyle,
                                          ),
                                        ),

                                        // --- 详情侧 ---
                                        buildAnimatedSide(
                                          left: detailLeft,
                                          width: detailWidth,
                                          child: _buildMetadataColumn(
                                            metadata,
                                            detailTextStyle,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),

                                Positioned(
                                  left: 0,
                                  top: height / 2 - 36 * 4,
                                  child: MouseRegion(
                                    onEnter: (_) =>
                                        _isCoverViewModeBarHover.value = true,
                                    onExit: (_) =>
                                        _isCoverViewModeBarHover.value = false,
                                    child: Padding(
                                      padding: const EdgeInsetsGeometry.only(
                                        left: 8,
                                      ),
                                      child: SignalBuilder(
                                        builder: (_) {
                                          return AnimatedOpacity(
                                            opacity:
                                                _isCoverViewModeBarHover.value
                                                ? 1.0
                                                : 0.0,
                                            duration: const Duration(
                                              milliseconds: 100,
                                            ),
                                            child: Column(
                                              children: [
                                                _buildBtn(
                                                  '封面+歌词',
                                                  _coverViewMode.value == 0
                                                      ? PhosphorIconsFill
                                                            .textbox
                                                      : PhosphorIconsLight
                                                            .textbox,
                                                  0,
                                                  mixColor,
                                                ),
                                                _buildBtn(
                                                  '仅封面',
                                                  _coverViewMode.value == 1
                                                      ? PhosphorIconsFill.image
                                                      : PhosphorIconsLight
                                                            .image,
                                                  1,
                                                  mixColor,
                                                ),
                                                _buildBtn(
                                                  '详情',
                                                  _coverViewMode.value == 2
                                                      ? PhosphorIconsFill.note
                                                      : PhosphorIconsLight.note,
                                                  2,
                                                  mixColor,
                                                ),
                                                _buildBtn(
                                                  '仅歌词',
                                                  _coverViewMode.value == 3
                                                      ? PhosphorIconsFill
                                                            .articleNyTimes
                                                      : PhosphorIconsLight
                                                            .articleNyTimes,
                                                  3,
                                                  mixColor,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),

                                // --- 频谱图 ---
                                Positioned(
                                  left: 0,
                                  bottom: 0,
                                  child: SignalBuilder(
                                    builder: (context) {
                                      if (!settingController
                                          .showSpectrogram
                                          .value) {
                                        return const SizedBox.shrink();
                                      }
                                      return SpectrogramWidget(
                                        key: ValueKey(
                                          _settingController
                                              .showSpectrogram
                                              .value,
                                        ),
                                        gradient: spectrogramBarGradient,
                                        lenth: spectrogramBarLength,
                                        barWidth: spectrogramBarWidth,
                                        paddingWidth: spectrogramPaddingWidth,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ControlBar(
                        mixColor: mixColor,
                        activeTrackCover: activeTrackCover,
                        inactiveTrackCover: inactiveTrackCover,
                        timeCurrentStyle: timeCurrentStyle,
                        timeTotalStyle: timeTotalStyle,
                        playQueueScrollController: _playQueueScrollController,
                        playQueueMenuController: _playQueueMenuController,
                        isBarHover: _isBarHover,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
