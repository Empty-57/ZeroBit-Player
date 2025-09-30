import 'package:flutter/foundation.dart';
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
import 'dart:async';

final AudioController _audioController = Get.find<AudioController>();
final SettingController _settingController = Get.find<SettingController>();

const double _ctrlBtnMinSize = 40.0;
const double _thumbRadius = 10.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));
const double _audioCtrlBarHeight = 96;
const int _coverRenderSize = 800;
const double _spectrogramHeight = 100.0;
const double _spectrogramWidthFactor = 0.94;
const double _spectrogramWidthFactorDiff = (1-_spectrogramWidthFactor)/2;
const _lrcAlignmentIcons = [
  PhosphorIconsLight.textAlignLeft,
  PhosphorIconsLight.textAlignCenter,
  PhosphorIconsLight.textAlignRight,
];
final _isBarHover = false.obs;
final _onlyCover = false.obs;

// --- 频谱图控制器 ---
class _SpectrogramController extends GetxController{
  Timer? _spectrogramAnimationTimer;

  @override
  void onClose() {
    _cancelSpectrogramAnimationTimer();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();
    if(_settingController.showSpectrogram.value){
      _startSpectrogramAnimationTimer();
    }
  }

  void _cancelSpectrogramAnimationTimer(){
    _spectrogramAnimationTimer?.cancel();
    _spectrogramAnimationTimer=null;
  }

  void _startSpectrogramAnimationTimer(){
    _cancelSpectrogramAnimationTimer();
    _spectrogramAnimationTimer=Timer.periodic(Duration(milliseconds: 16), (Timer timer) { // 约 60 fps
      _audioController.getAudioFFt();
    });
  }

  void toggleSpectrogramVisibility(){
    if(_settingController.showSpectrogram.value){
      _startSpectrogramAnimationTimer();
    }else{
      _cancelSpectrogramAnimationTimer();
    }
  }
}

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
              lyricData: v.lyric!.verbatimLrc,
              lyricDataTs: v.lyric!.translate,
              type: type,
            ),
            type: type,
          );
        }

        if (_settingController.autoDownloadLrc.value) {
          saveLyrics(
            path: _audioController.currentPath.value,
            lrcData: v.lyric,
          );
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
                          gaplessPlayback: true,
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
    final _SpectrogramController spectrogramController=Get.put(
      _SpectrogramController(),
  );
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
                                  _audioController.currentDuration.value,
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
                    width: context.width * 0.2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      spacing: 16,
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
                              _settingController.showSpectrogram.value =
                                  !_settingController.showSpectrogram.value;
                              _settingController.putScalableCache();
                              spectrogramController.toggleSpectrogramVisibility();
                            },
                          ),
                        ),

                        // GenIconBtn(
                        //   tooltip: '桌面歌词',
                        //   icon: PhosphorIconsLight.creditCard,
                        //   size: _ctrlBtnMinSize,
                        //   color: mixColor,
                        //   fn: () {},
                        // ),

                        //以上： 后续功能
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
    final spectrogramBarWidth = (context.width * _spectrogramWidthFactor) / spectrogramBarLength;
    final spectrogramPaddingWidth=context.width * _spectrogramWidthFactorDiff;

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
                        // --- 频谱图 ---
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: Obx(() {
                            final fftList = [..._audioController.audioFFT];
                            if (fftList.isEmpty ||
                                !_settingController.showSpectrogram.value) {
                              return const SizedBox.shrink();
                            }
                            return TweenAnimationBuilder<List<double>>(
                              tween: _FFTListTween(
                                begin: fftList,
                                end: fftList,
                              ),
                              duration: const Duration(milliseconds: 100),
                              builder: (_, value, _) {
                                return CustomPaint(
                                  willChange: true,
                                  size: Size(context.width, _spectrogramHeight),
                                  painter: SpectrogramPainter(
                                    fft: value,
                                    gradient: spectrogramBarGradient,
                                    length: spectrogramBarLength,
                                    barWidth: spectrogramBarWidth,
                                    paddingWidth: spectrogramPaddingWidth,
                                  ),
                                );
                              },
                            );
                          }),
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

/// 绘制频谱图
class SpectrogramPainter extends CustomPainter {
  final List<double> fft;
  final LinearGradient gradient;
  final double length;
  final double barWidth;
  final double paddingWidth;

  SpectrogramPainter({
    required this.fft,
    required this.gradient,
    required this.length,
    required this.barWidth,
    required this.paddingWidth,
  });

  final _paint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (fft.isEmpty) {
      return;
    }

    int n = 0;
    for (final data in fft) {
      if (n > length) {
        return;
      }

      final height = data * _spectrogramHeight;
      final rect = Rect.fromLTWH(
        n * barWidth + paddingWidth,
        _spectrogramHeight - height,
        barWidth *0.5,
        height,
      );
      canvas.drawRect(rect, _paint..shader = gradient.createShader(rect));
      n++;
    }
  }

  @override
  bool shouldRepaint(SpectrogramPainter oldDelegate) {
    return !listEquals(oldDelegate.fft, fft); // 如果不需要重绘，返回false
  }
}

/// 对 audioFFT `List<double>` 的自定义Tween
class _FFTListTween extends Tween<List<double>> {
  _FFTListTween({required super.begin, required super.end});

  @override
  List<double> lerp(double t) {
    if (begin == null || end == null) {
      return [];
    }

    // 防止 index out range
    final l = begin!.length <= end!.length ? begin!.length : end!.length;

    return List.generate(l, (index) {
      return lerpDouble(begin![index], end![index], t)!;
    });
  }

  // 辅助函数，用于 double 类型的线性插值
  double? lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    a ??= 0.0;
    b ??= 0.0;
    return a + (b - a) * t;
  }
}
