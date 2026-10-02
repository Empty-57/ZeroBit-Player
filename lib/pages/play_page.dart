import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/blur_background.dart';
import 'package:zerobit_player/components/lyric/lyrics_render.dart';
import 'package:zerobit_player/components/play_page/control_bar.dart';
import 'package:zerobit_player/components/play_page/play_page_constant.dart';
import 'package:zerobit_player/components/play_page/spectrogram_widget.dart';
import 'package:zerobit_player/components/widget/audio_ctrl_btn.dart';
import 'package:zerobit_player/components/widget/covers.dart';
import 'package:zerobit_player/components/widget/general_btn.dart';
import 'package:zerobit_player/components/widget/scroll_text.dart';
import 'package:zerobit_player/components/window_ctrl_bar.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/lyric_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/controller/user_playlist_ctrl.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/field/set_constants.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
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
    return RepaintBoundary(
      child: ShaderMask(
        shaderCallback: (rect) => _lyricsFadeShaderCache.shader(
          gradient: _lyricsFadeGradient,
          rect: rect,
        ),
        blendMode: BlendMode.dstIn,
        child: const LyricsRender(),
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
    final audioController = AudioController.instance;
    final titleStrut = StrutStyle(
      fontSize: widget.titleStyle.fontSize,
      forceStrutHeight: true,
    );
    final subTitleStrut = StrutStyle(
      fontSize: widget.subTitleStyle.fontSize,
      forceStrutHeight: true,
    );

    return SizedBox(
      width: widget.coverSize,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'playingCover',
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: PlayPageConstant.borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: PlayPageConstant.borderRadius,
                child: SignalBuilder(
                  builder: (context) {
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
                      child: LoadU8Cover(
                        data: audioController.currentCover,
                        coverResolutionFlag: CoverResolutionFlag.big,
                        key: ValueKey(audioController.coverRevision.value),
                        size: widget.coverSize,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Container(
            width: widget.coverSize - 24,
            margin: const EdgeInsets.only(top: 24),
            child: MouseRegion(
              onEnter: (_) => _isHeadHover.value = true,
              onExit: (_) => _isHeadHover.value = false,
              child: SignalBuilder(
                builder: (context) {
                  final meta = audioController.currentMetadata.value;
                  final title = meta.title;
                  final artistAndAlbum = "${meta.artist} - ${meta.album}";
                  final isHover = _isHeadHover.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      isHover
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
                            ),
                      isHover
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

class _MetadataDetailSide extends StatelessWidget {
  final MusicCache metadata;
  final TextStyle style;

  const _MetadataDetailSide({required this.metadata, required this.style});

  @override
  Widget build(BuildContext context) {
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
}

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

  late final VoidCallback _fontSizeAddFn;
  late final VoidCallback _fontSizeDecFn;
  late final VoidCallback _fontWeightAddFn;
  late final VoidCallback _fontWeightDecFn;

  late Color _mixColor;
  late Color _mixSubColor;
  late Color _activeTrackCover;
  late Color _inactiveTrackCover;
  late TextStyle _timeCurrentStyle;
  late TextStyle _timeTotalStyle;
  late TextStyle _titleStyle;
  late TextStyle _subTitleStyle;
  late LinearGradient _spectrogramBarGradient;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context); // 建立对主题色的依赖

    // 获取暗色配色（优先使用当前上下文的主题方案）
    final darkColorScheme = theme.brightness == Brightness.dark
        ? theme.colorScheme
        : _themeService.darkTheme.colorScheme;
    final primaryColor = darkColorScheme.primary;

    _mixColor = Color.lerp(primaryColor, Colors.white, 0.3) ?? primaryColor;
    _mixSubColor =
        Color.lerp(primaryColor.withValues(alpha: 0.8), Colors.white, 0.3) ??
        primaryColor;

    _activeTrackCover = _mixColor;
    _inactiveTrackCover = _mixColor.withValues(alpha: 0.2);

    _timeCurrentStyle = generalTextStyle(
      ctx: context,
      size: '2xl',
      color: _mixColor,
      weight: FontWeight.w300,
    );
    _timeTotalStyle = generalTextStyle(
      ctx: context,
      size: 'md',
      weight: FontWeight.w300,
      color: _mixSubColor,
    );
    _titleStyle = generalTextStyle(
      ctx: context,
      size: '2xl',
      color: _mixColor,
      weight: FontWeight.w600,
    );
    _subTitleStyle = generalTextStyle(
      ctx: context,
      size: 'md',
      color: _mixSubColor,
      weight: FontWeight.w300,
    );

    _spectrogramBarGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        _activeTrackCover.withValues(alpha: 0.0),
        _activeTrackCover.withValues(alpha: 0.2),
        _activeTrackCover.withValues(alpha: 0.5),
      ],
      stops: const [0.0, 0.45, 1.0],
    );
  }

  @override
  void initState() {
    super.initState();
    _playQueueScrollController = ScrollController();
    _menuController = MenuController();
    _playQueueMenuController = MenuController();

    _fontSizeAddFn = () {
      if (_settingController.lrcFontSize.value <
          SettingController.lrcFontSizeMax) {
        batch(() {
          _settingController.lrcFontSize.value++;
          _audioController.lyricRenderRevision.value++;
          _lyricController.springController?.cachedScreenHeight = 0.0;
        });
        _settingController.putCache(isSaveFolders: false);
      }
    }.throttle(ms: 300);

    _fontSizeDecFn = () {
      if (_settingController.lrcFontSize.value >
          SettingController.lrcFontSizeMin) {
        batch(() {
          _settingController.lrcFontSize.value--;
          _audioController.lyricRenderRevision.value++;
          _lyricController.springController?.cachedScreenHeight = 0.0;
        });
        _settingController.putCache(isSaveFolders: false);
      }
    }.throttle(ms: 300);

    _fontWeightAddFn = () {
      if (_settingController.lrcFontWeight.value <
          SettingController.lrcFontWeightMax) {
        batch(() {
          _settingController.lrcFontWeight.value++;
          _audioController.lyricRenderRevision.value++;
        });
        _settingController.putCache(isSaveFolders: false);
      }
    }.throttle(ms: 300);

    _fontWeightDecFn = () {
      if (_settingController.lrcFontWeight.value >
          SettingController.lrcFontWeightMin) {
        batch(() {
          _settingController.lrcFontWeight.value--;
          _audioController.lyricRenderRevision.value++;
        });
        _settingController.putCache(isSaveFolders: false);
      }
    }.throttle(ms: 300);
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
    required VoidCallback fn,
  }) {
    return GeneralBtn(
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
    required VoidCallback fn,
    String? toolTip,
  }) {
    return GeneralBtn(
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
    required VoidCallback addFn,
    required VoidCallback decFn,
  }) {
    return Container(
      height: 36,
      color: darkColorScheme.surfaceContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              text,
              style: generalTextStyle(
                size: 'md',
                color: _themeService.darkTheme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _createMenuIconBtn(
            toolTip: '增大',
            icon: PhosphorIconsLight.plus,
            fn: addFn,
          ),
          const SizedBox(width: 4),
          _createMenuIconBtn(
            toolTip: '减小',
            icon: PhosphorIconsLight.minus,
            fn: decFn,
          ),
        ],
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
      animated: true,
      submenuIcon: const WidgetStatePropertyAll(SizedBox.shrink()),
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
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

  List<Widget> _buildMenuItems(ColorScheme darkColorScheme) {
    final divider = Divider(
      color: darkColorScheme.primary.withValues(alpha: 0.8),
      height: 0.5,
      thickness: 0.5,
    );
    final iconSize = getIconSize(size: 'md');

    return [
      SignalBuilder(
        builder: (_) => _createInfoBar(
          text: "字号 ${_settingController.lrcFontSize.value}",
          darkColorScheme: darkColorScheme,
          addFn: _fontSizeAddFn,
          decFn: _fontSizeDecFn,
        ),
      ),
      SignalBuilder(
        builder: (_) => _createInfoBar(
          text: "字重 ${_settingController.lrcFontWeight.value * 100 + 100}",
          darkColorScheme: darkColorScheme,
          addFn: _fontWeightAddFn,
          decFn: _fontWeightDecFn,
        ),
      ),
      divider,
      SignalBuilder(
        builder: (context) {
          final album = _audioController.currentMetadata.value.album;
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
              _menuController.close();
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
          final artistList = _audioController.currentMetadata.value.artist
              .split('/');
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
                _menuController.close();
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  router.replace(AppRoutes.details, extra: extra);
                });
              },
              text: artistFirst,
              icon: PhosphorIconsLight.userFocus,
              toolTip: '跳转到 "$artistFirst"',
            );
          }
          return _createdSubmenuBtn(
            text: '查看艺术家',
            darkColorScheme: darkColorScheme,
            leadingIcon: Icon(PhosphorIconsLight.userFocus, size: iconSize),
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
                  _menuController.close();
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    router.replace(AppRoutes.details, extra: extra);
                  });
                },
                child: Center(child: Text(v)),
              );
            }).toList(),
          );
        },
      ),
      divider,
      SignalBuilder(
        builder: (_) => _createMenuBtn(
          fn: () {
            _menuController.close();
            _settingController.useBlur.value =
                !_settingController.useBlur.value;
            _settingController.putCache();
          },
          text: '歌词行模糊',
          icon: _settingController.useBlur.value
              ? PhosphorIconsFill.dotsNine
              : PhosphorIconsLight.dotsNine,
        ),
      ),
      SignalBuilder(
        builder: (_) => _createMenuBtn(
          fn: () {
            _menuController.close();
            _settingController.setSpringScroll();
            SchedulerBinding.instance.addPostFrameCallback((_) {
              _lyricController.scrollToCenter();
            });
          },
          text: '弹性滚动',
          icon: _settingController.useSpringScroll.value
              ? PhosphorIconsFill.waves
              : PhosphorIconsLight.waves,
        ),
      ),
      SignalBuilder(
        builder: (_) => _createdSubmenuBtn(
          text: '调整倍速',
          darkColorScheme: darkColorScheme,
          leadingIcon: Icon(PhosphorIconsLight.waveform, size: iconSize),
          menuChildren: List.generate(16, (index) => index + 5).map((i) {
            final speed = i / 10;
            return MenuItemButton(
              closeOnActivate: false,
              leadingIcon: Icon(
                _audioController.currentSpeed.value == speed
                    ? PhosphorIconsLight.check
                    : null,
                size: iconSize,
              ),
              onPressed: () {
                unawaited(setSpeed(speed: speed));
                _audioController.currentSpeed.value = speed;
              },
              child: Center(child: Text(speed.toString())),
            );
          }).toList(),
        ),
      ),
      SignalBuilder(
        builder: (_) => _createdSubmenuBtn(
          text: '频谱图样式',
          darkColorScheme: darkColorScheme,
          leadingIcon: Icon(PhosphorIconsLight.waveTriangle, size: iconSize),
          menuChildren: SettingController.spectrogramStyleMap.entries.map((v) {
            return MenuItemButton(
              closeOnActivate: false,
              leadingIcon: Icon(
                _settingController.spectrogramStyle.value == v.key
                    ? PhosphorIconsLight.check
                    : null,
                size: iconSize,
              ),
              onPressed: () =>
                  _settingController.setSpectrogramStyle(value: v.key),
              child: Center(child: Text(v.value)),
            );
          }).toList(),
        ),
      ),
      divider,
      _createdSubmenuBtn(
        text: '添加到歌单',
        darkColorScheme: darkColorScheme,
        leadingIcon: Icon(PhosphorIconsLight.plus, size: iconSize),
        menuChildren: _userPlayListController.allUserKey.map((v) {
          return MenuItemButton(
            onPressed: () {
              _userPlayListController.addToAudioList(
                metadata: _audioController.currentMetadata.value,
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
  Widget _buildModeBtn(
    String tip,
    IconData fillIcon,
    IconData lightIcon,
    int id,
    Color? mixColor,
  ) {
    return SignalBuilder(
      builder: (_) {
        final isSelected = _coverViewMode.value == id;
        return GenIconBtn(
          tooltip: tip,
          icon: isSelected ? fillIcon : lightIcon,
          size: 36,
          iconSize: 20,
          color: mixColor,
          fn: () => _coverViewMode.value = id,
        );
      },
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
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;
    final halfWidth = width / 2;

    final maxCoverConstraint = (halfWidth - 32).clamp(150.0, 500.0);
    final double coverSize = (width * 0.3).clamp(200.0, maxCoverConstraint);

    final spectrogramBarLength = AudioController.bassDataFFT512 * 0.5625; // 144
    final spectrogramBarWidth =
        (width * PlayPageConstant.spectrogramWidthFactor) /
        spectrogramBarLength;
    final spectrogramPaddingWidth =
        width * PlayPageConstant.spectrogramWidthFactorDiff;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: ExcludeSemantics(
        child: BlurWithCoverBackground(
          cover: _audioController.currentSmallCover,
          useGradient: false,
          useMask: true,
          radius: 0,
          meshEnable: true,
          onlyDarkMode: true,
          isPlayPage: true,
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
                        onSecondaryTapDown: (details) => _menuController.isOpen
                            ? _menuController.close()
                            : _menuController.open(
                                position: details.localPosition,
                              ),
                        child: MenuAnchor(
                          consumeOutsideTap: true,
                          controller: _menuController,
                          style: MenuStyle(
                            backgroundColor: WidgetStatePropertyAll(
                              _themeService
                                  .darkTheme
                                  .colorScheme
                                  .surfaceContainer
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                          menuChildren: _buildMenuItems(
                            _themeService.darkTheme.colorScheme,
                          ),
                          child: Stack(
                            children: [
                              SignalBuilder(
                                builder: (context) {
                                  final mode = _coverViewMode.value;
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

                                  final (
                                    detailLeft,
                                    detailOpacity,
                                  ) = (mode == 2)
                                      ? (detailWidth / 4, 1.0)
                                      : (-halfWidth, 0.0);

                                  final lyricsWidth = (mode == 3)
                                      ? width
                                      : halfWidth;

                                  Widget buildAnimatedWidget({
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

                                  return Stack(
                                    children: [
                                      buildAnimatedWidget(
                                        right: lyricsRight,
                                        width: lyricsWidth,
                                        child: const _LyricsSide(),
                                      ),

                                      buildAnimatedWidget(
                                        left: coverLeft,
                                        width: coverSize,
                                        child: _CoverSide(
                                          coverSize: coverSize,
                                          titleStyle: _titleStyle,
                                          subTitleStyle: _subTitleStyle,
                                        ),
                                      ),

                                      buildAnimatedWidget(
                                        left: detailLeft,
                                        width: detailWidth,
                                        child: SignalBuilder(
                                          builder: (_) => _MetadataDetailSide(
                                            metadata: _audioController
                                                .currentMetadata
                                                .value,
                                            style: _titleStyle.copyWith(
                                              fontWeight: FontWeight.w300,
                                              fontSize:
                                                  _titleStyle.fontSize! - 3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),

                              Positioned(
                                left: 8,
                                top: height / 2 - 36 * 4,
                                child: MouseRegion(
                                  onEnter: (_) =>
                                      _isCoverViewModeBarHover.value = true,
                                  onExit: (_) =>
                                      _isCoverViewModeBarHover.value = false,
                                  child: SignalBuilder(
                                    builder: (_) {
                                      final isHover =
                                          _isCoverViewModeBarHover.value;
                                      return AnimatedOpacity(
                                        opacity: isHover ? 1.0 : 0.0,
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildModeBtn(
                                              '封面+歌词',
                                              PhosphorIconsFill.textbox,
                                              PhosphorIconsLight.textbox,
                                              0,
                                              _mixColor,
                                            ),
                                            _buildModeBtn(
                                              '仅封面',
                                              PhosphorIconsFill.image,
                                              PhosphorIconsLight.image,
                                              1,
                                              _mixColor,
                                            ),
                                            _buildModeBtn(
                                              '详情',
                                              PhosphorIconsFill.note,
                                              PhosphorIconsLight.note,
                                              2,
                                              _mixColor,
                                            ),
                                            _buildModeBtn(
                                              '仅歌词',
                                              PhosphorIconsFill.articleNyTimes,
                                              PhosphorIconsLight.articleNyTimes,
                                              3,
                                              _mixColor,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              // --- 频谱图 ---
                              Positioned(
                                left: 0,
                                bottom: 0,
                                child: SignalBuilder(
                                  builder: (context) {
                                    final style = _settingController
                                        .spectrogramStyle
                                        .value;
                                    return switch (style) {
                                      SpectrogramStyleType.none =>
                                        const SizedBox.shrink(),
                                      SpectrogramStyleType.rect =>
                                        SpectrogramWidget(
                                          gradient: _spectrogramBarGradient,
                                          length: spectrogramBarLength,
                                          barWidth: spectrogramBarWidth,
                                          paddingWidth: spectrogramPaddingWidth,
                                        ),
                                      SpectrogramStyleType.waveform ||
                                      SpectrogramStyleType
                                          .wave => WaveSpectrogramWidget(
                                        color: _activeTrackCover,
                                        length: spectrogramBarLength,
                                        width: width,
                                        isFill:
                                            style == SpectrogramStyleType.wave,
                                      ),
                                      _ => const SizedBox.shrink(),
                                    };
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ControlBar(
                      mixColor: _mixColor,
                      activeTrackCover: _activeTrackCover,
                      inactiveTrackCover: _inactiveTrackCover,
                      timeCurrentStyle: _timeCurrentStyle,
                      timeTotalStyle: _timeTotalStyle,
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
    );
  }
}
