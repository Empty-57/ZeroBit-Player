import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/play_queue_menu_anchor.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/tools/func/general_style.dart';
import 'package:zerobit_player/tools/paint_cache.dart';

class SidebarNavState {
  static Offset beginOffset = const Offset(0.1, 0.1);
  static final currentNavigationIndex = signal(0);
}

int _oldIndex = 0;

const double _navigationBtnWidth = 200;
const double _navigationBtnHeight = 48;

const double _navigationWidth = 220;
const double _navigationWidthSmall = 64;
const double _resViewThresholds = 1100;

final _mainRoutes = AppRoutes.orderMap.keys.toList();
const _borderRadius = BorderRadius.all(Radius.circular(4));

class SideBarBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final int localIndex;

  const SideBarBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.localIndex,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).colorScheme.secondaryContainer;
    final width = MediaQuery.sizeOf(context).width;
    final c = AudioController.instance;
    return SizedBox(
      width: _navigationBtnWidth,
      height: _navigationBtnHeight,
      child: SignalBuilder(
        builder: (context) {
          final index = SidebarNavState.currentNavigationIndex.value;
          return TextButton(
            onPressed: index != localIndex
                ? () {
                    _oldIndex = index;
                    SidebarNavState.beginOffset = _oldIndex >= localIndex
                        ? const Offset(0.1, 0.1)
                        : const Offset(-0.1, -0.1);
                    context.push(_mainRoutes[localIndex]);
                  }
                : null,
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              backgroundColor: index == localIndex
                  ? backgroundColor
                  : backgroundColor.withValues(alpha: 0),
              padding: const EdgeInsets.only(
                left: 12,
                right: 0,
                top: 8,
                bottom: 8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 8,
                    children: [
                      Tooltip(
                        message: width > _resViewThresholds
                            ? c.navigationIsExtend.value
                                  ? ""
                                  : label
                            : label,
                        child: Icon(
                          icon,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: getIconSize(size: 'md'),
                        ),
                      ),
                      Expanded(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          opacity:
                              (width > _resViewThresholds &&
                                  c.navigationIsExtend.value)
                              ? 1.0
                              : 0.0,
                          child: Text(
                            label,
                            style: generalTextStyle(ctx: context, size: 'md'),
                            softWrap: false,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                      width: 4,
                      height: _navigationBtnHeight - 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: index == localIndex
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.8)
                            : Colors.transparent,
                      ),
                    )
                    .animate()
                    .moveX(duration: 0.ms, end: 8)
                    .animate(target: index == localIndex ? 1 : 0)
                    .fade(duration: 500.ms)
                    .moveY(
                      duration: 300.ms,
                      begin: _oldIndex >= localIndex
                          ? _navigationBtnHeight
                          : -_navigationBtnHeight,
                      end: 0,
                      curve: Curves.easeOutBack,
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SideBar extends StatelessWidget {
  const SideBar({super.key, required this.btnList});

  final List<Widget> btnList;

  @override
  Widget build(BuildContext context) {
    final titleStyle = generalTextStyle(ctx: context, size: 'md');
    final highLightTitleStyle = generalTextStyle(
      ctx: context,
      size: 'md',
      color: Theme.of(context).colorScheme.primary,
    );
    final subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);
    final highLightSubStyle = generalTextStyle(
      ctx: context,
      size: 'sm',
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
    );

    final c = AudioController.instance;

    return SignalBuilder(
      builder: (context) {
        final width = MediaQuery.sizeOf(context).width;
        final isExtend = c.navigationIsExtend.value;
        final targetWidth = width > _resViewThresholds
            ? isExtend
                  ? _navigationWidth
                  : _navigationWidthSmall
            : _navigationWidthSmall;

        return ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: BackdropFilter(
            enabled:
                SettingController
                    .instance
                    .backgroundImagePath
                    .value
                    .isNotEmpty ||
                SettingController.instance.useTransparencyBackground.value,
            filter: ImageFilterCache.imageFilter(sigma: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: targetWidth,
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainer.withValues(alpha: 0.4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6.0,
                children:
                    btnList +
                    <Widget>[
                      const Spacer(),
                      PlayQueueMenuAnchor(
                        titleStyle: titleStyle,
                        highLightTitleStyle: highLightTitleStyle,
                        subStyle: subStyle,
                        highLightSubStyle: highLightSubStyle,
                        builder: (c) {
                          return SizedBox(
                            width: _navigationBtnWidth,
                            height: _navigationBtnHeight,
                            child: TextButton(
                              onPressed: () {
                                if (c.isOpen) {
                                  c.close();
                                } else {
                                  c.open();
                                }
                              },
                              style: TextButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                shape: RoundedRectangleBorder(
                                  borderRadius: _borderRadius,
                                ),
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  right: 0,
                                  top: 8,
                                  bottom: 8,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                spacing: 8,
                                children: [
                                  Tooltip(
                                    message: width > _resViewThresholds
                                        ? isExtend
                                              ? ""
                                              : "播放列表"
                                        : "播放列表",
                                    child: Icon(
                                      PhosphorIconsLight.queue,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      size: getIconSize(size: 'md'),
                                    ),
                                  ),
                                  Expanded(
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      opacity:
                                          (width > _resViewThresholds &&
                                              isExtend)
                                          ? 1.0
                                          : 0.0,
                                      child: Text(
                                        "播放队列",
                                        style: generalTextStyle(
                                          ctx: context,
                                          size: 'md',
                                        ),
                                        softWrap: false,
                                        overflow: TextOverflow.clip,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(
                        width: _navigationBtnWidth,
                        height: _navigationBtnHeight,
                        child: TextButton(
                          onPressed: width > _resViewThresholds
                              ? () {
                                  c.navigationIsExtend.value = !isExtend;
                                }
                              : null,
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(
                              left: 12,
                              right: 0,
                              top: 8,
                              bottom: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 8,
                            children: [
                              Tooltip(
                                message: isExtend
                                    ? width > _resViewThresholds
                                          ? "收起"
                                          : "空间不足"
                                    : width > _resViewThresholds
                                    ? "展开"
                                    : "空间不足",
                                child: Icon(
                                  isExtend && width > _resViewThresholds
                                      ? PhosphorIconsLight.caretLeft
                                      : PhosphorIconsLight.caretRight,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  size: getIconSize(size: 'md'),
                                ),
                              ),
                              Expanded(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  opacity:
                                      (width > _resViewThresholds && isExtend)
                                      ? 1.0
                                      : 0.0,
                                  child: Text(
                                    isExtend ? "收起侧栏" : "",
                                    style: generalTextStyle(
                                      ctx: context,
                                      size: 'md',
                                    ),
                                    softWrap: false,
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
              ),
            ),
          ),
        );
      },
    );
  }
}
