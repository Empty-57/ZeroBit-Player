import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/app_dialog.dart';
import 'package:zerobit_player/core/widgets/app_empty_state.dart';
import 'package:zerobit_player/core/widgets/app_text_segmented.dart';
import 'package:zerobit_player/core/widgets/get_snack_bar.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';

import '../../../core/storage/models/music_cache_model.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_button/app_button.dart';
import '../models/lyric_model.dart';

const double _dialogSizeFactor = 2 / 3;
const int _editorMinLines = 6;
const double _buttonWidth = 96.0;
const double _buttonHeight = 36.0;

/// 可选的结构化歌词格式
const Map<String, String> _formatOptions = {
  LyricFormat.lrc: 'LRC',
  LyricFormat.qrc: 'QRC',
  LyricFormat.yrc: 'YRC',
  LyricFormat.krc: 'KRC',
};

/// 打开内嵌歌词编辑器
Future<void> showEmbeddedLyricsEditor(
  BuildContext context,
  MusicCache metadata,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _LyricsEditDialog(metadata: metadata),
  );
}

/// 编辑方式
enum _EditMode { structured, raw }

class _LyricsEditDialog extends StatefulWidget {
  final MusicCache metadata;

  const _LyricsEditDialog({required this.metadata});

  @override
  State<_LyricsEditDialog> createState() => _LyricsEditDialogState();
}

class _LyricsEditDialogState extends State<_LyricsEditDialog> {
  late final TextEditingController _lyricsCtrl;
  late final TextEditingController _lyricsTsCtrl;
  late final TextEditingController _rawCtrl;

  final _isLoading = signal(true);
  final _hasError = signal(false);
  final _isSaving = signal(false);

  final _mode = signal<_EditMode>(_EditMode.structured);
  final _format = signal<String>(LyricFormat.lrc);

  late final _canSave = computed(
    () => !_isLoading.value && !_hasError.value && !_isSaving.value,
  );

  @override
  void initState() {
    super.initState();
    _lyricsCtrl = TextEditingController();
    _lyricsTsCtrl = TextEditingController();
    _rawCtrl = TextEditingController();
    unawaited(_load());
  }

  @override
  void dispose() {
    _lyricsCtrl.dispose();
    _lyricsTsCtrl.dispose();
    _rawCtrl.dispose();

    _isLoading.dispose();
    _hasError.dispose();
    _isSaving.dispose();
    _mode.dispose();
    _format.dispose();
    _canSave.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final path = widget.metadata.path;
    try {
      final raw = await getEmbeddedLyric(path: path) ?? '';
      if (!mounted) return;

      _rawCtrl.text = raw;
      _EditMode mode = raw.isEmpty ? _EditMode.structured : _EditMode.raw;

      final parsed = _tryParseStructured(raw);
      if (parsed != null) {
        _lyricsCtrl.text = parsed.lyrics;
        _lyricsTsCtrl.text = parsed.lyricsTs;
        _format.value = parsed.format;
        mode = _EditMode.structured;
      }

      batch(() {
        _mode.value = mode;
        _isLoading.value = false;
      });
    } catch (e, stackTrace) {
      LoggerUni.w('加载内嵌歌词失败 Path: $path', e, stackTrace);
      if (!mounted) return;
      batch(() {
        _isLoading.value = false;
        _hasError.value = true;
      });
    }
  }

  ({String lyrics, String lyricsTs, String format})? _tryParseStructured(
    String raw,
  ) {
    if (raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return null;
      return (
        lyrics: data['lyrics'] as String? ?? '',
        lyricsTs: data['lyricsTs'] as String? ?? '',
        format: data['type'] as String? ?? LyricFormat.lrc,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> _save() async {
    if (_isSaving.value) return;
    _isSaving.value = true;

    final payload = switch (_mode.value) {
      _EditMode.structured => jsonEncode({
        'lyrics': _lyricsCtrl.text,
        'lyricsTs': _lyricsTsCtrl.text,
        'type': _format.value,
      }),
      _EditMode.raw => _rawCtrl.text,
    };

    try {
      await editEmbeddedLyric(path: widget.metadata.path, lyric: payload);
      if (!mounted) return;
      Navigator.pop(context);
      showSnackBar(type: .success, msg: '保存成功！');
    } catch (e, stackTrace) {
      LoggerUni.w('保存内嵌歌词失败 Path: ${widget.metadata.path}', e, stackTrace);
      showSnackBar(type: .error, msg: '保存失败：$e');
      if (mounted) _isSaving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '编辑内嵌歌词',
      widthFactor: _dialogSizeFactor,
      heightFactor: _dialogSizeFactor,
      content: _buildContent(),
      footer: _buildFooter(),
    );
  }

  Widget _buildContent() {
    return SignalBuilder(
      builder: (_) {
        if (_isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_hasError.value) {
          return const AppEmptyState(
            text: '读取内嵌歌词失败，文件可能已被移动或占用',
            icon: PhosphorIconsLight.warningCircle,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.lg,
          children: [
            // 顶部分段选择栏
            Row(
              spacing: AppSpacing.lg,
              children: [
                AppTextSegmented<_EditMode>(
                  options: const {
                    _EditMode.structured: '按格式编辑',
                    _EditMode.raw: '编辑源数据',
                  },
                  value: _mode.value,
                  onChanged: (mode) => _mode.value = mode,
                ),
                if (_mode.value == _EditMode.structured) ...[
                  const Spacer(),
                  Text(
                    '格式',
                    style: context.createTextStyle(
                      size: AppFontSize.sm,
                      opacity: AppAlpha.textSecondary,
                    ),
                  ),
                  AppTextSegmented<String>(
                    options: _formatOptions,
                    value: _format.value,
                    onChanged: (format) => _format.value = format,
                  ),
                ],
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: AnimatedSwitcher(
                  duration: AppDuration.fast,
                  child: _mode.value == _EditMode.structured
                      ? _buildStructuredEditor()
                      : _buildRawEditor(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStructuredEditor() {
    return Column(
      key: const ValueKey(_EditMode.structured),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xl,
      children: [
        _LyricsField(
          label: '歌词原文',
          controller: _lyricsCtrl,
          hint: '请提供完整且符合所选格式的歌词数据',
        ),
        _LyricsField(
          label: '歌词翻译',
          controller: _lyricsTsCtrl,
          hint: '逐行 LRC 格式的翻译。逐字 LRC、增强型 LRC 与 KRC 自带翻译，不需要填写',
        ),
      ],
    );
  }

  Widget _buildRawEditor() {
    return _LyricsField(
      key: const ValueKey(_EditMode.raw),
      label: '内嵌源数据',
      controller: _rawCtrl,
      hint: '原样写入文件。读取时按 LRC 识别（逐行、逐字、增强型），留空保存即清除内嵌歌词',
    );
  }

  Widget _buildFooter() {
    return SignalBuilder(
      builder: (_) {
        final isSaving = _isSaving.value;
        final hasError = _hasError.value;
        final canSave = _canSave.value;

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: AppSpacing.md,
          children: [
            AppButton.secondary(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              label: hasError ? '关闭' : '取消',
              width: _buttonWidth,
              height: _buttonHeight,
            ),
            if (!hasError)
              AppButton.filled(
                onPressed: canSave ? () => unawaited(_save()) : null,
                width: _buttonWidth,
                height: _buttonHeight,
                loading: isSaving,
                label: '保存',
              ),
          ],
        );
      },
    );
  }
}

class _LyricsField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;

  const _LyricsField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.sm,
      children: [
        Text(
          label,
          style: context.createTextStyle(
            size: AppFontSize.md,
            weight: FontWeight.w600,
          ),
        ),
        TextField(
          controller: controller,
          minLines: _editorMinLines,
          maxLines: null,
          style: context.createTextStyle(
            size: AppFontSize.sm,
            tabularFigures: true,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.createTextStyle(
              size: AppFontSize.sm,
              opacity: AppAlpha.textFaint,
            ),
            hintMaxLines: 2,
            border: const OutlineInputBorder(borderRadius: AppRadius.xsAll),
          ),
        ),
      ],
    );
  }
}
