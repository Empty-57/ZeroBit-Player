import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/audio_page/audio_page_constant.dart';
import 'package:zerobit_player/components/widget/app_tappable.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/tools/details_ctrl_mixin.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

class FloatingButton extends StatefulWidget {
  final ScrollController scrollControllerList;
  final ScrollController scrollControllerGrid;
  final DetailsPageControllerBase controller;
  final int gridColumns;

  const FloatingButton({
    super.key,
    required this.scrollControllerList,
    required this.scrollControllerGrid,
    required this.controller,
    required this.gridColumns,
  });

  @override
  State<FloatingButton> createState() => _FloatingButtonState();
}

class _FloatingButtonState extends State<FloatingButton> {
  final AudioController _audioController = AudioController.instance;
  late final EffectCleanup _jumpWorker;

  @override
  void initState() {
    super.initState();
    _jumpWorker = effect(() {
      _audioController.currentPath.value;
      untracked(() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _jumpToCurrent(useAnimate: false, scrollOnVisible: false);
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _jumpWorker.call();
    super.dispose();
  }

  int _currentPlayingIndex() {
    final currentPath = _audioController.currentPath.value;
    if (currentPath.isEmpty) return -1;
    return widget.controller.items.indexWhere((m) => m.path == currentPath);
  }

  void _scrollTo(ScrollController controller, double to, bool useAnimate) {
    if (!controller.hasClients) return;
    if (useAnimate) {
      controller.animateTo(
        to,
        duration: AudioPageSpec.scrollAnimation,
        curve: AppCurve.standard,
      );
    } else {
      controller.jumpTo(to);
    }
  }

  void _alignToCenter({
    required ScrollController controller,
    required double itemOffset,
    required double itemExtent,
    required bool useAnimate,
    required bool scrollOnVisible,
  }) {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;

    if (!scrollOnVisible) {
      final viewStart = position.pixels;
      final viewEnd = viewStart + position.viewportDimension;
      if (itemOffset >= viewStart && itemOffset + itemExtent <= viewEnd) return;
    }

    final target =
        (itemOffset + itemExtent / 2 - position.viewportDimension / 2).clamp(
          0.0,
          position.maxScrollExtent,
        );
    _scrollTo(controller, target, useAnimate);
  }

  void _jumpToCurrent({bool useAnimate = true, bool scrollOnVisible = true}) {
    if (!mounted) return;

    final index = _currentPlayingIndex();
    if (index < 0) return;

    _alignToCenter(
      controller: widget.scrollControllerList,
      itemOffset: index * AudioPageSpec.itemHeight,
      itemExtent: AudioPageSpec.itemHeight,
      useAnimate: useAnimate,
      scrollOnVisible: scrollOnVisible,
    );

    _alignToCenter(
      controller: widget.scrollControllerGrid,
      itemOffset: (index ~/ widget.gridColumns) * AudioPageSpec.gridRowExtent,
      itemExtent: AudioPageSpec.gridRowExtent,
      useAnimate: useAnimate,
      scrollOnVisible: scrollOnVisible,
    );
  }

  void _backToTop() {
    _scrollTo(widget.scrollControllerList, 0.0, true);
    _scrollTo(widget.scrollControllerGrid, 0.0, true);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: AudioPageSpec.floatingBottom,
      right: AudioPageSpec.floatingRight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: AudioPageSpec.floatingSpacing,
        children: [
          _FloatingBtn(
            tooltip: '回到顶部',
            icon: PhosphorIconsFill.arrowLineUp,
            onPressed: _backToTop,
          ),
          _FloatingBtn(
            tooltip: '定位到当前播放',
            icon: PhosphorIconsRegular.diamond,
            emphasize: true,
            onPressed: _jumpToCurrent,
          ),
        ],
      ),
    );
  }
}

class _FloatingBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  /// 用主色前景
  final bool emphasize;

  const _FloatingBtn({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = colorScheme.surfaceContainerHighest.withValues(
      alpha: AppAlpha.surfaceStrong,
    );

    return AppTappable(
      onTap: onPressed,
      tooltip: tooltip,
      borderRadius: AppRadius.smAll,
      background: background,
      hoverBackground: Color.alphaBlend(
        colorScheme.primary.withValues(alpha: AppAlpha.fill),
        background,
      ),
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: AppAlpha.border),
        width: AppSize.hairline,
      ),
      child: SizedBox.square(
        dimension: AudioPageSpec.floatingButtonSize,
        child: Center(
          child: Icon(
            icon,
            size: AppIconSize.md,
            color: emphasize
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
