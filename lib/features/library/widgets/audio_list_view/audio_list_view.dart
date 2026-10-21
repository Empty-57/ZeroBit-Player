import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/constants/app_routes.dart';
import 'package:zerobit_player/core/constants/operate_area.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/app_empty_state.dart';
import 'package:zerobit_player/core/widgets/floating_button.dart';

import '../../../../core/storage/models/music_cache_model.dart';
import '../../../../core/utils/details_ctrl_mixin.dart';
import '../../../../core/utils/format_time.dart';
import '../../../../core/utils/func_extension.dart';
import '../../../../core/widgets/app_button/app_button.dart';
import '../../../../core/widgets/covers.dart';
import '../../../setting/widgets/setting_fields.dart';
import 'audio_list_view_args.dart';
import 'audio_list_view_constant.dart';
import 'audio_list_view_context_menu.dart';
import 'audio_page_header.dart';

/// 音乐列表页
class AudioListView extends StatefulWidget {
  final String title;
  final String operateArea;
  final String audioSource;
  final DetailsPageControllerBase controller;
  final String userKey;
  final double? Function({required String route, bool rw, double? offset})?
  rwScrollOffset;

  const AudioListView({
    super.key,
    required this.title,
    required this.operateArea,
    required this.audioSource,
    required this.controller,
    required this.userKey,
    this.rwScrollOffset,
  });

  @override
  State<AudioListView> createState() => _AudioListViewState();
}

class _AudioListViewState extends State<AudioListView> {
  late final Signal<bool> _isMulSelect;
  late final ListSignal<MusicCache> _selectedList;
  late final ScrollController _scrollControllerList;
  late final ScrollController _scrollControllerGrid;
  late final AudioListViewArgs _args;

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

    _args = AudioListViewArgs(
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
      tabularFigures: true,
    );
    _highLightSubStyle = context.createTextStyle(
      size: AppFontSize.sm,
      color: primary.withValues(alpha: AppAlpha.textSecondary),
      tabularFigures: true,
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
                final columns = AudioListViewSpec.gridColumnsFor(
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
              return Column(
                mainAxisAlignment: .center,
                children: [
                  const AppEmptyState(text: '这里还没有音乐'),
                  if (widget.operateArea == OperateArea.allMusic)
                    const SettingFolderField(),
                ],
              );
            }

            return AnimatedSwitcher(
              duration: AppDuration.fast,
              child: isListView
                  ? _buildList(
                      key: const ValueKey('list_view'),
                      itemCount: itemCount,
                    )
                  : _buildGrid(
                      key: const ValueKey('grid_view'),
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
    AudioListViewSpec.itemHeight * 4,
  );
  static const _listPadding = EdgeInsets.only(
    bottom: AudioListViewSpec.listBottomInset,
  );

  Widget _buildList({required Key key, required int itemCount}) {
    return ListView.builder(
      key: key,
      scrollCacheExtent: _cacheExtent,
      controller: _scrollControllerList,
      itemCount: itemCount,
      itemExtent: AudioListViewSpec.itemHeight,
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
        mainAxisSpacing: AudioListViewSpec.gridMainSpacing,
        crossAxisSpacing: AudioListViewSpec.gridCrossSpacing,
        mainAxisExtent: AudioListViewSpec.itemHeight,
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
      child: _MusicTile(
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

class _MusicTile extends SignalWidget {
  final MusicCache metadata;
  final TextStyle titleStyle;
  final TextStyle highLightTitleStyle;
  final TextStyle subStyle;
  final TextStyle highLightSubStyle;
  final String audioSource;
  final String operateArea;
  final Signal<bool> isMulSelect;
  final ListSignal<MusicCache> selectedList;
  final bool viewMode;
  final DetailsPageControllerBase baseController;

  const _MusicTile({
    required this.metadata,
    required this.titleStyle,
    required this.highLightTitleStyle,
    required this.subStyle,
    required this.highLightSubStyle,
    required this.audioSource,
    required this.operateArea,
    required this.isMulSelect,
    required this.selectedList,
    required this.viewMode,
    required this.baseController,
  });

  void _onTileTapped() {
    if (isMulSelect.value) {
      final index = selectedList.indexWhere((v) => v.path == metadata.path);
      if (index != -1) {
        selectedList.removeAt(index);
      } else {
        selectedList.add(metadata);
      }
    } else {
      baseController.play(audioSource, metadata: metadata);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying =
        baseController.audioController.currentPath.value == metadata.path;
    final isSelected = selectedList.any((v) => v.path == metadata.path);

    final textStyle = isPlaying ? highLightTitleStyle : titleStyle;
    final subTextStyle = isPlaying ? highLightSubStyle : subStyle;

    return AppButton.ghost(
      onPressed: _onTileTapped,
      selected: isSelected,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: AppSpacing.xl,
        children: [
          if (operateArea == OperateArea.albumDetails)
            Text(
              metadata.trackNumber.toString().padLeft(2, '0'),
              style: subTextStyle,
            ),
          ClipRRect(
            borderRadius: AppRadius.smAll,
            child: LoadLocalOrNetCover(music: metadata, size: AppSize.coverSm),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Text(
                  metadata.title,
                  style: textStyle,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  metadata.artist,
                  style: subTextStyle,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (viewMode)
            Expanded(
              flex: 2,
              child: Text(
                metadata.album,
                style: subTextStyle,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          Text(
            formatTime(totalSeconds: metadata.duration),
            style: subTextStyle,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
