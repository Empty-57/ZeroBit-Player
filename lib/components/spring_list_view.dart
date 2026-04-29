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

  final int delay = 60;
  static const double durationMax = 1200;
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

    return Obx(() {
      if (controller.currentIndex.value < lineDuration.length &&
          controller.currentIndex.value >= 0) {
        controller.duration = (lineDuration[controller.currentIndex.value] *
                    1000 -
                controller.delay)
            .clamp(
              SpringController.durationMax * 0.2,
              SpringController.durationMax,
            );
      } else {
        controller.duration = SpringController.durationMax;
      }

      Key? centerKey;
      if (controller.totalLength > 0 &&
          controller.currentIndex.value >= 0 &&
          controller.currentIndex.value < controller.totalLength) {
        centerKey = controller.getSliverKey(controller.currentIndex.value);
      }
      return CustomScrollView(
        key: controller.scrollAreaKey,
        controller: controller.scrollController,
        center: centerKey,
        anchor: controller.anchorPercentage,
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: context.height * 0.3)),

          for (int i = 0; i < length; i++)
            SliverToBoxAdapter(
              key: controller.getSliverKey(i),
              child: _SpringItem(
                index: i,
                boxKey: controller.getBoxKey(i),
                child: itemBuilder(context, i),
              ),
            ),

          SliverToBoxAdapter(child: SizedBox(height: context.height * 0.3)),
        ],
      );
    });
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
