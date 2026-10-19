import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/app_dialog.dart';
import 'package:zerobit_player/core/widgets/app_empty_state.dart';
import 'package:zerobit_player/core/widgets/get_snack_bar.dart';
import 'package:zerobit_player/features/library/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/features/player/controller/audio_ctrl.dart';
import 'package:zerobit_player/features/playlist/controller/user_playlist_ctrl.dart';

import '../../../core/storage/models/music_cache_model.dart';
import '../../../core/widgets/app_button/app_button.dart';

const double _resultRowHeight = 56.0;

/// 打开曲库搜索对话框
Future<void> showLibrarySearchDialog(BuildContext context) {
  return showDialog<void>(
    barrierDismissible: true,
    context: context,
    builder: (_) => const _LibrarySearchDialog(),
  );
}

class _LibrarySearchDialog extends StatefulWidget {
  const _LibrarySearchDialog();

  @override
  State<_LibrarySearchDialog> createState() => _LibrarySearchDialogState();
}

class _LibrarySearchDialogState extends State<_LibrarySearchDialog> {
  final _cacheController = MusicCacheController.instance;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _cacheController.resetSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '搜索',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.lg,
        children: [
          TextField(
            autofocus: true,
            controller: _searchController,
            style: context.createTextStyle(size: AppFontSize.md),
            decoration: InputDecoration(
              border: const OutlineInputBorder(borderRadius: AppRadius.xsAll),
              hintText: '搜索曲名、艺术家或专辑',
              hintStyle: context.createTextStyle(
                size: AppFontSize.md,
                opacity: AppAlpha.textFaint,
              ),
              prefixIcon: const Icon(
                PhosphorIconsLight.magnifyingGlass,
                size: AppIconSize.sm,
              ),
            ),
            onChanged: _cacheController.onInputChangedDebounce,
          ),
          Expanded(
            child: SignalBuilder(
              builder: (context) {
                final results = _cacheController.searchResult.value;
                if (results.isEmpty) {
                  return const AppEmptyState(
                    text: '输入关键词开始搜索',
                    icon: PhosphorIconsLight.magnifyingGlass,
                  );
                }

                return ListView.builder(
                  scrollCacheExtent: const ScrollCacheExtent.pixels(
                    _resultRowHeight * 4,
                  ),
                  itemCount: results.length,
                  itemExtent: _resultRowHeight,
                  addAutomaticKeepAlives: false,
                  addSemanticIndexes: false,
                  itemBuilder: (context, index) =>
                      _SearchResultRow(metadata: results[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultRow extends StatefulWidget {
  final MusicCache metadata;

  const _SearchResultRow({required this.metadata});

  @override
  State<_SearchResultRow> createState() => _SearchResultRowState();
}

class _SearchResultRowState extends State<_SearchResultRow> {
  final _menuController = MenuController();
  final _playListController = UserPlayListController.instance;

  void _openPlaylistMenu() {
    if (_playListController.allUserKey.isEmpty) {
      showSnackBar(type: .warning, msg: '还未创建任何歌单');
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
    final metadata = widget.metadata;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: AppButton.ghost(
        onPressed: () =>
            AudioController.instance.searchInsert(metadata: metadata),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: AppSpacing.md,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xxs,
                children: [
                  Text(
                    metadata.title,
                    style: context.createTextStyle(size: AppFontSize.md),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${metadata.artist} · ${metadata.album}',
                    style: context.createTextStyle(
                      size: AppFontSize.sm,
                      opacity: AppAlpha.textTertiary,
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AppButton.icon(
              icon: PhosphorIconsLight.arrowBendDownRight,
              tooltip: '添加到下一首',
              onPressed: () =>
                  AudioController.instance.insertNext(metadata: metadata),
            ),
            MenuAnchor(
              controller: _menuController,
              consumeOutsideTap: true,
              style: MenuStyle(
                maximumSize: WidgetStatePropertyAll(
                  Size.fromHeight(
                    MediaQuery.sizeOf(context).height *
                        AppDialogSpec.heightFactor,
                  ),
                ),
              ),
              menuChildren: [
                for (final key in _playListController.allUserKey)
                  MenuItemButton(
                    onPressed: () => _playListController.addToAudioList(
                      metadata: metadata,
                      userKey: key,
                    ),
                    style: const ButtonStyle(
                      splashFactory: NoSplash.splashFactory,
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text(
                      UserPlayListController.displayNameOf(key),
                      style: context.createTextStyle(size: AppFontSize.md),
                    ),
                  ),
              ],
              child: AppButton.icon(
                icon: PhosphorIconsLight.plus,
                tooltip: '添加到歌单',
                onPressed: _openPlaylistMenu,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
