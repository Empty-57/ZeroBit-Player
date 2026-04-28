import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cache_model.dart';
import '../components/music_list_tool.dart';
import '../field/app_routes.dart';
import '../tools/general_style.dart';
import 'package:get/get.dart';

// 内容项宽高
const double _itemHeight = 200.0;
const double _itemWidth = 150.0;

const double _itemHeight_2 = 64;
const double _itemWidth_2 = _itemWidth + 100;

const double _coverSize = _itemWidth;
const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
const double _itemSpacing = 16.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

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

/// 代表一个包含 GlobalKey 且按首字母分组的内容项列表
class _SectionItem {
  final String letter;
  final GlobalKey key;
  final List<_ContentItem> items;

  const _SectionItem({
    required this.letter,
    required this.key,
    required this.items,
  });
}

/// 视图类型：专辑 or 艺术家
enum _ViewType { album, artist }

/// 按照字母排序的可定位列表
class SortedListView extends StatefulWidget {
  final String title;
  final String subTitle;
  final Rx<SplayTreeMap<String, List<String>>> sortedDict;
  final String toRoute;
  final List<MusicCache> items;
  final List<String> letterList;

  const SortedListView({
    super.key,
    required this.title,
    required this.subTitle,
    required this.sortedDict,
    required this.toRoute,
    required this.items,
    required this.letterList,
  });

  @override
  State<SortedListView> createState() => _SortedListViewState();
}

class _SortedListViewState extends State<SortedListView> {
  // 以首字母为键、以 GlobalKey 为值的映射，用于定位滚动
  final Map<String, GlobalKey> _sectionKeys = {};

  /// 处理已排序的音频数据，返回 _SectionItem 列表；
  List<_SectionItem> _processData(
    SplayTreeMap<String, List<String>> dict,
    List<MusicCache> allItems,
  ) {
    // 创建以 path 为键、以 MusicCache 为值的 map
    final Map<String, MusicCache> itemMap = {
      for (final item in allItems) item.path: item,
    };

    // 以首字母为键、以内容项列表为值的分组 map
    final Map<String, List<_ContentItem>> grouped = {};

    for (final entry in dict.entries) {
      final key = entry.key;
      if (key.isEmpty) continue;

      final letter = key[0]; // 首字母
      final title = key.substring(1); // 标题
      final paths = entry.value; // 音频路径列表

      // 取第一首作为封面
      final coverMusic = paths.isNotEmpty ? itemMap[paths[0]] : null;

      grouped
          .putIfAbsent(letter, () => [])
          .add(
            _ContentItem(title: title, paths: paths, coverMusic: coverMusic),
          );
    }

    // 清理已失效的 section key，避免 Map 无限膨胀
    _sectionKeys.removeWhere((k, _) => !grouped.containsKey(k));

    return grouped.entries.map((e) {
      final sectionKey = _sectionKeys.putIfAbsent(e.key, () => GlobalKey());
      return _SectionItem(letter: e.key, key: sectionKey, items: e.value);
    }).toList();
  }

  // 根据首字母找到对应 GlobalKey 并滚动到该位置
  Future<void> _scrollToLetter(String letter) async {
    final ctx = _sectionKeys[letter]?.currentContext;
    if (ctx == null) return;

    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final letterTitleStyle = generalTextStyle(ctx: context, size: 'xl');
    final titleStyle = generalTextStyle(ctx: context, size: 'md');
    final subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);

    final foregroundColorHover = WidgetStateProperty.resolveWith<Color>((
      states,
    ) {
      return states.contains(WidgetState.hovered)
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8);
    });

    final itemBackgroundColor = Theme.of(context).colorScheme.surfaceContainer;

    // 根据路由判断视图类型
    final viewType =
        widget.toRoute == AppRoutes.albumList
            ? _ViewType.album
            : _ViewType.artist;

    return Container(
      padding: const EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() {
              final sections = _processData(
                widget.sortedDict.value,
                widget.items,
              );

              return Row(
                children: [
                  Expanded(
                    child: _buildMainList(
                      sections,
                      viewType,
                      letterTitleStyle,
                      titleStyle,
                      subStyle,
                      itemBackgroundColor,
                    ),
                  ),
                  _buildLetterIndexer(foregroundColorHover),
                ],
              );
            }),
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
        Obx(
          () => Text(
            widget.subTitle,
            style: generalTextStyle(ctx: context, size: 'md'),
          ),
        ),
      ],
    );
  }

  /// 主列表：按首字母分组的 SliverGrid
  Widget _buildMainList(
    List<_SectionItem> sections,
    _ViewType viewType,
    TextStyle letterTitleStyle,
    TextStyle titleStyle,
    TextStyle subStyle,
    Color itemBackgroundColor,
  ) {
    if (sections.isEmpty) {
      return Center(
        child: Text('无内容', style: generalTextStyle(ctx: context, size: '2xl')),
      );
    }

    final isAlbum = viewType == _ViewType.album;
    final maxCrossAxisExtent = isAlbum ? _itemWidth : _itemWidth_2;
    final mainAxisExtent = isAlbum ? _itemHeight : _itemHeight_2;

    return CustomScrollView(
      slivers: [
        for (final section in sections) ...[
          // 首字母标题
          SliverToBoxAdapter(
            key: section.key,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: _itemSpacing),
              child: Text(section.letter, style: letterTitleStyle),
            ),
          ),
          // 内容网格
          SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxCrossAxisExtent,
              mainAxisExtent: mainAxisExtent,
              crossAxisSpacing: _itemSpacing,
              mainAxisSpacing: _itemSpacing,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = section.items[index];
              return isAlbum
                  ? _buildAlbumTile(
                    item,
                    titleStyle,
                    subStyle,
                    itemBackgroundColor,
                  )
                  : _buildArtistTile(
                    item,
                    titleStyle,
                    subStyle,
                    itemBackgroundColor,
                  );
            }, childCount: section.items.length),
          ),
        ],
        SliverToBoxAdapter(
          child: const SizedBox(height: 128,),
        )
      ],
    );
  }

  /// album_view 样式
  Widget _buildAlbumTile(
    _ContentItem item,
    TextStyle titleStyle,
    TextStyle subStyle,
    Color itemBackgroundColor,
  ) {
    return Tooltip(
      message: item.title,
      child: TextButton(
        onPressed: () => _navigateTo(item),
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: _coverBorderRadius),
          padding: EdgeInsets.zero,
          backgroundColor: itemBackgroundColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 1,
          children: [
            // 封面区域 始终占据正方形空间，保证布局稳定
            AspectRatio(
              aspectRatio: 1,
              child:
                  item.coverMusic != null
                      ? AsyncCover(music: item.coverMusic!, size: _coverSize)
                      : const SizedBox.shrink(),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: titleStyle,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                  Text('共${item.paths.length}首', style: subStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// artist_view 样式
  Widget _buildArtistTile(
    _ContentItem item,
    TextStyle titleStyle,
    TextStyle subStyle,
    Color itemBackgroundColor,
  ) {
    const double coverSize = _itemHeight_2;
    return Tooltip(
      message: item.title,
      child: TextButton(
        onPressed: () => _navigateTo(item),
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: _coverBorderRadius),
          padding: EdgeInsets.zero,
          backgroundColor: itemBackgroundColor,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 1,
          children: [
            // 封面区域 固定正方形
            SizedBox.square(
              dimension: coverSize,
              child:
                  item.coverMusic != null
                      ? AsyncCover(music: item.coverMusic!, size: coverSize)
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
                      style: titleStyle,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                    ),
                    Text('共${item.paths.length}首', style: subStyle),
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
  Widget _buildLetterIndexer(WidgetStateProperty<Color?> foregroundColorHover) {
    return SizedBox(
      width: 24,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView(
          padding: EdgeInsets.only(bottom: 64),
          children:
              widget.letterList.map((letter) {
                return TextButton(
                  onPressed: () => _scrollToLetter(letter),
                  style: ButtonStyle(
                    foregroundColor: foregroundColorHover,
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    shape: const WidgetStatePropertyAll(
                      RoundedRectangleBorder(borderRadius: _borderRadius),
                    ),
                  ),
                  child: Text(letter, style: const TextStyle(fontSize: 11)),
                );
              }).toList(),
        ),
      ),
    );
  }

  /// 导航到详情页 传入路径列表和标题
  void _navigateTo(_ContentItem item) {
    Get.toNamed(
      widget.toRoute,
      arguments: {'pathList': item.paths, 'title': item.title},
      id: 1,
    );
  }
}
