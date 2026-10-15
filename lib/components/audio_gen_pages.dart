import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/audio_page/audio_page_args.dart';
import 'package:zerobit_player/components/audio_page/audio_page_constant.dart';
import 'package:zerobit_player/components/audio_page/audio_page_header.dart';
import 'package:zerobit_player/components/audio_page/music_context_menu.dart';
import 'package:zerobit_player/components/widget/app_empty_state.dart';
import 'package:zerobit_player/components/widget/floating_button.dart';
import 'package:zerobit_player/components/widget/music_tile.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/tools/details_ctrl_mixin.dart';
import 'package:zerobit_player/tools/func/func_extension.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

/// 音乐列表页
class AudioGenPages extends StatefulWidget {
  final String title;
  final String operateArea;
  final String audioSource;
  final DetailsPageControllerBase controller;
  final String userKey;
  final double? Function({required String route, bool rw, double? offset})?
  rwScrollOffset;

  const AudioGenPages({
    super.key,
    required this.title,
    required this.operateArea,
    required this.audioSource,
    required this.controller,
    required this.userKey,
    this.rwScrollOffset,
  });

  @override
  State<AudioGenPages> createState() => _AudioGenPagesState();
}

class _AudioGenPagesState extends State<AudioGenPages> {
  late final Signal<bool> _isMulSelect;
  late final ListSignal<MusicCache> _selectedList;
  late final ScrollController _scrollControllerList;
  late final ScrollController _scrollControllerGrid;
  late final AudioPageArgs _args;

  final _menuController = MusicContextMenuController();

  late TextStyle _titleStyle;
  late TextStyle _highLightTitleStyle;
  late TextStyle _subStyle;
  late TextStyle _highLightSubStyle;

  late final void Function() _playAllThrottle;

  String get _scrollRoute =>
      widget.operateArea == OperateArea.allMusic ? AppRoutes.home : '';

  @override
  void initState() {
    super.initState();
    _isMulSelect = signal(false);
    _selectedList = listSignal(<MusicCache>[]);

    final initialOffset =
        widget.rwScrollOffset?.call(route: _scrollRoute, rw: true) ?? 0.0;
    _scrollControllerList = ScrollController(
      initialScrollOffset: initialOffset,
    );
    _scrollControllerGrid = ScrollController(
      initialScrollOffset: initialOffset,
    );

    _playAllThrottle = (() => widget.controller.play(
      widget.audioSource,
    )).throttle();

    _args = AudioPageArgs(
      title: widget.title,
      operateArea: widget.operateArea,
      audioSource: widget.audioSource,
      userKey: widget.userKey,
      controller: widget.controller,
      isMulSelect: _isMulSelect,
      selectedList: _selectedList,
      onPlayAll: _playAllThrottle,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final primary = Theme.of(context).colorScheme.primary;
    _titleStyle = context.createTextStyle(size: AppFontSize.md);
    _highLightTitleStyle = context.createTextStyle(
      size: AppFontSize.md,
      color: primary,
    );
    _subStyle = context.createTextStyle(
      size: AppFontSize.sm,
      opacity: AppAlpha.textSecondary,
    );
    _highLightSubStyle = context.createTextStyle(
      size: AppFontSize.sm,
      color: primary.withValues(alpha: AppAlpha.textSecondary),
    );
  }

  @override
  void dispose() {
    _scrollControllerList.dispose();
    _scrollControllerGrid.dispose();
    // 释放 signal，避免监听器残留
    _isMulSelect.dispose();
    _selectedList.dispose();
    super.dispose();
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    widget.rwScrollOffset?.call(
      route: _scrollRoute,
      rw: false,
      offset: notification.metrics.pixels,
    );
    // false = 继续冒泡
    return false;
  }

  void _openContextMenu(Offset globalPosition, MusicCache metadata) {
    if (_menuController.isOpen) {
      _menuController.close();
      return;
    }

    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    _menuController.open(
      cursorPosition: overlayBox.globalToLocal(globalPosition),
      metadata: metadata,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xl,
        children: [
          RepaintBoundary(child: AudioPageHeader(args: _args)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = AudioPageSpec.gridColumnsFor(
                  constraints.maxWidth,
                );
                return Stack(
                  children: [
                    _buildListArea(columns),
                    FloatingButton(
                      scrollControllerList: _scrollControllerList,
                      scrollControllerGrid: _scrollControllerGrid,
                      controller: widget.controller,
                      gridColumns: columns,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListArea(int columns) {
    return RawMenuAnchor(
      controller: _menuController.menuController,
      consumeOutsideTaps: false,
      overlayBuilder: (context, info) => MusicContextMenuOverlay(
        controller: _menuController,
        userKey: widget.userKey,
        showRemove: widget.operateArea == OperateArea.playListDetails,
      ),
      child: NotificationListener<ScrollEndNotification>(
        onNotification: _onScrollEnd,
        child: SignalBuilder(
          builder: (context) {
            final isListView = _args.isListView;
            final itemCount = widget.controller.items.length;

            if (itemCount == 0) {
              return const Center(child: AppEmptyState(text: '这里还没有音乐'));
            }

            return AnimatedSwitcher(
              duration: AppDuration.fast,
              child: isListView
                  ? _buildList(key: const ValueKey(true), itemCount: itemCount)
                  : _buildGrid(
                      key: const ValueKey(false),
                      itemCount: itemCount,
                      columns: columns,
                    ),
            );
          },
        ),
      ),
    );
  }

  static const _cacheExtent = ScrollCacheExtent.pixels(
    AudioPageSpec.itemHeight * 4,
  );
  static const _listPadding = EdgeInsets.only(
    bottom: AudioPageSpec.listBottomInset,
  );

  Widget _buildList({required Key key, required int itemCount}) {
    return ListView.builder(
      key: key,
      scrollCacheExtent: _cacheExtent,
      controller: _scrollControllerList,
      itemCount: itemCount,
      itemExtent: AudioPageSpec.itemHeight,
      padding: _listPadding,
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: false,
      addSemanticIndexes: false,
      itemBuilder: (context, index) => _buildMusicTile(index, isListView: true),
    );
  }

  Widget _buildGrid({
    required Key key,
    required int itemCount,
    required int columns,
  }) {
    return GridView.builder(
      key: key,
      scrollCacheExtent: _cacheExtent,
      controller: _scrollControllerGrid,
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AudioPageSpec.gridMainSpacing,
        crossAxisSpacing: AudioPageSpec.gridCrossSpacing,
        mainAxisExtent: AudioPageSpec.itemHeight,
      ),
      padding: _listPadding,
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: false,
      addSemanticIndexes: false,
      itemBuilder: (context, index) =>
          _buildMusicTile(index, isListView: false),
    );
  }

  Widget _buildMusicTile(int index, {required bool isListView}) {
    final metadata = widget.controller.items[index];

    return GestureDetector(
      key: ValueKey(metadata.path),
      onSecondaryTapDown: (event) =>
          _openContextMenu(event.globalPosition, metadata),
      child: MusicTile(
        metadata: metadata,
        titleStyle: _titleStyle,
        highLightTitleStyle: _highLightTitleStyle,
        subStyle: _subStyle,
        highLightSubStyle: _highLightSubStyle,
        audioSource: widget.audioSource,
        operateArea: widget.operateArea,
        isMulSelect: _isMulSelect,
        selectedList: _selectedList,
        viewMode: isListView,
        baseController: widget.controller,
      ),
    );
  }
}
