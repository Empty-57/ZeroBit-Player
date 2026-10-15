import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/audio_page/audio_page_args.dart';
import 'package:zerobit_player/components/audio_page/audio_page_constant.dart';
import 'package:zerobit_player/components/widget/general_btn.dart';
import 'package:zerobit_player/components/widget/get_snack_bar.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/controller/user_playlist_ctrl.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/field/set_constants.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

final SettingController _setting = SettingController.instance;
final AudioController _audio = AudioController.instance;
final UserPlayListController _playList = UserPlayListController.instance;

/// 头部操作栏
class AudioActionBar extends StatelessWidget {
  final AudioPageArgs args;

  const AudioActionBar({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      spacing: AppSpacing.lg,
      children: [
        GeneralBtn(
          fn: args.onPlayAll,
          icon: PhosphorIconsFill.play,
          iconSize: AppIconSize.sm,
          label: '播放',
          btnHeight: AudioPageSpec.actionHeight,
          btnWidth: AudioPageSpec.playButtonWidth,
          mainAxisAlignment: MainAxisAlignment.center,
          backgroundColor: colorScheme.primary,
          contentColor: colorScheme.onPrimary,
          overlayColor: colorScheme.surface,
        ),
        SignalBuilder(
          builder: (_) => AnimatedSwitcher(
            duration: AppDuration.fast,
            child: args.isMulSelect.value
                ? _MultiSelectActions(key: const ValueKey(true), args: args)
                : _NormalActions(key: const ValueKey(false), args: args),
          ),
        ),
      ],
    );
  }
}

/// 操作栏的次要按钮
class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String? tooltip;
  final VoidCallback? onTap;
  final double width;

  /// 覆盖前景色
  final Color? contentColor;

  /// 自定义内容
  final List<Widget>? children;

  /// 是否位于 [_ActionGroup]
  final bool inGroup;

  const _ActionButton({
    this.icon,
    this.label,
    this.tooltip,
    required this.onTap,
    this.width = AudioPageSpec.actionSquare,
    this.contentColor,
    this.children,
    this.inGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GeneralBtn(
      fn: onTap,
      icon: icon,
      iconSize: AppIconSize.sm,
      label: label,
      tooltip: tooltip,
      btnWidth: width,
      btnHeight: inGroup
          ? AudioPageSpec.groupedActionHeight
          : AudioPageSpec.actionHeight,
      mainAxisAlignment: label == null
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      backgroundColor: inGroup
          ? Colors.transparent
          : colorScheme.surfaceContainerHighest.withValues(
              alpha: AppAlpha.surfaceSubtle,
            ),
      borderWidth: inGroup ? 0 : AppSize.hairline,
      borderColor: colorScheme.outlineVariant.withValues(
        alpha: AppAlpha.border,
      ),
      contentColor: contentColor ?? colorScheme.onSurfaceVariant,
      children: children,
    );
  }
}

/// 按钮组
class _ActionGroup extends StatelessWidget {
  final List<Widget> children;

  const _ActionGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: AppAlpha.surfaceSubtle,
        ),
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: AppAlpha.border),
          width: AppSize.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AudioPageSpec.actionGroupPadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AudioPageSpec.actionGroupPadding,
          children: children,
        ),
      ),
    );
  }
}

/// 普通态
class _NormalActions extends StatelessWidget {
  final AudioPageArgs args;

  const _NormalActions({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.lg,
      children: [
        _ActionGroup(
          children: [
            _SortButton(args: args),
            SignalBuilder(
              builder: (_) {
                final isReverse = _setting.isReverse.value;
                return _ActionButton(
                  inGroup: true,
                  icon: isReverse
                      ? PhosphorIconsLight.arrowDown
                      : PhosphorIconsLight.arrowUp,
                  tooltip: isReverse ? '降序' : '升序',
                  onTap: () {
                    _setting.isReverse.value = !isReverse;
                    args.controller.itemReverse();
                    _setting.putCache();
                    _audio.syncCurrentIndex();
                  },
                );
              },
            ),
          ],
        ),
        SignalBuilder(
          builder: (_) {
            final isList = args.isListView;
            return _ActionButton(
              icon: isList
                  ? PhosphorIconsLight.listDashes
                  : PhosphorIconsLight.gridFour,
              tooltip: isList ? '列表视图' : '表格视图',
              onTap: () {
                _setting.viewModeMap[args.operateArea] = !isList;
                _setting.putCache();
              },
            );
          },
        ),
        _MultiSelectToggle(args: args),
      ],
    );
  }
}

/// 多选态
class _MultiSelectActions extends StatelessWidget {
  final AudioPageArgs args;

  const _MultiSelectActions({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      spacing: AppSpacing.lg,
      children: [
        if (args.operateArea == OperateArea.playListDetails)
          _ActionButton(
            icon: PhosphorIconsLight.trash,
            tooltip: '从歌单移除所选',
            contentColor: colorScheme.error,
            onTap: () {
              if (args.userKey.isEmpty) return;
              batch(() {
                _playList.audioRemoveAll(
                  userKey: args.userKey,
                  removeList: [...args.selectedList],
                );
                args.clearSelection();
              });
            },
          ),
        _AddToPlaylistButton(args: args),
        _ActionGroup(
          children: [
            SignalBuilder(
              builder: (_) {
                final hasSelection = args.selectedList.isNotEmpty;
                return _ActionButton(
                  inGroup: true,
                  icon: hasSelection
                      ? PhosphorIconsLight.selectionSlash
                      : PhosphorIconsLight.selectionAll,
                  tooltip: hasSelection ? '清空选择' : '全选',
                  onTap: () {
                    if (hasSelection) {
                      args.clearSelection();
                    } else {
                      args.selectedList.value = [...args.controller.items];
                    }
                  },
                );
              },
            ),
            _MultiSelectToggle(args: args, inGroup: true),
          ],
        ),
      ],
    );
  }
}

class _MultiSelectToggle extends StatelessWidget {
  final AudioPageArgs args;
  final bool inGroup;

  const _MultiSelectToggle({required this.args, this.inGroup = false});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (_) {
        final isMulSelect = args.isMulSelect.value;
        return _ActionButton(
          inGroup: inGroup,
          icon: isMulSelect
              ? PhosphorIconsLight.xSquare
              : PhosphorIconsLight.selection,
          tooltip: isMulSelect ? '退出多选' : '多选模式',
          onTap: () => batch(() {
            args.clearSelection();
            args.isMulSelect.value = !isMulSelect;
          }),
        );
      },
    );
  }
}

/// 排序选择
class _SortButton extends StatefulWidget {
  final AudioPageArgs args;

  const _SortButton({required this.args});

  @override
  State<_SortButton> createState() => _SortButtonState();
}

class _SortButtonState extends State<_SortButton> {
  final _menuController = MenuController();

  List<({int type, String label, IconData icon})> get _options {
    final operateArea = widget.args.operateArea;
    const labels = SettingController.sortType;

    return [
      (
        type: SortType.title,
        label: labels[SortType.title] ?? '',
        icon: PhosphorIconsRegular.textT,
      ),
      if (operateArea != OperateArea.artistDetails)
        (
          type: SortType.artist,
          label: labels[SortType.artist] ?? '',
          icon: PhosphorIconsRegular.userFocus,
        ),
      if (operateArea != OperateArea.albumDetails)
        (
          type: SortType.album,
          label: labels[SortType.album] ?? '',
          icon: PhosphorIconsRegular.vinylRecord,
        ),
      if (operateArea == OperateArea.albumDetails)
        (
          type: SortType.trackNumber,
          label: labels[SortType.trackNumber] ?? '',
          icon: PhosphorIconsRegular.hash,
        ),
      (
        type: SortType.duration,
        label: labels[SortType.duration] ?? '',
        icon: PhosphorIconsRegular.clockCountdown,
      ),
      (
        type: SortType.editTime,
        label: labels[SortType.editTime] ?? '',
        icon: PhosphorIconsRegular.fileMagnifyingGlass,
      ),
      (
        type: SortType.createTime,
        label: labels[SortType.createTime] ?? '',
        icon: PhosphorIconsRegular.filePlus,
      ),
    ];
  }

  void _applySort(int type) {
    final args = widget.args;
    _setting.sortMap[args.operateArea] = type;
    args.controller.itemReSort(operateArea: args.operateArea);
    _setting.putCache();
    _audio.syncCurrentIndex();
    _menuController.close();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MenuAnchor(
      controller: _menuController,
      consumeOutsideTap: true,
      menuChildren: [
        for (final option in _options)
          SignalBuilder(
            builder: (_) {
              final isCurrent = widget.args.sortType == option.type;
              return GeneralBtn(
                fn: () => _applySort(option.type),
                icon: option.icon,
                iconSize: AppIconSize.sm,
                label: option.label,
                btnHeight: AudioPageSpec.actionHeight,
                btnWidth: AudioPageSpec.sortMenuWidth,
                mainAxisAlignment: MainAxisAlignment.start,
                backgroundColor: isCurrent
                    ? colorScheme.primary.withValues(alpha: AppAlpha.fill)
                    : Colors.transparent,
                contentColor: isCurrent ? colorScheme.primary : null,
              );
            },
          ),
      ],
      child: SignalBuilder(
        builder: (context) {
          final label =
              SettingController.sortType[widget.args.sortType] ?? '未指定';
          final contentColor = colorScheme.onSurfaceVariant;

          return _ActionButton(
            inGroup: true,
            width: AudioPageSpec.sortButtonWidth,
            onTap: () => _menuController.isOpen
                ? _menuController.close()
                : _menuController.open(),
            children: [
              Icon(
                PhosphorIconsLight.funnelSimple,
                color: contentColor,
                size: AppIconSize.sm,
              ),
              Expanded(
                child: Text(
                  label,
                  style: context.createTextStyle(
                    size: AppFontSize.sm,
                    color: contentColor,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
              Icon(
                PhosphorIconsFill.caretDown,
                color: contentColor.withValues(alpha: AppAlpha.textSecondary),
                size: AppIconSize.xs,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 批量添加到歌单
class _AddToPlaylistButton extends StatefulWidget {
  final AudioPageArgs args;

  const _AddToPlaylistButton({required this.args});

  @override
  State<_AddToPlaylistButton> createState() => _AddToPlaylistButtonState();
}

class _AddToPlaylistButtonState extends State<_AddToPlaylistButton> {
  final _menuController = MenuController();

  void _open() {
    if (_playList.allUserKey.isEmpty) {
      showSnackBar(title: 'WARNING', msg: '未创建歌单！');
      return;
    }
    if (widget.args.selectedList.isEmpty) {
      showSnackBar(title: 'WARNING', msg: '未选择任何音乐！');
      return;
    }
    _menuController.open();
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menuController,
      menuChildren: [
        for (final key in _playList.allUserKey)
          GeneralBtn(
            fn: () {
              _menuController.close();
              _playList.addAllToAudioList(
                selectedList: [...widget.args.selectedList],
                userKey: key,
              );
            },
            label: UserPlayListController.displayNameOf(key),
            btnHeight: AudioPageSpec.actionHeight,
            btnWidth: AudioPageSpec.playlistMenuWidth,
            mainAxisAlignment: MainAxisAlignment.start,
            backgroundColor: Colors.transparent,
          ),
      ],
      child: _ActionButton(
        icon: PhosphorIconsLight.plus,
        label: '添加到歌单',
        width: AudioPageSpec.playlistMenuWidth,
        onTap: _open,
      ),
    );
  }
}
