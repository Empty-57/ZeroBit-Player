import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/components/blur_background.dart';
import 'package:zerobit_player/components/lyrics_render.dart';
import 'package:zerobit_player/tools/func_extension.dart';
import 'package:zerobit_player/tools/general_style.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';
import 'package:zerobit_player/tools/lrcTool/save_lyric.dart';
import '../HIveCtrl/models/music_cache_model.dart';
import '../components/audio_ctrl_btn.dart';
import '../components/window_ctrl_bar.dart';
import '../custom_widgets/custom_button.dart';
import '../desktop_lyrics_sever.dart';
import '../field/tag_suffix.dart';
import '../getxController/audio_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../theme_manager.dart';
import '../tools/format_time.dart';
import '../tools/lrcTool/parse_lyrics.dart';
import '../tools/rect_value_indicator.dart';
import 'dart:async';

const double _ctrlBtnMinSize = 40.0;
const double _thumbRadius = 10.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));
const double _audioCtrlBarHeight = 96;
const int _coverRenderSize = 800;
const double _spectrogramHeight = 100.0;
const double _spectrogramWidthFactor = 0.94;
const double _spectrogramWidthFactorDiff = (1 - _spectrogramWidthFactor) / 2;
const _lrcAlignmentIcons = [
  PhosphorIconsLight.textAlignLeft,
  PhosphorIconsLight.textAlignCenter,
  PhosphorIconsLight.textAlignRight,
];
final _isBarHover = false.obs;
final _isHeadHover = false.obs;
// 0: 默认（封面+歌词）, 1: 封面完全居中, 2: 封面+详情
final _coverViewMode = 0.obs;
const double _menuBtnWidth = 180;
const double _menuBtnHeight = 48;
const double _menuBtnRadius = 0;

// --- 歌词搜索控制器 ---
class _LrcSearchController extends GetxController {
  final AudioController _audioController = Get.find<AudioController>();
  final currentNetLrc = <SearchLrcModel?>[].obs;
  final currentNetLrcOffest = 0.obs;
  final searchText = "".obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    searchText.value =
        "${_audioController.currentMetadata.value.title} - ${_audioController.currentMetadata.value.artist}";

    debounce(searchText, (_) async {
      currentNetLrcOffest.value = 0;
      await search();
    }, time: const Duration(milliseconds: 500));

    ever(currentNetLrcOffest, (_) async {
      await search();
    });
  }

  Future<void> search() async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      currentNetLrc.value = await getLrcBySearch(
        text: searchText.value,
        offset: currentNetLrcOffest.value,
        limit: 5,
      );

      currentNetLrc.removeWhere(
        (v) =>
            (v == null ||
                v.lyric == null ||
                (v.lyric!.lrc == null && v.lyric!.verbatimLrc == null)),
      );
    } finally {
      isLoading.value = false;
    }
  }
}

// --- 自定义Slider轨道 ---
class _GradientSliderTrackShape extends SliderTrackShape {
  final double activeTrackHeight;
  final double inactiveTrackHeight;
  final Color activeColor;
  const _GradientSliderTrackShape({
    this.activeTrackHeight = 6.0,
    this.inactiveTrackHeight = 4.0,
    required this.activeColor,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double height = activeTrackHeight;
    final double left = offset.dx;
    final double width = parentBox.size.width;
    final double top = offset.dy + (parentBox.size.height - height) / 2;
    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    Offset? secondaryOffset,
    required Offset thumbCenter,
    required TextDirection textDirection,
  }) {
    final Canvas canvas = context.canvas;

    final Rect baseRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final double inH = inactiveTrackHeight;
    final double inTop = offset.dy + (parentBox.size.height - inH) / 2;
    final Rect inactiveRect = Rect.fromLTWH(
      baseRect.left,
      inTop,
      baseRect.width,
      inH,
    );
    final Paint inactivePaint =
        Paint()
          ..color = sliderTheme.inactiveTrackColor!
          ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(inactiveRect, Radius.circular(inH / 2)),
      inactivePaint,
    );

    final Rect activeRect = Rect.fromLTRB(
      baseRect.left,
      baseRect.top,
      thumbCenter.dx,
      baseRect.bottom,
    );
    final Paint activePaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [activeColor.withValues(alpha: 0.0), activeColor],
            stops: [0.0, 0.1],
          ).createShader(activeRect)
          ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        activeRect,
        Radius.circular(activeTrackHeight / 2),
      ),
      activePaint,
    );
  }
}

// --- 搜索结果列表项 ---
class _SearchResultItem extends StatelessWidget {
  final SearchLrcModel lyricInfo;
  final TextStyle textStyle;
  final AudioController audioController;
  final SettingController settingController;

  const _SearchResultItem({
    required this.lyricInfo,
    required this.textStyle,
    required this.audioController,
    required this.settingController,
  });

  @override
  Widget build(BuildContext context) {
    final v = lyricInfo;
    final String? verbatimLrc = v.lyric!.verbatimLrc;
    String? ts = v.lyric!.translate;
    final String title = v.title;
    final String artist = v.artist;

    if (v.lyric!.type == LyricFormat.krc && ts != null && ts.isNotEmpty) {
      try {
        final content = jsonDecode(ts);

        ts = null;
        for (final item in content['content']) {
          if (item['type'] == 1) {
            String str = '';
            str = (item['lyricContent'] as List).fold(
              '',
              (s, l) => '${'${s.trim()}\n'}${(l as List).join()}',
            );
            ts = str;
          }
        }
      } catch (_) {}
    }

    return TextButton(
      onPressed: () {
        final type = v.lyric!.type;
        if (type == LyricFormat.lrc) {
          audioController.currentLyrics.value = ParsedLyricModel(
            parsedLrc: parseLrc(
              lyricData: v.lyric!.lrc,
              lyricDataTs: v.lyric!.translate,
            ),
            type: type,
          );
        } else if (type == LyricFormat.yrc ||
            type == LyricFormat.qrc ||
            type == LyricFormat.krc) {
          audioController.currentLyrics.value = ParsedLyricModel(
            parsedLrc: parseKaraOkLyric(
              lyricData: v.lyric!.verbatimLrc,
              lyricDataTs: v.lyric!.translate,
              type: type,
            ),
            type: type,
          );
        }

        if (settingController.autoDownloadLrc.value) {
          saveLyrics(path: audioController.currentPath.value, lrcData: v.lyric);
        }

        Navigator.pop(context);
      },
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      child: FractionallySizedBox(
        widthFactor: 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Column(
              children: [
                Text(
                  verbatimLrc != null && verbatimLrc.isNotEmpty ? '逐字' : 'Lrc',
                  style: textStyle,
                ),
                Text(
                  ts != null && ts.isNotEmpty ? '有翻译' : '无翻译',
                  style: textStyle,
                ),
              ],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                  Text(
                    artist,
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: FractionallySizedBox(
                      widthFactor: 0.8,
                      child: SingleChildScrollView(
                        child: Text(
                          "歌词: \n${ts ?? verbatimLrc ?? ''}",
                          softWrap: true,
                          overflow: TextOverflow.fade,
                          style: textStyle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 网络歌词弹窗 ---
class _NetLrcDialog extends StatefulWidget {
  final Color? color;
  const _NetLrcDialog({required this.color});

  @override
  State<_NetLrcDialog> createState() => _NetLrcDialogState();
}

class _NetLrcDialogState extends State<_NetLrcDialog> {
  final _LrcSearchController lrcSearchController = Get.put(
    _LrcSearchController(),
  );
  final TextEditingController textEditingController = TextEditingController();

  late final AudioController _audioController = Get.find<AudioController>();
  late final SettingController _settingController =
      Get.find<SettingController>();

  @override
  void dispose() {
    textEditingController.dispose();
    Get.delete<_LrcSearchController>();
    super.dispose();
  }

  void _showLrcDialog() {
    lrcSearchController.searchText.value =
        "${_audioController.currentMetadata.value.title} - ${_audioController.currentMetadata.value.artist}";
    textEditingController.text = lrcSearchController.searchText.value;
    lrcSearchController.search();
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("选择歌词"),
          titleTextStyle: generalTextStyle(
            ctx: context,
            size: 'xl',
            weight: FontWeight.w600,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          actionsAlignment: MainAxisAlignment.end,
          content: _buildDialogContent(),
        );
      },
    );
  }

  Widget _buildDialogContent() {
    final textStyle = generalTextStyle(ctx: context, size: 'md');
    final bgColor = Theme.of(
      context,
    ).colorScheme.secondaryContainer.withValues(alpha: 0.4);

    return SizedBox(
      width: context.width * 0.65,
      height: context.height * 0.65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextField(
                  autofocus: true,
                  controller: textEditingController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '搜索歌词',
                  ),
                  onChanged:
                      (text) => lrcSearchController.searchText.value = text,
                ),
              ),
              GenIconBtn(
                tooltip: '上一页',
                icon: PhosphorIconsLight.caretLeft,
                size: _ctrlBtnMinSize * 1.5,
                color: widget.color,
                backgroundColor: bgColor,
                fn: () {
                  if (lrcSearchController.currentNetLrcOffest.value > 0) {
                    lrcSearchController.currentNetLrcOffest.value--;
                  }
                },
              ),
              GenIconBtn(
                tooltip: '下一页',
                icon: PhosphorIconsLight.caretRight,
                size: _ctrlBtnMinSize * 1.5,
                color: widget.color,
                backgroundColor: bgColor,
                fn: () => lrcSearchController.currentNetLrcOffest.value++,
              ),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              for (final key in SettingController.apiMap.keys) ...[
                Obx(
                  () => TextButton(
                    onPressed: () async {
                      _settingController.apiIndex.value = key;
                      await lrcSearchController.search();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor:
                          _settingController.apiIndex.value == key
                              ? Theme.of(context).colorScheme.primary
                              : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      SettingController.apiMap[key] ?? 'QQ音乐',
                      style:
                          _settingController.apiIndex.value == key
                              ? textStyle.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                              )
                              : textStyle,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Expanded(
            child: Obx(() {
              if (lrcSearchController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (lrcSearchController.currentNetLrc.isEmpty) {
                return const Center(child: Text("网络错误或没有找到歌词"));
              }
              return ListView.builder(
                itemCount: lrcSearchController.currentNetLrc.length,
                itemBuilder: (context, index) {
                  return _SearchResultItem(
                    lyricInfo: lrcSearchController.currentNetLrc[index]!,
                    textStyle: textStyle,
                    audioController: _audioController,
                    settingController: _settingController,
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GenIconBtn(
      tooltip: '网络歌词',
      icon: PhosphorIconsLight.article,
      size: _ctrlBtnMinSize,
      color: widget.color,
      fn: _showLrcDialog,
    );
  }
}

// --- 主视图 ---
class LrcView extends StatelessWidget {
  const LrcView({super.key});

  ThemeService get _themeService => Get.find<ThemeService>();
  DesktopLyricsSever get _desktopLyricsSever => Get.find<DesktopLyricsSever>();
  AudioController get _audioController => Get.find<AudioController>();
  SettingController get _settingController => Get.find<SettingController>();

  Widget _buildScrollText(String text, TextStyle textStyle) {
    return TextScroll(
      text,
      mode: TextScrollMode.bouncing,
      fadeBorderSide: FadeBorderSide.both,
      fadedBorder: true,
      fadedBorderWidth: 0.05,
      velocity: Velocity(pixelsPerSecond: Offset(50, 0)),
      delayBefore: Duration(milliseconds: 500),
      pauseBetween: Duration(milliseconds: 1000),
      style: textStyle,
      textAlign: TextAlign.left,
    );
  }

  Widget _buildCoverSide(
    BuildContext ctx,
    double coverSize,
    TextStyle titleStyle,
    TextStyle subTitleStyle,
  ) {
    return SizedBox(
      width: ctx.width / 2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'playingCover',
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: _borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: _borderRadius,
                child: GestureDetector(
                  onTap:
                      () =>
                          _coverViewMode.value = (_coverViewMode.value + 1) % 3,
                  child: Obx(() {
                    final mode = _coverViewMode.value;
                    final tip =
                        mode == 0
                            ? '切换居中模式'
                            : mode == 1
                            ? '展开详情'
                            : '切换歌词模式';
                    final cover = _audioController.currentCover.value;
                    return AnimatedSwitcher(
                      duration: 300.ms,
                      transitionBuilder:
                          (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                      child: Tooltip(
                        message: tip,
                        mouseCursor: SystemMouseCursors.click,
                        verticalOffset: -coverSize / 2 - 32,
                        child: Image.memory(
                          cover,
                          key: ValueKey(cover),
                          cacheWidth: _coverRenderSize,
                          cacheHeight: _coverRenderSize,
                          height: coverSize,
                          width: coverSize,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          Container(
            width: coverSize - 24,
            margin: const EdgeInsets.only(top: 24),
            child: MouseRegion(
              onEnter: (_) => _isHeadHover.value = true,
              onExit: (_) => _isHeadHover.value = false,
              child: Obx(() {
                final title = _audioController.currentMetadata.value.title;
                final artistAndAlbum =
                    "${_audioController.currentMetadata.value.artist} - ${_audioController.currentMetadata.value.album}";
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    _isHeadHover.value
                        ? _buildScrollText(title, titleStyle)
                        : Text(
                          title,
                          style: titleStyle,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          maxLines: 1,
                          textAlign: TextAlign.left,
                        ),
                    _isHeadHover.value
                        ? _buildScrollText(artistAndAlbum, subTitleStyle)
                        : Text(
                          artistAndAlbum,
                          style: subTitleStyle,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          maxLines: 1,
                          textAlign: TextAlign.left,
                        ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsSide(BuildContext ctx) {
    return RepaintBoundary(
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.2, 0.8, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: SizedBox(
          width: ctx.width / 2,
          child: const Padding(
            padding: EdgeInsets.only(right: 16),
            child: LyricsRender(),
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar(
    BuildContext context,
    Color? mixColor,
    Color activeTrackCover,
    Color inactiveTrackCover,
    TextStyle timeCurrentStyle,
    TextStyle timeTotalStyle,
  ) {
    final audioCtrlWidget = AudioCtrlWidget(
      context: context,
      size: _ctrlBtnMinSize,
      color: mixColor,
    );
    final titleStyle = generalTextStyle(ctx: context, size: 'md');
    final highLightTitleStyle = generalTextStyle(
      ctx: context,
      size: 'md',
      color: Theme.of(context).colorScheme.primary,
    );
    final subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);
    final highLightSubStyle = generalTextStyle(
      ctx: context,
      size: 'sm',
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
    );
    final double itemHeight = 64;
    final playQueueController = MenuController();
    final playQueueScrollController = ScrollController();
    return SizedBox(
      height: _audioCtrlBarHeight,
      child: Column(
        children: [
          RepaintBoundary(
            child: Material(
              color: Colors.transparent,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackShape: _GradientSliderTrackShape(
                    activeTrackHeight: 2,
                    inactiveTrackHeight: 1,
                    activeColor: activeTrackCover,
                  ),
                  inactiveTrackColor: inactiveTrackCover,
                  showValueIndicator: ShowValueIndicator.always,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: _thumbRadius,
                    elevation: 0,
                    pressedElevation: 0,
                  ),
                  padding: EdgeInsets.zero,
                  thumbColor: Colors.transparent,
                  overlayColor: Colors.transparent,
                  valueIndicatorShape: const RectangularValueIndicatorShape(
                    width: 48,
                    height: 28,
                    radius: 4,
                  ),
                  valueIndicatorTextStyle: generalTextStyle(
                    ctx: context,
                    size: 'sm',
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  mouseCursor: WidgetStateProperty.all(
                    SystemMouseCursors.click,
                  ),
                ),
                child: audioCtrlWidget.seekSlide,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: _thumbRadius,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: context.width * 0.25,
                    height: _audioCtrlBarHeight - 24, // 固定高度避免重新layout
                    child: RepaintBoundary(
                      child: Obx(
                        () => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatTime(
                                totalSeconds: _audioController.currentSec.value,
                              ),
                              style: timeCurrentStyle,
                            ),
                            Text(
                              formatTime(
                                totalSeconds:
                                    _audioController.currentDuration.value,
                              ),
                              style: timeTotalStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Obx(
                      () => AnimatedOpacity(
                        opacity: _isBarHover.value ? 1.0 : 0.0,
                        duration: 150.ms,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 16,
                          children: [
                            audioCtrlWidget.speedSet,
                            audioCtrlWidget.volumeSet,
                            audioCtrlWidget.skipBack,
                            audioCtrlWidget.toggle,
                            audioCtrlWidget.skipForward,
                            audioCtrlWidget.changeMode,
                            audioCtrlWidget.equalizerSet,
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: context.width * 0.25,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      spacing: 8,
                      children: [
                        Obx(
                          () => GenIconBtn(
                            tooltip:
                                SettingController
                                    .lrcAlignmentMap[_settingController
                                    .lrcAlignment
                                    .value] ??
                                '',
                            icon:
                                _lrcAlignmentIcons[_settingController
                                    .lrcAlignment
                                    .value],
                            size: _ctrlBtnMinSize,
                            color: mixColor,
                            fn: () => _audioController.changeLrcAlignment(),
                          ),
                        ),
                        _NetLrcDialog(color: mixColor),
                        MenuAnchor(
                          consumeOutsideTap: true,
                          menuChildren: [
                            Container(
                              height: Get.height - 200,
                              width: Get.width / 2,
                              color: Colors.transparent,
                              padding: EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 8.0,
                                children: [
                                  Text(
                                    "播放队列",
                                    style: generalTextStyle(
                                      ctx: context,
                                      size: 'xl',
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Obx(() {
                                      return ListView.builder(
                                        itemCount:
                                            _audioController
                                                .playListCacheItems
                                                .length,
                                        itemExtent: itemHeight,
                                        cacheExtent: itemHeight * 1,
                                        controller: playQueueScrollController,
                                        padding: EdgeInsets.only(
                                          bottom: itemHeight * 2,
                                        ),
                                        itemBuilder: (context, index) {
                                          final items =
                                              _audioController
                                                  .playListCacheItems[index];
                                          return TextButton(
                                            onPressed: () async {
                                              await _audioController.audioPlay(
                                                metadata: items,
                                              );
                                            }.throttle(ms: 300),
                                            style: TextButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius: _borderRadius,
                                              ),
                                            ),
                                            child: SizedBox.expand(
                                              child: Obx(() {
                                                final subTextStyle =
                                                    _audioController
                                                                .currentPath
                                                                .value !=
                                                            items.path
                                                        ? subStyle
                                                        : highLightSubStyle;

                                                final textStyle =
                                                    _audioController
                                                                .currentPath
                                                                .value !=
                                                            items.path
                                                        ? titleStyle
                                                        : highLightTitleStyle;
                                                return Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      items.title,
                                                      style: textStyle,
                                                      softWrap: true,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                    Text(
                                                      "${items.artist} - ${items.album}",
                                                      style: subTextStyle,
                                                      softWrap: true,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ],
                                                );
                                              }),
                                            ),
                                          );
                                        },
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onOpen: () {
                            SchedulerBinding.instance.addPostFrameCallback((_) {
                              playQueueScrollController.jumpTo(
                                (itemHeight *
                                        _audioController.currentIndex.value)
                                    .clamp(
                                      0.0,
                                      playQueueScrollController
                                          .position
                                          .maxScrollExtent,
                                    ),
                              );
                            });
                          },
                          style: MenuStyle(
                            backgroundColor: WidgetStatePropertyAll(
                              Theme.of(context).colorScheme.surfaceContainer
                                  .withValues(alpha: 0.8),
                            ),
                          ),

                          controller: playQueueController,

                          child: GenIconBtn(
                            tooltip: '播放列表',
                            icon: PhosphorIconsLight.queue,
                            size: _ctrlBtnMinSize,
                            color: mixColor,
                            fn: () {
                              if (playQueueController.isOpen) {
                                playQueueController.close();
                              } else {
                                playQueueController.open();
                              }
                            },
                          ),
                        ),
                        Obx(
                          () => GenIconBtn(
                            tooltip: '频谱图',
                            icon:
                                _settingController.showSpectrogram.value
                                    ? PhosphorIconsFill.waveTriangle
                                    : PhosphorIconsLight.waveTriangle,
                            size: _ctrlBtnMinSize,
                            color: mixColor,
                            fn: () {
                              _settingController.showSpectrogram.toggle();
                              _settingController.putScalableCache();
                            },
                          ),
                        ),
                        Obx(
                          () => GenIconBtn(
                            tooltip: '桌面歌词',
                            icon:
                                _settingController.showDesktopLyrics.value
                                    ? PhosphorIconsFill.creditCard
                                    : PhosphorIconsLight.creditCard,
                            size: _ctrlBtnMinSize,
                            color: mixColor,
                            fn:
                                () async {
                                  _settingController.showDesktopLyrics.toggle();
                                  await _settingController.putScalableCache();

                                  if (_settingController
                                      .showDesktopLyrics
                                      .value) {
                                    _desktopLyricsSever.connect();
                                  } else {
                                    _desktopLyricsSever.close();
                                  }
                                }.throttle(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _createMenuBtn({
    required String text,
    IconData? icon,
    required void Function() fn,
  }) {
    return CustomBtn(
      fn: fn,
      btnHeight: _menuBtnHeight,
      btnWidth: _menuBtnWidth,
      radius: _menuBtnRadius,
      icon: icon,
      label: text,
      contentColor: _themeService.darkTheme.colorScheme.onSecondaryContainer,
      mainAxisAlignment: MainAxisAlignment.start,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      Get.back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    double coverSize = (context.width * 0.3).clamp(300, 500);
    final halfWidth = context.width / 2;
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
        (context.width * _spectrogramWidthFactor) / spectrogramBarLength;
    final spectrogramPaddingWidth = context.width * _spectrogramWidthFactorDiff;

    final menuController = MenuController();

    Widget createInfoBar({required String text}) {
      return Container(
        height: 36,
        color: darkColorScheme.surface.withValues(alpha: 0.3),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsetsGeometry.symmetric(horizontal: 16),
            child: Text(text, style: subTitleStyle),
          ),
        ),
      );
    }

    final settingController = _settingController;

    List<Widget> playListBuilder(MusicCache metadata) {
      return _audioController.allUserKey.map((v) {
        return MenuItemButton(
          onPressed: () {
            _audioController.addToAudioList(metadata: metadata, userKey: v);
          },
          child: Center(child: Text(v.split(TagSuffix.playList)[0])),
        );
      }).toList();
    }

    final menuItem = [
      Obx(
        () => createInfoBar(text: "字号 ${settingController.lrcFontSize.value}"),
      ),
      _createMenuBtn(
        text: "字号+",
        fn: () {
          if (settingController.lrcFontSize.value <
              SettingController.lrcFontSizeMax) {
            settingController.lrcFontSize.value++;
            settingController.putCache(isSaveFolders: false);
          }
        },
      ),
      _createMenuBtn(
        text: "字号-",
        fn: () {
          if (settingController.lrcFontSize.value >
              SettingController.lrcFontSizeMin) {
            settingController.lrcFontSize.value--;
            settingController.putCache(isSaveFolders: false);
          }
        },
      ),
      Obx(
        () => createInfoBar(
          text: "字重 ${settingController.lrcFontWeight.value * 100 + 100}",
        ),
      ),
      _createMenuBtn(
        text: "字重+",
        fn: () {
          if (settingController.lrcFontWeight.value <
              SettingController.lrcFontWeightMax) {
            settingController.lrcFontWeight.value++;
            settingController.putCache(isSaveFolders: false);
          }
        },
      ),
      _createMenuBtn(
        text: "字重-",
        fn: () {
          if (settingController.lrcFontWeight.value >
              SettingController.lrcFontWeightMin) {
            settingController.lrcFontWeight.value--;
            settingController.putCache(isSaveFolders: false);
          }
        },
      ),
      SubmenuButton(
        submenuIcon: WidgetStatePropertyAll(const SizedBox.shrink()),
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        menuStyle: MenuStyle(
          alignment: Alignment.topRight,
          backgroundColor: WidgetStatePropertyAll(
            darkColorScheme.surfaceContainer.withValues(alpha: 0.6),
          ),
        ),
        menuChildren: playListBuilder(_audioController.currentMetadata.value),
        child: Text(
          '添加到歌单',
          style: generalTextStyle(
            size: 'md',
            color: _themeService.darkTheme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    ];

    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: BlurWithCoverBackground(
        cover: _audioController.currentCover,
        useGradient: false,
        sigma: 256,
        useMask: true,
        radius: 0,
        meshEnable: true,
        onlyDarkMode: true,
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
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTapDown:
                            (_) =>
                                menuController.isOpen
                                    ? menuController.close()
                                    : null,
                        onSecondaryTapDown:
                            (details) => menuController.open(
                              position: details.localPosition,
                            ),
                        child: MenuAnchor(
                          consumeOutsideTap: true,
                          controller: menuController,
                          style: MenuStyle(
                            backgroundColor: WidgetStatePropertyAll(
                              darkColorScheme.surfaceContainer.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                          menuChildren: menuItem,
                          child: Stack(
                            children: [
                              // --- 歌词侧 ---
                              Obx(
                                () => AnimatedPositioned(
                                  duration: 300.ms,
                                  curve: Curves.fastOutSlowIn,
                                  right:
                                      _coverViewMode.value == 0
                                          ? 0
                                          : (-halfWidth),
                                  width: halfWidth, // 水平约束
                                  top: 0, // 垂直约束
                                  bottom: 0, // 垂直约束
                                  child: AnimatedOpacity(
                                    opacity:
                                        _coverViewMode.value == 0 ? 1.0 : 0.0,
                                    duration: 100.ms,
                                    child: _buildLyricsSide(context),
                                  ),
                                ),
                              ),
                              // --- 封面侧 ---
                              Obx(
                                () => AnimatedPositioned(
                                  duration: 300.ms,
                                  curve: Curves.fastOutSlowIn,
                                  left:
                                      _coverViewMode.value == 0
                                          ? (halfWidth - coverSize) / 2
                                          : _coverViewMode.value == 1
                                          ? (context.width - coverSize) / 2
                                          : halfWidth +
                                              (halfWidth - coverSize) / 2,
                                  width: coverSize, // 水平约束 (使用封面自身的尺寸)
                                  top: 0, // 垂直约束
                                  bottom: 0, // 垂直约束
                                  child: _buildCoverSide(
                                    context,
                                    coverSize,
                                    titleStyle,
                                    subTitleStyle,
                                  ),
                                ),
                              ),
                              // --- 详情侧 ---
                              Obx(() {
                                final textStyle_ = titleStyle.copyWith(
                                  fontWeight: FontWeight.w100,
                                  fontSize: titleStyle.fontSize! - 3,
                                );
                                final metadata =
                                    _audioController.currentMetadata.value;
                                return AnimatedPositioned(
                                  duration: 300.ms,
                                  curve: Curves.fastOutSlowIn,
                                  left:
                                      _coverViewMode.value == 2
                                          ? (halfWidth - 100) / 4
                                          : (-halfWidth),
                                  width: halfWidth - 100, // 水平约束
                                  top: 0, // 垂直约束
                                  bottom: 0, // 垂直约束
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 10,
                                    children: [
                                      Text(
                                        "标题：${metadata.title}",
                                        style: textStyle_,
                                      ),
                                      Text(
                                        "艺术家：${metadata.artist}",
                                        style: textStyle_,
                                      ),
                                      Text(
                                        "专辑：${metadata.album}",
                                        style: textStyle_,
                                      ),
                                      Text(
                                        "流派：${metadata.genre}",
                                        style: textStyle_,
                                      ),
                                      Text(
                                        "时长：${formatTime(totalSeconds: metadata.duration)}",
                                        style: textStyle_,
                                      ),
                                      Text(
                                        "比特率：${metadata.bitrate ?? "UNKNOWN"}kbps",
                                        style: textStyle_,
                                      ),
                                      Text(
                                        "采样率：${metadata.sampleRate ?? "UNKNOWN"}hz",
                                        style: textStyle_,
                                      ),
                                      Text(
                                        "音轨号：${metadata.trackNumber}",
                                        style: textStyle_,
                                      ),
                                      Text(
                                        "位深度：${metadata.bitDepth}",
                                        style: textStyle_,
                                      ),
                                      Text(
                                        "通道数：${metadata.channels}",
                                        style: textStyle_,
                                      ),
                                      Text(
                                        "路径：${metadata.path}",
                                        style: textStyle_,
                                        maxLines: 5,
                                      ),
                                    ],
                                  ),
                                );
                              }),

                              // --- 频谱图 ---
                              Positioned(
                                left: 0,
                                bottom: 0,
                                child: Obx(() {
                                  if (!settingController
                                      .showSpectrogram
                                      .value) {
                                    return const SizedBox.shrink();
                                  }
                                  return _SpectrogramWidget(
                                    key: ValueKey(
                                      _settingController.showSpectrogram.value,
                                    ),
                                    gradient: spectrogramBarGradient,
                                    lenth: spectrogramBarLength,
                                    barWidth: spectrogramBarWidth,
                                    paddingWidth: spectrogramPaddingWidth,
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    MouseRegion(
                      onEnter: (_) => _isBarHover.value = true,
                      onExit: (_) => _isBarHover.value = false,
                      child: _buildControlBar(
                        context,
                        mixColor,
                        activeTrackCover,
                        inactiveTrackCover,
                        timeCurrentStyle,
                        timeTotalStyle,
                      ),
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

class _SpectrogramWidget extends StatefulWidget {
  final LinearGradient gradient;
  final double lenth;
  final double barWidth;
  final double paddingWidth;
  const _SpectrogramWidget({
    super.key,
    required this.gradient,
    required this.lenth,
    required this.barWidth,
    required this.paddingWidth,
  });

  @override
  State<_SpectrogramWidget> createState() => _SpectrogramWidgetState();
}

class _SpectrogramWidgetState extends State<_SpectrogramWidget>
    with SingleTickerProviderStateMixin {
  final AudioController _audioController = Get.find<AudioController>();

  // 颜色缓存，颜色变化的时候更新painter
  Color? _cachedColor;

  // 驱动补间插值动画
  late AnimationController _animController;

  /// 插值起点：动画开始时各柱子的高度
  List<double> _currentFFT = [];

  /// 插值终点：最新一帧从后端拉取的 FFT 数据
  List<double> _targetFFT = [];

  /// 当前实际渲染的值：_currentFFT 到 _targetFFT 之间插值的结果
  List<double> _displayFFT = [];

  /// 缓存的 Shader，尺寸不变时复用，避免每帧重建
  Shader? _cachedShader;
  Size _lastSize = Size.zero;

  Worker? _fftWorker;

  /// 防止 dispose 后异步回调仍然执行的保护标志
  bool _isDisposed = false;

  /// 定时从后端拉取 FFT 数据
  /// 不用 Ticker（每帧触发）是因为音频数据不需要和屏幕刷新率同步
  /// 视觉流畅度由 _animController 的插值保证，而非拉取频率
  Timer? _fetchTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _animController.addListener(_onAnimationTick);

    // 监听 audioFFT 变化，后端数据更新时触发 _onFFTUpdated
    _fftWorker = ever(_audioController.audioFFT, _onFFTUpdated);

    // 每50ms更新一次数据就已经足够，更新间隔为过渡时间(100ms)的一半
    _fetchTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _audioController.getAudioFFt();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    // 先取消监听，再 dispose controller
    // 顺序重要：防止 cancel 期间还有回调触发
    _fftWorker?.dispose();
    _fetchTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// 收到新 FFT 数据时，记录插值起点和终点，启动补间动画
  void _onFFTUpdated(List<double> newFFT) {
    if (_isDisposed || !mounted) return;

    // 以当前渲染值作为起点，避免动画跳变
    // 首帧 _displayFFT 为空时直接用新数据初始化
    _currentFFT = List<double>.from(_displayFFT.isEmpty ? newFFT : _displayFFT);
    _targetFFT = newFFT;

    // 每次数据更新都重新平滑过渡
    _animController.forward(from: 0);
  }

  /// AnimationController 每个动画帧回调，计算当前插值结果写入 _displayFFT
  void _onAnimationTick() {
    if (_isDisposed || !mounted || _targetFFT.isEmpty) return;
    final t = _animController.value; // 当前动画进度 0.0 ~ 1.0
    final len =
        _currentFFT.length <= _targetFFT.length
            ? _currentFFT.length
            : _targetFFT.length;

    // 长度变化时才重新分配，正常情况下复用同一个 List
    if (_displayFFT.length != len) {
      _displayFFT = List<double>.filled(len, 0.0);
    }

    // 线性插值
    for (int i = 0; i < len; i++) {
      _displayFFT[i] = _currentFFT[i] + (_targetFFT[i] - _currentFFT[i]) * t;
    }
  }

  /// 获取或创建 Shader，尺寸与颜色不变时直接返回缓存
  /// createShader 有一定开销，避免每帧调用
  Shader _getShader(Size size) {
    if (_cachedShader == null ||
        _cachedColor == null ||
        size != _lastSize ||
        widget.gradient.colors[0] != _cachedColor) {
      _lastSize = size;
      _cachedColor = widget.gradient.colors[0];
      _cachedShader = widget.gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    }
    return _cachedShader!;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animController,
        builder: (_, __) {
          if (_displayFFT.isEmpty) return const SizedBox.shrink();
          final size = Size(
            MediaQuery.of(context).size.width,
            _spectrogramHeight,
          );
          return CustomPaint(
            size: size,
            painter: _SpectrogramPainter(
              fft: _displayFFT,
              shader: _getShader(size),
              length: widget.lenth,
              barWidth: widget.barWidth,
              paddingWidth: widget.paddingWidth,
              // 用动画进度值作为 shouldRepaint 的判断依据
              version: _animController.value,
            ),
          );
        },
      ),
    );
  }
}

class _SpectrogramPainter extends CustomPainter {
  final List<double> fft;
  final Shader shader;
  final double length;
  final double barWidth;
  final double paddingWidth;
  final double version;

  _SpectrogramPainter({
    required this.fft,
    required this.shader,
    required this.length,
    required this.barWidth,
    required this.paddingWidth,
    required this.version,
  });

  /// 静态复用，避免每次 paint 创建新的 Paint 对象
  static final _paint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (fft.isEmpty) return;

    // Shader 在整个频谱图范围内统一设置一次
    // 所有柱子共享同一个 shader，而不是每根柱子单独 createShader
    _paint.shader = shader;

    final maxBars = length.toInt();
    final count = fft.length < maxBars ? fft.length : maxBars;

    for (int i = 0; i < count; i++) {
      final height = fft[i] * _spectrogramHeight;
      if (height < 0.5) continue;

      canvas.drawRect(
        Rect.fromLTWH(
          i * barWidth + paddingWidth,
          _spectrogramHeight - height,
          barWidth * 0.5,
          height,
        ),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpectrogramPainter old) {
    // version 是动画进度值，每帧都不同，判断是否需要重绘
    return old.version != version || old.shader != shader;
  }
}
