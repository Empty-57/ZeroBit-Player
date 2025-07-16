import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/tools/general_style.dart';

import '../getxController/audio_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../tools/lrcTool/lyric_model.dart';

const double _audioCtrlBarHeight = 96;
const double _controllerBarHeight = 48;
const _borderRadius = BorderRadius.all(Radius.circular(4));
final AudioController _audioController = Get.find<AudioController>();
final SettingController _settingController = Get.find<SettingController>();

const _lrcAlignment=[CrossAxisAlignment.start,CrossAxisAlignment.center,CrossAxisAlignment.end];

class LyricsRender extends StatelessWidget {
  const LyricsRender({super.key});

  Widget lrcLyric({required String text, required TextStyle style}) {
    return Text(text, style: style, softWrap: true);
  }

  Widget karaOkLyric({
    required List<WordEntry> text,
    required TextStyle style,
  }) {
    return Wrap(
      children:
          text.map((v) {
            return Text(v.lyricWord, style: style, softWrap: true);
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricStyle = generalTextStyle(
      ctx: context,
      size: 'lg',
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: _settingController.themeMode.value=='dark'?0.4:0.2),
      weight: FontWeight.w600,
    );
    final lrcScrollController = ScrollController();
    final hoverColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.2);

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Obx(() {
        final currentLyrics = _audioController.currentLyrics.value;
        final parsedLrc = currentLyrics?.parsedLrc;

        if (currentLyrics==null||parsedLrc is! List<LyricEntry> || parsedLrc.isEmpty) {
          return Center(child: Text("无歌词", style: lyricStyle));
        }

        final String lrcType = currentLyrics.type;

        late final Function lyricWidget;
        if (lrcType == LyricFormat.lrc) {
          lyricWidget = lrcLyric;
        } else {
          lyricWidget = karaOkLyric;
        }

        return ScrollablePositionedList.builder(
          itemCount: parsedLrc.length,
          itemScrollController: _lyricController.lrcViewScrollController,
          padding: EdgeInsets.symmetric(
            vertical:
                (context.height - _audioCtrlBarHeight - _controllerBarHeight) /
                2,
          ),
          itemBuilder: (BuildContext context, int index) {

            if(lrcType == LyricFormat.lrc&&parsedLrc[index].lyricText.isEmpty&&parsedLrc[index].translate.isEmpty){
              return SizedBox.shrink();
            }

            return TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: _borderRadius),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                overlayColor: hoverColor,
              ),
              child: FractionallySizedBox(
                widthFactor: 1,
                child: Obx(()=>Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: _lrcAlignment[_settingController.lrcAlignment.value],
                  children: [
                    lyricWidget(
                      text: parsedLrc[index].lyricText,
                      style: lyricStyle,
                    ),
                    parsedLrc[index].translate.isNotEmpty
                        ? Text(
                          parsedLrc[index].translate,
                          style: lyricStyle,
                          softWrap: true,
                        )
                        : SizedBox.shrink(),
                  ],
                )),
              ),
            );
          },
        );
      }),
    );
  }
}
