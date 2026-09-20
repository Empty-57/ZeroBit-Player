import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

class _JumpSignal {
  final int triggerId;
  final double deltaY;
  const _JumpSignal(this.triggerId, this.deltaY);
}

class SpringListController {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollAreaKey = GlobalKey();

  final ValueNotifier<int> _currentIndex = ValueNotifier(0);

  final Map<int, GlobalKey> _boxKeys = {};

  final ValueNotifier<_JumpSignal> _jumpNotifier = ValueNotifier(
    const _JumpSignal(0, 0.0),
  );

  static const double _anchorPercentage = 0.4;

  int _totalLength = 0;

  static const int _defaultVisibleItemCount = 10;
  int _visibleItemCount = _defaultVisibleItemCount; // 可视区域歌词行的数量的一半

  // 步进延迟，每行之间动画的间隔
  static const int _defaultStepDelay = 26; // ms

  static const Tolerance _springTolerance = Tolerance(
    distance: 0.5, // 离目标位置还有 0.5 逻辑像素时，直接掐断动画设为0
    velocity: 0.1, // 速度极慢时停止
  );

  GlobalKey getBoxKey(int index) =>
      _boxKeys.putIfAbsent(index, () => GlobalKey());

  int? _cachedVisibleItemCount;
  double cachedScreenHeight = 0.0;

  int getVisibleItemCount() {
    final scrollBox = _scrollAreaKey.currentContext?.findRenderObject();
    if (scrollBox is! RenderBox ||
        !scrollBox.hasSize ||
        scrollBox.size.height <= 0 ||
        _totalLength <= 0) {
      cachedScreenHeight = 0.0;
      return _defaultVisibleItemCount;
    }

    final double currentHeight = scrollBox.size.height;

    // 窗口高度基本不变且缓存不为空则使用缓存的值
    if (_cachedVisibleItemCount != null &&
        (cachedScreenHeight - currentHeight).abs() < 0.1) {
      _visibleItemCount = _cachedVisibleItemCount!;
      debugPrint('visibleLine> $_visibleItemCount | hitCache');
      return _visibleItemCount;
    }

    cachedScreenHeight = currentHeight;

    // 只测量距当前行前后5行数据，忽略前面几行
    final int currIndex = _currentIndex.value;
    final int safeIndex = _totalLength > 5 ? 5 : 0;
    final int start = max(safeIndex, currIndex - 5);
    final int end = (start + 10).clamp(0, _totalLength - 1);

    double minHeights = 999;

    for (int i = start; i <= end; i++) {
      final key = _boxKeys[i];
      if (key == null) continue;

      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is RenderBox &&
          renderObject.hasSize &&
          renderObject.size.height.isFinite) {
        final double h = renderObject.size.height;
        if (h > 36) {
          minHeights = min(minHeights, h); // 取最小值保底显示
        }
      }
    }

    if (minHeights < 999) {
      final visibleLineCount = (cachedScreenHeight / minHeights).ceil();
      _visibleItemCount = max((visibleLineCount ~/ 2) + 1, 2);
      _cachedVisibleItemCount = _visibleItemCount;
      debugPrint('visibleLine> $_visibleItemCount | calc');
    }
    return _visibleItemCount;
  }

  void nextLyric(int nextIndex) {
    if (nextIndex >= _totalLength) return;

    final nextBoxKey = getBoxKey(nextIndex);
    double deltaY = 60.0;

    final scrollBox = _scrollAreaKey.currentContext?.findRenderObject();
    final nextBox = nextBoxKey.currentContext?.findRenderObject();

    // 安全校验
    if (scrollBox is RenderBox &&
        scrollBox.hasSize &&
        nextBox is RenderBox &&
        nextBox.hasSize) {
      //计算下一行行相对于滚动区域的高度，用这个相对高度减去锚点高度获取偏移量
      final double nextLocalY = scrollBox
          .globalToLocal(nextBox.localToGlobal(Offset.zero))
          .dy;
      final double anchorY = scrollBox.size.height * _anchorPercentage;
      deltaY = nextLocalY - anchorY;
    }

    // 列表重建后强制对齐
    _currentIndex.value = nextIndex;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }

    _jumpNotifier.value = _JumpSignal(
      _jumpNotifier.value.triggerId + 1,
      deltaY,
    );
  }

  void clearState() {
    _boxKeys.clear();
    _currentIndex.value = 0;
    _jumpNotifier.value = _JumpSignal(_jumpNotifier.value.triggerId + 1, 0);
    _cachedVisibleItemCount = null;
    cachedScreenHeight = 0.0;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  void dispose() {
    _boxKeys.clear();
    _cachedVisibleItemCount = null;
    cachedScreenHeight = 0.0;
    _scrollController.dispose();
    _jumpNotifier.dispose();
    _currentIndex.dispose();
  }
}

class SpringListView extends StatelessWidget {
  final int length;
  final Widget Function(int index) itemBuilder;
  final SpringListController controller;

  const SpringListView({
    super.key,
    required this.length,
    required this.itemBuilder,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    controller._totalLength = length;

    /// 为了防止即将离开可视区域的列表项的滚动动画无效的方案(视觉欺骗)
    /// 将可滚动区域向上下两个方向拉伸一定距离(至少大于deltaY的值) ,使列表项在滚动动画开始的时候还在Layout(布局)内
    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double extraSpace = 300.0; // 向上下两个方向拉伸的距离 至少要大于deltaY的值
          final double screenHeight = constraints.maxHeight; // 视窗真实高度
          final double newHeight = screenHeight + extraSpace * 2; // 视窗拉伸后的高度

          // 重新计算 anchor 百分比
          // 为了在视觉上使锚点仍然保持在屏幕的 controller.anchorPercentage 处
          // 新 anchor算法: 原 anchor 距视窗顶部的位置(targetAnchorPixel)加上extraSpace后 占新视窗的百分比
          final double targetAnchorPixel =
              screenHeight *
              SpringListController._anchorPercentage; // 原 anchor 距离屏幕顶部的距离
          final double newAnchorPercentage =
              (targetAnchorPixel + extraSpace) / newHeight;

          return SizedBox(
            // 将原有的 scrollAreaKey 从 CustomScrollView 移到代表真实屏幕尺寸的外层 SizedBox
            // 保证 deltaY 计算依然精准 (deltaY 不受拉伸影响)
            key: controller._scrollAreaKey,
            width: constraints.maxWidth,
            height: screenHeight,
            child: ClipRect(
              // 裁剪掉超出屏幕的渲染区域
              child: Stack(
                // 这里使用 Stack 是因为要使用 Positioned 脱离组件树（文档流） 并拉伸大小
                clipBehavior: Clip.none, // 让子组件可以超出 Stack
                children: [
                  //如果同时指定了 top 和 bottom，则 height = Stack高度 - top - bottom
                  Positioned(
                    top: -extraSpace, // 往上拉伸 extraSpace 并往上偏移 extraSpace 距离
                    bottom: -extraSpace, // 往下拉伸 extraSpace
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder<int>(
                      valueListenable: controller._currentIndex,
                      builder: (_, index, _) {
                        Key? centerKey;
                        if (controller._totalLength > 0) {
                          final int effectiveIndex = index.clamp(
                            0, // 前奏时也为0
                            controller._totalLength - 1,
                          );
                          centerKey = ValueKey('sliver_$effectiveIndex');
                        }

                        return CustomScrollView(
                          scrollCacheExtent: const ScrollCacheExtent.pixels(
                            200.0,
                          ),
                          controller: controller._scrollController,
                          center: centerKey,
                          anchor: newAnchorPercentage,
                          slivers: [
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: screenHeight * 0.3 + extraSpace,
                              ), // 前后留白区域也要加上拉伸值
                            ),
                            for (int i = 0; i < length; i++)
                              SliverToBoxAdapter(
                                key: ValueKey('sliver_$i'),
                                child: _SpringItem(
                                  index: i,
                                  controller: controller,
                                  boxKey: controller.getBoxKey(i),
                                  child: itemBuilder(i),
                                ),
                              ),
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: screenHeight * 0.3 + extraSpace,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SpringItem extends StatefulWidget {
  final int index;
  final Key boxKey;
  final Widget child;
  final SpringListController controller;

  const _SpringItem({
    required this.index,
    required this.boxKey,
    required this.child,
    required this.controller,
  });

  @override
  State<_SpringItem> createState() => _SpringItemState();
}

class _SpringItemState extends State<_SpringItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _animController;
  int _animTriggerId = 0;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    // 使用无边界控制器，它的 value 直接代表 Y 轴的偏移像素(deltaY)。
    // 控制器在行真正进入动画范围时才创建，避免整首歌词常驻 ticker。
    widget.controller._jumpNotifier.addListener(_onJumpSignal);
  }

  void _onJumpSignal() {
    _triggerAnimation(widget.controller._jumpNotifier.value.deltaY);
  }

  void _triggerAnimation(double deltaY) {
    if (!mounted) return;
    _delayTimer?.cancel();
    final currentTriggerId = ++_animTriggerId;

    final int targetIndex = widget.controller._currentIndex.value;
    final int halfVisible = widget.controller._visibleItemCount;
    final int totalLength = widget.controller._totalLength;

    // 计算当前视窗可见区域大致的起始与结束索引
    // 锚点在 _anchorPercentage 处，所以当前行上方约占 _anchorPercentageb比例行数，下方占 1- _anchorPercentage
    final int linesAbove =
        (halfVisible * 2 * SpringListController._anchorPercentage).ceil();
    final int linesBelow =
        (halfVisible * 2 * (1.0 - SpringListController._anchorPercentage))
            .ceil();

    final int topVisibleIndex = max(0, targetIndex - linesAbove);
    final int bottomVisibleIndex = min(
      totalLength - 1,
      targetIndex + linesBelow,
    );

    // 屏幕外的元素直接归位，不消耗动画资源
    if (deltaY == 0 ||
        widget.index < topVisibleIndex - 1 ||
        widget.index > bottomVisibleIndex + 1) {
      _animController?.value = 0.0;
      return;
    }

    // 当向上/下滚动（deltaY > 0）时：
    // 最上/下方的可见行（topVisibleIndex/bottomVisibleIndex）最先开始弹动（delay = 0），
    // 动态delay，越往下/上的行，delay逐步增加 (stepIndex递增)
    final bool isForward = deltaY >= 0;
    final int stepIndex = isForward
        ? (widget.index - topVisibleIndex)
        : (bottomVisibleIndex - widget.index);

    final int delayMs =
        max(0, stepIndex) * SpringListController._defaultStepDelay;

    // 动画准备阶段：瞬间将元素偏移到 deltaY 的位置
    final needsBuilder = _animController == null;
    final controller = _animController ??= AnimationController.unbounded(
      vsync: this,
    )..value = 0.0;
    if (needsBuilder) {
      setState(() {});
    }
    controller.value = deltaY;

    // 每句歌词行在可视区的位置比例 [0.0,1.0]
    final double positionRatio =
        ((widget.index - topVisibleIndex) /
                max(1, bottomVisibleIndex - topVisibleIndex))
            .clamp(0.0, 1.0);

    if (delayMs > 0) {
      _delayTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted && currentTriggerId == _animTriggerId) {
          _startSimulation(deltaY, positionRatio);
        }
      });
    } else {
      _startSimulation(deltaY, positionRatio);
    }
  }

  void _startSimulation(double deltaY, double positionRatio) {
    // 动态计算刚度(决定回弹的速度)
    // 弹簧振子的周期公式 T=2*pi*sqrt(m/k)
    // m: 质量 ,k: 刚度 ,T: duration
    // 越往下的行，刚度越小
    final double stiffness = (175.0 - (20.0 * positionRatio));

    // 动态计算阻尼比(决定弹性)
    // 越往下的行阻尼越小
    final double dampingRatio = 0.86 - (0.08 * positionRatio);

    final springDesc = SpringDescription.withDampingRatio(
      mass: 1.0,
      stiffness: stiffness,
      ratio: dampingRatio,
    );

    // 创建弹簧物理仿真 (从当前的 deltaY 运动到 0，初始速度为 0)
    final simulation = SpringSimulation(
      springDesc,
      deltaY,
      0.0,
      0.0,
      tolerance: SpringListController._springTolerance, // 加入容差，防止像素抖动
    );

    // 使用物理仿真驱动动画控制器
    _animController?.animateWith(simulation);
  }

  @override
  void dispose() {
    widget.controller._jumpNotifier.removeListener(_onJumpSignal);
    _delayTimer?.cancel();
    _animController?.dispose();
    widget.controller._boxKeys.remove(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _animController;
    if (controller == null) {
      return RepaintBoundary(key: widget.boxKey, child: widget.child);
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, controller.value), // 直接应用物理控制器的值
          child: child,
        );
      },
      child: RepaintBoundary(key: widget.boxKey, child: widget.child),
    );
  }
}
