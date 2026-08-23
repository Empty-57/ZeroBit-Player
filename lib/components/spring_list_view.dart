import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

class _JumpSignal {
  final int triggerId;
  final double deltaY;
  const _JumpSignal(this.triggerId, this.deltaY);
}

class SpringListController extends GetxController {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollAreaKey = GlobalKey();

  final ValueNotifier<int> _currentIndex = ValueNotifier(0);

  final Map<int, GlobalKey> _boxKeys = {};

  final ValueNotifier<_JumpSignal> _jumpNotifier = ValueNotifier(
    const _JumpSignal(0, 0.0),
  );

  static const double _anchorPercentage = 0.4;

  int _totalLength = 0;

  static const int _centerOffset = 0; // 这个常量作用是将滚动开始的中心向上/下偏移，实现弹簧从上/下拉的效果
  static const double _durationMax = 1.5; // sec
  static const int _delayMax = 60; // ms
  int _delay = _delayMax; // ms
  double _duration = _durationMax; // sec

  // 加入容差，防止像素抖动
  static const Tolerance _springTolerance = Tolerance(
    distance: 0.5, // 离目标位置还有 0.5 逻辑像素时，直接掐断动画设为0
    velocity: 0.1, // 速度极慢时停止
  );

  GlobalKey getBoxKey(int index) =>
      _boxKeys.putIfAbsent(index, () => GlobalKey());

  static const int _defaultVisibleItemCount = 10;
  int _visibleItemCount = _defaultVisibleItemCount;

  int? _cachedVisibleItemCount;
  double cachedScreenHeight = 0.0;

  /// 更新动画速率与延迟参数
  void updateDurationAndDelay(int index, List<double> lineDuration) {
    if (index >= 0 && index < lineDuration.length) {
      // 原式: controller.delay = lineDuration[index] *1000 / SpringController.durationMax *SpringController.delayMax
      _delay = (lineDuration[index] * 50)
          .clamp(_delayMax * 0.2, _delayMax.toDouble())
          .toInt();
      _duration = lineDuration[index];
    } else {
      _duration = _durationMax;
      _delay = _delayMax;
    }
  }

  int getVisibleItemCount() {
    final scrollBox = _scrollAreaKey.currentContext?.findRenderObject();
    if (scrollBox is! RenderBox ||
        !scrollBox.hasSize ||
        scrollBox.size.height <= 0 ||
        _totalLength <= 0) {
      return _defaultVisibleItemCount;
    }

    final double currentHeight = scrollBox.size.height;

    // 窗口高度基本不变且缓存不为空则使用缓存的值
    if (_cachedVisibleItemCount != null &&
        (cachedScreenHeight - currentHeight).abs() < 0.1) {
      _visibleItemCount = _cachedVisibleItemCount!;
      debugPrint('visibleLine> $_visibleItemCount | hitCache');
      return _cachedVisibleItemCount!;
    }

    cachedScreenHeight = currentHeight;

    double totalHeight = 0.0;
    int measuredCount = 0;

    // 只测量距当前行前后5行数据
    final int currIndex = _currentIndex.value;
    final int start = (currIndex - 5).clamp(0, _totalLength - 1);
    final int end = (currIndex + 5).clamp(0, _totalLength - 1);

    for (int i = start; i <= end; i++) {
      final key = _boxKeys[i];
      if (key == null) continue;

      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is RenderBox &&
          renderObject.hasSize &&
          renderObject.size.height.isFinite &&
          renderObject.size.height > 0) {
        totalHeight += renderObject.size.height;
        measuredCount++;
      }
    }

    // 降级方案
    if (measuredCount == 0) {
      for (final key in _boxKeys.values) {
        final renderObject = key.currentContext?.findRenderObject();
        if (renderObject is RenderBox &&
            renderObject.hasSize &&
            renderObject.size.height.isFinite &&
            renderObject.size.height > 0) {
          totalHeight += renderObject.size.height;
          measuredCount++;
          if (measuredCount >= _defaultVisibleItemCount) {
            break; // 只测量_defaultVisibleItemCount次
          }
        }
      }
    }

    if (measuredCount == 0) {
      _cachedVisibleItemCount = _defaultVisibleItemCount;
      _visibleItemCount = _defaultVisibleItemCount;
      return _defaultVisibleItemCount;
    }

    final averageItemHeight = (totalHeight / measuredCount).clamp(
      48.0,
      double.infinity,
    );

    final visibleLineCount = (currentHeight / averageItemHeight).ceil();
    final visibleItemCount = max((visibleLineCount ~/ 2) + 2, 5);

    _cachedVisibleItemCount = visibleItemCount;
    _visibleItemCount = visibleItemCount;

    debugPrint('visibleLine> $_visibleItemCount | calc');
    return visibleItemCount;
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
    _cachedVisibleItemCount = null;
    cachedScreenHeight = 0.0;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  @override
  void onClose() {
    _boxKeys.clear();
    _cachedVisibleItemCount = null;
    cachedScreenHeight = 0.0;
    _scrollController.dispose();
    _jumpNotifier.dispose();
    _currentIndex.dispose();
    super.onClose();
  }
}

class SpringListView extends StatelessWidget {
  final int length;
  final List<double> lineDuration;
  final Widget Function(int index) itemBuilder;

  const SpringListView({
    super.key,
    required this.length,
    required this.itemBuilder,
    required this.lineDuration,
  });

  @override
  Widget build(BuildContext context) {
    final SpringListController controller = Get.find();
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
                        controller.updateDurationAndDelay(index, lineDuration);

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

    final int relativeIndex =
        widget.index -
        widget.controller._currentIndex.value +
        SpringListController._centerOffset; //计算相对索引

    final int relativeIndexAbs = relativeIndex.abs();

    // 在屏幕外的元素不执行动画，直接归位
    if (relativeIndexAbs > widget.controller._visibleItemCount) {
      _animController?.value = 0.0;
      return;
    }

    final int delayMs =
        (relativeIndex < 0 && SpringListController._centerOffset != 0)
        ? 0
        : (relativeIndexAbs + 1) * widget.controller._delay;
    final currentTriggerId = ++_animTriggerId;

    // 动画准备阶段：瞬间将元素偏移到 deltaY 的位置
    final needsBuilder = _animController == null;
    final controller = _animController ??= AnimationController.unbounded(
      vsync: this,
    )..value = 0.0;
    if (needsBuilder) {
      setState(() {});
    }
    controller.value = deltaY;

    _delayTimer?.cancel();
    if (delayMs > 0) {
      _delayTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted && currentTriggerId == _animTriggerId) {
          _startSimulation(deltaY);
        }
      });
    } else {
      _startSimulation(deltaY);
    }
  }

  void _startSimulation(double deltaY) {
    // 动态计算刚度 (决定运动快慢)
    // 弹簧振子的周期公式 T=2*pi*sqrt(m/k)
    // m: 质量 ,k: 刚度 ,T: duration
    final double durationSq =
        widget.controller._duration * widget.controller._duration;
    final double stiffness = (200.0 / (durationSq > 0 ? durationSq : 1.0))
        .clamp(100.0, 200.0);

    // 动态计算弹性,duration越大越有弹性
    final double durationProgress =
        (widget.controller._duration / SpringListController._durationMax).clamp(
          0.0,
          1.0,
        );
    final double springRatio = 1.0 - (0.3 * durationProgress); // 区间 [0.7,1.0

    final springDesc = SpringDescription.withDampingRatio(
      mass: 1.0,
      stiffness: stiffness,
      ratio: springRatio,
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
