import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zerobit_player/core/constants/app_routes.dart';
import 'package:zerobit_player/core/constants/operate_area.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/app_empty_state.dart';
import 'package:zerobit_player/core/widgets/app_interaction_widget.dart';
import 'package:zerobit_player/core/widgets/covers.dart';

import '../storage/models/music_cache_model.dart';
import 'app_button/app_button.dart';

const double _albumTileWidth = 180.0;
const double _albumTileHeight = 230.0;

const double _artistTileWidth = 240.0;
const double _artistTileHeight = 72.0;

const double _tileSpacing = AppSpacing.lg;

/// 首字母分组标题占的高度。[_recalculateOffsets] 依赖它推算跳转位置
const double _sectionHeaderHeight = 54.0;

/// 列表底部留白
const double _bottomInset = 128.0;

/// 右侧首字母索引条
const double _indexerWidth = 24.0;
const double _indexerItemHeight = 22.0;
const double _indexerBottomInset = 64.0;

const Duration _scrollToLetterDuration = Duration(milliseconds: 250);

/// 一个内容项
class _ContentItem {
  final String title;
  final List<String> paths;
  final MusicCache? coverMusic;

  const _ContentItem({
    required this.title,
    required this.paths,
    this.coverMusic,
  });
}

/// 按首字母分组后的一段
class _SectionItem {
  final String letter;
  final List<_ContentItem> items;

  const _SectionItem({required this.letter, required this.items});
}

/// 视图类型：专辑 or 艺术家
enum _ViewType { album, artist }

/// 列表行用到的文本样式
typedef _TileStyles = ({TextStyle title, TextStyle sub});

/// 按首字母分组、带右侧字母索引的网格列表
class SortedListView extends StatefulWidget {
  final String title;
  final String subTitle;
  final SplayTreeMap<String, List<String>> sortedDict;
  final String toRoute;
  final List<MusicCache> items;
  final List<String> letterList;
  final double? Function({required String route, bool rw, double? offset})
  rwScrollOffset;

  const SortedListView({
    super.key,
    required this.title,
    required this.subTitle,
    required this.sortedDict,
    required this.toRoute,
    required this.items,
    required this.letterList,
    required this.rwScrollOffset,
  });

  @override
  State<SortedListView> createState() => _SortedListViewState();
}

class _SortedListViewState extends State<SortedListView> {
  late final ScrollController _scrollController;
  List<_SectionItem> _sections = [];

  /// 每个首字母在滚动视图中的绝对像素位置
  final Map<String, double> _letterOffsets = {};

  late _TileStyles _tileStyles;
  late TextStyle _letterTitleStyle;

  double _lastAvailableWidth = 0;

  _ViewType get _viewType => widget.toRoute == AppRoutes.albumDetails
      ? _ViewType.album
      : _ViewType.artist;

  @override
  void initState() {
    super.initState();
    final initialOffset =
        widget.rwScrollOffset(route: widget.toRoute, rw: true) ?? 0.0;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    _processData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _letterTitleStyle = context.createTextStyle(
      size: AppFontSize.xl,
      weight: FontWeight.w600,
    );
    _tileStyles = (
      title: context.createTextStyle(size: AppFontSize.md),
      sub: context.createTextStyle(
        size: AppFontSize.sm,
        opacity: AppAlpha.textTertiary,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant SortedListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sortedDict != widget.sortedDict ||
        oldWidget.items != widget.items) {
      _processData();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _sections.clear();
    _letterOffsets.clear();
    super.dispose();
  }

  void _processData() {
    final itemMap = <String, MusicCache>{
      for (final item in widget.items) item.path: item,
    };

    final grouped = <String, List<_ContentItem>>{};
    for (final entry in widget.sortedDict.entries) {
      final key = entry.key;
      if (key.isEmpty) continue;

      final letter = key[0];
      final title = key.substring(1);
      final paths = entry.value;

      grouped
          .putIfAbsent(letter, () => [])
          .add(
            _ContentItem(
              title: title,
              paths: paths,
              coverMusic: paths.isNotEmpty ? itemMap[paths.first] : null,
            ),
          );
    }

    _sections = [
      for (final entry in grouped.entries)
        _SectionItem(letter: entry.key, items: entry.value),
    ];
  }

  /// 纯数学推算每个首字母在滚动视图里的像素位置。
  void _recalculateOffsets({
    required double availableWidth,
    required bool isAlbum,
  }) {
    _letterOffsets.clear();

    final tileWidth = isAlbum ? _albumTileWidth : _artistTileWidth;
    final tileHeight = isAlbum ? _albumTileHeight : _artistTileHeight;

    final crossAxisCount = (availableWidth / (tileWidth + _tileSpacing))
        .ceil()
        .clamp(1, 1 << 20);

    double offset = 0.0;
    for (final section in _sections) {
      _letterOffsets[section.letter] = offset;

      final rows = (section.items.length / crossAxisCount).ceil();
      final gridHeight = rows > 0
          ? rows * tileHeight + (rows - 1) * _tileSpacing
          : 0.0;

      offset += _sectionHeaderHeight + gridHeight;
    }
  }

  void _scrollToLetter(String letter) {
    final targetOffset = _letterOffsets[letter];
    if (targetOffset == null || !_scrollController.hasClients) return;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: _scrollToLetterDuration,
      curve: AppCurve.standard,
    );
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    widget.rwScrollOffset(
      route: widget.toRoute,
      rw: false,
      offset: notification.metrics.pixels,
    );
    // false = 继续冒泡
    return false;
  }

  void _navigateTo(_ContentItem item) {
    context.push(
      AppRoutes.details,
      extra: {
        'pathList': item.paths,
        'title': item.title,
        'operateArea': _viewType == _ViewType.album
            ? OperateArea.albumDetails
            : OperateArea.artistDetails,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAlbum = _viewType == _ViewType.album;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.huge,
        AppSpacing.xs,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xl,
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      if (_lastAvailableWidth != maxWidth) {
                        _lastAvailableWidth = maxWidth;
                        _recalculateOffsets(
                          availableWidth: maxWidth,
                          isAlbum: isAlbum,
                        );
                      }
                      return _buildGrid(isAlbum);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _LetterIndexer(
                  letters: widget.letterList,
                  onTap: _scrollToLetter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.md,
      children: [
        Text(
          widget.title,
          style: context.createTextStyle(
            size: AppFontSize.title,
            weight: FontWeight.w600,
          ),
        ),
        Text(
          widget.subTitle,
          style: context.createTextStyle(
            size: AppFontSize.md,
            opacity: AppAlpha.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(bool isAlbum) {
    if (_sections.isEmpty) {
      return AppEmptyState(
        text: isAlbum ? '还没有专辑' : '还没有艺术家',
        icon: isAlbum
            ? PhosphorIconsLight.vinylRecord
            : PhosphorIconsLight.userFocus,
      );
    }

    final tileHeight = isAlbum ? _albumTileHeight : _artistTileHeight;
    final gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: isAlbum ? _albumTileWidth : _artistTileWidth,
      mainAxisExtent: tileHeight,
      crossAxisSpacing: _tileSpacing,
      mainAxisSpacing: _tileSpacing,
    );

    return NotificationListener<ScrollEndNotification>(
      onNotification: _onScrollEnd,
      child: CustomScrollView(
        scrollCacheExtent: ScrollCacheExtent.pixels(tileHeight * 2),
        controller: _scrollController,
        slivers: [
          for (final section in _sections) ...[
            SliverToBoxAdapter(
              child: SizedBox(
                height: _sectionHeaderHeight,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(section.letter, style: _letterTitleStyle),
                  ),
                ),
              ),
            ),
            SliverGrid(
              gridDelegate: gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = section.items[index];
                  return isAlbum
                      ? _AlbumTile(
                          item: item,
                          styles: _tileStyles,
                          onTap: () => _navigateTo(item),
                        )
                      : _ArtistTile(
                          item: item,
                          styles: _tileStyles,
                          onTap: () => _navigateTo(item),
                        );
                },
                childCount: section.items.length,
                addAutomaticKeepAlives: false,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
        ],
      ),
    );
  }
}

/// 卡片外观
class _TileShell extends StatelessWidget {
  final Widget child;
  final String tooltip;
  final VoidCallback onTap;

  const _TileShell({
    required this.child,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton.secondary(
      onPressed: onTap,
      tooltip: tooltip,
      borderRadius: AppRadius.smAll,
      padding: const EdgeInsets.all(0),
      child: child,
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final _ContentItem item;
  final _TileStyles styles;
  final VoidCallback onTap;

  const _AlbumTile({
    required this.item,
    required this.styles,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      tooltip: item.title,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: item.title + OperateArea.albumDetails,
            createRectTween: (begin, end) =>
                MaterialRectArcTween(begin: begin, end: end),
            child: AspectRatio(
              aspectRatio: 1,
              child: item.coverMusic == null
                  ? const SizedBox.shrink()
                  : LoadLocalOrNetCover(
                      music: item.coverMusic!,
                      coverResolutionFlag: CoverResolutionFlag.middle,
                      size: _albumTileWidth,
                      evictOnDispose: false,
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xxs,
                children: [
                  Text(
                    item.title,
                    style: styles.title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                  Text('共 ${item.paths.length} 首', style: styles.sub),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  final _ContentItem item;
  final _TileStyles styles;
  final VoidCallback onTap;

  const _ArtistTile({
    required this.item,
    required this.styles,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      tooltip: item.title,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: AppSpacing.md,
        children: [
          Hero(
            tag: item.title + OperateArea.artistDetails,
            createRectTween: (begin, end) =>
                MaterialRectArcTween(begin: begin, end: end),
            child: SizedBox.square(
              dimension: _artistTileHeight,
              child: item.coverMusic == null
                  ? const SizedBox.shrink()
                  : LoadLocalOrNetCover(
                      music: item.coverMusic!,
                      size: _artistTileHeight,
                      evictOnDispose: false,
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xxs,
                children: [
                  Text(
                    item.title,
                    style: styles.title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                  Text('共 ${item.paths.length} 首', style: styles.sub),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 右侧首字母索引条
class _LetterIndexer extends StatelessWidget {
  final List<String> letters;
  final ValueChanged<String> onTap;

  const _LetterIndexer({required this.letters, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _indexerWidth,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: _indexerBottomInset),
          itemCount: letters.length,
          itemExtent: _indexerItemHeight,
          itemBuilder: (context, index) => _LetterButton(
            letter: letters[index],
            onTap: () => onTap(letters[index]),
          ),
        ),
      ),
    );
  }
}

class _LetterButton extends StatelessWidget {
  final String letter;
  final VoidCallback onTap;

  const _LetterButton({required this.letter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return HoverBuilder(
      onPressed: onTap,
      builder: (context, hovered) => DecoratedBox(
        decoration: BoxDecoration(
          color: hovered
              ? colorScheme.primary.withValues(alpha: AppAlpha.fill)
              : null,
          borderRadius: AppRadius.xsAll,
        ),
        child: Center(
          child: Text(
            letter,
            style: context.createTextStyle(
              size: AppFontSize.xs,
              color: hovered ? colorScheme.primary : null,
              opacity: hovered ? 1.0 : AppAlpha.textSecondary,
              weight: hovered ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
