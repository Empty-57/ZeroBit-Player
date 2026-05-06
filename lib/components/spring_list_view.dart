import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';

class _JumpSignal {
  final int triggerId;
  final double deltaY;
  _JumpSignal(this.triggerId, this.deltaY);
}

class SpringController extends GetxController {
  final ScrollController scrollController = ScrollController();
  final GlobalKey scrollAreaKey = GlobalKey();

  final RxInt currentIndex = 0.obs;

  final Map<int, GlobalKey> sliverKeys = {};
  final Map<int, GlobalKey> boxKeys = {};

  final Rx<_JumpSignal> _jumpSignal = _JumpSignal(0, 0.0).obs;
  final double anchorPercentage = 0.3;

  int totalLength = 0;

  static const double durationMax = 1200;
  static const int delayMax = 60;
  int delay = delayMax;
  double duration = durationMax;

  GlobalKey getSliverKey(int index) =>
      sliverKeys.putIfAbsent(index, () => GlobalKey());
  GlobalKey getBoxKey(int index) => boxKeys.putIfAbsent(
    index,
    () => GlobalKey(),
  ); // 每次center更新的时候，此方法会被重新循环调用

  void nextLyric() async {
    // 如果还没超过一首歌曲的长度，且当前没有被锁定
    if (currentIndex.value < totalLength - 1) {
      final nextIndex = currentIndex.value + 1;
      final nextBoxKey = getBoxKey(nextIndex);
      double deltaY = 60.0;

      if (nextBoxKey.currentContext != null &&
          scrollAreaKey.currentContext != null) {
        final scrollBox =
            scrollAreaKey.currentContext!.findRenderObject() as RenderBox;
        final nextBox =
            nextBoxKey.currentContext!.findRenderObject() as RenderBox;

        //计算下一行行相对于滚动区域的高度，用这个相对高度减去锚点高度获取偏移量
        double nextLocalY =
            scrollBox.globalToLocal(nextBox.localToGlobal(Offset.zero)).dy;
        double anchorY = scrollBox.size.height * anchorPercentage;
        deltaY = nextLocalY - anchorY;
      }

      // 列表重建后强制对齐
      currentIndex.value = nextIndex;
      if (scrollController.hasClients) {
        scrollController.jumpTo(0.0);
      }

      _jumpSignal.value = _JumpSignal(
        _jumpSignal.value.triggerId + 1,
        deltaY,
      ); //发送滚动信号
    }
  }

  void clearState() {
    sliverKeys.clear();
    boxKeys.clear();
    currentIndex.value = 0;
    if (scrollController.hasClients) {
      scrollController.jumpTo(0.0);
    }
  }
}

class SpringListView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final controller = Get.put(SpringController());
    controller.totalLength = length;

    /// 为了防止即将离开可视区域的列表项的滚动动画无效的方案(视觉欺骗)
    /// 将可滚动区域向上下两个方向拉伸一定距离(至少大于deltaY的值) ,使列表项在滚动动画开始的时候还在Layout(布局)内
    return LayoutBuilder(
      builder: (context, constraints) {
        const double extraSpace = 300.0; // 向上下两个方向拉伸的距离 至少要大于deltaY的值
        final double screenHeight = constraints.maxHeight; // 视窗真实高度
        final double newHeight = screenHeight + extraSpace * 2; // 视窗拉伸后的高度

        // 重新计算 anchor 百分比
        // 为了在视觉上使锚点仍然保持在屏幕的 controller.anchorPercentage 处
        // 新 anchor算法: 原 anchor 距视窗顶部的位置(targetAnchorPixel)加上extraSpace后 占新视窗的百分比
        final double targetAnchorPixel =
            screenHeight * controller.anchorPercentage; // 原 anchor 距离屏幕顶部的距离
        final double newAnchorPercentage =
            (targetAnchorPixel + extraSpace) / newHeight;

        return SizedBox(
          // 将原有的 scrollAreaKey 从 CustomScrollView 移到代表真实屏幕尺寸的外层 SizedBox
          // 保证 deltaY 计算依然精准 (deltaY 不受拉伸影响)
          key: controller.scrollAreaKey,
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
                    if (controller.currentIndex.value < lineDuration.length &&
                        controller.currentIndex.value >= 0) {
                      // 原式: controller.delay = lineDuration[controller.currentIndex.value] *1000 / SpringController.durationMax *SpringController.delayMax
                      controller.delay =
                          (lineDuration[controller.currentIndex.value] * 50)
                              .clamp(
                                SpringController.delayMax * 0.2,
                                SpringController.delayMax,
                              )
                              .toInt();
                      controller.duration =
                          (lineDuration[controller.currentIndex.value] * 1000)
                              .clamp(
                                SpringController.durationMax * 0.2,
                                SpringController.durationMax,
                              );
                    } else {
                      controller.duration = SpringController.durationMax;
                    }

                    Key? centerKey;
                    if (controller.totalLength > 0) {
                      int effectiveIndex = controller.currentIndex.value.clamp(
                        0, // 前奏时也为0
                        controller.totalLength - 1,
                      );
                      centerKey = controller.getSliverKey(effectiveIndex);
                    }

                    return CustomScrollView(
                      controller: controller.scrollController,
                      center: centerKey,
                      anchor: newAnchorPercentage, // 使用转换后的锚点比例
                      cacheExtent: 200.0,
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: screenHeight * 0.3 + extraSpace,
                          ), // 前后留白区域也要加上拉伸值
                        ),

                        for (int i = 0; i < length; i++)
                          SliverToBoxAdapter(
                            key: controller.getSliverKey(i),
                            child: _SpringItem(
                              index: i,
                              boxKey: controller.getBoxKey(i),
                              child: itemBuilder(context, i),
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

  double _currentDeltaY = 60.0;
  int _animTriggerId = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: 800.ms);
    _animController.value = 1.0;

    _worker = ever(controller._jumpSignal, (_JumpSignal signal) {
      //监听滚动信号
      _triggerAnimation(signal.deltaY);
    });
  }

  void _triggerAnimation(double deltaY) async {
    if (!mounted) return;

    int relativeIndex =
        (widget.index - controller.currentIndex.value).abs(); //计算相对索引

    // 在屏幕外的元素不执行动画
    if (relativeIndex > 10) {
      setState(() {
        _currentDeltaY = 0.0;
      });
      _animController.value = 1.0;
      return;
    }

    int delayMs = (relativeIndex + 1) * controller.delay;

    setState(() {
      _currentDeltaY = deltaY;
    });

    _animController.value = 0.0; //从偏移位置回到原位
    final currentTriggerId = ++_animTriggerId;

    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs)); //延时启动动画
    }

    if (mounted && currentTriggerId == _animTriggerId) {
      _animController.forward();
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
    return Container(
          key: widget.boxKey,
          child: RepaintBoundary(child: widget.child),
        )
        .animate(controller: _animController, autoPlay: false)
        .moveY(
          begin: _currentDeltaY,
          end: 0,
          duration: controller.duration.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
