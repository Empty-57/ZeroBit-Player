import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/network/apis.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/app_card.dart';
import 'package:zerobit_player/core/widgets/app_dialog.dart';
import 'package:zerobit_player/core/widgets/audio_ctrl_btn.dart';
import 'package:zerobit_player/core/widgets/get_snack_bar.dart';
import 'package:zerobit_player/features/player/controller/audio_ctrl.dart';
import 'package:zerobit_player/features/player/widgets/play_page_constant.dart';
import 'package:zerobit_player/features/setting/controller/setting_ctrl.dart';

import '../../../core/utils/func_extension.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_button/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../lyrics/models/lyric_model.dart';
import '../../lyrics/parsers/parse_lyrics.dart';
import '../../lyrics/parsers/save_lyric.dart';

class _LrcSearchController {
  _LrcSearchController() {
    _stopSearchEffect = effect(() {
      final params = _searchParams.value;
      _loadSearch(params.query, params.offset, ++_requestId, params.apiIndex);
    });
  }

  late final void Function() _stopSearchEffect;

  final AudioController _audioController = AudioController.instance;

  final currentNetLrcOffset = signal(0);
  final _queryText = signal('');

  late final apiIndex = signal(SettingController.instance.apiIndex.value);

  bool _isDisposed = false;
  int _requestId = 0;

  final searchResults = asyncSignal<List<SearchLrcModel>>(AsyncState.data([]));

  late final _searchParams =
      computed<({String query, int offset, int apiIndex})>(
        () => (
          query: _queryText.value,
          offset: currentNetLrcOffset.value,
          apiIndex: apiIndex.value,
        ),
      );

  late final void Function(String) onInputChangedDebounce = ((String text) {
    if (_isDisposed) return;

    batch(() {
      currentNetLrcOffset.value = 0;
      _queryText.value = text;
    });
  }).debounceArgs();

  void setInitialQuery() {
    if (_isDisposed) return;

    final text =
        '${_audioController.currentMetadata.value.title} - '
        '${_audioController.currentMetadata.value.artist}';

    batch(() {
      currentNetLrcOffset.value = 0;
      _queryText.value = text;
    });
  }

  Future<void> _loadSearch(
    String query,
    int offset,
    int requestId,
    int apiIndex,
  ) async {
    query = query.trim();

    if (_isDisposed || requestId != _requestId) return;

    if (query.isEmpty) {
      searchResults.value = AsyncState.data([]);
      return;
    }

    searchResults.value = AsyncState.loading();

    try {
      final result = await getLrcBySearch(
        text: query,
        offset: offset,
        limit: 5,
        apiIndex: apiIndex,
      );

      if (_isDisposed || requestId != _requestId) return;

      final filtered = result
          .whereType<SearchLrcModel>()
          .where(
            (v) =>
                v.lyric != null &&
                (v.lyric!.lrc != null || v.lyric!.verbatimLrc != null),
          )
          .toList();

      searchResults.value = AsyncState.data(filtered);
    } catch (error, stackTrace) {
      if (_isDisposed || requestId != _requestId) return;
      searchResults.value = AsyncState.error(error, stackTrace);
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    ++_requestId;
    _stopSearchEffect();
    searchResults.dispose();
    _searchParams.dispose();
    _queryText.dispose();
    apiIndex.dispose();
    currentNetLrcOffset.dispose();
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

  Widget _buildTag(
    BuildContext context, {
    required String label,
    bool isHighlight = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isHighlight
            ? scheme.primary.withValues(alpha: AppAlpha.fillStrong)
            : scheme.onSurface.withValues(alpha: AppAlpha.controlFill),
        borderRadius: AppRadius.xsAll,
        border: Border.all(
          color: isHighlight
              ? scheme.primary.withValues(alpha: AppAlpha.borderStrong)
              : scheme.outlineVariant.withValues(alpha: AppAlpha.border),
          width: AppSize.hairline,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppFontSize.xs,
          fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
          color: isHighlight
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: AppAlpha.textSecondary),
        ),
      ),
    );
  }

  Future<void> _onUseAndSaveToLocal(
    SearchLrcModel data,
    BuildContext context,
  ) async {
    await _onUse(data, context);
    await saveLyrics(
      path: audioController.currentPath.value,
      lrcData: data.lyric,
    );
    showSnackBar(msg: '歌词已成功切换并保存', type: .success);
  }

  Future<void> _onUse(SearchLrcModel data, BuildContext context) async {
    final lyric = data.lyric;
    if (lyric == null) return;

    final type = lyric.type;

    Navigator.pop(context);
    if (type == LyricFormat.lrc) {
      audioController.currentLyrics.value = ParsedLyricModel(
        parsedLrc: await parseLrc(
          lyricData: lyric.lrc,
          lyricDataTs: lyric.translate,
        ),
        type: type,
      );
    } else if (type == LyricFormat.yrc ||
        type == LyricFormat.qrc ||
        type == LyricFormat.krc) {
      audioController.currentLyrics.value = ParsedLyricModel(
        parsedLrc: await parseKaraOkLyric(
          lyricData: lyric.verbatimLrc,
          lyricDataTs: lyric.translate,
          type: type,
        ),
        type: type,
      );
    }
    audioController.refreshLyrics();
    showSnackBar(msg: '歌词已成功切换', type: .success);
  }

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

    final isVerbatim = verbatimLrc != null && verbatimLrc.isNotEmpty;
    final hasTranslation = ts != null && ts.isNotEmpty;
    final previewContent = ts ?? verbatimLrc ?? v.lyric!.lrc ?? '暂无歌词内容';

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        borderRadius: AppRadius.xsAll,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.createTextStyle(
                          size: AppFontSize.md,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.createTextStyle(
                          size: AppFontSize.sm,
                          color: scheme.onSurface.withValues(
                            alpha: AppAlpha.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Row(
                  spacing: AppSpacing.xs,
                  children: [
                    _buildTag(
                      context,
                      label: isVerbatim ? '逐字' : 'LRC',
                      isHighlight: isVerbatim,
                    ),
                    if (hasTranslation)
                      _buildTag(context, label: '翻译', isHighlight: true),
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            Container(
              width: double.infinity,
              height: 200,
              alignment: .topLeft,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(
                  alpha: AppAlpha.surfaceSubtle,
                ),
                borderRadius: AppRadius.mdAll,
              ),
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: SingleChildScrollView(
                  child: Text(
                    previewContent.trim(),
                    style: context.createTextStyle(
                      size: AppFontSize.sm,
                      color: scheme.onSurface.withValues(
                        alpha: AppAlpha.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton.secondary(
                  label: '使用',
                  onPressed: () => unawaited(_onUse(v, context)),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton.filled(
                  label: '使用并保存',
                  onPressed: () => unawaited(_onUseAndSaveToLocal(v, context)),
                ),
              ],
            ),
          ],
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
            widthFactor: 0.65,
            heightFactor: 0.65,
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
    final pageNumStyle = context.createTextStyle(
      size: AppFontSize.sm,
      opacity: AppAlpha.textTertiary,
      tabularFigures: true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.md,
      children: [
        Row(
          spacing: AppSpacing.md,
          children: [
            Expanded(
              child: AppTextField(
                autofocus: true,
                controller: _textEditingController,
                label: '搜索封面',
                icon: PhosphorIconsLight.magnifyingGlass,
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

            SignalBuilder(
              builder: (_) {
                return Text(
                  '第 ${_controller.currentNetLrcOffset.value + 1} 页',
                  style: pageNumStyle,
                );
              },
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
                builder: (_) => AppButton.secondary(
                  label: SettingController.apiMap[key] ?? 'QQ音乐',
                  selected: _controller.apiIndex.value == key,
                  onPressed: () => batch(() {
                    _controller.apiIndex.value = key;
                    _controller.currentNetLrcOffset.value = 0;
                  }),
                ),
              ),
            ],
          ],
        ),
        Expanded(
          child: SignalBuilder(
            builder: (_) {
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
                loading: () => const Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ),
      ],
    );
  }
}
