import 'package:flutter/material.dart';
import 'package:zerobit_player/components/widget/app_tappable.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

/// 通用按钮
class GeneralBtn extends StatelessWidget {
  final VoidCallback? fn;
  final String? label;
  final double? labelSize;
  final IconData? icon;
  final double? iconSize;
  final double? radius;
  final Color? contentColor;
  final Color? backgroundColor;

  /// 悬停时的强调色
  final Color? overlayColor;

  final double? btnWidth;
  final double? btnHeight;
  final double? spacing;
  final EdgeInsets? padding;
  final String? tooltip;
  final MainAxisAlignment? mainAxisAlignment;
  final List<Widget>? children;
  final double? borderWidth;
  final Color? borderColor;

  const GeneralBtn({
    super.key,
    required this.fn,
    this.label,
    this.labelSize,
    this.icon,
    this.iconSize,
    this.radius = AppRadius.xs,
    this.contentColor,
    this.backgroundColor,
    this.overlayColor,
    this.btnWidth = 128,
    this.btnHeight = 48,
    this.spacing = AppSpacing.sm,
    this.padding,
    this.tooltip,
    this.mainAxisAlignment = MainAxisAlignment.spaceAround,
    this.children,
    this.borderWidth = 0,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = fn != null;

    final background =
        backgroundColor ?? colorScheme.secondaryContainer.withValues(alpha: 1);

    final effectiveContentColor = enabled
        ? (contentColor ?? colorScheme.onSecondaryContainer)
        : colorScheme.onSurfaceVariant.withValues(alpha: AppAlpha.textFaint);

    return AppTappable(
      onTap: fn,
      tooltip: tooltip,
      borderRadius: BorderRadius.circular(radius!),
      background: background,
      hoverBackground: Color.alphaBlend(
        (overlayColor ?? colorScheme.primary).withValues(alpha: AppAlpha.hover),
        background,
      ),
      border: borderWidth! > 0
          ? Border.all(
              width: borderWidth!,
              color: borderColor ?? colorScheme.onSecondaryContainer,
            )
          : null,
      child: SizedBox(
        width: btnWidth,
        height: btnHeight,
        child: Padding(
          padding:
              padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: mainAxisAlignment!,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: spacing!,
            children:
                children ??
                [
                  if (icon != null)
                    Icon(
                      icon,
                      color: effectiveContentColor,
                      size: context.getIconSize(iconSize ?? AppIconSize.md),
                    ),
                  if (label != null)
                    Flexible(
                      child: Text(
                        label!,
                        style: context.createTextStyle(
                          size: labelSize ?? AppFontSize.md,
                          color: effectiveContentColor,
                        ),
                        softWrap: false,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                ],
          ),
        ),
      ),
    );
  }
}
