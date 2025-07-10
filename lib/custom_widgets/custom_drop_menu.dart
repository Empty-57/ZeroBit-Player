import 'package:flutter/material.dart';
import 'package:zerobit_player/tools/general_style.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'custom_button.dart';

class CustomDropdownMenu<T> extends StatelessWidget {
  final Map<int, List<T>> itemMap;

  final void Function(MapEntry<int, List<T>>) fn;

  final String label;

  final double? btnWidth;
  final double? btnHeight;
  final double itemWidth;
  final double itemHeight;
  final double? spacing;
  final IconData? btnIcon;
  final double? radius;
  final MainAxisAlignment? mainAxisAlignment;

  const CustomDropdownMenu({
    super.key,
    required this.itemMap,
    required this.fn,
    required this.label,
    this.btnWidth,
    this.btnHeight,
    this.spacing,
    required this.itemWidth,
    required this.itemHeight,
    this.btnIcon,
    this.radius = 4,
    this.mainAxisAlignment,
  });

  @override
  Widget build(BuildContext context) {
    final menuController = MenuController();
    final menuList =
        itemMap.entries.map((entry) {
          return CustomBtn(
            fn: () {
              fn(entry);
              menuController.close();
            },
            btnHeight: itemHeight,
            btnWidth: itemWidth,
            radius: 4,
            icon: entry.value[1] as IconData?,
            label: entry.value[0].toString(),
            mainAxisAlignment: MainAxisAlignment.start,
            backgroundColor: Colors.transparent,
          );
        }).toList();

    return MenuAnchor(
      menuChildren: menuList,
      controller: menuController,
      consumeOutsideTap: true,
      child: CustomBtn(
        fn: () {
          if (menuController.isOpen) {
            menuController.close();
          } else {
            menuController.open();
          }
        },
        radius: radius!,
        btnHeight: btnHeight,
        btnWidth: btnWidth,
        mainAxisAlignment: mainAxisAlignment,
        spacing: spacing,

        children: [
          if (btnIcon != null)
            Icon(
              btnIcon!,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              size: getIconSize(size: 'md'),
            ),

          Expanded(
            flex: 1,
            child: Text(
              label,
              style: generalTextStyle(ctx: context, size: 'md'),
            ),
          ),
          Icon(
            PhosphorIconsFill.caretDown,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            size: getIconSize(size: 'sm'),
          ),
        ],
      ),
    );
  }
}
