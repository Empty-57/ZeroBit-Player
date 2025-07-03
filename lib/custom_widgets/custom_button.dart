import 'package:flutter/material.dart';
import 'package:zerobit_player/tools/general_style.dart';


class CustomBtn<T> extends StatelessWidget {
  final VoidCallback fn;
  final String? label;
  final T? labelSize;
  final IconData? icon;
  final T? iconSize;
  final double? radius;
  final Color? contentColor;
  final Color? backgroundColor;
  final Color? overlayColor;
  final double? btnWidth;
  final double? btnHeight;
  final double? spacing;
  final EdgeInsets? padding;
  final String? tooltip;
  final MainAxisAlignment? mainAxisAlignment;
  final List<Widget>? children;

  const CustomBtn({
    super.key,
    required this.fn,
    this.label,
    this.labelSize,
    this.icon,
    this.iconSize,
    this.radius = 4,
    this.contentColor,
    this.backgroundColor,
    this.overlayColor,
    this.btnWidth=128,
    this.btnHeight=48,
    this.spacing=6,
    this.padding,
    this.tooltip,
    this.mainAxisAlignment = MainAxisAlignment.spaceAround,
    this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip??'',
      child: SizedBox(
        width: btnWidth!,
        height: btnHeight!,
        child: TextButton(
        onPressed: () {
          fn();
        },
        style: TextButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius!),
          ),
          overlayColor: overlayColor,
          backgroundColor: backgroundColor??Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 1),
          padding: padding??EdgeInsets.symmetric(horizontal: 8),
          shadowColor: Colors.transparent,
        ),

        child: Row(
          mainAxisAlignment: mainAxisAlignment!,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: spacing!,

          children:
              children ??
              [
                if (icon != null)
                  Icon(
                    icon!,
                    color:
                        contentColor??Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                    size:
                        getIconSize(size: iconSize??'md'),
                  ),

                if (label != null)
                  Text(
                    label!,
                    style: generalTextStyle(ctx: context,size: labelSize??'md',color: contentColor),
                  ),
              ],
        ),
      ),
      ),
    );
  }
}

