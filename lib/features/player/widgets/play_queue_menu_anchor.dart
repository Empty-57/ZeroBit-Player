import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/features/player/controller/audio_ctrl.dart';
import 'package:zerobit_player/features/player/widgets/play_page_constant.dart';

import '../../../../../core/theme/style_manager.dart';
import '../../../core/storage/models/music_cache_model.dart';
import '../../../core/utils/func_extension.dart';
import '../../../core/utils/fuzzy_search.dart';
import '../../../core/widgets/app_button/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

/// 可复用的播放队列
class PlayQueueMenuAnchor extends StatefulWidget {
  final TextStyle titleStyle;
  final TextStyle highLightTitleStyle;
  final TextStyle subStyle;
  final TextStyle highLightSubStyle;
  final Color? iconColor;
  final double iconSize;
  final double itemHeight;
  final double? menuWidth;
  final double? menuHeight;
  final AlignmentGeometry alignment;
  final Widget Function(MenuController) builder;

  const PlayQueueMenuAnchor({
    super.key,
    required this.titleStyle,
    required this.highLightTitleStyle,
    required this.subStyle,
    required this.highLightSubStyle,
    this.iconColor,
    this.iconSize = PlayPageConstant.ctrlBtnMinSize,
    this.itemHeight = 56.0,
    this.menuWidth,
    this.menuHeight,
    required this.builder,
    this.alignment = .topRight,
  });

  @override
  State<PlayQueueMenuAnchor> createState() => _PlayQueueMenuAnchorState();
}

class _PlayQueueMenuAnchorState extends State<PlayQueueMenuAnchor> {
  final MenuController _menuController = MenuController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final _searchQuery = signal<String>('');
  late final Computed<List<MusicCache>> _filteredList;
  late final void Function(String) onInputChangedDebounce = ((String text) {
    _searchQuery.value = text;
  }).debounceArgs();

  @override
  void initState() {
    super.initState();

    _filteredList = computed(() {
      final q = _searchQuery.value.trim().toLowerCase();
      final allItems = AudioController.instance.playListCacheItems.value;
      if (q.isEmpty) return allItems;
      return fuzzySearch(allItems, q);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _filteredList.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  void _scrollToCurrentPlaying() {
    final audioCtrl = AudioController.instance;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final targetOffset = widget.itemHeight * audioCtrl.currentIndex.value;
        _scrollController.jumpTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final audioCtrl = AudioController.instance;

    final effectiveWidth = widget.menuWidth ?? (screenSize.width / 2);
    final effectiveHeight = widget.menuHeight ?? (screenSize.height - 200);

    return MenuAnchor(
      controller: _menuController,
      consumeOutsideTap: true,
      style: MenuStyle(
        alignment: widget.alignment,
        backgroundColor: WidgetStatePropertyAll(
          theme.colorScheme.surfaceContainer.withValues(alpha: 0.95),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: PlayPageConstant.borderRadius),
        ),
        elevation: const WidgetStatePropertyAll(8),
      ),
      onOpen: () {
        _searchController.clear();
        _searchQuery.value = '';
        _scrollToCurrentPlaying();
      },
      menuChildren: [
        Container(
          height: effectiveHeight,
          width: effectiveWidth,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8.0,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "播放队列",
                    style: context.createTextStyle(
                      size: AppFontSize.xl,
                      weight: FontWeight.w600,
                    ),
                  ),
                  SignalBuilder(
                    builder: (context) => Text(
                      "${_filteredList.value.length} 首",
                      style: context.createTextStyle(
                        size: AppFontSize.sm,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 36,
                child: DefaultTextEditingShortcuts(
                  child: AppTextField(
                    controller: _searchController,
                    hintText: '搜索歌名、歌手或专辑...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    icon: Icons.search,
                    suffixIcon: SignalBuilder(
                      builder: (context) {
                        if (_searchQuery.value.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return AppButton.icon(
                          icon: Icons.clear,
                          size: .small,
                          borderRadius: AppRadius.pillAll,
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery.value = '';
                          },
                        );
                      },
                    ),
                    onChanged: onInputChangedDebounce,
                  ),
                ),
              ),
              Expanded(
                child: SignalBuilder(
                  builder: (context) {
                    final items = _filteredList.value;

                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          "无匹配歌曲",
                          style: context.createTextStyle(
                            size: AppFontSize.md,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: items.length,
                      itemExtent: widget.itemHeight,
                      scrollCacheExtent: ScrollCacheExtent.pixels(
                        widget.itemHeight * 2,
                      ),
                      padding: EdgeInsets.only(bottom: widget.itemHeight),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _PlayQueueItem(
                          item: item,
                          itemHeight: widget.itemHeight,
                          titleStyle: widget.titleStyle,
                          highLightTitleStyle: widget.highLightTitleStyle,
                          subStyle: widget.subStyle,
                          highLightSubStyle: widget.highLightSubStyle,
                          playThrottle: () =>
                              audioCtrl.audioPlayThrottled(item),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
      child: widget.builder(_menuController),
    );
  }
}

class _PlayQueueItem extends StatelessWidget {
  final MusicCache item;
  final double itemHeight;
  final TextStyle titleStyle;
  final TextStyle highLightTitleStyle;
  final TextStyle subStyle;
  final TextStyle highLightSubStyle;
  final VoidCallback playThrottle;

  const _PlayQueueItem({
    required this.item,
    required this.itemHeight,
    required this.titleStyle,
    required this.highLightTitleStyle,
    required this.subStyle,
    required this.highLightSubStyle,
    required this.playThrottle,
  });

  @override
  Widget build(BuildContext context) {
    final AudioController audioController = AudioController.instance;
    final isCurrent = audioController.currentPath.value == item.path;
    final currentTitleStyle = isCurrent ? highLightTitleStyle : titleStyle;
    final currentSubStyle = isCurrent ? highLightSubStyle : subStyle;

    return AppButton.ghost(
      onPressed: playThrottle,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: currentTitleStyle,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            Text(
              "${item.artist} - ${item.album}",
              style: currentSubStyle,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
