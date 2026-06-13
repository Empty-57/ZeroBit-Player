import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/components/audio_ctrl_btn.dart';
import 'package:zerobit_player/components/blur_background.dart';
import 'package:zerobit_player/components/lyrics_render.dart';
import 'package:zerobit_player/components/window_ctrl_bar.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/controller/user_playlist_ctrl.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:zerobit_player/custom_widgets/rect_value_indicator.dart';
import 'package:zerobit_player/custom_widgets/scroll_text.dart';
import 'package:zerobit_player/desktop_lyrics_sever.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/theme_manager.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/func_extension.dart';
import 'package:zerobit_player/tools/func/general_style.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';
import 'package:zerobit_player/tools/lrcTool/parse_lyrics.dart';
import 'package:zerobit_player/tools/lrcTool/save_lyric.dart';

const double _ctrlBtnMinSize = 40.0;
const double _thumbRadius = 10.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));
const double _audioCtrlBarHeight = 96;
const double _spectrogramHeight = 100.0;
const double _spectrogramWidthFactor = 0.94;
const double _spectrogramWidthFactorDiff = (1 - _spectrogramWidthFactor) / 2;
const _lrcAlignmentIcons = [
  PhosphorIconsLight.textAlignLeft,
  PhosphorIconsLight.textAlignCenter,
  PhosphorIconsLight.textAlignRight,
];
final _isBarHover = false.obs;
// 0: 默认（封面+歌词）, 1: 封面完全居中, 2: 封面+详情
final _coverViewMode = 0.obs;
const double _menuBtnWidth = 180;
const double _menuBtnHeight = 48;
const double _menuBtnRadius = 0;

final double _dpr = PlatformDispatcher.instance.views.first.devicePixelRatio;

// --- 歌词搜索控制器 ---
class _LrcSearchController {
  final AudioController _audioController = Get.find<AudioController>();
  final currentNetLrc = <SearchLrcModel?>[].obs;
  final currentNetLrcOffest = 0.obs;
  final searchText = "".obs;
  final isLoading = false.obs;

  late final Worker _debounceWorker;
  late final Worker _everWorker;

  void init() {
    searchText.value =
        "${_audioController.currentMetadata.value.title} - ${_audioController.currentMetadata.value.artist}";

    _debounceWorker = debounce(searchText, (_) async {
      currentNetLrcOffest.value = 0;
      await search();
    }, time: const Duration(milliseconds: 500));

    _everWorker = ever(currentNetLrcOffest, (_) async {
      await search();
    });
  }

  void close() {
    _debounceWorker.dispose();
    _everWorker.dispose();
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
    final Paint inactivePaint = Paint()
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
    final Paint activePaint = Paint()
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
        audioController.loadLyrics('', changed: true);
        audioController.update([GetBuilderId.lyricRender]);

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
  late final _LrcSearchController _lrcSearchController;
  final TextEditingController _textEditingController = TextEditingController();

  late final AudioController _audioController = Get.find<AudioController>();
  late final SettingController _settingController =
      Get.find<SettingController>();

  @override
  void initState() {
    super.initState();
    _lrcSearchController = _LrcSearchController()..init();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _lrcSearchController.close();
    super.dispose();
  }

  void _showLrcDialog() {
    _lrcSearchController.searchText.value =
        "${_audioController.currentMetadata.value.title} - ${_audioController.currentMetadata.value.artist}";
    _textEditingController.text = _lrcSearchController.searchText.value;
    _lrcSearchController.search();
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
                  controller: _textEditingController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '搜索歌词',
                  ),
                  onChanged: (text) =>
                      _lrcSearchController.searchText.value = text,
                ),
              ),
              GenIconBtn(
                tooltip: '上一页',
                icon: PhosphorIconsLight.caretLeft,
                size: _ctrlBtnMinSize * 1.5,
                color: widget.color,
                backgroundColor: bgColor,
                fn: () {
                  if (_lrcSearchController.currentNetLrcOffest.value > 0) {
                    _lrcSearchController.currentNetLrcOffest.value--;
                  }
                },
              ),
              GenIconBtn(
                tooltip: '下一页',
                icon: PhosphorIconsLight.caretRight,
                size: _ctrlBtnMinSize * 1.5,
                color: widget.color,
                backgroundColor: bgColor,
                fn: () => _lrcSearchController.currentNetLrcOffest.value++,
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
                      await _lrcSearchController.search();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: _settingController.apiIndex.value == key
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      SettingController.apiMap[key] ?? 'QQ音乐',
                      style: _settingController.apiIndex.value == key
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
              if (_lrcSearchController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_lrcSearchController.currentNetLrc.isEmpty) {
                return const Center(child: Text("网络错误或没有找到歌词"));
              }
              return ListView.builder(
                itemCount: _lrcSearchController.currentNetLrc.length,
                itemBuilder: (context, index) {
                  return _SearchResultItem(
                    lyricInfo: _lrcSearchController.currentNetLrc[index]!,
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

class _LyricsSide extends StatelessWidget {
  const _LyricsSide();

  @override
  Widget build(BuildContext context) {
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
          width: context.width / 2,
          child: const Padding(
            padding: EdgeInsets.only(right: 16),
            child: LyricsRender(),
          ),
        ),
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

class _CoverSide extends StatelessWidget {
  final double coverSize;
  final TextStyle titleStyle;
  final TextStyle subTitleStyle;

  const _CoverSide({
    required this.coverSize,
    required this.titleStyle,
    required this.subTitleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final isHeadHover = false.obs;
    final AudioController audioController = Get.find<AudioController>();
    final cacheResolution = (coverSize * _dpr).round();
    final titleStrut = StrutStyle(
      fontSize: titleStyle.fontSize,
      forceStrutHeight: true,
    );
    final subTitleStrut = StrutStyle(
      fontSize: subTitleStyle.fontSize,
      forceStrutHeight: true,
    );

    return SizedBox(
      width: context.width / 2,
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
                  onTap: () =>
                      _coverViewMode.value = (_coverViewMode.value + 1) % 3,
                  child: Obx(() {
                    final mode = _coverViewMode.value;
                    final tip = mode == 0
                        ? '切换居中模式'
                        : mode == 1
                        ? '展开详情'
                        : '切换歌词模式';
                    final cover = audioController.currentCover.value;
                    return Tooltip(
                      message: tip,
                      mouseCursor: SystemMouseCursors.click,
                      verticalOffset: -coverSize / 2 - 32,
                      child: AnimatedSwitcher(
                        duration: 300.ms,
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: Image.memory(
                          cover,
                          key: ValueKey(cover.hashCode),
                          cacheWidth: cacheResolution,
                          cacheHeight: cacheResolution,
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
              onEnter: (_) => isHeadHover.value = true,
              onExit: (_) => isHeadHover.value = false,
              child: Obx(() {
                final title = audioController.currentMetadata.value.title;
                final artistAndAlbum =
                    "${audioController.currentMetadata.value.artist} - ${audioController.currentMetadata.value.album}";
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    isHeadHover.value
                        ? _ScrollTextWidget(
                            text: title,
                            style: titleStyle,
                            strutStyle: titleStrut,
                          )
                        : Text(
                            title,
                            style: titleStyle,
                            softWrap: false,
                            strutStyle: titleStrut,
                            overflow: TextOverflow.fade,
                            maxLines: 1,
                            textAlign: TextAlign.left,
                          ),
                    isHeadHover.value
                        ? _ScrollTextWidget(
                            text: artistAndAlbum,
                            style: subTitleStyle,
                            strutStyle: subTitleStrut,
                          )
                        : Text(
                            artistAndAlbum,
                            style: subTitleStyle,
                            softWrap: false,
                            strutStyle: subTitleStrut,
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
}

class _PlayQueueItem extends StatelessWidget {
  final MusicCache item;
  final double itemHeight;
  final TextStyle titleStyle;
  final TextStyle highLightTitleStyle;
  final TextStyle subStyle;
  final TextStyle highLightSubStyle;

  const _PlayQueueItem({
    required this.item,
    required this.itemHeight,
    required this.titleStyle,
    required this.highLightTitleStyle,
    required this.subStyle,
    required this.highLightSubStyle,
  });

  @override
  Widget build(BuildContext context) {
    final AudioController audioController = Get.find<AudioController>();
    return TextButton(
      onPressed: () async {
        await audioController.audioPlay(metadata: item);
      }.throttle(ms: 300),
      style: TextButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
      ),
      child: SizedBox.expand(
        child: Obx(() {
          final isCurrent = audioController.currentPath.value == item.path;
          final currentTitleStyle = isCurrent
              ? highLightTitleStyle
              : titleStyle;
          final currentSubStyle = isCurrent ? highLightSubStyle : subStyle;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: currentTitleStyle,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                "${item.artist} - ${item.album}",
                style: currentSubStyle,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  final Color? mixColor;
  final Color activeTrackCover;
  final Color inactiveTrackCover;
  final TextStyle timeCurrentStyle;
  final TextStyle timeTotalStyle;
  final ScrollController playQueueScrollController;

  const _ControlBar({
    required this.mixColor,
    required this.activeTrackCover,
    required this.inactiveTrackCover,
    required this.timeCurrentStyle,
    required this.timeTotalStyle,
    required this.playQueueScrollController,
  });

  @override
  Widget build(BuildContext context) {
    final AudioController audioController = Get.find<AudioController>();
    final SettingController settingController = Get.find<SettingController>();
    final DesktopLyricsSever desktopLyricsSever =
        Get.find<DesktopLyricsSever>();

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

    const double itemHeight = 64;
    final playQueueController = MenuController();

    return MouseRegion(
      onEnter: (_) => _isBarHover.value = true,
      onExit: (_) => _isBarHover.value = false,
      child: SizedBox(
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
                    showValueIndicator: ShowValueIndicator.onDrag,
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
                      height: _audioCtrlBarHeight - 24,
                      child: RepaintBoundary(
                        child: Obx(
                          () => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatTime(
                                  totalSeconds:
                                      audioController.currentSec.value,
                                ),
                                style: timeCurrentStyle,
                              ),
                              Text(
                                formatTime(
                                  totalSeconds:
                                      audioController.currentDuration.value,
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
                                      .lrcAlignmentMap[settingController
                                      .lrcAlignment
                                      .value] ??
                                  '',
                              icon:
                                  _lrcAlignmentIcons[settingController
                                      .lrcAlignment
                                      .value],
                              size: _ctrlBtnMinSize,
                              color: mixColor,
                              fn: () => audioController.changeLrcAlignment(),
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
                                padding: const EdgeInsets.all(16),
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
                                        final itemsList =
                                            audioController.playListCacheItems;
                                        return ListView.builder(
                                          scrollCacheExtent:
                                              const ScrollCacheExtent.pixels(
                                                itemHeight * 1,
                                              ),
                                          itemCount: itemsList.length,
                                          itemExtent: itemHeight,
                                          controller: playQueueScrollController,
                                          padding: const EdgeInsets.only(
                                            bottom: itemHeight * 2,
                                          ),
                                          itemBuilder: (context, index) {
                                            return _PlayQueueItem(
                                              item: itemsList[index],
                                              itemHeight: itemHeight,
                                              titleStyle: titleStyle,
                                              highLightTitleStyle:
                                                  highLightTitleStyle,
                                              subStyle: subStyle,
                                              highLightSubStyle:
                                                  highLightSubStyle,
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
                              SchedulerBinding.instance.addPostFrameCallback((
                                _,
                              ) {
                                if (playQueueScrollController.hasClients) {
                                  playQueueScrollController.jumpTo(
                                    (itemHeight *
                                            audioController.currentIndex.value)
                                        .clamp(
                                          0.0,
                                          playQueueScrollController
                                              .position
                                              .maxScrollExtent,
                                        ),
                                  );
                                }
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
                              icon: settingController.showSpectrogram.value
                                  ? PhosphorIconsFill.waveTriangle
                                  : PhosphorIconsLight.waveTriangle,
                              size: _ctrlBtnMinSize,
                              color: mixColor,
                              fn: () {
                                settingController.showSpectrogram.toggle();
                                settingController.putScalableCache();
                              },
                            ),
                          ),
                          Obx(
                            () => GenIconBtn(
                              tooltip: '桌面歌词',
                              icon: settingController.showDesktopLyrics.value
                                  ? PhosphorIconsFill.creditCard
                                  : PhosphorIconsLight.creditCard,
                              size: _ctrlBtnMinSize,
                              color: mixColor,
                              fn: () async {
                                settingController.showDesktopLyrics.toggle();
                                await settingController.putScalableCache();

                                if (settingController.showDesktopLyrics.value) {
                                  desktopLyricsSever.connect();
                                } else {
                                  desktopLyricsSever.close();
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

  ThemeService get _themeService => ThemeService.instance;
  AudioController get _audioController => Get.find<AudioController>();
  SettingController get _settingController => Get.find<SettingController>();
  MusicCacheController get _musicCacheController =>
      Get.find<MusicCacheController>();
  UserPlayListController get _userPlayListController =>
      Get.find<UserPlayListController>();

  @override
  void initState() {
    super.initState();
    _playQueueScrollController = ScrollController();
    _menuController = MenuController();
  }

  @override
  void dispose() {
    _playQueueScrollController.dispose();
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
      btnHeight: _menuBtnHeight,
      btnWidth: _menuBtnWidth,
      radius: _menuBtnRadius,
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
  }) {
    return SubmenuButton(
      submenuIcon: const WidgetStatePropertyAll(SizedBox.shrink()),
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
    Rx<MusicCache> currentMetadata,
  ) {
    final Widget divider = Divider(
      color: darkColorScheme.primary.withValues(alpha: 0.8),
      height: 0.5,
      thickness: 0.5,
    );
    final settingController = _settingController;
    final musicCacheController = _musicCacheController;
    final audioController = _audioController;

    return [
      Obx(
        () => _createInfoBar(
          text: "字号 ${settingController.lrcFontSize.value}",
          darkColorScheme: darkColorScheme,
          addFn: () {
            if (settingController.lrcFontSize.value <
                SettingController.lrcFontSizeMax) {
              settingController.lrcFontSize.value++;
              audioController.update([GetBuilderId.lyricRender]);
              settingController.putCache(isSaveFolders: false);
            }
          },
          decFn: () {
            if (settingController.lrcFontSize.value >
                SettingController.lrcFontSizeMin) {
              settingController.lrcFontSize.value--;
              audioController.update([GetBuilderId.lyricRender]);
              settingController.putCache(isSaveFolders: false);
            }
          },
        ),
      ),
      Obx(
        () => _createInfoBar(
          text: "字重 ${settingController.lrcFontWeight.value * 100 + 100}",
          darkColorScheme: darkColorScheme,
          addFn: () {
            if (settingController.lrcFontWeight.value <
                SettingController.lrcFontWeightMax) {
              settingController.lrcFontWeight.value++;
              audioController.update([GetBuilderId.lyricRender]);
              settingController.putCache(isSaveFolders: false);
            }
          },
          decFn: () {
            if (settingController.lrcFontWeight.value >
                SettingController.lrcFontWeightMin) {
              settingController.lrcFontWeight.value--;
              audioController.update([GetBuilderId.lyricRender]);
              settingController.putCache(isSaveFolders: false);
            }
          },
        ),
      ),
      divider,
      Obx(() {
        final album = currentMetadata.value.album;
        final albumWithLetter =
            musicCacheController.getLetter(str: album) + album;
        return _createMenuBtn(
          fn: () {
            menuController.close();
            Get.back();
            SchedulerBinding.instance.addPostFrameCallback((_) {
              Get.toNamed(
                AppRoutes.details,
                arguments: {
                  'pathList':
                      musicCacheController.albumItemsDict[albumWithLetter],
                  'title': album,
                  'operateArea': OperateArea.albumDetails,
                },
                id: 1,
              );
            });
          },
          text: album,
          toolTip: '跳转到 "$album"',
        );
      }),
      Obx(() {
        final artistList = currentMetadata.value.artist.split('/');
        final artistFirst = artistList.first;
        final artistFirstWithLetter =
            musicCacheController.getLetter(str: artistFirst) + artistFirst;

        if (artistList.length == 1) {
          return _createMenuBtn(
            fn: () {
              menuController.close();
              Get.back();
              SchedulerBinding.instance.addPostFrameCallback((_) {
                Get.toNamed(
                  AppRoutes.details,
                  arguments: {
                    'pathList': musicCacheController
                        .artistItemsDict[artistFirstWithLetter],
                    'title': artistFirst,
                    'operateArea': OperateArea.artistDetails,
                  },
                  id: 1,
                );
              });
            },
            text: artistFirst,
            toolTip: '跳转到 "$artistFirst"',
          );
        }
        if (artistList.length > 1) {
          return _createdSubmenuBtn(
            text: '查看艺术家',
            darkColorScheme: darkColorScheme,
            menuChildren: artistList.map((v) {
              return MenuItemButton(
                onPressed: () {
                  menuController.close();
                  Get.back();
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    Get.toNamed(
                      AppRoutes.details,
                      arguments: {
                        'pathList':
                            musicCacheController
                                .artistItemsDict[musicCacheController.getLetter(
                                  str: v,
                                ) +
                                v],
                        'title': v,
                        'operateArea': OperateArea.artistDetails,
                      },
                      id: 1,
                    );
                  });
                },
                child: Center(child: Text(v)),
              );
            }).toList(),
          );
        }
        return const SizedBox.shrink();
      }),
      divider,
      _createdSubmenuBtn(
        text: '添加到歌单',
        darkColorScheme: darkColorScheme,
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
                          onTapDown: (_) => _menuController.isOpen
                              ? _menuController.close()
                              : null,
                          onSecondaryTapDown: (details) => _menuController.open(
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
                                // --- 歌词侧 ---
                                Obx(
                                  () => AnimatedPositioned(
                                    duration: 300.ms,
                                    curve: Curves.fastOutSlowIn,
                                    right: _coverViewMode.value == 0
                                        ? 0
                                        : (-halfWidth),
                                    width: halfWidth, // 水平约束
                                    top: 0, // 垂直约束
                                    bottom: 0, // 垂直约束
                                    child: AnimatedOpacity(
                                      opacity: _coverViewMode.value == 0
                                          ? 1.0
                                          : 0.0,
                                      duration: 100.ms,
                                      child: const _LyricsSide(),
                                    ),
                                  ),
                                ),
                                // --- 封面侧 ---
                                Obx(
                                  () => AnimatedPositioned(
                                    duration: 300.ms,
                                    curve: Curves.fastOutSlowIn,
                                    left: _coverViewMode.value == 0
                                        ? (halfWidth - coverSize) / 2
                                        : _coverViewMode.value == 1
                                        ? (context.width - coverSize) / 2
                                        : halfWidth +
                                              (halfWidth - coverSize) / 2,
                                    width: coverSize,
                                    top: 0,
                                    bottom: 0,
                                    child: _CoverSide(
                                      coverSize: coverSize,
                                      titleStyle: titleStyle,
                                      subTitleStyle: subTitleStyle,
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
                                    left: _coverViewMode.value == 2
                                        ? (halfWidth - 100) / 4
                                        : (-halfWidth),
                                    width: halfWidth - 100, // 水平约束
                                    top: 0, // 垂直约束
                                    bottom: 0, // 垂直约束
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                        _settingController
                                            .showSpectrogram
                                            .value,
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
                      _ControlBar(
                        mixColor: mixColor,
                        activeTrackCover: activeTrackCover,
                        inactiveTrackCover: inactiveTrackCover,
                        timeCurrentStyle: timeCurrentStyle,
                        timeTotalStyle: timeTotalStyle,
                        playQueueScrollController: _playQueueScrollController,
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
  late final AnimationController _animController;

  /// 缓存的 Shader，尺寸不变时复用，避免每帧重建
  List<double> _currentFFT = const [];

  /// 插值终点：最新一帧从后端拉取的 FFT 数据
  List<double> _targetFFT = const [];

  /// 当前实际渲染的值：_currentFFT 到 _targetFFT 之间插值的结果
  List<double> _displayFFT = const [];

  /// 缓存的 Shader，尺寸不变时复用，避免每帧重建
  Shader? _cachedShader;
  Size _lastSize = Size.zero;

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

    _audioController.audioFFT.addListener(_onFFTUpdated);

    _fetchTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _audioController.getAudioFFt();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    // 先取消监听，再 dispose controller
    // 顺序重要：防止 cancel 期间还有回调触发
    _audioController.audioFFT.removeListener(_onFFTUpdated);
    _fetchTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _onFFTUpdated() {
    if (_isDisposed || !mounted) return;
    final newFFT = _audioController.audioFFT.value;

    final int len = newFFT.length;

    if (_currentFFT.length != len) {
      _currentFFT = List<double>.filled(len, 0.0);
    }
    if (_targetFFT.length != len) {
      _targetFFT = List<double>.filled(len, 0.0);
    }

    if (_displayFFT.isEmpty || _displayFFT.length != len) {
      _displayFFT = List<double>.filled(len, 0.0);
      for (int i = 0; i < len; i++) {
        _currentFFT[i] = newFFT[i];
        _displayFFT[i] = newFFT[i];
        _targetFFT[i] = newFFT[i];
      }
    } else {
      for (int i = 0; i < len; i++) {
        _currentFFT[i] = _displayFFT[i];
        _targetFFT[i] = newFFT[i];
      }
    }

    _animController.forward(from: 0);
  }

  void _onAnimationTick() {
    if (_isDisposed || !mounted || _targetFFT.isEmpty) return;
    final double t = _animController.value;
    final int len = _currentFFT.length < _targetFFT.length
        ? _currentFFT.length
        : _targetFFT.length;

    if (_displayFFT.length != len) {
      _displayFFT = List<double>.filled(len, 0.0);
    }

    final double oneMinusT = 1.0 - t;
    for (int i = 0; i < len; i++) {
      _displayFFT[i] = _currentFFT[i] * oneMinusT + _targetFFT[i] * t;
    }
  }

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

  final Paint _paint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (fft.isEmpty) return;

    _paint.shader = shader;

    final int maxBars = length.toInt();
    final int count = fft.length < maxBars ? fft.length : maxBars;

    for (int i = 0; i < count; i++) {
      final double height = fft[i] * _spectrogramHeight;
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
    return old.version != version || old.shader != shader;
  }
}
