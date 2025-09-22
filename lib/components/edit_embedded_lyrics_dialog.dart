import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../HIveCtrl/models/music_cache_model.dart';
import '../custom_widgets/custom_button.dart';
import '../src/rust/api/music_tag_tool.dart';
import '../tools/general_style.dart';
import '../tools/lrcTool/lyric_model.dart';

const double _menuWidth = 180;
const double _menuHeight = 48;
const double _menuRadius = 0;

class EditEmbeddedLyricsDialog extends StatelessWidget {
  final MenuController menuController;
  final MusicCache metadata;
  const EditEmbeddedLyricsDialog({
    super.key,
    required this.menuController,
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final lyricsCtrl = TextEditingController();
    final lyricsTsCtrl = TextEditingController();
    final border = OutlineInputBorder();
    final hintStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);
    final textStyle = generalTextStyle(ctx: context, size: 'md');
    final lyricsMap = <String, String>{
      'lyrics': '',
      'lyricsTs': '',
      'type': LyricFormat.lrc,
    };

    final types = [LyricFormat.lrc, LyricFormat.qrc, LyricFormat.yrc];

    final selectedValue = LyricFormat.lrc.obs;

    return CustomBtn(
      fn: () {
        menuController.close();
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return FutureBuilder<String?>(
              future: getEmbeddedLyric(path: metadata.path),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  try {
                    final data = jsonDecode(snapshot.data ?? '');
                    lyricsCtrl.text = data?['lyrics'] ?? '';
                    lyricsTsCtrl.text = data?['lyricsTs'] ?? '';
                    selectedValue.value = data?['type'] ?? LyricFormat.lrc;
                  } catch (_) {}

                  return AlertDialog(
                    title: const Text("编辑内嵌歌词"),
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
                    content: SizedBox(
                      width: context.width * 2 / 3,
                      height: context.height * 2 / 3,
                      child: SingleChildScrollView(
                        child: Column(
                          spacing: 8,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text("选择歌词格式", style: textStyle),
                            Wrap(
                              spacing: 4,
                              runSpacing: 8,
                              children:
                                  types.map((v) {
                                    return Row(
                                      spacing: 2,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(v, style: textStyle),
                                        Obx(
                                          () => Radio<String>(
                                            value: v,
                                            groupValue: selectedValue.value,
                                            onChanged: (String? value) {
                                              selectedValue.value =
                                                  value ?? LyricFormat.lrc;
                                              lyricsMap['type'] =
                                                  selectedValue.value;
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 8),
                            Text("歌词原文", style: textStyle),
                            TextField(
                              controller: lyricsCtrl,
                              minLines: 5,
                              maxLines: null,
                              decoration: InputDecoration(
                                border: border,
                                hintText: "请提供完整的且符合格式要求的歌词数据",
                                hintStyle: hintStyle,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text("歌词翻译", style: textStyle),
                            TextField(
                              controller: lyricsTsCtrl,
                              minLines: 5,
                              maxLines: null,
                              decoration: InputDecoration(
                                border: border,
                                hintText: "请提供完整的lrc格式的歌词数据",
                                hintStyle: hintStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        spacing: 8,
                        children: [
                          CustomBtn(
                            fn: () {
                              Navigator.pop(context);
                            },
                            backgroundColor: Colors.transparent,
                            contentColor: Theme.of(context).colorScheme.primary,
                            btnWidth: 108,
                            btnHeight: 36,
                            label: "取消",
                          ),
                          CustomBtn(
                            fn: () async {
                              lyricsMap['lyrics'] = lyricsCtrl.text;
                              lyricsMap['lyricsTs'] = lyricsTsCtrl.text;
                              lyricsMap['type'] = selectedValue.value;

                              late final String jsonData;
                              try {
                                jsonData = jsonEncode(lyricsMap);
                              } catch (_) {
                                Navigator.pop(context);
                              }

                              await editEmbeddedLyric(
                                path: metadata.path,
                                lyric: jsonData,
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            contentColor:
                                Theme.of(context).colorScheme.onPrimary,
                            overlayColor:
                                Theme.of(context).colorScheme.surfaceContainer,
                            btnWidth: 108,
                            btnHeight: 36,
                            label: "确定",
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return Center(
                  child: Text(
                    "加载出错！",
                    style: generalTextStyle(ctx: context, size: 'xl'),
                  ),
                );
              },
            );
          },
        );
      },
      btnHeight: _menuHeight,
      btnWidth: _menuWidth,
      radius: _menuRadius,
      icon: PhosphorIconsLight.articleNyTimes,
      label: "编辑内嵌歌词",
      mainAxisAlignment: MainAxisAlignment.start,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
