import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/tools/general_style.dart';

import '../getxController/audio_ctrl.dart';
import '../tools/lrcTool/lyric_model.dart';

const double _audioCtrlBarHeight = 96;
const double _controllerBarHeight = 48;
const _borderRadius = BorderRadius.all(Radius.circular(4));
final AudioController _audioController = Get.find<AudioController>();

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
      runSpacing: 2.0, // 每一“行”之间的垂直间距
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
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
        final parsedLrc = currentLyrics?['parsedLrc'];

        if (parsedLrc is! List<LyricEntry> || parsedLrc.isEmpty) {
          return Center(child: Text("无歌词", style: lyricStyle));
        }

        final String lrcType = currentLyrics?['type'];

        late final Function lyricWidget;
        if (lrcType == LyricFormat.lrc) {
          lyricWidget = lrcLyric;
        } else {
          lyricWidget = karaOkLyric;
        }

        return ListView.builder(
          itemCount: parsedLrc.length,
          controller: lrcScrollController,
          padding: EdgeInsets.symmetric(
            vertical:
                (context.height - _audioCtrlBarHeight - _controllerBarHeight) /
                2,
          ),
          itemBuilder: (BuildContext context, int index) {
            return TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: _borderRadius),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                overlayColor: hoverColor,
              ),
              child: FractionallySizedBox(
                widthFactor: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
