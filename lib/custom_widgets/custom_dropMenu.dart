import 'package:flutter/material.dart';
import 'package:zerobit_player/general_style.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'custom_button.dart';

class _DropdownController<T> extends GetxController {
  final selectedValue = Rx<T?>(null);
  final selectedKey = '未选择'.obs;

  void updateSelection(T? newValue, String key) {
    selectedValue.value = newValue;
    selectedKey.value = key;
  }
}

class CustomDropdownMenu<T> extends StatelessWidget {
  final Map<String, List<T>> itemMap;
  final double? btnWidth;
  final double? btnHeight;
  final double itemWidth;
  final double itemHeight;
  final IconData? btnIcon;
  final double? radius;
  final MainAxisAlignment? mainAxisAlignment;

  const CustomDropdownMenu({
    super.key,
    required this.itemMap,
    this.btnWidth,
    this.btnHeight,
    required this.itemWidth,
    required this.itemHeight,
    this.btnIcon,
    this.radius = 4,
    this.mainAxisAlignment,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(_DropdownController());
    final menuList =
        itemMap.entries.map((entry) {
          return PopupMenuItem<T>(
            padding: EdgeInsets.zero,
            value: entry.value[0],
            height: itemHeight,
            child: InkWell(
              onTap: () {
                // 记得手动 pop 返回 value
                Navigator.pop(context, entry.value[0]);
                controller.updateSelection(entry.value[0], entry.key);
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
                      entry.key,
                      style: generalTextStyle(ctx: context,size: 'md'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList();

    return Obx(
      () => CustomBtn(
        fn: () => _createMenu(context, menuList),
        radius: radius!,
        btnHeight: btnHeight,
        btnWidth: btnWidth,
        mainAxisAlignment: mainAxisAlignment,

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
              controller.selectedKey.value.toString(),
              style: generalTextStyle(ctx: context,size: 'md'),
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

  void _createMenu(BuildContext context, List<PopupMenuItem<T>> menuList) {
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
