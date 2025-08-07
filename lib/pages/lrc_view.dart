import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/components/blur_background.dart';
import 'package:zerobit_player/components/lyrics_render.dart';
import 'package:zerobit_player/tools/general_style.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';
import 'package:zerobit_player/tools/lrcTool/save_lyric.dart';

import '../components/audio_ctrl_btn.dart';
import '../components/window_ctrl_bar.dart';
import '../getxController/audio_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../tools/format_time.dart';
import '../tools/lrcTool/parse_lyrics.dart';
import '../tools/rect_value_indicator.dart';

final AudioController _audioController = Get.find<AudioController>();
final SettingController _settingController = Get.find<SettingController>();

const double _ctrlBtnMinSize = 40.0;
const double _thumbRadius = 10.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));
const double _audioCtrlBarHeight = 96;
const int _coverRenderSize = 800;
const _lrcAlignmentIcons = [
  PhosphorIconsLight.textAlignLeft,
  PhosphorIconsLight.textAlignCenter,
  PhosphorIconsLight.textAlignRight,
];
final _isBarHover = false.obs;
final _onlyCover = false.obs;

// --- 歌词搜索控制器 ---
class _LrcSearchController extends GetxController {
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
  final SearchLrcModel? lyricInfo;
  final TextStyle textStyle;

  const _SearchResultItem({required this.lyricInfo, required this.textStyle});

  @override
  Widget build(BuildContext context) {
    final v = lyricInfo;
    if (v == null ||
        v.lyric == null ||
        (v.lyric!.lrc == null && v.lyric!.verbatimLrc == null)) {
      return const SizedBox.shrink();
    }

    final String? verbatimLrc = v.lyric!.verbatimLrc;
    final String? ts = v.lyric!.translate;
    final String title = v.title;
    final String artist = v.artist;

    return TextButton(
      onPressed: () {
        final type = v.lyric!.type;
        if (type == LyricFormat.lrc) {
          _audioController.currentLyrics.value = ParsedLyricModel(
            parsedLrc: parseLrc(
              lyricData: v.lyric!.lrc,
              lyricDataTs: v.lyric!.translate,
            ),
            type: type,
          );
        } else if (type == LyricFormat.yrc || type == LyricFormat.qrc) {
          _audioController.currentLyrics.value = ParsedLyricModel(
            parsedLrc: parseKaraOkLyric(
              v.lyric!.verbatimLrc,
              v.lyric!.translate,
              type: type,
            ),
            type: type,
          );
        }

        if(_settingController.autoDownloadLrc.value){
          saveLyrics(path: _audioController.currentPath.value, lrcData: v.lyric);
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
      width: context.width / 2,
      height: context.height / 2,
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
          Expanded(
            child: Obx(() {
              if (lrcSearchController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (lrcSearchController.currentNetLrc.isEmpty) {
                return const Center(child: Text("没有找到歌词"));
              }
              return ListView.builder(
                itemCount: lrcSearchController.currentNetLrc.length,
                itemBuilder: (context, index) {
                  return _SearchResultItem(
                    lyricInfo: lrcSearchController.currentNetLrc[index],
                    textStyle: textStyle,
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
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _onlyCover.value = !_onlyCover.value,
                    child: Obx(
                      () => AnimatedSwitcher(
                        duration: 300.ms,
                        transitionBuilder:
                            (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                        child: Image.memory(
                          _audioController.currentCover.value,
                          key: ValueKey(
                            _audioController.currentCover.value.hashCode,
                          ),
                          cacheWidth: _coverRenderSize,
                          cacheHeight: _coverRenderSize,
                          height: coverSize,
                          width: coverSize,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: coverSize - 24,
            margin: const EdgeInsets.only(top: 24),
            child: Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    _audioController.currentMetadata.value.title,
                    style: titleStyle,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    maxLines: 1,
                  ),
                  Text(
                    "${_audioController.currentMetadata.value.artist} - ${_audioController.currentMetadata.value.album}",
                    style: subTitleStyle,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsSide(BuildContext ctx) {
    return ShaderMask(
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
    return SizedBox(
      height: _audioCtrlBarHeight,
      child: Column(
        children: [
          Material(
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
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              child: audioCtrlWidget.seekSlide,
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
                    width: context.width * 0.2,
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
                                  _audioController
                                      .currentMetadata
                                      .value
                                      .duration,
                            ),
                            style: timeTotalStyle,
                          ),
                        ],
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
                            audioCtrlWidget.volumeSet,
                            audioCtrlWidget.skipBack,
                            audioCtrlWidget.toggle,
                            audioCtrlWidget.skipForward,
                            audioCtrlWidget.changeMode,
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: context.width * 0.2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      spacing: 16,
                      children: [
                        Obx(
                          () => GenIconBtn(
                            tooltip:
                                _settingController
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
                        GenIconBtn(
                          tooltip: '桌面歌词',
                          icon: PhosphorIconsLight.creditCard,
                          size: _ctrlBtnMinSize,
                          color: mixColor,
                          fn: () {},
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

  @override
  Widget build(BuildContext context) {
    double coverSize = (context.width * 0.3).clamp(300, 500);
    final halfWidth = context.width / 2;
    final themeModeValue = _settingController.themeMode.value;

    final mixColor = Color.lerp(
      Theme.of(context).colorScheme.primary,
      themeModeValue == 'dark' ? Colors.white : Colors.black,
      0.3,
    );
    final mixSubColor = Color.lerp(
      Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
      themeModeValue == 'dark' ? Colors.white : Colors.black,
      0.3,
    );

    final activeTrackCover = mixColor ?? Theme.of(context).colorScheme.primary;
    final inactiveTrackCover =
        mixColor?.withValues(alpha: 0.2) ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);

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
    );

    return BlurWithCoverBackground(
      cover: _audioController.currentCover,
      useGradient: false,
      sigma: 256,
      useMask: true,
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
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        // --- 歌词侧 ---
                        Obx(
                          () => AnimatedPositioned(
                            duration: 300.ms,
                            curve: Curves.fastOutSlowIn,
                            right: _onlyCover.value ? (-halfWidth) : 0,
                            width: halfWidth, // 水平约束
                            top: 0, // 垂直约束
                            bottom: 0, // 垂直约束
                            child: AnimatedOpacity(
                              opacity: _onlyCover.value ? 0.0 : 1.0,
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
                                _onlyCover.value
                                    ? (halfWidth - coverSize / 2)
                                    : (halfWidth - coverSize) / 2,
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
                      ],
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
    );
  }
}
