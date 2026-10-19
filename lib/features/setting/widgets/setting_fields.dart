import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:path/path.dart' as p;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/app_dialog.dart';
import 'package:zerobit_player/core/widgets/get_snack_bar.dart';
import 'package:zerobit_player/features/library/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/features/setting/controller/setting_ctrl.dart';
import 'package:zerobit_player/features/setting/widgets/setting_constant.dart';
import 'package:zerobit_player/features/setting/widgets/setting_controls.dart';
import 'package:zerobit_player/src/rust/api/get_fonts.dart';

import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_button/app_button.dart';
import '../../../core/widgets/app_button/app_tappable.dart';

final SettingController _settingController = SettingController.instance;

/// 系统字体列表
final ListSignal<String> fontsList = listSignal([]);

/// 装载系统字体列表
Future<void> loadFontsList() async {
  if (fontsList.isNotEmpty) return;
  final list = await getFontsList();
  fontsList.value = list;
}

/// 歌曲文件夹管理
class SettingFolderField extends StatelessWidget {
  const SettingFolderField({super.key});

  Future<void> _open(BuildContext context) async {
    final snapshot = [..._settingController.folders];

    final confirmed = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (_) => const _FolderManagerDialog(),
    );

    if (confirmed != true) {
      _settingController.folders.value = snapshot;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingActionButton(
      label: '管理文件夹',
      icon: PhosphorIconsLight.folder,
      onPressed: () => unawaited(_open(context)),
    );
  }
}

class _FolderManagerDialog extends StatelessWidget {
  const _FolderManagerDialog();

  Future<void> _addFolder() async {
    final selected = await FilePicker.getDirectoryPath();
    if (selected == null) return;
    if (_settingController.folders.contains(selected)) return;
    _settingController.folders.add(selected);
  }

  Future<void> _confirm(BuildContext context) async {
    await _settingController.putCache(isSaveFolders: true);
    if (context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final musicCacheController = MusicCacheController.instance;

    return AppDialog(
      title: '文件夹管理',
      content: SignalBuilder(
        builder: (context) {
          final folders = _settingController.folders;
          if (folders.isEmpty) {
            return Center(
              child: Text(
                '还没有添加任何文件夹',
                style: context.createTextStyle(
                  size: AppFontSize.md,
                  opacity: AppAlpha.textTertiary,
                ),
              ),
            );
          }

          return ListView.builder(
            scrollCacheExtent: const ScrollCacheExtent.pixels(
              AppDialogSpec.listRowHeight * 4,
            ),
            itemCount: folders.length,
            itemExtent: AppDialogSpec.listRowHeight,
            itemBuilder: (context, index) => _FolderRow(
              path: folders[index],
              onRemove: () => _settingController.folders.removeAt(index),
            ),
          );
        },
      ),
      footer: SignalBuilder(
        builder: (context) {
          final scanning = musicCacheController.currentScanAudio.value;
          if (scanning.isNotEmpty) {
            return Row(
              spacing: AppSpacing.md,
              children: [
                const SizedBox.square(
                  dimension: AppIconSize.xs,
                  child: CircularProgressIndicator(
                    strokeWidth: AppSize.trackThin,
                  ),
                ),
                Expanded(
                  child: Text(
                    '已扫描到：$scanning',
                    style: context.createTextStyle(
                      size: AppFontSize.sm,
                      opacity: AppAlpha.textTertiary,
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }

          return AppDialogActions(
            leading: SettingActionButton(
              label: '添加',
              icon: PhosphorIconsLight.plus,
              onPressed: () => unawaited(_addFolder()),
            ),
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => unawaited(_confirm(context)),
          );
        },
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;

  const _FolderRow({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: AppSpacing.md,
      children: [
        Icon(
          PhosphorIconsLight.folderOpen,
          size: AppIconSize.sm,
          color: colorScheme.onSurfaceVariant.withValues(
            alpha: AppAlpha.textTertiary,
          ),
        ),
        Expanded(
          child: Text(
            path,
            style: context.createTextStyle(size: AppFontSize.md),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
        ),
        SettingIconButton(
          danger: true,
          icon: PhosphorIconsLight.trash,
          tooltip: '移除此文件夹',
          onPressed: onRemove,
        ),
      ],
    );
  }
}

/// 颜色字段
class SettingColorField extends SignalWidget {
  final Signal<int> color;
  final ValueChanged<int> onChanged;
  final bool enableAlpha;

  const SettingColorField({
    super.key,
    required this.color,
    required this.onChanged,
    this.enableAlpha = false,
  });

  static String _formatHex(int value) {
    final rgb = (value & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '#${rgb.toUpperCase()}';
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<int>(
      barrierDismissible: true,
      context: context,
      builder: (_) => _ColorPickerDialog(
        initialColor: color.value,
        enableAlpha: enableAlpha,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = color.value;
    return AppButton.secondary(
      onPressed: () => unawaited(_pick(context)),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      label: _formatHex(value),
      tabularFigures: true,
      spacing: AppSpacing.md,
      leading: Container(
        width: SettingControlSpec.swatchSize,
        height: SettingControlSpec.swatchSize,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.xsAll,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(
              alpha: AppAlpha.borderStrong,
            ),
            width: AppSize.hairline,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(value),
            borderRadius: AppRadius.xsAll,
          ),
        ),
      ),
      trailing: Icon(
        PhosphorIconsLight.palette,
        size: AppIconSize.xs,
        color: colorScheme.primary,
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final int initialColor;
  final bool enableAlpha;

  const _ColorPickerDialog({
    required this.initialColor,
    required this.enableAlpha,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late final TextEditingController _hexController;
  late int _color;

  @override
  void initState() {
    super.initState();
    _color = widget.initialColor;
    _hexController = TextEditingController();
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog.confirm(
      title: '取色器',
      widthFactor: null,
      heightFactor: null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.md,
        children: [
          TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Hex RGB',
            ),
            controller: _hexController,
            autofocus: true,
            inputFormatters: [
              UpperCaseTextFormatter(),
              FilteringTextInputFormatter.allow(RegExp(kValidHexPattern)),
            ],
          ),
          ColorPicker(
            pickerAreaBorderRadius: AppRadius.xsAll,
            pickerColor: Color(_color),
            colorPickerWidth: SettingDialogSpec.colorPickerWidth,
            pickerAreaHeightPercent: SettingDialogSpec.colorPickerAreaPercent,
            enableAlpha: widget.enableAlpha,
            displayThumbColor: true,
            labelTypes: const [],
            portraitOnly: true,
            hexInputBar: false,
            hexInputController: _hexController,
            onColorChanged: (color) =>
                setState(() => _color = color.toARGB32()),
          ),
        ],
      ),
      onConfirm: () => Navigator.pop(context, _color),
    );
  }
}

/// 字体字段
class SettingFontField extends SignalWidget {
  final Signal<String> fontFamily;
  final ValueChanged<String> onChanged;

  const SettingFontField({
    super.key,
    required this.fontFamily,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context, String current) async {
    final picked = await showDialog<String>(
      barrierDismissible: true,
      context: context,
      builder: (_) => _FontPickerDialog(currentFont: current),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final current = fontFamily.value;

    return SettingActionButton(
      label: current.isEmpty ? '选择字体' : current,
      icon: PhosphorIconsLight.textAa,
      onPressed: () => unawaited(_pick(context, current)),
    );
  }
}

class _FontPickerDialog extends StatefulWidget {
  final String currentFont;

  const _FontPickerDialog({required this.currentFont});

  @override
  State<_FontPickerDialog> createState() => _FontPickerDialogState();
}

class _FontPickerDialogState extends State<_FontPickerDialog> {
  late final TextEditingController _searchController;
  late final _query = signal('');
  late final _filteredFonts = computed(() {
    final query = _query.value;
    final all = fontsList.value;
    if (query.isEmpty) return all;
    return all.where((font) => font.toLowerCase().contains(query)).toList();
  });

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _query.dispose();
    _filteredFonts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '选择字体',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.lg,
        children: [
          SizedBox(
            height: AppDialogSpec.searchFieldHeight,
            child: TextField(
              controller: _searchController,
              style: context.createTextStyle(size: AppFontSize.sm),
              decoration: InputDecoration(
                hintText: '搜索字体名称',
                hintStyle: context.createTextStyle(
                  size: AppFontSize.sm,
                  opacity: AppAlpha.textFaint,
                ),
                prefixIcon: const Icon(
                  PhosphorIconsLight.magnifyingGlass,
                  size: AppIconSize.xs,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                border: const OutlineInputBorder(borderRadius: AppRadius.xsAll),
              ),
              onChanged: (value) => _query.value = value.trim().toLowerCase(),
            ),
          ),
          Expanded(
            child: SignalBuilder(
              builder: (context) {
                if (fontsList.isEmpty) {
                  return const Center(
                    child: SizedBox.square(
                      dimension: AppIconSize.lg,
                      child: CircularProgressIndicator(
                        strokeWidth: AppSize.track,
                      ),
                    ),
                  );
                }

                final list = _filteredFonts.value;
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      '未找到匹配字体',
                      style: context.createTextStyle(
                        size: AppFontSize.md,
                        opacity: AppAlpha.textTertiary,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  scrollCacheExtent: const ScrollCacheExtent.pixels(
                    AppDialogSpec.listRowHeight * 4,
                  ),
                  itemCount: list.length,
                  itemExtent: AppDialogSpec.listRowHeight,
                  addAutomaticKeepAlives: false,
                  addSemanticIndexes: false,
                  itemBuilder: (context, index) => _FontRow(
                    font: list[index],
                    isCurrent: list[index] == widget.currentFont,
                    onTap: () => Navigator.pop(context, list[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FontRow extends StatelessWidget {
  final String font;
  final bool isCurrent;
  final VoidCallback onTap;

  const _FontRow({
    required this.font,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppTappable(
      onPressed: onTap,
      background: isCurrent
          ? colorScheme.primary.withValues(alpha: AppAlpha.fill)
          : null,
      hoverBackground: colorScheme.primary.withValues(alpha: AppAlpha.hover),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Text(
                font,
                style: context.createTextStyle(
                  size: AppFontSize.md,
                  fontFamily: font,
                  weight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                  color: isCurrent ? colorScheme.primary : null,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ),
            if (isCurrent)
              Icon(
                PhosphorIconsLight.check,
                size: AppIconSize.xs,
                color: colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

/// 把快捷键拆成按键名列表，供键帽展示
List<String> _hotKeyParts(HotKey hotKey) => [
  ...?hotKey.modifiers?.map((m) => m.physicalKeys.first.keyLabel),
  hotKey.physicalKey.keyLabel,
];

/// 快捷键字段
class SettingHotkeyField extends StatelessWidget {
  final Signal<HotKey> hotKey;

  /// 冲突检测用的偏好键
  final String prefKey;

  final void Function(HotKey) onRecorded;

  const SettingHotkeyField({
    super.key,
    required this.hotKey,
    required this.prefKey,
    required this.onRecorded,
  });

  Future<void> _record(BuildContext context) async {
    final previous = hotKey.value;

    // 录制期间必须先放开注册
    await _settingController.pauseHotKeysForRecord();
    if (!context.mounted) {
      await _settingController.resumeHotKeysAfterRecord();
      return;
    }

    await showDialog<void>(
      barrierDismissible: true,
      context: context,
      builder: (_) => _HotkeyRecorderDialog(hotKey: hotKey),
    );

    if (_settingController.checkHotConflict(hotKey.value, prefKey)) {
      hotKey.value = previous;
      showSnackBar(type: .warning, msg: '快捷键已被占用，请更换。');
    }

    onRecorded(hotKey.value);
    await _settingController.resumeHotKeysAfterRecord();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: AppSpacing.lg,
      children: [
        SignalBuilder(
          builder: (_) => _HotkeyCaps(parts: _hotKeyParts(hotKey.value)),
        ),
        SettingActionButton(
          label: '录制',
          icon: PhosphorIconsLight.option,
          onPressed: () => unawaited(_record(context)),
        ),
      ],
    );
  }
}

/// 键帽组
class _HotkeyCaps extends StatelessWidget {
  final List<String> parts;

  const _HotkeyCaps({required this.parts});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final plusStyle = context.createTextStyle(
      size: AppFontSize.xs,
      opacity: AppAlpha.textFaint,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: AppSpacing.xs,
      children: [
        for (int i = 0; i < parts.length; i++) ...[
          if (i > 0) Text('+', style: plusStyle),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: AppAlpha.surfaceStrong,
              ),
              borderRadius: AppRadius.xsAll,
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(
                  alpha: AppAlpha.borderStrong,
                ),
                width: AppSize.hairline,
              ),
            ),
            child: Text(
              parts[i],
              style: context.createTextStyle(
                size: AppFontSize.xs,
                weight: FontWeight.w600,
              ),
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ],
    );
  }
}

class _HotkeyRecorderDialog extends StatelessWidget {
  final Signal<HotKey> hotKey;

  const _HotkeyRecorderDialog({required this.hotKey});

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '录制快捷键',
      widthFactor: SettingDialogSpec.hotkeyWidthFactor,
      heightFactor: SettingDialogSpec.hotkeyHeightFactor,
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: AppSpacing.xl,
        children: [
          Text(
            '按下想要的组合键',
            style: context.createTextStyle(
              size: AppFontSize.sm,
              opacity: AppAlpha.textTertiary,
            ),
          ),
          // 录制器默认尺寸在桌面端偏小，放大后更好识别
          Transform.scale(
            scale: SettingDialogSpec.hotkeyRecorderScale,
            filterQuality: FilterQuality.high,
            child: SignalBuilder(
              builder: (_) => HotKeyRecorder(
                initalHotKey: hotKey.value,
                onHotKeyRecorded: (recorded) => hotKey.value = recorded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 背景图片字段
class SettingBackgroundField extends SignalWidget {
  const SettingBackgroundField({super.key});

  Future<void> _pick() async {
    try {
      final result = await FilePicker.pickFile(type: FileType.image);
      final path = result?.path;
      if (path == null || path.isEmpty) return;
      _settingController.backgroundImagePath.value = path;
      _settingController.setBackgroundImagePath(value: path);
    } catch (e, stackTrace) {
      LoggerUni.w('FilePicker错误', e, stackTrace);
      showSnackBar(type: .error, msg: '发生错误： $e');
    }
  }

  void _reset() {
    _settingController.backgroundImagePath.value = '';
    _settingController.setBackgroundImagePath(value: '');
  }

  @override
  Widget build(BuildContext context) {
    final path = _settingController.backgroundImagePath.value;

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.md,
      children: [
        SizedBox(
          width: SettingControlSpec.pathTextWidth,
          child: Text(
            path.isEmpty ? '未选择' : p.basename(path),
            style: context.createTextStyle(
              size: AppFontSize.sm,
              opacity: path.isEmpty
                  ? AppAlpha.textFaint
                  : AppAlpha.textSecondary,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SettingIconButton(
          icon: PhosphorIconsLight.image,
          tooltip: '选择背景图片',
          onPressed: () => unawaited(_pick()),
        ),
        SettingIconButton(
          icon: PhosphorIconsLight.arrowCounterClockwise,
          tooltip: '还原默认背景',
          onPressed: _reset,
        ),
      ],
    );
  }
}
