import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cache_model.dart';

import '../tools/general_style.dart';
import 'package:get/get.dart';

const double _itemHeight = 64.0;
const double _headerHeight = _itemHeight;
const double _coverSize = 48.0;
const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
const int _coverSmallRenderSize = 150;
const double _itemSpacing = 16.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

// 使用一个抽象类来代表列表中的所有可能项
abstract class _RenderItem {
  double get height;
}

// 代表一个字母标题，如 'A'
class _HeaderItem extends _RenderItem {
  final String letter;
  _HeaderItem(this.letter);

  @override
  double get height => _headerHeight;
}

// 代表一个内容条目，如一个艺术家或专辑
class _ContentItem extends _RenderItem {
  final String title;
  final List<String> paths;
  final MusicCache? coverMusic; // 预先查找好的封面数据源

  _ContentItem({
    required this.title,
    required this.paths,
    this.coverMusic,
  });

  @override
  double get height => _itemHeight;
}

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
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 这个方法将原始数据转换为高效的渲染模型
  ({List<_RenderItem> flattenedList, Map<String, double> letterOffsets}) _processData(
    SplayTreeMap<String, List<String>> dict,
    List<MusicCache> allItems,
  ) {
    final List<_RenderItem> list = [];
    final Map<String, double> offsets = {};
    double currentOffset = 0.0;

    // 创建一个从 path到MusicCache的映射，用于O(1)时间复杂度的快速查找
    final Map<String, MusicCache> itemMap = {for (var item in allItems) item.path: item};

    for (var entry in dict.entries) {
      final key = entry.key;
      final paths = entry.value;
      final letter = key[0];

      // 如果是新的字母，添加一个 Header
      if (offsets[letter] == null) {
        offsets[letter] = currentOffset;
        final header = _HeaderItem(letter);
        list.add(header);
        currentOffset += header.height;
      }

      // 预先查找封面，避免在 build 中执行高成本操作
      MusicCache? coverMusic;
      if (paths.isNotEmpty) {
        // 使用Map进行O(1)查找，而不是List.firstWhere()的O(N)查找
        coverMusic = itemMap[paths[0]];
      }

      final content = _ContentItem(
        title: key.substring(1),
        paths: paths,
        coverMusic: coverMusic,
      );
      list.add(content);
      currentOffset += content.height;
    }
    return (flattenedList: list, letterOffsets: offsets);
  }

  @override
  Widget build(BuildContext context) {
    // --- 样式定义 ---
    final letterTitleStyle = generalTextStyle(ctx: context, size: 'xl');
    final titleStyle = generalTextStyle(ctx: context, size: 'md');
    final subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);
    final foregroundColorHover = WidgetStateProperty.resolveWith<Color>((states) {
      return states.contains(WidgetState.hovered)
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8);
    });

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          // --- 头部信息 ---
          _buildHeader(),
          // --- 列表和索引条 ---
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Obx(() {
                    // --- 调用数据预处理 ---
                    final processed = _processData(widget.sortedDict.value, widget.items);
                    final flattenedList = processed.flattenedList;
                    final letterOffsets = processed.letterOffsets;

                    return Row(
                      children: [
                        // --- 主列表 ---
                        Expanded(
                          child: _buildMainList(flattenedList, letterTitleStyle, titleStyle, subStyle),
                        ),
                        // --- 字母索引条 ---
                        _buildLetterIndexer(letterOffsets, foregroundColorHover),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 8,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              widget.title,
              style: generalTextStyle(ctx: context, size: 'title', weight: FontWeight.w600),
            ),
            Obx(() => Text(
              widget.subTitle,
              style: generalTextStyle(ctx: context, size: 'md'),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildMainList(
    List<_RenderItem> flattenedList,
    TextStyle letterTitleStyle,
    TextStyle titleStyle,
    TextStyle subStyle,
  ) {
    if (flattenedList.isEmpty) {
      return const Center(child: Text("无内容"));
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: flattenedList.length,
      itemExtentBuilder: (index, dimensions) => flattenedList[index].height,
      padding: const EdgeInsets.only(bottom: _itemHeight * 2),
      itemBuilder: (context, index) {
        final item = flattenedList[index];
        if (item is _HeaderItem) {
          return Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: _itemSpacing),
            child: Text(item.letter, style: letterTitleStyle),
          );
        } else if (item is _ContentItem) {
          return TextButton(
            onPressed: () {
              Get.toNamed(
                widget.toRoute,
                arguments: {'pathList': item.paths, 'title': item.title},
                id: 1,
              );
            },
            style: TextButton.styleFrom(
              shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
              fixedSize: const Size.fromHeight(_itemHeight),
              padding: const EdgeInsets.symmetric(horizontal: _itemSpacing),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: _itemSpacing,
              children: [
                ClipRRect(
                  borderRadius: _coverBorderRadius,
                  child: Image.memory(
                    item.coverMusic?.src ?? kTransparentImage,
                    cacheWidth: _coverSmallRenderSize,
                    cacheHeight: _coverSmallRenderSize,
                    height: _coverSize,
                    width: _coverSize,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
                Expanded(
                  child: Text(
                    item.title,
                    style: titleStyle,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    maxLines: 1,
                  ),
                ),
                Text("共${item.paths.length}首作品", style: subStyle),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLetterIndexer(
    Map<String, double> letterOffsets,
    WidgetStateProperty<Color?> foregroundColorHover,
  ) {
    return SizedBox(
      width: 24,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView(
          padding: const EdgeInsets.only(bottom:  _itemHeight * 2),
          children: widget.letterList.map((letter) {
            return TextButton(
              onPressed: () {
                final offset = letterOffsets[letter];
                if (offset != null) {
                  _scrollController.jumpTo(
                    offset.clamp(0, _scrollController.position.maxScrollExtent),
                  );
                }
              },
              style: ButtonStyle(
                foregroundColor: foregroundColorHover,
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: _borderRadius)),
              ),
              child: Text(letter, style: const TextStyle(fontSize: 11)),
            );
          }).toList(),
        ),
      ),
    );
  }
}