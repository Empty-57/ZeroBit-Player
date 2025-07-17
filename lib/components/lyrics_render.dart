import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:zerobit_player/tools/general_style.dart';

import '../getxController/audio_ctrl.dart';
import '../getxController/lyric_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../tools/lrcTool/lyric_model.dart';

const double _audioCtrlBarHeight = 96;
const double _controllerBarHeight = 48;
const _borderRadius = BorderRadius.all(Radius.circular(4));
final AudioController _audioController = Get.find<AudioController>();
final SettingController _settingController = Get.find<SettingController>();
final LyricController _lyricController = Get.find<LyricController>();

const _lrcAlignment = [
  CrossAxisAlignment.start,
  CrossAxisAlignment.center,
  CrossAxisAlignment.end,
];
const _lrcScaleAlignment = [
  Alignment.centerLeft,
  Alignment.center,
  Alignment.centerRight,
];
const _lrcScale = 1.2;

class LyricsRender extends StatelessWidget {
  const LyricsRender({super.key});

  Widget lrcLyric<T>({
    required T text,
    required TextStyle style,
    required int index,
    required BuildContext ctx,
  }) {
    final text_ = text as String;

    return Obx(
      () => Text(text_, style: style, softWrap: true)
          .animate(
            target: index == _lyricController.lrcCurrentIndex.value ? 1 : 0,
          )
          .custom(
            duration: 300.ms,
            builder: (_, value, _) {
              return Text(
                text_,
                style: style.copyWith(
                  color: Color.lerp(
                    style.color,
                    style.color?.withValues(alpha: 0.8),
                    value,
                  ),
                ),
                softWrap: true,
              );
            },
          )
          .scale(
            alignment:
                _lrcScaleAlignment[_settingController.lrcAlignment.value],
            begin: Offset(1.0, 1.0),
            end: Offset(_lrcScale, _lrcScale),
            duration: 300.ms,
            curve: Curves.easeInOutQuad,
          ),
    );
  }

  Widget karaOkLyric<T>({
    required T text,
    required TextStyle style,
    required int index,
    required BuildContext ctx,
  }) {
    final text_ = text as List<WordEntry>;

    return Obx(
      () => Wrap(
            children:
                text_.map((v) {
                  return Text(v.lyricWord, style: style, softWrap: true);
                }).toList(),
          )
          .animate(
            target: index == _lyricController.lrcCurrentIndex.value ? 1 : 0,
          )
          .scale(
            alignment:
                _lrcScaleAlignment[_settingController.lrcAlignment.value],
            begin: Offset(1.0, 1.0),
            end: Offset(_lrcScale, _lrcScale),
            duration: 300.ms,
            curve: Curves.easeInOutQuad,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final lyricStyle = generalTextStyle(
      ctx: context,
      size: 24,
      color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(
        alpha: _settingController.themeMode.value == 'dark' ? 0.2 : 0.2,
      ),
      weight: FontWeight.w600,
    );

    final hoverColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.2);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lyricController.scrollToCenter();
    });

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _lyricController.pointerScroll();
        }
        },
      child: ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Obx(() {
        final currentLyrics = _audioController.currentLyrics.value;
        final parsedLrc = currentLyrics?.parsedLrc;

        if (currentLyrics == null ||
            parsedLrc is! List<LyricEntry> ||
            parsedLrc.isEmpty) {
          return Center(child: Text("无歌词", style: lyricStyle));
        }

        final String lrcType = currentLyrics.type;

        late final Widget Function<T>({
          required T text,
          required TextStyle style,
          required int index,
          required BuildContext ctx,
        })
        lyricWidget;
        if (lrcType == LyricFormat.lrc) {
          lyricWidget = lrcLyric;
        } else {
          lyricWidget = karaOkLyric;
        }

        return ScrollablePositionedList.builder(
          initialScrollIndex: 0,
          initialAlignment: 0.5,
          itemCount: parsedLrc.length,
          itemScrollController: _lyricController.lrcViewScrollController,
          padding: EdgeInsets.symmetric(
            vertical:
                (context.height - _audioCtrlBarHeight - _controllerBarHeight) /
                2,
          ),
          itemBuilder: (BuildContext context, int index) {
            if ((lrcType == LyricFormat.lrc &&
                    parsedLrc[index].lyricText.isEmpty &&
                    parsedLrc[index].translate.isEmpty) ||
                index == -1) {
              return SizedBox.shrink();
            }

            return TextButton(
              onPressed: () {
                _audioController.audioSetPositon(
                  pos: parsedLrc[index].segmentStart,
                );
              },
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: _borderRadius),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                overlayColor: hoverColor,
              ),
              child: FractionallySizedBox(
                widthFactor: 1,
                child: Obx(
                  () => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment:
                        _lrcAlignment[_settingController.lrcAlignment.value],
                    children: [
                      lyricWidget(
                        text: parsedLrc[index].lyricText,
                        style: lyricStyle,
                        index: index,
                        ctx: context,
                      ),
                      parsedLrc[index].translate.isNotEmpty
                          ? Text(
                            parsedLrc[index].translate,
                            style: lyricStyle,
                            softWrap: true,
                          )
                          : SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    ),
    );
  }
}
