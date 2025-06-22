import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zerobit_player/tools/general_style.dart';
import 'package:get/get.dart';

import '../field/app_routes.dart';


final currentNavigationIndex = 0.obs;

int _oldIndex = 0;

const double _navigationBtnWidth = 220;
const double _navigationBtnHeight = 52;

const double _navigationWidth = 260;

const mainRoutes = [AppRoutes.home, AppRoutes.userPlayList,AppRoutes.setting];

const Map<String, int> routesMap = {
  AppRoutes.home: 0,
  '/': 0,
  AppRoutes.userPlayList:1,
  AppRoutes.setting: 2,
};

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
    return Obx(
      () => AnimatedContainer(
        width: _navigationBtnWidth,
        height: _navigationBtnHeight,
        duration: 300.ms,

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.transparent,
        ),

        child: TextButton(
          onPressed:
              currentNavigationIndex.value != localIndex
                  ? () {
                    _oldIndex = currentNavigationIndex.value;
                    currentNavigationIndex.value = localIndex;
                    Get.toNamed(mainRoutes[localIndex], id: 1);
                  }
                  : null,

          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            disabledMouseCursor: SystemMouseCursors.click,
            overlayColor:
                Theme.of(context).colorScheme.onSecondaryContainer,
            foregroundColor:
                Theme.of(context).colorScheme.onSecondaryContainer,
            backgroundColor:
                currentNavigationIndex.value == localIndex
                    ? Theme.of(context)
                        .colorScheme.secondaryContainer
                        .withValues(alpha: 1)
                    : Theme.of(context)
                        .colorScheme.secondaryContainer
                        .withValues(alpha: 0),
            padding: EdgeInsets.only(left: 12, right: 0, top: 8, bottom: 8),
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,

            spacing: 8,

            children: [
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 16,

                  children: [
                    Icon(
                      icon,
                      color:
                          Theme.of(
                            context,
                          ).colorScheme.onSurface,
                      size:
                          getIconSize(size: 'md'),
                    ),

                    Text(
                      label,
                      style: generalTextStyle(ctx: context,size: 'md'),
                    ),
                  ],
                ),
              ),
              Container(
                    width: 4,
                    height: _navigationBtnHeight - 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color:
                          currentNavigationIndex.value == localIndex
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.8)
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
        ),
      ),
    );
  }
}

class CustomNavigation extends StatelessWidget {
  const CustomNavigation({super.key, required this.btnList});

  final List<Widget> btnList;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _navigationWidth,
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8.0,

        children: btnList + const <Widget>[],
      ),
    );
  }
}
