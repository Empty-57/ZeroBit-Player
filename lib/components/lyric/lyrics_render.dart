import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/lyric/interlude_widget.dart';
import 'package:zerobit_player/components/lyric/line_render.dart';
import 'package:zerobit_player/components/lyric/lyric_arg_constants.dart';
import 'package:zerobit_player/components/spring_list_view.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/lyric_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/logger.dart';
import 'package:zerobit_player/theme_manager.dart';
import 'package:zerobit_player/tools/func/general_style.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';

import '../../field/set_constants.dart';
import '../widget/audio_ctrl_btn.dart';

class _LyricsStyle {
  final SettingController _settingsController = SettingController.instance;

  final _themeService = ThemeService.instance;

  // 提取基础参数，避免重复访问 Rx 变量的 .value
  double get _baseSize => _settingsController.lrcFontSize.value.toDouble();
  FontWeight get _weight =>
      FontWeight.values[_settingsController.lrcFontWeight.value];
  Color get _primaryColor => _themeService.darkTheme.colorScheme.primary;
  Color get _onContainerColor =>
      _themeService.darkTheme.colorScheme.onSecondaryContainer;

  // StrutStyle 强制行高一致，防止跳动
  StrutStyle get strutStyle =>
      StrutStyle(fontSize: _baseSize.toDouble(), forceStrutHeight: true);

  // 核心样式生成
  TextStyle get lyricStyle => generalTextStyle(
    size: _baseSize,
    color: _onContainerColor.withValues(
      alpha: LyricConstants.notPlayedDarkAlpha,
    ),
    weight: _weight,
  );

  TextStyle get tsLyricStyle => lyricStyle.copyWith(fontSize: _baseSize - 4);

  TextStyle get romaLyricStyle => lyricStyle.copyWith(fontSize: _baseSize - 6);

  TextStyle get interludeLyricStyle =>
      lyricStyle.copyWith(fontFamily: 'Microsoft YaHei Light');

  Color get hoverColor => _themeService.darkTheme.colorScheme.onSurface
      .withValues(alpha: LyricConstants.notPlayedDarkAlpha);

  Color? get mixColor => Color.lerp(
    _primaryColor,
    Colors.white,
    LyricConstants.notPlayedLightAlpha,
  );
}

class LyricsRender extends StatefulWidget {
  const LyricsRender({super.key});

  @override
  State<LyricsRender> createState() => _LyricsRenderState();
}

class _LyricsRenderState extends State<LyricsRender> {
  final AudioController _audioController = AudioController.instance;
  final SettingController _settingController = SettingController.instance;
  final LyricController _lyricController = LyricController.instance;
  final _isHover = signal(false);
  final _LyricsStyle lrcStylePackage = _LyricsStyle();

  @override
  void initState() {
    super.initState();
    if (_settingController.useSpringScroll.value) {
      _lyricController.springController = SpringListController();
    }
    _lyricController.lrcViewScrollController = ItemScrollController();

    // 首次进入页面时，跳转到当前行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _lyricController.scrollToCenter();
      }
    });
  }

  @override
  void dispose() {
    _lyricController.lrcViewScrollController = null;
    _lyricController.springController = null;
    _isHover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color? mixColor = lrcStylePackage.mixColor;
    final height = MediaQuery.sizeOf(context).height;
    final width = MediaQuery.sizeOf(context).width;

    final dynamicPadding = width / 2 * (1 - 1 / LyricConstants.lrcScale);
    return MouseRegion(
      onEnter: (_) => _isHover.value = true,
      onExit: (_) => _isHover.value = false,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _lyricController.pointerScroll();
          }
        },
        child: Stack(
          children: [
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SignalBuilder(
                dependencies: [_audioController.lyricRenderRevision],
                builder: (context) {
                  final c = _audioController;
                  // 将 style 定义在SignalBuilder内以接收样式更改信号
                  final lyricsStyle = lrcStylePackage.lyricStyle;
                  final tsLyricStyle = lrcStylePackage.tsLyricStyle;
                  final romaLyricStyle = lrcStylePackage.romaLyricStyle;
                  final strutStyle = lrcStylePackage.strutStyle;
                  final interludeLyricStyle =
                      lrcStylePackage.interludeLyricStyle;
                  final hoverColor = lrcStylePackage.hoverColor;
                  mixColor = lrcStylePackage.mixColor;

                  LoggerUni.i("LyricRenderReBuild");
                  if (!c.showLyricRender) {
                    return Center(
                      child: Text(
                        "无歌词",
                        style: lyricsStyle.copyWith(
                          color: lyricsStyle.color?.withValues(
                            alpha: LyricConstants.highLightAlpha,
                          ),
                        ),
                      ),
                    );
                  }
                  final useSpringscroll =
                      _settingController.useSpringScroll.value;
                  final lrcAlignment = _settingController.lrcAlignment.value;
                  final showRoma = _settingController.showRoma.value;
                  final showTranslate = _settingController.showTranslate.value;
                  final useBlur = _settingController.useBlur.value;
                  final currentSongPath = c.currentPath.peek();

                  final lrcPadding = EdgeInsets.only(
                    top: 16,
                    bottom: 16,
                    left: lrcAlignment == LrcAlignmentType.right
                        ? dynamicPadding
                        : lrcAlignment == LrcAlignmentType.center
                        ? dynamicPadding / 2
                        : 16,
                    right: lrcAlignment == LrcAlignmentType.left
                        ? dynamicPadding
                        : lrcAlignment == LrcAlignmentType.center
                        ? dynamicPadding / 2
                        : 16,
                  );
                  final textAlign = lrcAlignment == LrcAlignmentType.left
                      ? TextAlign.left
                      : lrcAlignment == LrcAlignmentType.center
                      ? TextAlign.center
                      : TextAlign.right;

                  Widget creatLyricItem(int index) {
                    if (index < 0 ||
                        (c.currentlyricType == LyricFormat.lrc &&
                            c.lineTextList[index].isEmpty &&
                            c.translateList[index].isEmpty)) {
                      return const SizedBox.shrink();
                    }
                    return _StaggeredLyricItem(
                      key: ValueKey('${currentSongPath}_$index'),
                      index: index,
                      onClick: c.throttledSeek,
                      lyricController: _lyricController,
                      lrcType: c.currentlyricType,
                      lineText: c.lineTextList[index],
                      translateText: c.translateList[index],
                      romaText: c.romaList[index],
                      startTime: c.startTime[index],
                      lyricStyle: lyricsStyle,
                      tsLyricStyle: tsLyricStyle,
                      romaLyricStyle: romaLyricStyle,
                      interludeLyricStyle: interludeLyricStyle,
                      strutStyle: strutStyle,
                      hoverColor: hoverColor,
                      lrcAlignment: lrcAlignment,
                      lrcPadding: lrcPadding,
                      textAlign: textAlign,
                      showTranslate: showTranslate,
                      showRoma: showRoma,
                      useSpringScroll: useSpringscroll,
                      useBlur: useBlur,
                    );
                  }

                  return useSpringscroll
                      ? SpringListView(
                          key: ValueKey(currentSongPath),
                          length: c.lineTextList.length,
                          controller: _lyricController.springController!,
                          itemBuilder: (int index) {
                            return creatLyricItem(index);
                          },
                        )
                      : Focus(
                          canRequestFocus: false,
                          descendantsAreFocusable: false,
                          child: ScrollablePositionedList.builder(
                            key: ValueKey(currentSongPath),
                            itemCount: c.lineTextList.length,
                            initialScrollIndex: 0,
                            initialAlignment: 0.4,
                            itemScrollController:
                                _lyricController.lrcViewScrollController,
                            minCacheExtent: 48.0,
                            addAutomaticKeepAlives: false,
                            addSemanticIndexes: false,
                            addRepaintBoundaries: true,
                            padding: EdgeInsets.symmetric(
                              vertical:
                                  (height -
                                      LyricConstants.audioCtrlBarHeight -
                                      LyricConstants.controllerBarHeight) /
                                  2,
                            ),
                            itemBuilder: (BuildContext context, int index) {
                              return creatLyricItem(index);
                            },
                          ),
                        );
                },
              ),
            ),

            Positioned(
              bottom: 100,
              right: 8,
              child: SignalBuilder(
                builder: (context) => AnimatedOpacity(
                  opacity: _isHover.value ? 1.0 : 0.0,
                  duration: 150.ms,
                  child: Column(
                    spacing: 4.0,
                    children: [
                      GenIconBtn(
                        tooltip: '翻译',
                        icon: _settingController.showTranslate.value
                            ? PhosphorIconsFill.translate
                            : PhosphorIconsLight.translate,
                        size: LyricConstants.ctrlBtnMinSize,
                        color: mixColor,
                        fn: () {
                          batch(() {
                            _settingController.setShowTranslate();
                            _audioController.lyricRenderRevision.value++;
                          });
                          _lyricController
                                  .springController
                                  ?.cachedScreenHeight =
                              0.0; // 重置缓存
                        },
                      ),
                      GenIconBtn(
                        tooltip: '注音',
                        icon: _settingController.showRoma.value
                            ? PhosphorIconsFill.textAUnderline
                            : PhosphorIconsLight.textAUnderline,
                        size: LyricConstants.ctrlBtnMinSize,
                        color: mixColor,
                        fn: () {
                          batch(() {
                            _settingController.setShowRoma();
                            _audioController.lyricRenderRevision.value++;
                          });
                          _lyricController
                                  .springController
                                  ?.cachedScreenHeight =
                              0.0; // 重置缓存
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 独立的歌词行组件
class _StaggeredLyricItem extends StatelessWidget {
  final int index;

  final LyricController lyricController;

  final String lrcType;
  final dynamic lineText;
  final String translateText;
  final String romaText;
  final double startTime;

  final int lrcAlignment;
  final TextAlign textAlign;
  final EdgeInsets lrcPadding;
  final bool showTranslate;
  final bool showRoma;
  final bool useSpringScroll;
  final bool useBlur;

  final TextStyle lyricStyle;
  final TextStyle tsLyricStyle;
  final TextStyle romaLyricStyle;
  final TextStyle interludeLyricStyle;
  final StrutStyle strutStyle;
  final Color? hoverColor;

  final void Function(double) onClick;

  const _StaggeredLyricItem({
    super.key,
    required this.index,
    required this.lyricController,
    required this.lrcType,
    required this.lineText,
    required this.translateText,
    required this.romaText,
    required this.startTime,
    required this.lyricStyle,
    required this.tsLyricStyle,
    required this.romaLyricStyle,
    required this.interludeLyricStyle,
    required this.strutStyle,
    required this.hoverColor,
    required this.lrcAlignment,
    required this.lrcPadding,
    required this.textAlign,
    required this.showTranslate,
    required this.showRoma,
    required this.useSpringScroll,
    required this.useBlur,
    required this.onClick,
  });

  Widget _createAnimatedScaleWidget({
    required Widget child,
    required bool isCurrent,
  }) {
    return AnimatedScale(
      scale: isCurrent ? LyricConstants.lrcScale : 1.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      alignment: LyricConstants.lrcScaleAlignment[lrcAlignment],
      child: child,
    );
  }

  Widget _createAnimatedSizeWidget({
    required Widget child,
    required bool show,
  }) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: LyricConstants.lrcScaleAlignment[lrcAlignment],
      child: show ? child : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final int currentLineIndex = lyricController.currentLineIndex.value;
        final int distance = (currentLineIndex - index).abs();
        final renderWidget = distance <= lyricController.visibleItemCount;

        final isPointerScrolling = lyricController.isPointerScroll.value;
        if (!renderWidget && useSpringScroll && !isPointerScrolling) {
          return const SizedBox.shrink(); // ?
        }

        final isCurrent = index == currentLineIndex;
        final bool isPrevLine = (currentLineIndex - index == 1);
        final int blurSigma =
            !useBlur ||
                isCurrent ||
                (index == 0 && currentLineIndex <= 0) ||
                isPointerScrolling ||
                !renderWidget
            ? 0
            : distance.clamp(0, 4);

        final content = SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: LyricConstants.lrcCrossAlignment[lrcAlignment],
            children: [
              if (index == 0)
                InterludeWidget(
                  lyricController: lyricController,
                  lrcAlignment: lrcAlignment,
                  interludeLyricStyle: interludeLyricStyle,
                  strutStyle: strutStyle,
                  isCurrent: currentLineIndex < 0,
                ),
              if (lrcType == LyricFormat.lrc)
                _createAnimatedScaleWidget(
                  child: LrcLyricWidget(
                    text: lineText as String,
                    style: lyricStyle,
                    isCurrent: isCurrent,
                    textAlign: textAlign,
                    blurSigma: blurSigma,
                  ),
                  isCurrent: isCurrent,
                )
              else
                _createAnimatedScaleWidget(
                  child: KaraOkLyricWidget(
                    text: lineText as List<WordEntry>,
                    style: lyricStyle,
                    isCurrentLine: isCurrent,
                    isPrevLine: isPrevLine,
                    lrcAlignment: lrcAlignment,
                    lyricController: lyricController,
                    strutStyle: strutStyle,
                    blurSigma: blurSigma,
                  ),
                  isCurrent: isCurrent,
                ),

              _createAnimatedSizeWidget(
                show: romaText.isNotEmpty && showRoma,
                child: LrcLyricWidget(
                  text: romaText,
                  style: romaLyricStyle,
                  isCurrent: isCurrent,
                  textAlign: textAlign,
                  highLightAlpha: LyricConstants.currentAlpha,
                  blurSigma: blurSigma,
                ),
              ),

              _createAnimatedSizeWidget(
                show: translateText.isNotEmpty && showTranslate,
                child: LrcLyricWidget(
                  text: translateText,
                  style: tsLyricStyle,
                  isCurrent: isCurrent,
                  textAlign: textAlign,
                  highLightAlpha: LyricConstants.currentAlpha,
                  blurSigma: blurSigma,
                ),
              ),
              if (isCurrent || isPrevLine)
                InterludeWidget(
                  lyricController: lyricController,
                  lrcAlignment: lrcAlignment,
                  interludeLyricStyle: interludeLyricStyle,
                  strutStyle: strutStyle,
                  isCurrent: isCurrent,
                ),
            ],
          ),
        );

        return TextButton(
          onPressed: () => onClick(startTime),
          style: TextButton.styleFrom(
            shape: const RoundedRectangleBorder(
              borderRadius: LyricConstants.borderRadius,
            ),
            padding: lrcPadding,
            overlayColor: hoverColor,
          ),
          child: content,
        );
      },
    );
  }
}
