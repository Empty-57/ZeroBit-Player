import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zerobit_player/core/constants/app_routes.dart';
import 'package:zerobit_player/core/constants/operate_area.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/features/library/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/features/lyrics/widgets/edit_embedded_lyrics_dialog.dart';
import 'package:zerobit_player/features/player/controller/audio_ctrl.dart';
import 'package:zerobit_player/features/playlist/controller/user_playlist_ctrl.dart';

import '../../../../core/storage/models/music_cache_model.dart';
import '../../../../core/widgets/app_button/app_button.dart';
import 'audio_list_view_constant.dart';

/// 列表项右键菜单的状态
class MusicContextMenuController {
  final menuController = MenuController();

  Offset? cursorPosition;
  MusicCache? metadata;

  bool get isOpen => menuController.isOpen;

  void open({required Offset cursorPosition, required MusicCache metadata}) {
    this.cursorPosition = cursorPosition;
    this.metadata = metadata;
    menuController.open(position: Offset.zero);
  }

  void close() {
    if (menuController.isOpen) menuController.close();
  }
}

/// 右键菜单浮层。
///
/// 位置由 [_MenuPositionDelegate] 算出
class MusicContextMenuOverlay extends StatelessWidget {
  final MusicContextMenuController controller;
  final String userKey;
  final bool showRemove;

  const MusicContextMenuOverlay({
    super.key,
    required this.controller,
    required this.userKey,
    required this.showRemove,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = controller.metadata;
    final cursor = controller.cursorPosition;
    if (metadata == null || cursor == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return CustomSingleChildLayout(
      delegate: _MenuPositionDelegate(cursor: cursor),
      child: TapRegion(
        behavior: HitTestBehavior.opaque,
        groupId: controller.menuController,
        onTapOutside: (_) => controller.close(),
        child: Container(
          width: AudioListViewSpec.menuWidth,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: AppRadius.xsAll,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(
                alpha: AppAlpha.border,
              ),
              width: AppSize.hairline,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: AppAlpha.border),
                offset: const Offset(0, AppSpacing.xxs),
                blurRadius: AppSpacing.xs,
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _buildItems(context, metadata),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildItems(BuildContext context, MusicCache metadata) {
    final audioController = AudioController.instance;
    final cacheController = MusicCacheController.instance;
    final playListController = UserPlayListController.instance;
    final menuController = controller.menuController;

    final album = metadata.album;
    final albumKey = cacheController.getLetter(str: album) + album;
    final artists = metadata.artist.split('/');
    final firstArtist = artists.first;
    final firstArtistKey =
        cacheController.getLetter(str: firstArtist) + firstArtist;

    void pushDetails({
      required List<String>? pathList,
      required String title,
      required String operateArea,
    }) {
      context.push(
        AppRoutes.details,
        extra: {
          'pathList': pathList,
          'title': title,
          'operateArea': operateArea,
        },
      );
    }

    return <Widget>[
      _MenuAction(
        menuController: menuController,
        icon: PhosphorIconsLight.arrowBendDownRight,
        label: '添加到下一首',
        onTap: () => audioController.insertNext(metadata: metadata),
      ),
      _MenuAction(
        menuController: menuController,
        icon: PhosphorIconsLight.pencilSimpleLine,
        label: '编辑元数据',
        onTap: () => context.push(
          AppRoutes.audioInfoEdit,
          extra: {'metadata': metadata},
        ),
      ),
      _MenuAction(
        menuController: menuController,
        icon: PhosphorIconsLight.articleNyTimes,
        label: '编辑内嵌歌词',
        onTap: () => unawaited(showEmbeddedLyricsEditor(context, metadata)),
      ),

      const _MenuDivider(),

      _MenuAction(
        menuController: menuController,
        icon: PhosphorIconsLight.vinylRecord,
        label: album,
        tooltip: '跳转到 "$album"',
        onTap: () => pushDetails(
          pathList: cacheController.albumItemsDict[albumKey],
          title: album,
          operateArea: OperateArea.albumDetails,
        ),
      ),

      if (artists.length == 1)
        _MenuAction(
          menuController: menuController,
          icon: PhosphorIconsLight.userFocus,
          label: firstArtist,
          tooltip: '跳转到 "$firstArtist"',
          onTap: () => pushDetails(
            pathList: cacheController.artistItemsDict[firstArtistKey],
            title: firstArtist,
            operateArea: OperateArea.artistDetails,
          ),
        )
      else
        _MenuSubmenu(
          icon: PhosphorIconsLight.userFocus,
          label: '查看艺术家',
          entries: [
            for (final artist in artists)
              _SubmenuEntry(
                label: artist,
                onTap: () {
                  menuController.close();
                  pushDetails(
                    pathList:
                        cacheController.artistItemsDict[cacheController
                                .getLetter(str: artist) +
                            artist],
                    title: artist,
                    operateArea: OperateArea.artistDetails,
                  );
                },
              ),
          ],
        ),

      const _MenuDivider(),

      _MenuSubmenu(
        icon: PhosphorIconsLight.plus,
        label: '添加到歌单',
        entries: [
          for (final key in playListController.allUserKey)
            _SubmenuEntry(
              label: UserPlayListController.displayNameOf(key),
              onTap: () {
                menuController.close();
                playListController.addToAudioList(
                  metadata: metadata,
                  userKey: key,
                );
              },
            ),
        ],
      ),

      _MenuAction(
        menuController: menuController,
        icon: PhosphorIconsLight.folderOpen,
        label: '打开本地资源',
        onTap: () => Process.run('explorer.exe', ['/select,', metadata.path]),
      ),

      if (showRemove) ...[
        const _MenuDivider(),
        _MenuAction(
          menuController: menuController,
          icon: PhosphorIconsLight.trash,
          label: '从歌单移除',
          danger: true,
          onTap: () {
            if (userKey.isEmpty) return;
            playListController.audioRemove(
              userKey: userKey,
              metadata: metadata,
            );
          },
        ),
      ],
    ];
  }
}

/// 把菜单摆进可视区域内
class _MenuPositionDelegate extends SingleChildLayoutDelegate {
  final Offset cursor;

  const _MenuPositionDelegate({required this.cursor});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const gap = AudioListViewSpec.menuCursorGap;
    double x = cursor.dx + gap;
    if (x + childSize.width > size.width) {
      x = cursor.dx - childSize.width - gap;
    }
    final bottomLimit = size.height - AudioListViewSpec.playBarInset;
    double y = cursor.dy;
    if (y + childSize.height > bottomLimit) {
      y = bottomLimit - childSize.height;
    }
    return Offset(
      x.clamp(0.0, (size.width - childSize.width).clamp(0.0, double.infinity)),
      y.clamp(
        0.0,
        (size.height - childSize.height).clamp(0.0, double.infinity),
      ),
    );
  }

  @override
  bool shouldRelayout(_MenuPositionDelegate oldDelegate) =>
      oldDelegate.cursor != cursor;
}

/// 普通菜单项
class _MenuAction extends StatelessWidget {
  final MenuController menuController;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? tooltip;

  /// 危险动作
  final bool danger;

  const _MenuAction({
    required this.menuController,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tooltip,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton.ghost(
      onPressed: () {
        menuController.close();
        onTap();
      },
      icon: icon,
      label: label,
      danger: danger,
      tooltip: tooltip,
      width: AudioListViewSpec.menuWidth,
      size: .menuItem,
      alignment: MainAxisAlignment.start,
      borderRadius: const BorderRadius.all(Radius.zero),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: AppSize.hairline,
      thickness: AppSize.hairline,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: AppAlpha.borderStrong),
    );
  }
}

class _SubmenuEntry {
  final String label;
  final VoidCallback onTap;

  const _SubmenuEntry({required this.label, required this.onTap});
}

/// 带子菜单的项
class _MenuSubmenu extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<_SubmenuEntry> entries;

  const _MenuSubmenu({
    required this.icon,
    required this.label,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final noSplash = ButtonStyle(
      splashFactory: NoSplash.splashFactory,
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(
          horizontal: AudioListViewSpec.menuItemPaddingH,
        ),
      ),
      alignment: Alignment.centerLeft,
    );

    return SizedBox(
      height: AudioListViewSpec.menuItemHeight,
      child: SubmenuButton(
        animated: true,
        style: noSplash,
        menuStyle: const MenuStyle(alignment: Alignment.topRight),
        leadingIcon: Icon(icon, size: context.getIconSize(AppIconSize.md)),
        menuChildren: [
          for (final entry in entries)
            SizedBox(
              height: AudioListViewSpec.menuItemHeight,
              child: MenuItemButton(
                onPressed: entry.onTap,
                style: noSplash,
                child: Text(
                  entry.label,
                  style: context.createTextStyle(size: AppFontSize.md),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
            ),
        ],
        child: Text(
          label,
          style: context.createTextStyle(size: AppFontSize.md),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
        ),
      ),
    );
  }
}
