import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/tools/general_style.dart';
import 'package:get/get.dart';

import '../field/app_routes.dart';
import '../getxController/audio_ctrl.dart';

final currentNavigationIndex = 0.obs;

int _oldIndex = 0;

const double _navigationBtnWidth = 220;
const double _navigationBtnHeight = 48;

const double _navigationWidth = 260;
const double _navigationWidthSmall = 64;
const double resViewThresholds = 1100;

final _mainRoutes = AppRoutes.orderMap.keys.toList();

final _playQueueController = MenuController();
final _playQueueScrollController = ScrollController();
final AudioController _audioController = Get.find<AudioController>();
const double _itemHeight = 64;
const _borderRadius = BorderRadius.all(Radius.circular(4));

class CustomNavigationBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final int localIndex;

  const CustomNavigationBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.localIndex,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: _navigationBtnWidth,
        height: _navigationBtnHeight,
        child: Obx(()=>TextButton(
          onPressed:
              currentNavigationIndex.value != localIndex
                  ? () {
                    _oldIndex = currentNavigationIndex.value;
                    currentNavigationIndex.value = localIndex;
                    Get.toNamed(_mainRoutes[localIndex], id: 1);
                  }
                  : null,

          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            backgroundColor:
                currentNavigationIndex.value == localIndex
                    ? Theme.of(
                      context,
                    ).colorScheme.secondaryContainer.withValues(alpha: 1)
                    : Theme.of(
                      context,
                    ).colorScheme.secondaryContainer.withValues(alpha: 0),
            padding: EdgeInsets.only(left: 12, right: 0, top: 8, bottom: 8),
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,

            spacing: 8,

            children: [
              Expanded(
                flex: 1,
                child: Tooltip(
                  message: context.width > resViewThresholds ? "" : label,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 16,

                    children: [
                      Icon(
                        icon,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: getIconSize(size: 'md'),
                      ),

                      if (context.width > resViewThresholds)
                        Text(
                          label,
                          style: generalTextStyle(ctx: context, size: 'md'),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                    width: 4,
                    height: _navigationBtnHeight - 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color:
                          currentNavigationIndex.value == localIndex
                              ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.8)
                              : Colors.transparent,
                    ),
                  )
                  .animate()
                  .moveX(duration: 0.ms, end: 8)
                  .animate(
                    target: currentNavigationIndex.value == localIndex ? 1 : 0,
                  )
                  .fade(duration: 500.ms)
                  .moveY(
                    duration: 300.ms,
                    begin:
                        _oldIndex >= localIndex
                            ? _navigationBtnHeight
                            : -_navigationBtnHeight,
                    end: 0,
                    curve: Curves.easeOutBack,
                  ),
            ],
          ),
        )),
      );
  }
}

class CustomNavigation extends StatelessWidget {
  const CustomNavigation({super.key, required this.btnList});

  final List<Widget> btnList;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:
          context.width > resViewThresholds
              ? _navigationWidth
              : _navigationWidthSmall,
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8.0,

        children:
            btnList +
            <Widget>[
              Expanded(flex: 1, child: Container()),
              MenuAnchor(
                consumeOutsideTap: true,
                menuChildren: [
                  Container(
                    height: Get.height - 200,
                    width: Get.width / 2,
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8.0,
                      children: [
                        Text(
                          "播放队列",
                          style: generalTextStyle(
                            ctx: context,
                            size: 'xl',
                            weight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Obx(() {
                            final items = _audioController.playListCacheItems;
                            return ListView.builder(
                              itemCount: items.length,
                              itemExtent: _itemHeight,
                              cacheExtent: _itemHeight * 1,
                              controller: _playQueueScrollController,
                              padding: EdgeInsets.only(bottom: _itemHeight * 2),
                              itemBuilder: (context, index) {
                                return TextButton(
                                  onPressed: () {
                                    _audioController.audioPlay(
                                      metadata: items[index],
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: _borderRadius,
                                    ),
                                  ),
                                  child: SizedBox.expand(
                                    child: Obx(
                                      () => Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            items[index].title,
                                            style: generalTextStyle(
                                              ctx: context,
                                              size: 'md',
                                              color:
                                                  _audioController
                                                              .currentIndex
                                                              .value ==
                                                          index
                                                      ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                      : null,
                                            ),
                                            softWrap: true,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          Text(
                                            "${items[index].artist} - ${items[index].album}",
                                            style: generalTextStyle(
                                              ctx: context,
                                              size: 'sm',
                                              color:
                                                  _audioController
                                                              .currentIndex
                                                              .value ==
                                                          index
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.8,
                                                          )
                                                      : null,
                                              opacity: 0.8,
                                            ),
                                            softWrap: true,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
                onOpen: () {
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    _playQueueScrollController.jumpTo(
                      (_itemHeight * _audioController.currentIndex.value).clamp(
                        0.0,
                        _playQueueScrollController.position.maxScrollExtent,
                      ),
                    );
                  });
                },
                style: MenuStyle(alignment: Alignment.topRight),
                controller: _playQueueController,
                child: Container(
                  width: _navigationBtnWidth,
                  height: _navigationBtnHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.transparent,
                  ),
                  child: SizedBox(
                    width: _navigationBtnWidth,
                    height: _navigationBtnHeight,
                    child: TextButton(
                    onPressed: () {
                      if (_playQueueController.isOpen) {
                        _playQueueController.close();
                      } else {
                        _playQueueController.open();
                      }
                    },
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 0,
                        top: 8,
                        bottom: 8,
                      ),
                    ),
                    child: Tooltip(
                      message: context.width > resViewThresholds ? "" : "播放队列",
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 16,

                        children: [
                          Icon(
                            PhosphorIconsLight.queue,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: getIconSize(size: 'md'),
                          ),

                          if (context.width > resViewThresholds)
                            Text(
                              "播放队列",
                              style: generalTextStyle(ctx: context, size: 'md'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  ),
                ),
              ),
            ],
      ),
    );
  }
}
