import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:get/get.dart';

class _JumpSignal {
  final int triggerId;
  final double deltaY;
  _JumpSignal(this.triggerId, this.deltaY);
}

class SpringController extends GetxController {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollAreaKey = GlobalKey();

  final RxInt _currentIndex = 0.obs;

  final Map<int, GlobalKey> _sliverKeys = {};
  final Map<int, GlobalKey> _boxKeys = {};

  final Rx<_JumpSignal> _jumpSignal = _JumpSignal(0, 0.0).obs;
  static const double _anchorPercentage = 0.3;

  int _totalLength = 0;

  static const int _centerOffset = 0; // 这个常量作用是将滚动开始的中心向上/下偏移，实现弹簧从上/下拉的效果
  static const double _durationMax = 1.5; // sec
  static const int _delayMax = 60; // ms
  int _delay = _delayMax; // ms
  double _duration = _durationMax; // sec

  GlobalKey getSliverKey(int index) =>
      _sliverKeys.putIfAbsent(index, () => GlobalKey());
  GlobalKey getBoxKey(int index) => _boxKeys.putIfAbsent(
    index,
    () => GlobalKey(),
  ); // 每次center更新的时候，此方法会被重新循环调用

  void nextLyric(int nextIndex) async {
    // 如果还没超过一首歌曲的长度，且当前没有被锁定
    if (nextIndex < _totalLength - 1) {
      final nextBoxKey = getBoxKey(nextIndex);
      double deltaY = 60.0;

      if (nextBoxKey.currentContext != null &&
          _scrollAreaKey.currentContext != null) {
        final scrollBox =
            _scrollAreaKey.currentContext!.findRenderObject() as RenderBox;
        final nextBox =
            nextBoxKey.currentContext!.findRenderObject() as RenderBox;

        //计算下一行行相对于滚动区域的高度，用这个相对高度减去锚点高度获取偏移量
        double nextLocalY =
            scrollBox.globalToLocal(nextBox.localToGlobal(Offset.zero)).dy;
        double anchorY = scrollBox.size.height * _anchorPercentage;
        deltaY = nextLocalY - anchorY;
      }

      // 列表重建后强制对齐
      _currentIndex.value = nextIndex;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }

      _jumpSignal.value = _JumpSignal(
        _jumpSignal.value.triggerId + 1,
        deltaY,
      ); //发送滚动信号
    }
  }

  void clearState() {
    _sliverKeys.clear();
    _boxKeys.clear();
    _currentIndex.value = 0;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  @override
  void onClose() {
    _sliverKeys.clear();
    _boxKeys.clear();
    _scrollController.dispose();
    super.onClose();
  }
}

class SpringListView extends StatefulWidget {
  final int length;
  final List<double> lineDuration;
  final Widget Function(BuildContext context, int index) itemBuilder;
  const SpringListView({
    super.key,
    required this.length,
    required this.itemBuilder,
    required this.lineDuration,
  });
  @override
  State<SpringListView> createState() => _SpringListViewState();
}

class _SpringListViewState extends State<SpringListView> {
  @override
  void dispose() {
    Get.delete<SpringController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SpringController());
    controller._totalLength = widget.length;

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
              SpringController._anchorPercentage; // 原 anchor 距离屏幕顶部的距离
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
                    child: Obx(() {
                      if (controller._currentIndex.value <
                              widget.lineDuration.length &&
                          controller._currentIndex.value >= 0) {
                        // 原式: controller.delay = lineDuration[controller.currentIndex.value] *1000 / SpringController.durationMax *SpringController.delayMax
                        controller._delay =
                            (widget.lineDuration[controller
                                        ._currentIndex
                                        .value] *
                                    50)
                                .clamp(
                                  SpringController._delayMax * 0.2,
                                  SpringController._delayMax,
                                )
                                .toInt();
                        controller._duration =
                            widget.lineDuration[controller._currentIndex.value];
                      } else {
                        controller._duration = SpringController._durationMax;
                      }

                      Key? centerKey;
                      if (controller._totalLength > 0) {
                        int effectiveIndex = controller._currentIndex.value
                            .clamp(
                              0, // 前奏时也为0
                              controller._totalLength - 1,
                            );
                        centerKey = controller.getSliverKey(effectiveIndex);
                      }

                      return CustomScrollView(
                        controller: controller._scrollController,
                        center: centerKey,
                        anchor: newAnchorPercentage, // 使用转换后的锚点比例
                        cacheExtent: 200.0,
                        slivers: [
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: screenHeight * 0.3 + extraSpace,
                            ), // 前后留白区域也要加上拉伸值
                          ),

                          for (int i = 0; i < widget.length; i++)
                            SliverToBoxAdapter(
                              key: controller.getSliverKey(i),
                              child: _SpringItem(
                                index: i,
                                boxKey: controller.getBoxKey(i),
                                child: widget.itemBuilder(context, i),
                              ),
                            ),

                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: screenHeight * 0.3 + extraSpace,
                            ),
                          ),
                        ],
                      );
                    }),
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
  const _SpringItem({
    required this.index,
    required this.boxKey,
    required this.child,
  });

  @override
  State<_SpringItem> createState() => _SpringItemState();
}

class _SpringItemState extends State<_SpringItem>
    with SingleTickerProviderStateMixin {
  final SpringController controller = Get.find();
  late AnimationController _animController;
  Worker? _worker;

  int _animTriggerId = 0;

  @override
  void initState() {
    super.initState();
    // 使用无边界控制器，它的 value 直接代表 Y 轴的偏移像素(deltaY)
    _animController = AnimationController.unbounded(vsync: this)
      ..value = 0.0; // 0.0 表示在原位

    _worker = ever(controller._jumpSignal, (_JumpSignal signal) {
      //监听滚动信号
      _triggerAnimation(signal.deltaY);
    });
  }

  void _triggerAnimation(double deltaY) async {
    if (!mounted) return;

    final int relativeIndex =
        widget.index -
        controller._currentIndex.value +
        SpringController._centerOffset; //计算相对索引

    final int relativeIndexAbs = relativeIndex.abs();

    // 在屏幕外的元素不执行动画，直接归位
    if (relativeIndexAbs > 10) {
      _animController.value = 0.0;
      return;
    }

    int delayMs =
        relativeIndex < 0 && SpringController._centerOffset != 0
            ? 0
            : (relativeIndexAbs + 1) * controller._delay;
    final currentTriggerId = ++_animTriggerId;

    // 动画准备阶段：瞬间将元素偏移到 deltaY 的位置
    _animController.value = deltaY;

    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs)); //延时启动动画
    }

    if (mounted && currentTriggerId == _animTriggerId) {
      // 动态计算刚度 (决定运动快慢)
      // 弹簧振子的周期公式 T=2*pi*sqrt(m/k)
      // m: 质量 ,k: 刚度 ,T: duration
      double stiffness = 200.0 / (controller._duration * controller._duration);
      stiffness = stiffness.clamp(100.0, 200.0);

      // 动态计算弹性,duration越大越有弹性
      double durationProgress = (controller._duration /
              SpringController._durationMax)
          .clamp(0.0, 1.0);
      double springRatio = 1.0 - (0.3 * durationProgress); // 区间 [0.75,1.0]

      final springDesc = SpringDescription.withDampingRatio(
        mass: 1.0,
        stiffness: stiffness,
        ratio: springRatio,
      );

      // 加入容差，防止像素抖动
      final tolerance = Tolerance(
        distance: 0.5, // 离目标位置还有 0.5 逻辑像素时，直接掐断动画设为0
        velocity: 0.1, // 速度极慢时停止
      );
      // 创建弹簧物理仿真 (从当前的 deltaY 运动到 0，初始速度为 0)
      final simulation = SpringSimulation(
        springDesc,
        deltaY,
        0.0,
        0.0,
        tolerance: tolerance,
      );

      // 使用物理仿真驱动动画控制器
      _animController.animateWith(simulation);
    }
  }

  @override
  void dispose() {
    _worker?.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animController.value), // 直接应用物理控制器的值
          child: child,
        );
      },
      child: Container(
        key: widget.boxKey,
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
