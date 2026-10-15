import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/widget/app_empty_state.dart';
import 'package:zerobit_player/components/widget/app_tappable.dart';
import 'package:zerobit_player/components/widget/general_btn.dart';
import 'package:zerobit_player/controller/user_playlist_ctrl.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/models/user_playlist_model.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

const double _itemHeight = 64.0;

/// 歌单没有封面，用一个固定尺寸的图标块占位，和列表页的缩略图对齐
const double _iconBoxSize = AppSize.coverSm;

const double _rowActionSize = 40.0;
const double _headerButtonWidth = 128.0;
const double _headerButtonHeight = 42.0;

/// 列表底部留白
const double _bottomInset = _itemHeight * 2;

/// 小对话框的内容宽度
const double _dialogContentWidth = 400.0;
const double _dialogButtonWidth = 80.0;
const double _dialogButtonHeight = 36.0;

class PlayListPreviewPage extends StatelessWidget {
  const PlayListPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xl,
        children: [
          const _Header(),
          Expanded(child: SignalBuilder(builder: (_) => const _PlayListView())),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  Future<void> _create(BuildContext context) async {
    final name = await showPlaylistNameDialog(context, title: '新建歌单');
    if (name == null) return;
    UserPlayListController.instance.createPlayList(userKey: name);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = UserPlayListController.instance;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.md,
          children: [
            Text(
              '歌单',
              style: context.createTextStyle(
                size: AppFontSize.title,
                weight: FontWeight.w600,
              ),
            ),
            SignalBuilder(
              builder: (context) => Text(
                '共 ${controller.items.length} 个歌单',
                style: context.createTextStyle(
                  size: AppFontSize.md,
                  opacity: AppAlpha.textSecondary,
                  tabularFigures: true,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        GeneralBtn(
          fn: () => unawaited(_create(context)),
          label: '新建歌单',
          icon: PhosphorIconsLight.plus,
          iconSize: AppIconSize.sm,
          btnWidth: _headerButtonWidth,
          btnHeight: _headerButtonHeight,
          mainAxisAlignment: MainAxisAlignment.center,
          backgroundColor: colorScheme.primary,
          contentColor: colorScheme.onPrimary,
          overlayColor: colorScheme.surface,
        ),
      ],
    );
  }
}

class _PlayListView extends StatelessWidget {
  const _PlayListView();

  @override
  Widget build(BuildContext context) {
    final controller = UserPlayListController.instance;
    final items = controller.items;

    if (items.isEmpty) {
      return const AppEmptyState(
        text: '还没有歌单，点右上角新建一个',
        icon: PhosphorIconsLight.playlist,
      );
    }

    final titleStyle = context.createTextStyle(size: AppFontSize.md);
    final subStyle = context.createTextStyle(
      size: AppFontSize.sm,
      opacity: AppAlpha.textTertiary,
    );

    return ListView.builder(
      scrollCacheExtent: const ScrollCacheExtent.pixels(_itemHeight * 4),
      itemCount: items.length,
      itemExtent: _itemHeight,
      padding: const EdgeInsets.only(bottom: _bottomInset),
      addAutomaticKeepAlives: false,
      addSemanticIndexes: false,
      itemBuilder: (context, index) {
        final item = items[index];
        return _PlayListTile(
          key: ValueKey(item.userKey),
          item: item,
          titleStyle: titleStyle,
          subStyle: subStyle,
        );
      },
    );
  }
}

class _PlayListTile extends StatelessWidget {
  final UserPlayListCache item;
  final TextStyle titleStyle;
  final TextStyle subStyle;

  const _PlayListTile({
    super.key,
    required this.item,
    required this.titleStyle,
    required this.subStyle,
  });

  String get _displayName => UserPlayListController.displayNameOf(item.userKey);

  void _open(BuildContext context) {
    context.push(
      AppRoutes.details,
      extra: {
        'title': _displayName,
        'pathList': item.pathList,
        'operateArea': OperateArea.playListDetails,
        'userKey': item.userKey,
      },
    );
  }

  Future<void> _rename(BuildContext context) async {
    final name = await showPlaylistNameDialog(
      context,
      title: '重命名歌单',
      initialText: _displayName,
    );
    if (name == null || name == _displayName) return;
    await UserPlayListController.instance.renamePlayList(
      oldKey: item.userKey,
      newKey: name,
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDeleteConfirmDialog(context, _displayName);
    if (!confirmed) return;
    UserPlayListController.instance.removePlayList(userKey: item.userKey);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: AppTappable(
        onTap: () => _open(context),
        hoverBackground: colorScheme.primary.withValues(alpha: AppAlpha.hover),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: AppSpacing.lg,
          children: [
            Container(
              width: _iconBoxSize,
              height: _iconBoxSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(
                  alpha: AppAlpha.surfaceStrong,
                ),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(
                PhosphorIconsLight.playlist,
                size: AppIconSize.md,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xxs,
                children: [
                  Text(
                    _displayName,
                    style: titleStyle,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('共 ${item.pathList.length} 首音乐', style: subStyle),
                ],
              ),
            ),
            _RowAction(
              icon: PhosphorIconsLight.pencilSimpleLine,
              tooltip: '重命名',
              onTap: () => unawaited(_rename(context)),
            ),
            _RowAction(
              icon: PhosphorIconsLight.trash,
              tooltip: '删除歌单',
              color: colorScheme.error,
              onTap: () => unawaited(_delete(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = color ?? colorScheme.onSurfaceVariant;

    return AppTappable(
      onTap: onTap,
      tooltip: tooltip,
      hoverBackground: foreground.withValues(alpha: AppAlpha.fill),
      child: SizedBox.square(
        dimension: _rowActionSize,
        child: Center(
          child: Icon(icon, size: AppIconSize.sm, color: foreground),
        ),
      ),
    );
  }
}

/// 重命名/新歌单建的对话框
Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  required String title,
  String initialText = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PlaylistNameDialog(title: title, initialText: initialText),
  );
}

/// 输入框所在的对话框
class _PlaylistNameDialog extends StatefulWidget {
  final String title;
  final String initialText;

  const _PlaylistNameDialog({required this.title, required this.initialText});

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _textController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: widget.title,
      content: SizedBox(
        width: _dialogContentWidth,
        child: TextField(
          autofocus: true,
          controller: _textController,
          style: context.createTextStyle(size: AppFontSize.md),
          decoration: InputDecoration(
            labelText: '歌单名称',
            labelStyle: context.createTextStyle(
              size: AppFontSize.md,
              opacity: AppAlpha.textSecondary,
            ),
            border: const OutlineInputBorder(borderRadius: AppRadius.xsAll),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      confirmLabel: '确定',
      onConfirm: _submit,
    );
  }
}

/// 删除确认
Future<bool> showDeleteConfirmDialog(BuildContext context, String name) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => _DialogShell(
      title: '删除歌单',
      content: SizedBox(
        width: _dialogContentWidth,
        child: Text(
          '确定要删除歌单「$name」吗？此操作无法撤销。',
          style: context.createTextStyle(size: AppFontSize.md),
        ),
      ),
      confirmLabel: '删除',
      isDangerous: true,
      onConfirm: () => Navigator.pop(context, true),
    ),
  );
  return confirmed ?? false;
}

/// 两个小对话框共用的外壳
class _DialogShell extends StatelessWidget {
  final String title;
  final Widget content;
  final String confirmLabel;
  final VoidCallback onConfirm;

  final bool isDangerous;

  const _DialogShell({
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.onConfirm,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = isDangerous ? colorScheme.error : colorScheme.primary;

    return AlertDialog(
      title: Text(title),
      titleTextStyle: context.createTextStyle(
        size: AppFontSize.xl,
        weight: FontWeight.w600,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xsAll),
      backgroundColor: colorScheme.surface,
      content: Column(
        crossAxisAlignment: .stretch,
        mainAxisSize: .min,
        spacing: AppSpacing.lg,
        children: [
          content,
          Row(
            mainAxisAlignment: .end,
            spacing: AppSpacing.md,
            children: [
              GeneralBtn(
                fn: () => Navigator.pop(context),
                label: '取消',
                btnWidth: _dialogButtonWidth,
                btnHeight: _dialogButtonHeight,
                mainAxisAlignment: MainAxisAlignment.center,
                backgroundColor: Colors.transparent,
                contentColor: colorScheme.onSurfaceVariant,
                borderWidth: AppSize.hairline,
                borderColor: colorScheme.outlineVariant.withValues(
                  alpha: AppAlpha.border,
                ),
              ),
              GeneralBtn(
                fn: onConfirm,
                label: confirmLabel,
                btnWidth: _dialogButtonWidth,
                btnHeight: _dialogButtonHeight,
                mainAxisAlignment: MainAxisAlignment.center,
                backgroundColor: accent,
                contentColor: colorScheme.onPrimary,
                overlayColor: colorScheme.surface,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
