import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../field/operate_area.dart';
import '../getxController/album_list_crl.dart';
import '../getxController/artist_list_ctrl.dart';
import '../getxController/audio_ctrl.dart';
import '../getxController/folders_list_ctrl.dart';
import '../getxController/music_cache_ctrl.dart';
import '../getxController/play_list_ctrl.dart';
import '../tools/general_style.dart';

const double _bottom = 96;
const double _radius = 6;
const double _ctrlBtnMinSize = 40.0;
const double _itemHeight = 64.0;
const double _resViewThresholds = 1100;

final MusicCacheController _musicCacheController = Get.find<MusicCacheController>();
final AudioController _audioController = Get.find<AudioController>();

class _FloatingBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _FloatingBtn({
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(_ctrlBtnMinSize, _ctrlBtnMinSize),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          // backgroundColor: Colors.transparent, // TextButton 默认为透明
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
        child: Icon(icon, size: getIconSize(size: 'lg')),
      ),
    );
  }
}

// --- 主组件 (FloatingButton) ---
class FloatingButton extends StatelessWidget {
  final ScrollController scrollControllerList;
  final ScrollController scrollControllerGrid;
  final String operateArea;

  const FloatingButton({
    super.key,
    required this.scrollControllerList,
    required this.scrollControllerGrid,
    required this.operateArea,
  });

  int _getCurrentPlayingIndex() {
    final currentPath = _audioController.currentPath.value;
    if (currentPath.isEmpty) return -1;

    switch (operateArea) {
      case OperateArea.allMusic:
        return _musicCacheController.items.indexWhere((m) => m.path == currentPath);
      case OperateArea.playList:
        return PlayListController.audioListItems.indexWhere((m) => m.path == currentPath);
      case OperateArea.artistList:
        return ArtistListController.audioListItems.indexWhere((m) => m.path == currentPath);
      case OperateArea.albumList:
        return AlbumListController.audioListItems.indexWhere((m) => m.path == currentPath);
      case OperateArea.foldersList:
        return FoldersListController.audioListItems.indexWhere((m) => m.path == currentPath);
      default:
        return -1;
    }
  }

  void _jumpToCurrent(BuildContext context) {
    final index = _getCurrentPlayingIndex();

    final screenSize = MediaQuery.of(context).size;

    // 头部区域的大致高度，用于计算屏幕中间位置
    // 这个值应该与 AudioGenPages 中的头部高度保持一致
    final double headerOffset = (operateArea == OperateArea.allMusic || operateArea == OperateArea.foldersList) ? 280 : 384;
    final double middleOffset = (screenSize.height - headerOffset) / 2;

    // --- ListView 定位逻辑 ---
    if (scrollControllerList.hasClients) {
      final double targetOffsetList = (index * _itemHeight - middleOffset)
          .clamp(0.0, scrollControllerList.position.maxScrollExtent);
      scrollControllerList.jumpTo(
        targetOffsetList,
      );
    }

    // --- 计算 GridView 的定位逻辑 ---
    if (scrollControllerGrid.hasClients) {
      // 计算列数
      final int crossAxisCount = screenSize.width < _resViewThresholds ? 3 : 4;

      // 计算目标项所在的行号 (从0开始)
      final int targetRow = index ~/ crossAxisCount;

      // 计算 GridView 中每行的高度（包括间距）
      const double rowHeight = _itemHeight+8;

      // 计算最终的滚动偏移量
      final double targetOffsetGrid = (targetRow * rowHeight - middleOffset)
          .clamp(0.0, scrollControllerGrid.position.maxScrollExtent);

      scrollControllerGrid.jumpTo(
        targetOffsetGrid,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: _bottom,
      right: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 4,
        children: [
          _FloatingBtn(
            tooltip: '回到顶部',
            icon: PhosphorIconsFill.arrowLineUp,
            onPressed: () {
              if (scrollControllerList.hasClients) {
                scrollControllerList.jumpTo(0.0);
              }
              if (scrollControllerGrid.hasClients) {
                scrollControllerGrid.jumpTo(0.0);
              }
            },
          ),
          _FloatingBtn(
            tooltip: '定位',
            icon: PhosphorIconsLight.diamond,
            onPressed: () => _jumpToCurrent(context),
          ),
        ],
      ),
    );
  }
}