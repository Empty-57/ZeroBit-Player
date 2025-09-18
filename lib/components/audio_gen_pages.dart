import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cache_model.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/tools/func_extension.dart';

import '../custom_widgets/custom_button.dart';
import '../custom_widgets/custom_drop_menu.dart';
import '../field/audio_source.dart';
import '../getxController/audio_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../tools/audio_ctrl_mixin.dart';
import '../tools/general_style.dart';
import '../field/tag_suffix.dart';
import 'edit_metadata_dialog.dart';
import 'floating_button.dart';
import 'get_snack_bar.dart';
import 'music_list_tool.dart';

const double _itemHeight = 64.0;
const double _headCoverSize = 240;
const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
const int _coverBigRenderSize = 800;
const double btnHeight = 42;
const double btnWidth = 42;
const double resViewThresholds = 1100;
const double _menuWidth = 180;
const double _menuHeight = 48;
const double _menuRadius = 0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

final SettingController _settingController = Get.find<SettingController>();
final AudioController _audioController = Get.find<AudioController>();
final AudioSource _audioSource = Get.find<AudioSource>();

class _MusicMenuController extends GetxController {
  final menuController = MenuController();
  final Rxn<Offset> menuPosition = Rxn<Offset>();
  final Rxn<MusicCache> currentMetadata = Rxn<MusicCache>();
  final RxInt currentIndex = (-1).obs;

  void openMenu({
    required Offset overlayOffset,
    required MusicCache metadata,
    required int index,
  }) {
    menuPosition.value = overlayOffset;
    currentMetadata.value = metadata;
    currentIndex.value = index;
    menuController.open(position: Offset.zero);
  }

  void closeMenu() {
    if (menuController.isOpen) {
      menuController.close();
    }
  }
}

final _MusicMenuController _musicMenuCtrl = Get.put(_MusicMenuController());

List<Widget> _genMenuItems({
  required BuildContext context,
  required MenuController menuController,
  required MusicCache metadata,
  required String userKey,
  required int index,
  required String operateArea,
  required List<Widget> playList,
  bool renderMaybeDel = false,
}) {
  final List<Widget> maybeDel = renderMaybeDel
      ? [
          Divider(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
            height: 0.5,
            thickness: 0.5,
          ),
          CustomBtn(
            fn: () async {
              menuController.close();
              await _audioController.audioRemove(
                userKey: userKey,
                metadata: metadata,
              );
            },
            btnHeight: _menuHeight,
            btnWidth: _menuWidth,
            radius: _menuRadius,
            icon: PhosphorIconsLight.trash,
            label: "删除",
            mainAxisAlignment: MainAxisAlignment.start,
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ]
      : [];

  return <Widget>[
    CustomBtn(
      fn: () {
        _audioSource.currentAudioSource.value = userKey;
        menuController.close();
        _audioController.audioPlay(metadata: metadata);
      },
      btnHeight: _menuHeight,
      btnWidth: _menuWidth,
      radius: _menuRadius,
      icon: PhosphorIconsLight.play,
      label: "播放",
      mainAxisAlignment: MainAxisAlignment.start,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    CustomBtn(
      fn: () {
        menuController.close();
        _audioController.insertNext(metadata: metadata);
      },
      btnHeight: _menuHeight,
      btnWidth: _menuWidth,
      radius: _menuRadius,
      icon: PhosphorIconsLight.arrowBendDownRight,
      label: "添加到下一首",
      mainAxisAlignment: MainAxisAlignment.start,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    EditMetadataDialog(
      menuController: menuController,
      metadata: metadata,
      index: index,
      operateArea: operateArea,
    ),
    SubmenuButton(
      style: ButtonStyle(
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
      ),
      menuStyle: const MenuStyle(alignment: Alignment.topRight),
      menuChildren: playList,
      leadingIcon: Icon(PhosphorIconsLight.plus, size: getIconSize(size: 'md')),
      child: const Text('添加到歌单'),
    ),
    CustomBtn(
      fn: () {
        menuController.close();
        Process.run('explorer.exe', ['/select,', metadata.path]);
      },
      btnHeight: _menuHeight,
      btnWidth: _menuWidth,
      radius: _menuRadius,
      icon: PhosphorIconsLight.folderOpen,
      label: "打开本地资源",
      mainAxisAlignment: MainAxisAlignment.start,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    ),
  ] + maybeDel;
}

List<Widget> Function(MusicCache metadata) _playListBuilder = (metadata) {
  return _audioController.allUserKey.map((v) {
    return MenuItemButton(
      onPressed: () {
        _audioController.addToAudioList(metadata: metadata, userKey: v);
      },
      child: Center(child: Text(v.split(TagSuffix.playList)[0])),
    );
  }).toList();
};

class AudioGenPages extends StatefulWidget {
  final String title;
  final String operateArea;
  final String audioSource;
  final AudioControllerGenClass controller;
  final Color? backgroundColor;

  const AudioGenPages({
    super.key,
    required this.title,
    required this.operateArea,
    required this.audioSource,
    required this.controller,
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
    _audioSource.currentAudioSource.value = widget.audioSource;
    if (widget.controller.items.isEmpty) {
      showSnackBar(
        title: "WARNING",
        msg: "此歌单暂无音乐！",
        duration: const Duration(milliseconds: 1500),
      );
      return;
    }
    final metadataToPlay = _settingController.playMode.value == 2
        ? widget.controller.items[Random().nextInt(widget.controller.items.length)]
        : widget.controller.items[0];
    _audioController.audioPlay(metadata: metadataToPlay);
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
          _buildHeader(),
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
        if (widget.operateArea != OperateArea.allMusic&&widget.operateArea != OperateArea.foldersList) _buildHeaderCover(),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                widget.title,
                style: generalTextStyle(ctx: context, size: 'title', weight: FontWeight.w600),
                softWrap: false,
                overflow: TextOverflow.fade,
                maxLines: 1,
              ),
              Obx(() => Text(
                '共${widget.controller.items.length}首音乐',
                style: generalTextStyle(ctx: context, size: 'md'),
              )),
              _buildActionButtons(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCover() {
    return ClipRRect(
      borderRadius: _coverBorderRadius,
      child: Obx(() {
        return AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          transitionBuilder:
              (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
          child: Image.memory(
            widget.controller.headCover.value,
            key: ValueKey(widget.controller.headCover.value.hashCode),
            cacheWidth: _coverBigRenderSize,
            cacheHeight: _coverBigRenderSize,
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
        Obx(() => AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: _isMulSelect.value ? _buildMultiSelectActions() : _buildNormalActions(),
        )),
      ],
    );
  }

  Widget _buildNormalActions() {
    return Row(
      key: const ValueKey('normal_actions'),
      spacing: 8,
      children: [
        _buildSortButton(),
        Obx(() => CustomBtn(
          fn: () {
            _settingController.isReverse.value = !_settingController.isReverse.value;
            _settingController.putCache();
            widget.controller.itemReverse();
            _audioController.syncCurrentIndex();
          },
          icon: _settingController.isReverse.value ? PhosphorIconsLight.arrowDown : PhosphorIconsLight.arrowUp,
          btnHeight: btnHeight,
          btnWidth: btnWidth,
          tooltip: _settingController.isReverse.value ? '降序' : '升序',
        )),
        Obx(() => CustomBtn(
          fn: () {
            _settingController.viewModeMap[widget.operateArea] = !_settingController.viewModeMap[widget.operateArea]!;
            _settingController.putCache();
          },
          icon: _settingController.viewModeMap[widget.operateArea]! ? PhosphorIconsLight.listDashes : PhosphorIconsLight.gridFour,
          btnHeight: btnHeight,
          btnWidth: btnWidth,
          tooltip: _settingController.viewModeMap[widget.operateArea]! ? "列表视图" : "表格视图",
        )),
        _buildMultiSelectToggleButton(),
      ],
    );
  }

  Widget _buildMultiSelectActions() {
    return Row(
      key: const ValueKey('multi_select_actions'),
      spacing: 8,
      children: [
        if (widget.operateArea == OperateArea.playList)
          CustomBtn(
            fn: () {
              _audioController.audioRemoveAll(userKey: widget.audioSource, removeList: [..._selectedList]);
              _selectedList.clear();
            },
            icon: PhosphorIconsLight.trash,
            btnHeight: btnHeight,
            btnWidth: btnWidth,
            contentColor: Colors.red,
            tooltip: "删除所选项",
          ),
        _buildAddToPlaylistMenuButton(),
        Obx(() => CustomBtn(
          fn: () {
            if (_selectedList.isNotEmpty) {
              _selectedList.clear();
            } else {
              _selectedList.value = [...widget.controller.items];
            }
          },
          icon: _selectedList.isNotEmpty ? PhosphorIconsLight.selectionSlash : PhosphorIconsLight.selectionAll,
          btnHeight: btnHeight,
          btnWidth: btnWidth,
          tooltip: _selectedList.isNotEmpty ? '清空选择' : '全选',
        )),
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
      icon: _isMulSelect.value ? PhosphorIconsLight.xSquare : PhosphorIconsLight.selection,
      btnHeight: btnHeight,
      btnWidth: btnWidth,
      tooltip: _isMulSelect.value ? '退出多选' : '多选模式',
    );
  }

  Widget _buildSortButton() {
    final itemMap = {
      0: [SettingController.sortType[0], PhosphorIconsRegular.textT],
      1: [SettingController.sortType[1], PhosphorIconsRegular.userFocus],
      2: [SettingController.sortType[2], PhosphorIconsRegular.vinylRecord],
      3: [SettingController.sortType[3], PhosphorIconsRegular.clockCountdown],
    };
    if (widget.operateArea == OperateArea.artistList) itemMap.remove(1);
    if (widget.operateArea == OperateArea.albumList) itemMap.remove(2);

    return CustomDropdownMenu(
      itemMap: itemMap,
      fn: (entry) {
        _settingController.sortMap[widget.operateArea] = entry.key;
        _settingController.putCache();
        widget.controller.itemReSort(type: entry.key);
        _audioController.syncCurrentIndex();
      },
      label: SettingController.sortType[_settingController.sortMap[widget.operateArea] as int] ?? "未指定",
      btnWidth: 128,
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
      menuChildren: _audioController.allUserKey.map((v) {
        return CustomBtn(
          fn: () {
            _playListMenuController.close();
            _audioController.addAllToAudioList(selectedList: [..._selectedList], userKey: v);
          },
          btnWidth: 160,
          btnHeight: btnHeight,
          label: v.split(TagSuffix.playList)[0],
          mainAxisAlignment: MainAxisAlignment.center,
          backgroundColor: Colors.transparent,
        );
      }).toList(),
      child: CustomBtn(
        fn: () {
          if (_audioController.allUserKey.isEmpty) {
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
    final titleStyle = generalTextStyle(ctx: context, size: 'md');
    final highLightTitleStyle = generalTextStyle(ctx: context, size: 'md', color: Theme.of(context).colorScheme.primary);
    final subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);
    final highLightSubStyle = generalTextStyle(ctx: context, size: 'sm', color: Theme.of(context).colorScheme.primary.withOpacity(0.8));

    return RawMenuAnchor(
      controller: _musicMenuCtrl.menuController,
      consumeOutsideTaps: true,
      overlayBuilder: (context, info) {
        final currentMetadata = _musicMenuCtrl.currentMetadata.value;
        final position = _musicMenuCtrl.menuPosition.value;
        if (currentMetadata == null || position == null) return const SizedBox.shrink();

        double left = position.dx + 16;
        double top = position.dy;
        final itemCount = widget.operateArea == OperateArea.playList ? 6 : 5;
        if (top + _menuHeight * (itemCount + 1.5) > Get.height) {
          top = top - _menuHeight * itemCount;
        }
        if (left + _menuWidth * 2 > Get.width) {
          left = left - _menuWidth - 16;
        }

        return Positioned(
          top: top,
          left: left,
          child: TapRegion(
            onTapOutside: (_) => Future.delayed(const Duration(milliseconds: 100), _musicMenuCtrl.closeMenu),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: _borderRadius,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), offset: const Offset(0, 2), blurRadius: 4)],
              ),
              width: _menuWidth,
              child: Column(
                children: _genMenuItems(
                  context: context,
                  menuController: _musicMenuCtrl.menuController,
                  metadata: currentMetadata,
                  userKey: widget.audioSource,
                  index: _musicMenuCtrl.currentIndex.value,
                  renderMaybeDel: widget.operateArea == OperateArea.playList,
                  operateArea: widget.operateArea,
                  playList: _playListBuilder(currentMetadata),
                ),
              ),
            ),
          ),
        );
      },
      child: Stack(
        children: [
          Obx(() => Offstage(
            offstage: !_settingController.viewModeMap[widget.operateArea]!,
            child: ListView.builder(
              controller: _scrollControllerList,
              itemCount: widget.controller.items.length,
              itemExtent: _itemHeight,
              cacheExtent: _itemHeight * 1,
              padding: const EdgeInsets.only(bottom: _itemHeight * 2),
              itemBuilder: (context, index) => _buildMusicTile(context, index, titleStyle, highLightTitleStyle, subStyle, highLightSubStyle),
            ),
          )),
          Obx(() => Offstage(
            offstage: _settingController.viewModeMap[widget.operateArea]!,
            child: GridView.builder(
              controller: _scrollControllerGrid,
              itemCount: widget.controller.items.length,
              cacheExtent: _itemHeight * 1,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: context.width < resViewThresholds ? 3 : 4,
                mainAxisSpacing: 4.0,
                crossAxisSpacing: 8.0,
                childAspectRatio: 1.0,
                mainAxisExtent: _itemHeight,
              ),
              padding: const EdgeInsets.only(bottom: _itemHeight * 2),
              itemBuilder: (context, index) => _buildMusicTile(context, index, titleStyle, highLightTitleStyle, subStyle, highLightSubStyle),
            ),
          )),
          FloatingButton(
            scrollControllerList: _scrollControllerList,
            scrollControllerGrid: _scrollControllerGrid,
            operateArea: widget.operateArea,
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
  ) {
    final metadata = widget.controller.items[index];
    return GestureDetector(
      onSecondaryTapDown: (e) {
        RenderBox overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
        Offset overlayOffset = overlayBox.globalToLocal(e.globalPosition);
        _musicMenuCtrl.openMenu(
          overlayOffset: overlayOffset,
          metadata: metadata,
          index: index,
        );
      },
      child: MusicTile(
        key: ValueKey(metadata.path),
        metadata: metadata,
        titleStyle: titleStyle,
        highLightTitleStyle: highLightTitleStyle,
        subStyle: subStyle,
        highLightSubStyle: highLightSubStyle,
        audioSource: widget.audioSource,
        operateArea: widget.operateArea,
        isMulSelect: _isMulSelect,
        selectedList: _selectedList,
      ),
    );
  }
}