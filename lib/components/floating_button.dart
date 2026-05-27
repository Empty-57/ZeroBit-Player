import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../controller/details_page_ctrl.dart';
import '../field/operate_area.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import '../tools/func/general_style.dart';

const double _bottom = 96;
const double _radius = 6;
const double _ctrlBtnMinSize = 40.0;
const double _itemHeight = 64.0;
const double _resViewThresholds = 1100;

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
class FloatingButton extends StatefulWidget {
  final ScrollController scrollControllerList;
  final ScrollController scrollControllerGrid;
  final String operateArea;

  const FloatingButton({
    super.key,
    required this.scrollControllerList,
    required this.scrollControllerGrid,
    required this.operateArea,
  });

  @override
  State<FloatingButton> createState() => _FloatingButtonState();
}

class _FloatingButtonState extends State<FloatingButton> {
  final MusicCacheController _musicCacheController =
      Get.find<MusicCacheController>();
  final AudioController _audioController = Get.find<AudioController>();
  late final Worker _jumpWorker;

  @override
  void initState() {
    super.initState();
    // 首次进入页面时，跳转到当前行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _jumpToCurrent(useAnimate: false);
      }
    });

    _jumpWorker = ever(_audioController.currentPath, (_) {
      _jumpToCurrent(useAnimate: false, scrollOnVisible: false);
    });
  }

  @override
  void dispose() {
    _jumpWorker.dispose();
    super.dispose();
  }

  bool _isOffsetVisible(ScrollController controller, double targetOffset) {
    final current = controller.offset; // 当前滚动位置
    final viewport = controller.position.viewportDimension; // 可视区域高度

    return targetOffset >= current && targetOffset <= current + viewport;
  }

  int _getCurrentPlayingIndex() {
    final currentPath = _audioController.currentPath.value;
    if (currentPath.isEmpty) return -1;

    switch (widget.operateArea) {
      case OperateArea.allMusic:
        return _musicCacheController.items.indexWhere(
          (m) => m.path == currentPath,
        );
      default:
        if (Get.isRegistered<DetailsPageController>()) {
          return Get.find<DetailsPageController>().items.indexWhere(
            (v) => v.path == currentPath,
          );
        }
        return -1;
    }
  }

  void _scrollTo(ScrollController ctrl, double to, [bool useAnimate = true]) {
    if (useAnimate) {
      ctrl.animateTo(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        to,
      );
    } else {
      ctrl.jumpTo(to);
    }
  }

  void _jumpToCurrent({bool useAnimate = true, bool scrollOnVisible = true}) {
    if (!mounted) return;

    final index = _getCurrentPlayingIndex();
    if (index < 0) return;

    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return;

    final screenSize = mediaQuery.size;

    // 头部区域的大致高度，用于计算屏幕中间位置
    // 这个值应该与 AudioGenPages 中的头部高度保持一致
    final double headerOffset =
        (widget.operateArea == OperateArea.allMusic ||
                widget.operateArea == OperateArea.foldersDetails)
            ? 280
            : 384;
    final double middleOffset = (screenSize.height - headerOffset) / 2;

    final scrollControllerList = widget.scrollControllerList;
    final scrollControllerGrid = widget.scrollControllerGrid;

    // --- ListView 定位逻辑 ---
    if (scrollControllerList.hasClients &&
        scrollControllerList.position.hasContentDimensions) {
      final double targetOffsetList = (index * _itemHeight - middleOffset)
          .clamp(0.0, scrollControllerList.position.maxScrollExtent);

      if (scrollOnVisible) {
        _scrollTo(scrollControllerList, targetOffsetList, useAnimate);
      } else {
        if (!_isOffsetVisible(
          scrollControllerList,
          targetOffsetList + middleOffset,
        )) {
          _scrollTo(scrollControllerList, targetOffsetList, useAnimate);
        }
      }
    }

    // --- 计算 GridView 的定位逻辑 ---
    if (scrollControllerGrid.hasClients &&
        scrollControllerGrid.position.hasContentDimensions) {
      // 计算列数
      final int crossAxisCount = screenSize.width < _resViewThresholds ? 3 : 4;

      // 计算目标项所在的行号 (从0开始)
      final int targetRow = index ~/ crossAxisCount;

      // 计算 GridView 中每行的高度（包括间距）
      const double rowHeight = _itemHeight + 8;

      // 计算最终的滚动偏移量
      final double targetOffsetGrid = (targetRow * rowHeight - middleOffset)
          .clamp(0.0, scrollControllerGrid.position.maxScrollExtent);

      if (scrollOnVisible) {
        _scrollTo(scrollControllerGrid, targetOffsetGrid, useAnimate);
      } else {
        if (!_isOffsetVisible(
          scrollControllerGrid,
          targetOffsetGrid + middleOffset,
        )) {
          _scrollTo(scrollControllerGrid, targetOffsetGrid, useAnimate);
        }
      }
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
              if (widget.scrollControllerList.hasClients) {
                _scrollTo(widget.scrollControllerList, 0.0);
              }
              if (widget.scrollControllerGrid.hasClients) {
                _scrollTo(widget.scrollControllerGrid, 0.0);
              }
            },
          ),
          _FloatingBtn(
            tooltip: '定位',
            icon: PhosphorIconsLight.diamond,
            onPressed: () => _jumpToCurrent(),
          ),
        ],
      ),
    );
  }
}
