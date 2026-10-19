import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/constants/operate_area.dart';
import 'package:zerobit_player/core/constants/set_constants.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/get_snack_bar.dart';
import 'package:zerobit_player/features/player/controller/audio_ctrl.dart';
import 'package:zerobit_player/features/playlist/controller/user_playlist_ctrl.dart';
import 'package:zerobit_player/features/setting/controller/setting_ctrl.dart';

import '../../../../core/widgets/app_button/app_button.dart';
import 'audio_list_view_args.dart';
import 'audio_list_view_constant.dart';

final SettingController _setting = SettingController.instance;
final AudioController _audio = AudioController.instance;
final UserPlayListController _playList = UserPlayListController.instance;

/// 头部操作栏
class AudioActionBar extends StatelessWidget {
  final AudioListViewArgs args;

  const AudioActionBar({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.md,
      children: [
        AppButton.filled(
          onPressed: args.onPlayAll,
          icon: PhosphorIconsFill.play,
          size: .large,
          label: '播放',
          spacing: AppSpacing.md,
          width: AudioListViewSpec.playButtonWidth,
          height: AudioListViewSpec.actionHeight,
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
  final Widget? child;

  final AppButtonSize size;

  /// 是否位于 [_ActionGroup]
  final bool inGroup;

  const _ActionButton({
    this.icon,
    this.label,
    this.tooltip,
    required this.onTap,
    this.width = AudioListViewSpec.actionSquare,
    this.contentColor,
    this.child,
    this.inGroup = false,
    this.size = .large,
  });

  @override
  Widget build(BuildContext context) {
    final btn = inGroup ? AppButton.ghost : AppButton.secondary;
    return btn(
      onPressed: onTap,
      icon: icon,
      label: label,
      tooltip: tooltip,
      width: width,
      size: size,
      height: inGroup
          ? AudioListViewSpec.groupedActionHeight
          : AudioListViewSpec.actionHeight,
      alignment: label == null
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      child: child,
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
        borderRadius: AppRadius.xsAll,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: AppAlpha.border),
          width: AppSize.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AudioListViewSpec.actionGroupPadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AudioListViewSpec.actionGroupPadding,
          children: children,
        ),
      ),
    );
  }
}

/// 普通态
class _NormalActions extends StatelessWidget {
  final AudioListViewArgs args;

  const _NormalActions({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.md,
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
  final AudioListViewArgs args;

  const _MultiSelectActions({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      spacing: AppSpacing.md,
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
  final AudioListViewArgs args;
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
  final AudioListViewArgs args;

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
    return MenuAnchor(
      controller: _menuController,
      consumeOutsideTap: true,
      menuChildren: [
        for (final option in _options)
          SignalBuilder(
            builder: (_) {
              final isCurrent = widget.args.sortType == option.type;
              return AppButton.ghost(
                onPressed: () => _applySort(option.type),
                selected: isCurrent,
                icon: option.icon,
                label: option.label,
                size: .large,
                width: AudioListViewSpec.sortMenuWidth,
                alignment: MainAxisAlignment.start,
              );
            },
          ),
      ],
      child: SignalBuilder(
        builder: (context) {
          final label =
              SettingController.sortType[widget.args.sortType] ?? '未指定';
          return _ActionButton(
            inGroup: true,
            size: .medium,
            width: AudioListViewSpec.sortButtonWidth,
            onTap: () => _menuController.isOpen
                ? _menuController.close()
                : _menuController.open(),
            child: Row(
              spacing: AppSpacing.xs,
              children: [
                const Icon(PhosphorIconsLight.funnelSimple),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                ),
                const Icon(PhosphorIconsFill.caretDown),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 批量添加到歌单
class _AddToPlaylistButton extends StatefulWidget {
  final AudioListViewArgs args;

  const _AddToPlaylistButton({required this.args});

  @override
  State<_AddToPlaylistButton> createState() => _AddToPlaylistButtonState();
}

class _AddToPlaylistButtonState extends State<_AddToPlaylistButton> {
  final _menuController = MenuController();

  void _open() {
    if (_playList.allUserKey.isEmpty) {
      showSnackBar(type: .warning, msg: '未创建歌单！');
      return;
    }
    if (widget.args.selectedList.isEmpty) {
      showSnackBar(type: .warning, msg: '未选择任何音乐！');
      return;
    }
    if (_menuController.isOpen) {
      _menuController.close();
    } else {
      _menuController.open();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menuController,
      menuChildren: [
        for (final key in _playList.allUserKey)
          AppButton.ghost(
            onPressed: () {
              _menuController.close();
              _playList.addAllToAudioList(
                selectedList: [...widget.args.selectedList],
                userKey: key,
              );
            },
            label: UserPlayListController.displayNameOf(key),
            size: .large,
            width: AudioListViewSpec.playlistMenuWidth,
            alignment: MainAxisAlignment.start,
          ),
      ],
      child: _ActionButton(
        icon: PhosphorIconsLight.plus,
        label: '添加到歌单',
        width: AudioListViewSpec.playlistMenuWidth,
        onTap: _open,
      ),
    );
  }
}
