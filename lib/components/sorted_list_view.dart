import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobit_player/components/covers.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/tools/func/general_style.dart';

// 内容项宽高常量
const double _itemHeight = 230.0;
const double _itemWidth = 180.0;

const double _itemHeight_2 = 72.0;
const double _itemWidth_2 = 240.0;

const BorderRadius _coverBorderRadius = BorderRadius.all(Radius.circular(6));
const BorderRadius _borderRadius = BorderRadius.all(Radius.circular(4));
const double _itemSpacing = 12.0;

// 固定字母标题区域的高度
const double _sectionHeaderHeight = 54.0;
const double _bottomPadding = 128.0;

/// 代表一个内容项
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

/// 代表一个按首字母分组的内容项列表
class _SectionItem {
  final String letter;
  final List<_ContentItem> items;

  const _SectionItem({required this.letter, required this.items});
}

/// 视图类型：专辑 or 艺术家
enum _ViewType { album, artist }

/// 按照字母排序的可定位列表
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

  // 保存每个字母对应的精确像素偏移量
  final Map<String, double> _letterOffsets = {};

  // 样式缓存，避免在 build 阶段重复创建
  late TextStyle _letterTitleStyle;
  late TextStyle _titleStyle;
  late TextStyle _subStyle;
  late WidgetStateProperty<Color?> _foregroundColorHover;
  late ButtonStyle _itemBtnStyle;

  double _lastAvailableWidth = 0;

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
    final colorScheme = Theme.of(context).colorScheme;

    // 初始化并缓存所有 TextStyle 和 ButtonStyle
    _letterTitleStyle = generalTextStyle(ctx: context, size: 'xl');
    _titleStyle = generalTextStyle(ctx: context, size: 'md');
    _subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);

    _foregroundColorHover = WidgetStateProperty.resolveWith<Color>((states) {
      return states.contains(WidgetState.hovered)
          ? colorScheme.primary
          : colorScheme.onSurface.withValues(alpha: 0.8);
    });

    // 缓存 TextButton 样式
    _itemBtnStyle = TextButton.styleFrom(
      shape: const RoundedRectangleBorder(borderRadius: _coverBorderRadius),
      padding: EdgeInsets.zero,
      backgroundColor: colorScheme.surfaceContainer.withValues(alpha: 0.8),
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
    final Map<String, MusicCache> tempItemMap = {
      for (final item in widget.items) item.path: item,
    };

    final Map<String, List<_ContentItem>> grouped = {};
    for (final entry in widget.sortedDict.entries) {
      final key = entry.key;
      if (key.isEmpty) continue;

      final letter = key[0];
      final title = key.substring(1);
      final paths = entry.value;

      final coverMusic = paths.isNotEmpty ? tempItemMap[paths[0]] : null;

      grouped
          .putIfAbsent(letter, () => [])
          .add(
            _ContentItem(title: title, paths: paths, coverMusic: coverMusic),
          );
    }

    _sections = grouped.entries.map((e) {
      return _SectionItem(letter: e.key, items: e.value);
    }).toList();
  }

  /// 纯数学计算每个字母在 CustomScrollView 中的绝对像素位置
  void _recalculateOffsets({
    required double availableWidth,
    required bool isAlbum,
  }) {
    _letterOffsets.clear();

    final double maxExtent = isAlbum ? _itemWidth : _itemWidth_2;
    final double mainAxisExtent = isAlbum ? _itemHeight : _itemHeight_2;

    // 算出一行最多有多少列
    int crossAxisCount = (availableWidth / (maxExtent + _itemSpacing)).ceil();
    if (crossAxisCount <= 0) crossAxisCount = 1;

    double accumulatedOffset = 0.0;

    for (final section in _sections) {
      // 记录当前字母在滑动视图中的起点像素
      _letterOffsets[section.letter] = accumulatedOffset;

      final int itemCount = section.items.length;
      // 算出一共多少行
      final int rows = (itemCount / crossAxisCount).ceil();

      // 计算当前字母分类总高度
      final double gridHeight = rows > 0
          ? (rows * mainAxisExtent + (rows - 1) * _itemSpacing)
          : 0.0;

      accumulatedOffset += _sectionHeaderHeight + gridHeight;
    }
  }

  /// 动画跳转到指定字母
  void _scrollToLetter(String letter) {
    final targetOffset = _letterOffsets[letter];
    if (targetOffset == null || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 根据路由判断视图类型
    final viewType = widget.toRoute == AppRoutes.albumDetails
        ? _ViewType.album
        : _ViewType.artist;

    return Container(
      padding: const EdgeInsets.only(left: 16, top: 32, right: 4, bottom: 16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                // 通过 LayoutBuilder 动态获取宽度以保证精准度
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      if (_lastAvailableWidth != maxWidth) {
                        _lastAvailableWidth = maxWidth;
                        _recalculateOffsets(
                          availableWidth: maxWidth,
                          isAlbum: viewType == _ViewType.album,
                        );
                      }
                      return _buildMainList(_sections, viewType);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                _buildLetterIndexer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 头部信息
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: generalTextStyle(
            ctx: context,
            size: 'title',
            weight: FontWeight.w600,
          ),
        ),
        Text(
          widget.subTitle,
          style: generalTextStyle(ctx: context, size: 'md'),
        ),
      ],
    );
  }

  /// 主列表：按首字母分组的 SliverGrid
  Widget _buildMainList(List<_SectionItem> sections, _ViewType viewType) {
    if (sections.isEmpty) {
      return Center(
        child: Text(
          '无内容',
          style: generalTextStyle(ctx: context, size: '2xl'),
        ),
      );
    }

    final isAlbum = viewType == _ViewType.album;
    final mainAxisExtent = isAlbum ? _itemHeight : _itemHeight_2;

    final gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: isAlbum ? _itemWidth : _itemWidth_2,
      mainAxisExtent: mainAxisExtent,
      crossAxisSpacing: _itemSpacing,
      mainAxisSpacing: _itemSpacing,
    );

    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        widget.rwScrollOffset(
          route: widget.toRoute,
          rw: false,
          offset: notification.metrics.pixels,
        );
        // false = 继续冒泡
        return false;
      },
      child: CustomScrollView(
        scrollCacheExtent: ScrollCacheExtent.pixels(mainAxisExtent * 2),
        controller: _scrollController,
        slivers: [
          for (final section in sections) ...[
            // 首字母标题
            SliverToBoxAdapter(
              child: SizedBox(
                height: _sectionHeaderHeight,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(section.letter, style: _letterTitleStyle),
                  ),
                ),
              ),
            ),
            // 内容网格
            SliverGrid(
              gridDelegate: gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = section.items[index];
                  return isAlbum
                      ? _buildAlbumTile(item)
                      : _buildArtistTile(item);
                },
                childCount: section.items.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: _bottomPadding)),
        ],
      ),
    );
  }

  /// album_view 样式
  Widget _buildAlbumTile(_ContentItem item) {
    return Tooltip(
      message: item.title,
      child: TextButton(
        onPressed: () => _navigateTo(item),
        style: _itemBtnStyle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面区域 始终占据正方形空间，保证布局稳定
            AspectRatio(
              aspectRatio: 1,
              child: item.coverMusic != null
                  ? LoadLocalOrNetCover(
                      music: item.coverMusic!,
                      coverResolutionFlag: CoverResolutionFlag.middle,
                      size: _itemWidth,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: _titleStyle,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                  Text('共${item.paths.length}首', style: _subStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// artist_view 样式
  Widget _buildArtistTile(_ContentItem item) {
    return Tooltip(
      message: item.title,
      child: TextButton(
        onPressed: () => _navigateTo(item),
        style: _itemBtnStyle,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 1,
          children: [
            // 封面区域 固定正方形
            SizedBox.square(
              dimension: _itemHeight_2,
              child: item.coverMusic != null
                  ? LoadLocalOrNetCover(
                      music: item.coverMusic!,
                      size: _itemHeight_2,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 2),
            // 文字区域 占满剩余宽度，防止文字溢出
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: _titleStyle,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                    ),
                    Text('共${item.paths.length}首', style: _subStyle),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 首字母索引条
  Widget _buildLetterIndexer() {
    return SizedBox(
      width: 24,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 64),
          itemCount: widget.letterList.length,
          itemBuilder: (context, index) {
            final letter = widget.letterList[index];
            return TextButton(
              onPressed: () => _scrollToLetter(letter),
              style: ButtonStyle(
                foregroundColor: _foregroundColorHover,
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                shape: const WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: _borderRadius),
                ),
              ),
              child: Text(letter, style: const TextStyle(fontSize: 11)),
            );
          },
        ),
      ),
    );
  }

  /// 导航到详情页 传入路径列表和标题
  void _navigateTo(_ContentItem item) {
    context.push(
      AppRoutes.details,
      extra: {
        'pathList': item.paths,
        'title': item.title,
        'operateArea': widget.toRoute == AppRoutes.albumDetails
            ? OperateArea.albumDetails
            : OperateArea.artistDetails,
      },
    );
  }
}
