import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/tools/func/general_style.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';

import 'get_snack_bar.dart';

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
    return CustomBtn(
      fn: () {
        menuController.close();
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return _LyricsEditDialog(metadata: metadata);
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

class _LyricsEditDialog extends StatefulWidget {
  final MusicCache metadata;

  const _LyricsEditDialog({required this.metadata});

  @override
  State<_LyricsEditDialog> createState() => _LyricsEditDialogState();
}

class _LyricsEditDialogState extends State<_LyricsEditDialog> {
  late final TextEditingController _lyricsCtrl;
  late final TextEditingController _lyricsTsCtrl;
  late final TextEditingController _originCtrl;
  late final RxString _selectedValue;

  bool _isLoading = true;
  bool _hasError = false;

  final _lyricsMap = <String, String>{
    'lyrics': '',
    'lyricsTs': '',
    'type': LyricFormat.lrc,
  };

  @override
  void initState() {
    super.initState();
    _lyricsCtrl = TextEditingController();
    _lyricsTsCtrl = TextEditingController();
    _originCtrl = TextEditingController();
    _selectedValue = LyricFormat.lrc.obs;

    _loadEmbeddedLyric();
  }

  Future<void> _loadEmbeddedLyric() async {
    try {
      final rawData = await getEmbeddedLyric(path: widget.metadata.path);
      if (!mounted) return;

      _originCtrl.text = rawData ?? '';
      try {
        final data = jsonDecode(rawData ?? '');
        _lyricsCtrl.text = data?['lyrics'] ?? '';
        _lyricsTsCtrl.text = data?['lyricsTs'] ?? '';
        _selectedValue.value = data?['type'] ?? LyricFormat.lrc;
        _lyricsMap['type'] = _selectedValue.value;
      } catch (_) {}

      setState(() {
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _lyricsCtrl.dispose();
    _lyricsTsCtrl.dispose();
    _originCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = const OutlineInputBorder();
    final hintStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);
    final textStyle = generalTextStyle(ctx: context, size: 'md');
    final types = [LyricFormat.lrc, LyricFormat.qrc, LyricFormat.yrc];

    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_hasError) {
      return AlertDialog(
        title: const Text("加载失败"),
        titleTextStyle: generalTextStyle(
          ctx: context,
          size: 'xl',
          weight: FontWeight.w600,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        actions: [
          CustomBtn(
            fn: () => Navigator.pop(context),
            backgroundColor: Theme.of(context).colorScheme.primary,
            contentColor: Theme.of(context).colorScheme.onPrimary,
            overlayColor: Theme.of(context).colorScheme.surfaceContainer,
            btnWidth: 108,
            btnHeight: 36,
            label: "确定",
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text("编辑内嵌歌词"),
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
              Obx(
                () => RadioGroup<String>(
                  groupValue: _selectedValue.value,
                  onChanged: (String? value) {
                    _selectedValue.value = value ?? LyricFormat.lrc;
                    _lyricsMap['type'] = _selectedValue.value;
                  },
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 8,
                    children: types.map((v) {
                      return Row(
                        spacing: 2,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(v, style: textStyle),
                          Radio<String>(value: v),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text("歌词原文", style: textStyle),
              TextField(
                controller: _lyricsCtrl,
                minLines: 5,
                maxLines: null,
                decoration: InputDecoration(
                  border: border,
                  hintText:
                      "请提供完整的且符合格式要求的歌词数据，若使用逐字Lrc或增强型Lrc，直接填入内嵌源数据即可，注意：会优先保存内嵌源数据的数据",
                  hintStyle: hintStyle,
                ),
              ),
              const SizedBox(height: 8),
              Text("歌词翻译", style: textStyle),
              TextField(
                controller: _lyricsTsCtrl,
                minLines: 5,
                maxLines: null,
                decoration: InputDecoration(
                  border: border,
                  hintText: "请提供完整的逐行Lrc格式的歌词翻译数据，若使用逐字Lrc或增强型Lrc，则不需要填写此项",
                  hintStyle: hintStyle,
                ),
              ),
              const SizedBox(height: 8),
              Text("内嵌源数据", style: textStyle),
              TextField(
                controller: _originCtrl,
                minLines: 5,
                maxLines: null,
                decoration: InputDecoration(
                  border: border,
                  hintText:
                      "若保存在这里，则不需要填写以上两项，下次读取时将会以Lrc格式读取（逐字Lrc，逐行Lrc，增强型Lrc）",
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
              fn: () => Navigator.pop(context),
              backgroundColor: Colors.transparent,
              contentColor: Theme.of(context).colorScheme.primary,
              btnWidth: 108,
              btnHeight: 36,
              label: "取消",
            ),
            CustomBtn(
              fn: () async {
                if (_originCtrl.text.isNotEmpty) {
                  await editEmbeddedLyric(
                    path: widget.metadata.path,
                    lyric: _originCtrl.text,
                  );
                } else {
                  _lyricsMap['lyrics'] = _lyricsCtrl.text;
                  _lyricsMap['lyricsTs'] = _lyricsTsCtrl.text;
                  _lyricsMap['type'] = _selectedValue.value;

                  late final String jsonData;
                  try {
                    jsonData = jsonEncode(_lyricsMap);
                  } catch (_) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      showSnackBar(
                        title: "ERROR",
                        msg: "保存失败！",
                        duration: const Duration(milliseconds: 2000),
                      );
                    }
                    return;
                  }

                  await editEmbeddedLyric(
                    path: widget.metadata.path,
                    lyric: jsonData,
                  );
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  showSnackBar(
                    title: "OK",
                    msg: "保存成功！",
                    duration: const Duration(milliseconds: 1500),
                  );
                }
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              contentColor: Theme.of(context).colorScheme.onPrimary,
              overlayColor: Theme.of(context).colorScheme.surfaceContainer,
              btnWidth: 108,
              btnHeight: 36,
              label: "确定",
            ),
          ],
        ),
      ],
    );
  }
}
