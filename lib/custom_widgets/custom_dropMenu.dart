import 'package:flutter/material.dart';
import 'package:zerobit_player/general_style.dart';
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
    final menuList =
        itemMap.entries.map((entry) {
          return PopupMenuItem<int>(
            padding: EdgeInsets.zero,
            value: entry.key,
            height: itemHeight,
            child: InkWell(
              onTap: () {
                // 记得手动 pop 返回 value
                Navigator.pop(context, entry.key);
                fn(entry);
              },

              child: Container(
                width: itemWidth,
                height: itemHeight,

                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 8,
                  children: [
                    if (entry.value[1] != null)
                      Icon(
                        entry.value[1]! as IconData?,
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                        size:
                            getIconSize(size: 'md'),
                      ),
                    Text(
                      entry.value[0].toString(),
                      style: generalTextStyle(ctx: context,size: 'md'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList();

    return CustomBtn(
        fn: () => _createMenu(context, menuList),
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
              size:
                  getIconSize(size: 'md'),
            ),

          Expanded(
            flex: 1,
            child: Text(
              label,
              style: generalTextStyle(ctx: context,size: 'md'),
            ),
          ),
          Icon(
            PhosphorIconsFill.caretDown,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            size: getIconSize(size: 'sm'),
          ),
        ],
      );
  }

  void _createMenu(BuildContext context, List<PopupMenuItem<int>> menuList) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    showMenu(
      constraints: BoxConstraints(
        minWidth: itemWidth, // 约束最小宽度
        maxWidth: itemWidth, // 约束最大宽度
      ),
      context: context,
      position: RelativeRect.fromRect(
        // 定义菜单锚点区域
        Rect.fromLTWH(
          offset.dx + (renderBox.size.width - itemWidth) / 2, // 水平居中
          offset.dy + 8, // 父组件底部Y坐标
          itemWidth, // 菜单宽度
          0, // 高度由内容决定
        ),
        // 屏幕边界约束
        Offset.zero & MediaQuery.of(context).size,
      ),
      items: menuList,
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius!),
      ),
    );
  }
}
