import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/controller/user_playlist_ctrl.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:zerobit_player/custom_widgets/custom_drop_menu.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/field/sort_type.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/tools/details_ctrl_mixin.dart';
import 'package:zerobit_player/tools/func/func_extension.dart';
import 'package:zerobit_player/tools/func/general_style.dart';

import 'edit_embedded_lyrics_dialog.dart';
import 'edit_metadata_dialog.dart';
import 'floating_button.dart';
import 'get_snack_bar.dart';
import 'music_list_tool.dart';

const double _itemHeight = 64.0;
const double _headCoverSize = 240;
const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
const double btnHeight = 42;
const double btnWidth = 42;
const double resViewThresholds = 1100;
const double _menuBtnWidth = 180;
const double _menuBtnHeight = 48;
const double _menuBtnRadius = 0;
const _borderRadius = BorderRadius.all(Radius.circular(4));
final double _dpr = PlatformDispatcher.instance.views.first.devicePixelRatio;

class _MusicMenuController {
  final menuController = MenuController();
  Offset? menuPosition;
  MusicCache? currentMetadata;
  int currentIndex = -1;

  void openMenu({
    required Offset overlayOffset,
    required MusicCache metadata,
    required int index,
  }) {
    menuPosition = overlayOffset;
    currentMetadata = metadata;
    currentIndex = index;
    menuController.open(position: Offset.zero);
  }

  void closeMenu() {
    if (menuController.isOpen) {
      menuController.close();
    }
  }
}

List<Widget> _genMenuItems({
  required BuildContext context,
  required MenuController menuController,
  required MusicCache metadata,
  required String userKey,
  required int index,
  required String operateArea,
  required AudioController ctrl,
  required UserPlayListController playListCtrl,
  required MusicCacheController cacheCtrl,
  bool renderMaybeDel = false,
}) {
  final Widget divider = Divider(
    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
    height: 0.5,
    thickness: 0.5,
  );

  Widget buildMenuBtn({
    required VoidCallback fn,
    required IconData icon,
    required String label,
    String? tooltip,
  }) {
    return CustomBtn(
      fn: () {
        menuController.close();
        fn();
      },
      btnHeight: _menuBtnHeight,
      btnWidth: _menuBtnWidth,
      radius: _menuBtnRadius,
      icon: icon,
      label: label,
      tooltip: tooltip,
      mainAxisAlignment: MainAxisAlignment.start,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  // 数据预处理
  final artistList = metadata.artist.split('/');
  final album = metadata.album;
  final albumWithLetter = cacheCtrl.getLetter(str: album) + album;

  final artistFirst = artistList.first;
  final artistFirstWithLetter =
      cacheCtrl.getLetter(str: artistFirst) + artistFirst;

  return <Widget>[
    buildMenuBtn(
      fn: () => ctrl.insertNext(metadata: metadata),
      icon: PhosphorIconsLight.arrowBendDownRight,
      label: "添加到下一首",
    ),

    EditMetadataDialog(
      menuController: menuController,
      metadata: metadata,
      index: index,
      operateArea: operateArea,
    ),

    EditEmbeddedLyricsDialog(
      menuController: menuController,
      metadata: metadata,
    ),

    divider,

    buildMenuBtn(
      fn:
          () => Get.toNamed(
            AppRoutes.details,
            arguments: {
              'pathList': cacheCtrl.albumItemsDict[albumWithLetter],
              'title': album,
              'operateArea': OperateArea.albumDetails,
            },
            id: 1,
          ),
      icon: PhosphorIconsLight.vinylRecord,
      label: album,
      tooltip: '跳转到 "$album"',
    ),

    if (artistList.length == 1)
      buildMenuBtn(
        fn:
            () => Get.toNamed(
              AppRoutes.details,
              arguments: {
                'pathList': cacheCtrl.artistItemsDict[artistFirstWithLetter],
                'title': artistFirst,
                'operateArea': OperateArea.artistDetails,
              },
              id: 1,
            ),
        icon: PhosphorIconsLight.userFocus,
        label: artistFirst,
        tooltip: '跳转到 "$artistFirst"',
      ),

    if (artistList.length > 1)
      SubmenuButton(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        menuStyle: const MenuStyle(alignment: Alignment.topRight),
        leadingIcon: Icon(
          PhosphorIconsLight.userFocus,
          size: getIconSize(size: 'md'),
        ),
        menuChildren:
            artistList.map((v) {
              return MenuItemButton(
                onPressed: () {
                  menuController.close();
                  Get.toNamed(
                    AppRoutes.details,
                    arguments: {
                      'pathList':
                          cacheCtrl
                              .artistItemsDict[cacheCtrl.getLetter(str: v) + v],
                      'title': v,
                      'operateArea': OperateArea.artistDetails,
                    },
                    id: 1,
                  );
                },
                child: Center(child: Text(v)),
              );
            }).toList(),
        child: const Text('查看艺术家'),
      ),

    divider,

    SubmenuButton(
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      menuStyle: const MenuStyle(alignment: Alignment.topRight),
      leadingIcon: Icon(PhosphorIconsLight.plus, size: getIconSize(size: 'md')),
      menuChildren:
          playListCtrl.allUserKey.map((v) {
            return MenuItemButton(
              onPressed: () {
                menuController.close();
                playListCtrl.addToAudioList(metadata: metadata, userKey: v);
              },
              child: Center(child: Text(v.split('_')[0])),
            );
          }).toList(),
      child: const Text('添加到歌单'),
    ),

    buildMenuBtn(
      fn: () => Process.run('explorer.exe', ['/select,', metadata.path]),
      icon: PhosphorIconsLight.folderOpen,
      label: "打开本地资源",
    ),

    if (renderMaybeDel) ...[
      divider,
      buildMenuBtn(
        fn: () {
          if (userKey.isNotEmpty) {
            playListCtrl.audioRemove(userKey: userKey, metadata: metadata);
          }
        },
        icon: PhosphorIconsLight.trash,
        label: "删除",
      ),
    ],
  ];
}

class AudioGenPages extends StatefulWidget {
  final String title;
  final String operateArea;
  final String audioSource;
  final DetailsPageControllerBase controller;
  final String userKey;
  final Color? backgroundColor;

  const AudioGenPages({
    super.key,
    required this.title,
    required this.operateArea,
    required this.audioSource,
    required this.controller,
    required this.userKey,
    this.backgroundColor,
  });

  @override
  State<AudioGenPages> createState() => _AudioGenPagesState();
}

class _AudioGenPagesState extends State<AudioGenPages> {
  late final RxBool _isMulSelect;
  late final RxList<MusicCache> _selectedList;
  late final MenuController _playListMenuController;
  late final ScrollController _scrollControllerList;
  late final ScrollController _scrollControllerGrid;
  late final SettingController _settingController =
      Get.find<SettingController>();
  late final AudioController _audioController = Get.find<AudioController>();
  late final MusicCacheController _musicCacheController =
      Get.find<MusicCacheController>();
  late final _MusicMenuController _musicMenuCtrl = _MusicMenuController();
  late final UserPlayListController _userPlayListController =
      Get.find<UserPlayListController>();

  late TextStyle _titleStyle;
  late TextStyle _highLightTitleStyle;
  late TextStyle _subStyle;
  late TextStyle _highLightSubStyle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _titleStyle = generalTextStyle(ctx: context, size: 'md');
    _highLightTitleStyle = generalTextStyle(
      ctx: context,
      size: 'md',
      color: Theme.of(context).colorScheme.primary,
    );
    _subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);
    _highLightSubStyle = generalTextStyle(
      ctx: context,
      size: 'sm',
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
    );
  }

  @override
  void initState() {
    super.initState();
    _isMulSelect = false.obs;
    _selectedList = <MusicCache>[].obs;
    _playListMenuController = MenuController();
    _scrollControllerList = ScrollController();
    _scrollControllerGrid = ScrollController();
  }

  @override
  void dispose() {
    _scrollControllerList.dispose();
    _scrollControllerGrid.dispose();

    super.dispose();
  }

  void _playAll() {
    widget.controller.play(widget.audioSource);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          RepaintBoundary(child: _buildHeader()),
          Expanded(child: _buildMusicList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 16,
      children: <Widget>[
        if (widget.operateArea != OperateArea.allMusic &&
            widget.operateArea != OperateArea.foldersDetails)
          _buildHeaderCover(),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                widget.title,
                style: generalTextStyle(
                  ctx: context,
                  size: 'title',
                  weight: FontWeight.w600,
                ),
                softWrap: false,
                overflow: TextOverflow.fade,
                maxLines: 1,
              ),
              Obx(
                () => Text(
                  '共${widget.controller.items.length}首音乐',
                  style: generalTextStyle(ctx: context, size: 'md'),
                ),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCover() {
    final cacheResolution = (_headCoverSize * _dpr).round();
    return ClipRRect(
      borderRadius: _coverBorderRadius,
      child: Obx(() {
        return AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          transitionBuilder:
              (child, anim) => FadeTransition(opacity: anim, child: child),
          child: Image.memory(
            widget.controller.headCover.value,
            key: ValueKey(widget.controller.headCover.value.hashCode),
            cacheWidth: cacheResolution,
            cacheHeight: cacheResolution,
            height: _headCoverSize,
            width: _headCoverSize,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      }),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      spacing: 8,
      children: [
        CustomBtn(
          fn: _playAll.throttle(ms: 500),
          icon: PhosphorIconsLight.play,
          btnHeight: btnHeight,
          btnWidth: 96,
          mainAxisAlignment: MainAxisAlignment.center,
          label: "播放",
          backgroundColor: Theme.of(context).colorScheme.primary,
          contentColor: Theme.of(context).colorScheme.onPrimary,
          overlayColor: Theme.of(context).colorScheme.surfaceContainer,
        ),
        Obx(
          () => AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder:
                (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
            child:
                _isMulSelect.value
                    ? _buildMultiSelectActions()
                    : _buildNormalActions(),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalActions() {
    return Row(
      key: const ValueKey('normal_actions'),
      spacing: 8,
      children: [
        _buildSortButton(),
        Obx(
          () => CustomBtn(
            fn: () {
              _settingController.isReverse.toggle();
              _settingController.putCache();
              widget.controller.itemReverse();
              _audioController.syncCurrentIndex();
            },
            icon:
                _settingController.isReverse.value
                    ? PhosphorIconsLight.arrowDown
                    : PhosphorIconsLight.arrowUp,
            btnHeight: btnHeight,
            btnWidth: btnWidth,
            tooltip: _settingController.isReverse.value ? '降序' : '升序',
          ),
        ),
        Obx(
          () => CustomBtn(
            fn: () {
              _settingController.viewModeMap[widget.operateArea] =
                  !_settingController.viewModeMap[widget.operateArea]!;
              _settingController.putCache();
            },
            icon:
                _settingController.viewModeMap[widget.operateArea]!
                    ? PhosphorIconsLight.listDashes
                    : PhosphorIconsLight.gridFour,
            btnHeight: btnHeight,
            btnWidth: btnWidth,
            tooltip:
                _settingController.viewModeMap[widget.operateArea]!
                    ? "列表视图"
                    : "表格视图",
          ),
        ),
        _buildMultiSelectToggleButton(),
      ],
    );
  }

  Widget _buildMultiSelectActions() {
    return Row(
      key: const ValueKey('multi_select_actions'),
      spacing: 8,
      children: [
        if (widget.operateArea == OperateArea.playListDetails)
          CustomBtn(
            fn: () {
              if (widget.userKey.isNotEmpty) {
                _userPlayListController.audioRemoveAll(
                  userKey: widget.userKey,
                  removeList: [..._selectedList],
                );
                _selectedList.clear();
              }
            },
            icon: PhosphorIconsLight.trash,
            btnHeight: btnHeight,
            btnWidth: btnWidth,
            contentColor: Colors.red,
            tooltip: "删除所选项",
          ),
        _buildAddToPlaylistMenuButton(),
        Obx(
          () => CustomBtn(
            fn: () {
              if (_selectedList.isNotEmpty) {
                _selectedList.clear();
              } else {
                _selectedList.value = [...widget.controller.items];
              }
            },
            icon:
                _selectedList.isNotEmpty
                    ? PhosphorIconsLight.selectionSlash
                    : PhosphorIconsLight.selectionAll,
            btnHeight: btnHeight,
            btnWidth: btnWidth,
            tooltip: _selectedList.isNotEmpty ? '清空选择' : '全选',
          ),
        ),
        _buildMultiSelectToggleButton(),
      ],
    );
  }

  Widget _buildMultiSelectToggleButton() {
    return CustomBtn(
      fn: () {
        _selectedList.clear();
        _isMulSelect.value = !_isMulSelect.value;
      },
      icon:
          _isMulSelect.value
              ? PhosphorIconsLight.xSquare
              : PhosphorIconsLight.selection,
      btnHeight: btnHeight,
      btnWidth: btnWidth,
      tooltip: _isMulSelect.value ? '退出多选' : '多选模式',
    );
  }

  Widget _buildSortButton() {
    final itemMap = <int, List<dynamic>>{
      SortType.title: [
        SettingController.sortType[SortType.title],
        PhosphorIconsRegular.textT,
      ],
      if (widget.operateArea != OperateArea.artistDetails)
        SortType.artist: [
          SettingController.sortType[SortType.artist],
          PhosphorIconsRegular.userFocus,
        ],
      if (widget.operateArea != OperateArea.albumDetails)
        SortType.album: [
          SettingController.sortType[SortType.album],
          PhosphorIconsRegular.vinylRecord,
        ],
      if (widget.operateArea == OperateArea.albumDetails)
        SortType.trackNumber: [
          SettingController.sortType[SortType.trackNumber],
          PhosphorIconsRegular.hash,
        ],
      SortType.duration: [
        SettingController.sortType[SortType.duration],
        PhosphorIconsRegular.clockCountdown,
      ],
      SortType.editTime: [
        SettingController.sortType[SortType.editTime],
        PhosphorIconsRegular.fileMagnifyingGlass,
      ],
      SortType.createTime: [
        SettingController.sortType[SortType.createTime],
        PhosphorIconsRegular.filePlus,
      ],
    };

    return CustomDropdownMenu(
      itemMap: itemMap,
      fn: (entry) {
        _settingController.sortMap[widget.operateArea] = entry.key;
        _settingController.putCache();
        widget.controller.itemReSort(operateArea: widget.operateArea);
        _audioController.syncCurrentIndex();
      },
      label:
          SettingController.sortType[_settingController.sortMap[widget
                  .operateArea]
              as int] ??
          "未指定",
      btnWidth: 148,
      btnHeight: btnHeight,
      itemWidth: 128,
      itemHeight: btnHeight,
      btnIcon: PhosphorIconsLight.funnelSimple,
      mainAxisAlignment: MainAxisAlignment.start,
      spacing: 6,
    );
  }

  Widget _buildAddToPlaylistMenuButton() {
    return MenuAnchor(
      controller: _playListMenuController,
      menuChildren:
          _userPlayListController.allUserKey.map((v) {
            return CustomBtn(
              fn: () {
                _playListMenuController.close();
                _userPlayListController.addAllToAudioList(
                  selectedList: [..._selectedList],
                  userKey: v,
                );
              },
              btnWidth: 160,
              btnHeight: btnHeight,
              label: v.split('_')[0],
              mainAxisAlignment: MainAxisAlignment.center,
              backgroundColor: Colors.transparent,
            );
          }).toList(),
      child: CustomBtn(
        fn: () {
          if (_userPlayListController.allUserKey.isEmpty) {
            showSnackBar(title: "WARNING", msg: "未创建歌单！");
            return;
          }
          if (_selectedList.isEmpty) {
            showSnackBar(title: "WARNING", msg: "未选择任何音乐！");
            return;
          }
          _playListMenuController.open();
        },
        icon: PhosphorIconsLight.plus,
        mainAxisAlignment: MainAxisAlignment.center,
        btnHeight: btnHeight,
        btnWidth: 160,
        label: "添加到歌单",
      ),
    );
  }

  Widget _buildMusicList() {
    return RawMenuAnchor(
      controller: _musicMenuCtrl.menuController,
      consumeOutsideTaps: true,
      overlayBuilder: (context, info) {
        final currentMetadata = _musicMenuCtrl.currentMetadata;
        final position = _musicMenuCtrl.menuPosition;
        if (currentMetadata == null || position == null) {
          return const SizedBox.shrink();
        }

        double left = position.dx + 16;
        double top = position.dy;
        final itemCount =
            widget.operateArea == OperateArea.playListDetails ? 8 : 7;
        if (top + _menuBtnHeight * (itemCount + 1.5) > Get.height) {
          top = top - _menuBtnHeight * itemCount;
        }
        if (left + _menuBtnWidth * 2 > Get.width) {
          left = left - _menuBtnWidth - 16;
        }

        return Positioned(
          top: top,
          left: left,
          child: TapRegion(
            onTapOutside:
                (_) => Future.delayed(
                  const Duration(milliseconds: 100),
                  _musicMenuCtrl.closeMenu,
                ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: _borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              width: _menuBtnWidth,
              child: Column(
                children: _genMenuItems(
                  context: context,
                  menuController: _musicMenuCtrl.menuController,
                  metadata: currentMetadata,
                  userKey: widget.userKey,
                  index: _musicMenuCtrl.currentIndex,
                  renderMaybeDel:
                      widget.operateArea == OperateArea.playListDetails,
                  operateArea: widget.operateArea,
                  ctrl: _audioController,
                  playListCtrl: _userPlayListController,
                  cacheCtrl: _musicCacheController,
                ),
              ),
            ),
          ),
        );
      },
      child: Stack(
        children: [
          Obx(() {
            final viewMode = _settingController.viewModeMap[widget.operateArea];
            return viewMode!
                ? ListView.builder(
                  controller: _scrollControllerList,
                  itemCount: widget.controller.items.length,
                  itemExtent: _itemHeight,
                  cacheExtent: _itemHeight * 2,
                  padding: const EdgeInsets.only(bottom: _itemHeight * 2),
                  addRepaintBoundaries: true,
                  addAutomaticKeepAlives: false,
                  addSemanticIndexes: false,
                  itemBuilder:
                      (context, index) => _buildMusicTile(
                        context,
                        index,
                        _titleStyle,
                        _highLightTitleStyle,
                        _subStyle,
                        _highLightSubStyle,
                        viewMode,
                      ),
                )
                : GridView.builder(
                  controller: _scrollControllerGrid,
                  itemCount: widget.controller.items.length,
                  cacheExtent: _itemHeight * 2,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: context.width < resViewThresholds ? 3 : 4,
                    mainAxisSpacing: 4.0,
                    crossAxisSpacing: 8.0,
                    childAspectRatio: 1.0,
                    mainAxisExtent: _itemHeight,
                  ),
                  padding: const EdgeInsets.only(bottom: _itemHeight * 2),
                  addRepaintBoundaries: true,
                  addAutomaticKeepAlives: false,
                  addSemanticIndexes: false,
                  itemBuilder:
                      (context, index) => _buildMusicTile(
                        context,
                        index,
                        _titleStyle,
                        _highLightTitleStyle,
                        _subStyle,
                        _highLightSubStyle,
                        viewMode,
                      ),
                );
          }),
          FloatingButton(
            scrollControllerList: _scrollControllerList,
            scrollControllerGrid: _scrollControllerGrid,
            operateArea: widget.operateArea,
            controller: widget.controller,
          ),
        ],
      ),
    );
  }

  Widget _buildMusicTile(
    BuildContext context,
    int index,
    TextStyle titleStyle,
    TextStyle highLightTitleStyle,
    TextStyle subStyle,
    TextStyle highLightSubStyle,
    bool viewMode,
  ) {
    final metadata = widget.controller.items[index];
    return GestureDetector(
      key: ValueKey(metadata.path),
      onSecondaryTapDown: (e) {
        RenderBox overlayBox =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        Offset overlayOffset = overlayBox.globalToLocal(e.globalPosition);
        _musicMenuCtrl.openMenu(
          overlayOffset: overlayOffset,
          metadata: metadata,
          index: index,
        );
      },
      child: MusicTile(
        metadata: metadata,
        titleStyle: titleStyle,
        highLightTitleStyle: highLightTitleStyle,
        subStyle: subStyle,
        highLightSubStyle: highLightSubStyle,
        audioSource: widget.audioSource,
        operateArea: widget.operateArea,
        isMulSelect: _isMulSelect,
        selectedList: _selectedList,
        viewMode: viewMode,
        baseBontroller: widget.controller,
      ),
    );
  }
}
