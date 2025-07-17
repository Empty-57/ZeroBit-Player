import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/components/blur_background.dart';
import 'package:zerobit_player/components/lyrics_render.dart';
import 'package:zerobit_player/tools/general_style.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';

import '../components/audio_ctrl_btn.dart';
import '../components/window_ctrl_bar.dart';
import '../getxController/audio_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../tools/format_time.dart';
import '../tools/lrcTool/parse_lyrics.dart';
import '../tools/rect_value_indicator.dart';

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));

final AudioController _audioController = Get.find<AudioController>();
final SettingController _settingController = Get.find<SettingController>();

const int _coverRenderSize = 800;
const double _ctrlBtnMinSize = 40.0;
const double _thumbRadius = 10.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));
final _isBarHover = false.obs;
final _onlyCover = false.obs;

const double _audioCtrlBarHeight = 96;

const _lrcAlignmentIcons = [
  PhosphorIconsLight.textAlignLeft,
  PhosphorIconsLight.textAlignCenter,
  PhosphorIconsLight.textAlignRight,
];



class _LrcSearchController extends GetxController{
  final currentNetLrc=<SearchLrcModel?>[].obs;
  final currentNetLrcOffest=0.obs;
  final searchText="${_audioController.currentMetadata.value.title} - ${_audioController.currentMetadata.value.artist}".obs;

  @override
  void onInit() async{
    currentNetLrc.value=await getLrcBySearch(text: searchText.value, offset: currentNetLrcOffest.value, limit: 5);
    super.onInit();

    debounce(searchText, (_)async{
      currentNetLrc.value=await getLrcBySearch(text: searchText.value, offset: currentNetLrcOffest.value, limit: 5);
      currentNetLrcOffest.value=0;
    },time: Duration(milliseconds: 500));

    interval(currentNetLrcOffest, (_)async{
      debugPrint(currentNetLrcOffest.value.toString());
      currentNetLrc.value=await getLrcBySearch(text: searchText.value, offset: currentNetLrcOffest.value, limit: 5);
    },time: Duration(milliseconds: 300));

  }

}

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

class _NetLrcDialog extends StatelessWidget{
  final Color? color;
  const _NetLrcDialog({required this.color});

  @override
  Widget build(BuildContext context) {
    final searchCtrl = TextEditingController();
    final bgColor=Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4);
    final textStyle=generalTextStyle(ctx: context,size: 'md');
    searchCtrl.text="${_audioController.currentMetadata.value.title} - ${_audioController.currentMetadata.value.artist}";

    final lrcSearchController=Get.put(_LrcSearchController());


    return GenIconBtn(
      tooltip: '网络歌词',
      icon: PhosphorIconsLight.article,
      size: _ctrlBtnMinSize,
      color: color,
      fn: () {
        showDialog(
          barrierDismissible: true,
          context: context,
          builder: (BuildContext context) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               lrcSearchController.searchText.value=searchCtrl.text;
               lrcSearchController.currentNetLrcOffest.value=0;
             });

            return AlertDialog(
              title: const Text("选择歌词"),
              titleTextStyle: generalTextStyle(
                ctx: context,
                size: 'xl',
                weight: FontWeight.w600,
              ),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,

              actionsAlignment: MainAxisAlignment.end,
              actions: <Widget>[
                SizedBox(
                  width: context.width/2,
                  height: context.height/2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Row(
                        spacing: 8,
                        children: [
                          Expanded(child:
                          TextField(
                        autofocus: true,
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '搜索歌词',
                        ),
                        onChanged: (String text) {
                          lrcSearchController.searchText.value=text;
                        },
                      )),
                          Obx(()=>GenIconBtn(
                        tooltip: lrcSearchController.currentNetLrcOffest.value>0?'上一页':'',
                        icon: PhosphorIconsLight.caretLeft,
                        size: _ctrlBtnMinSize*1.5,
                        color: color,
                        backgroundColor: bgColor,
                        fn: lrcSearchController.currentNetLrcOffest.value>0? () {
                          if(lrcSearchController.currentNetLrcOffest.value>0){
                            lrcSearchController.currentNetLrcOffest.value--;
                          }
                        }:null,
                      )),

                      GenIconBtn(
                        tooltip: '下一页',
                        icon: PhosphorIconsLight.caretRight,
                        size: _ctrlBtnMinSize*1.5,
                        color: color,
                        backgroundColor: bgColor,
                        fn: () {
                          lrcSearchController.currentNetLrcOffest.value++;
                        },
                      )],
                      ),
                      Expanded(child: Obx((){
                        return ListView(
                        children: lrcSearchController.currentNetLrc.map((v){
                          if(v==null||v.lyric==null||(v.lyric!.lrc==null&&v.lyric!.verbatimLrc==null)){
                            return SizedBox.shrink();
                          }

                          final String? verbatimLrc=v.lyric!.verbatimLrc;
                          final String? ts=v.lyric!.translate;
                          final String title=v.title;
                          final String artist=v.artist;
                          return TextButton(
                              onPressed: (){
                                final type= v.lyric!.type;
                                if (type == LyricFormat.lrc) {
                                  _audioController.currentLyrics.value=ParsedLyricModel(parsedLrc: parseLrc(lyricData: v.lyric!.lrc,lyricDataTs: v.lyric!.translate),
                                    type: type,);
                                }
                                if (type == LyricFormat.yrc || type == LyricFormat.qrc) {
                                  _audioController.currentLyrics.value=ParsedLyricModel(parsedLrc: parseKaraOkLyric(
                                    v.lyric!.verbatimLrc,
                                    v.lyric!.translate,
                                    type: type,
                                  ),
                                    type: type,);
                                }
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: _borderRadius),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
                              child: FractionallySizedBox(
                            widthFactor: 1,
                            child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                verbatimLrc!=null&&verbatimLrc.isNotEmpty? '逐字':'Lrc',
                                style: textStyle,
                              ),
                                  Text(
                                ts!=null&&ts.isNotEmpty? '有翻译':'无翻译',
                                style: textStyle,
                              ),
                                ],
                              ),
                              Expanded(child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                    margin: EdgeInsets.only(top: 16),
                                    constraints: BoxConstraints(
                                      maxHeight: 200
                                    ),
                                    child: FractionallySizedBox(
                                      widthFactor: 0.8,
                                      child: SingleChildScrollView(
                                      child: Text(
                                "歌词: \n${ts??verbatimLrc??''}",
                                softWrap: true,
                                overflow: TextOverflow.fade,
                                style: textStyle,
                              ),
                                    ),
                                  ),
                                ],
                              ))
                            ],
                          ),
                          ));
                        }).toList(),
                      );
                      }))
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

}

class LrcView extends StatelessWidget {
  const LrcView({super.key});

  @override
  Widget build(BuildContext context) {
    double coverSize = (context.width * 0.3).clamp(300, 500);
    final halfWidth = context.width / 2;
    final mixColor=Color.lerp(Theme.of(context).colorScheme.primary, themeMode.value=='dark'? Colors.white:Colors.black, 0.4);
    final mixSubColor=Color.lerp(Theme.of(context).colorScheme.primary.withValues(alpha: 0.8), themeMode.value=='dark'? Colors.white:Colors.black, 0.4);

    final activeTrackCover = mixColor??Theme.of(context).colorScheme.primary;
    final inactiveTrackCover=mixColor?.withValues(alpha: 0.2)??Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);

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
    );//可能需要用主色来根据主题模式来混合颜色
    final subTitleStyle = generalTextStyle(
      ctx: context,
      size: 'md',
      color: mixSubColor,
    );
    final audioCtrlWidget = AudioCtrlWidget(
      context: context,
      size: _ctrlBtnMinSize,
      color: mixColor,
    );
    return BlurWithCoverBackground(
      cover: _audioController.currentCover,
      useGradient: false,
      sigma: 256,
      useMask: true,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainer.withValues(alpha: 0.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const WindowControllerBar(
              isNestedRoute: false,
              showLogo: false,
              useCaretDown: true,
              useSearch: false,
            ),

            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 1,
                    child: Obx(
                      () => Stack(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: ShaderMask(
                              shaderCallback: (rect) {
                                return LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black,
                                    Colors.black,
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.1, 0.9, 1.0],
                                ).createShader(rect);
                                },
                              blendMode: BlendMode.dstIn,  // 用 dstIn 保留子 Widget 的 alpha
                               child: Container(
                                  width: halfWidth,
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.only(right: 16),
                                  child: const LyricsRender(),
                                )
                                .animate(target: _onlyCover.value ? 1 : 0)
                                .fade(duration: 300.ms, begin: 1.0, end: 0.0),
                            ),
                          ) ,
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                                  width: halfWidth,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Hero(
                                        tag: 'playingCover',
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.2,
                                                ),
                                                offset: Offset(0, 2),
                                                blurRadius: 8,
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: _coverBorderRadius,
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: GestureDetector(
                                                onTap:
                                                    () =>
                                                        _onlyCover.value =
                                                            !_onlyCover.value,
                                                child: Obx(
                                                  () => AnimatedSwitcher(
                                                    duration: 300.ms,
                                                    switchInCurve:
                                                        Curves.easeIn,
                                                    switchOutCurve:
                                                        Curves.easeOut,
                                                    child: Image.memory(
                                                      _audioController
                                                          .currentCover
                                                          .value,
                                                      key: ValueKey(
                                                        _audioController
                                                            .currentCover
                                                            .value
                                                            .hashCode,
                                                      ),
                                                      cacheWidth:
                                                          _coverRenderSize,
                                                      cacheHeight:
                                                          _coverRenderSize,
                                                      height: coverSize,
                                                      width: coverSize,
                                                      fit: BoxFit.cover,
                                                    ),
                                                    transitionBuilder: (
                                                      Widget child,
                                                      Animation<double> anim,
                                                    ) {
                                                      return FadeTransition(
                                                        opacity: anim,
                                                        child: child,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: coverSize - 24,
                                        margin: EdgeInsets.only(top: 24),
                                        child: Obx(
                                          () => Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            spacing: 2,
                                            children: [
                                              Text(
                                                _audioController
                                                    .currentMetadata
                                                    .value
                                                    .title,
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
                                )
                                .animate(target: _onlyCover.value ? 1 : 0)
                                .moveX(
                                  begin: 0,
                                  end: halfWidth / 2,
                                  duration: 300.ms,
                                  curve: Curves.fastOutSlowIn,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _audioCtrlBarHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              valueIndicatorShape:
                                  RectangularValueIndicatorShape(
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
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 24,
                              right: 24,
                              bottom: _thumbRadius,
                            ),
                            child: MouseRegion(
                              onEnter: (_) {
                                _isBarHover.value = true;
                              },
                              onExit: (_) {
                                _isBarHover.value = false;
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: context.width * 0.2,
                                    child: Obx(
                                      () => Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            formatTime(
                                              totalSeconds:
                                                  _audioController
                                                      .currentMs100
                                                      .value,
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
                                    flex: 1,
                                    child: Obx(
                                      () => Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            spacing: 16,
                                            children: [
                                              audioCtrlWidget.volumeSet,
                                              audioCtrlWidget.skipBack,
                                              audioCtrlWidget.toggle,
                                              audioCtrlWidget.skipForward,
                                              audioCtrlWidget.changeMode,
                                            ],
                                          )
                                          .animate(
                                            target: _isBarHover.value ? 1 : 0,
                                          )
                                          .fade(duration: 150.ms),
                                    ),
                                  ),
                                  SizedBox(
                                    width: context.width * 0.2,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      spacing: 16,
                                      children: [
                                        Obx(()=>GenIconBtn(
                                          tooltip: _settingController.lrcAlignmentMap[_settingController.lrcAlignment.value]??'',
                                          icon: _lrcAlignmentIcons[_settingController.lrcAlignment.value],
                                          size: _ctrlBtnMinSize,
                                          color: mixColor,
                                          fn: () {
                                            _audioController.changeLrcAlignment();
                                          },
                                        )),
                                        _NetLrcDialog(color: mixColor,),
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
                        ),
                      ],
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
