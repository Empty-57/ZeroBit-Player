import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/network/apis.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/app_dialog.dart';
import 'package:zerobit_player/core/widgets/audio_ctrl_btn.dart';
import 'package:zerobit_player/features/player/controller/audio_ctrl.dart';
import 'package:zerobit_player/features/player/widgets/play_page_constant.dart';
import 'package:zerobit_player/features/setting/controller/setting_ctrl.dart';

import '../../../core/utils/func_extension.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_button/app_button.dart';
import '../../lyrics/models/lyric_model.dart';
import '../../lyrics/parsers/parse_lyrics.dart';
import '../../lyrics/parsers/save_lyric.dart';

class _LrcSearchController {
  final AudioController _audioController = AudioController.instance;
  final SettingController _settingController = SettingController.instance;

  final currentNetLrcOffset = signal(0);
  final _queryText = signal("");

  late final _searchParams = computed<({String query, int offset})>(
    () => (query: _queryText.value, offset: currentNetLrcOffset.value),
  );

  late final void Function(String) onInputChangedDebounce = ((String text) {
    batch(() {
      currentNetLrcOffset.value = 0;
      _queryText.value = text;
    });
  }).debounceArgs();

  late final searchResults = computedAsync<List<SearchLrcModel>>(
    () async {
      final params = _searchParams.peek();
      final query = params.query.trim();
      final offset = params.offset;

      if (query.isEmpty) return const [];

      final result = await getLrcBySearch(
        text: query,
        offset: offset,
        limit: 5,
      );
      return result
          .whereType<SearchLrcModel>()
          .where(
            (v) =>
                v.lyric != null &&
                (v.lyric!.lrc != null || v.lyric!.verbatimLrc != null),
          )
          .toList();
    },
    options: AsyncSignalOptions(
      dependencies: [_searchParams, _settingController.apiIndex],
    ),
  );

  void setInitialQuery() {
    final text =
        "${_audioController.currentMetadata.value.title} - ${_audioController.currentMetadata.value.artist}";
    batch(() {
      currentNetLrcOffset.value = 0;
      _queryText.value = text;
    });
  }

  void dispose() {
    searchResults.dispose();
    _searchParams.dispose();
    _queryText.dispose();
    currentNetLrcOffset.dispose(); // 最后释放被依赖的signals
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
      } catch (e, stackTrace) {
        LoggerUni.w('krc 翻译解析失败', e, stackTrace);
      }
    }

    return AppButton.ghost(
      onPressed: () async {
        final type = v.lyric!.type;
        if (type == LyricFormat.lrc) {
          audioController.currentLyrics.value = ParsedLyricModel(
            parsedLrc: await parseLrc(
              lyricData: v.lyric!.lrc,
              lyricDataTs: v.lyric!.translate,
            ),
            type: type,
          );
        } else if (type == LyricFormat.yrc ||
            type == LyricFormat.qrc ||
            type == LyricFormat.krc) {
          Navigator.pop(context);
          audioController.currentLyrics.value = ParsedLyricModel(
            parsedLrc: await parseKaraOkLyric(
              lyricData: v.lyric!.verbatimLrc,
              lyricDataTs: v.lyric!.translate,
              type: type,
            ),
            type: type,
          );
        }
        audioController.refreshLyrics();

        if (settingController.autoDownloadLrc.value) {
          unawaited(
            saveLyrics(
              path: audioController.currentPath.value,
              lrcData: v.lyric,
            ),
          );
        }
      },
      child: FractionallySizedBox(
        widthFactor: 1,
        child: Padding(
          padding: const EdgeInsetsGeometry.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Column(
                children: [
                  Text(
                    verbatimLrc != null && verbatimLrc.isNotEmpty
                        ? '逐字'
                        : 'Lrc',
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
      ),
    );
  }
}

class NetLrcDialog extends StatelessWidget {
  final Color? color;

  const NetLrcDialog({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return GenIconBtn(
      tooltip: '网络歌词',
      icon: PhosphorIconsLight.article,
      size: PlayPageConstant.ctrlBtnMinSize,
      color: color,
      fn: () {
        showDialog<void>(
          barrierDismissible: true,
          context: context,
          builder: (context) => AppDialog(
            title: "选择歌词",
            content: _NetLrcDialogContent(color: color),
          ),
        );
      },
    );
  }
}

class _NetLrcDialogContent extends StatefulWidget {
  final Color? color;

  const _NetLrcDialogContent({required this.color});

  @override
  State<_NetLrcDialogContent> createState() => _NetLrcDialogContentState();
}

class _NetLrcDialogContentState extends State<_NetLrcDialogContent> {
  // 在弹窗打开时才创建 Controller，此时自动立即执行初次搜索！
  late final _LrcSearchController _controller;
  late final TextEditingController _textEditingController;

  late final AudioController _audioController = AudioController.instance;
  late final SettingController _settingController = SettingController.instance;

  @override
  void initState() {
    super.initState();
    _controller = _LrcSearchController()..setInitialQuery();
    _textEditingController = TextEditingController(
      text:
          "${_audioController.currentMetadata.value.title} - ${_audioController.currentMetadata.value.artist}",
    );
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = context.createTextStyle(size: AppFontSize.md);
    final height = MediaQuery.sizeOf(context).height;
    final width = MediaQuery.sizeOf(context).width;

    return SizedBox(
      width: width * 0.65,
      height: height * 0.65,
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
                  onChanged: _controller.onInputChangedDebounce,
                ),
              ),

              SignalBuilder(
                builder: (_) => AppButton.icon(
                  icon: PhosphorIconsLight.caretLeft,
                  style: .secondary,
                  height: PlayPageConstant.ctrlBtnMinSize * 1.25,
                  tooltip: _controller.currentNetLrcOffset.value == 0
                      ? null
                      : '上一页',
                  onPressed: _controller.currentNetLrcOffset.value == 0
                      ? null
                      : () {
                          if (_controller.currentNetLrcOffset.value > 0) {
                            _controller.currentNetLrcOffset.value--;
                          }
                        },
                ),
              ),

              AppButton.icon(
                icon: PhosphorIconsLight.caretRight,
                style: .secondary,
                height: PlayPageConstant.ctrlBtnMinSize * 1.25,
                tooltip: '下一页',
                onPressed: () => _controller.currentNetLrcOffset.value++,
              ),
            ],
          ),
          Row(
            spacing: AppSpacing.sm,
            children: [
              for (final key in SettingController.apiMap.keys) ...[
                SignalBuilder(
                  builder: (context) => AppButton.secondary(
                    label: SettingController.apiMap[key] ?? 'QQ音乐',
                    selected: _settingController.apiIndex.value == key,
                    onPressed: () => _settingController.apiIndex.value = key,
                  ),
                ),
              ],
            ],
          ),
          Expanded(
            child: SignalBuilder(
              builder: (context) {
                return _controller.searchResults.value.map(
                  data: (data) {
                    if (data.isEmpty) {
                      return Center(child: Text("没有找到歌词", style: textStyle));
                    }
                    return ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        return _SearchResultItem(
                          lyricInfo: data[index],
                          textStyle: textStyle,
                          audioController: _audioController,
                          settingController: _settingController,
                        );
                      },
                    );
                  },
                  error: (_) =>
                      Center(child: Text("网络错误或没有找到歌词", style: textStyle)),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
