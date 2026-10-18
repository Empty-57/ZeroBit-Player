import 'package:flutter/material.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';

import 'app_button_style.dart';
import 'app_tappable.dart';

enum AppButtonSize {
  /// 紧凑：步进器、行内小操作
  small(
    height: 28.0,
    iconSize: AppIconSize.xs,
    fontSize: AppFontSize.sm,
    paddingH: AppSpacing.sm,
  ),

  /// 常规：对话框、设置页、行内操作
  medium(
    height: 36.0,
    iconSize: AppIconSize.sm,
    fontSize: AppFontSize.sm,
    paddingH: AppSpacing.lg,
  ),

  /// 页头操作栏、播放页控制条
  large(
    height: 42.0,
    iconSize: AppIconSize.sm,
    fontSize: AppFontSize.md,
    paddingH: AppSpacing.lg,
  ),

  /// 菜单项
  menuItem(
    height: 48.0,
    iconSize: AppIconSize.md,
    fontSize: AppFontSize.md,
    paddingH: AppSpacing.xl,
  );

  const AppButtonSize({
    required this.height,
    required this.iconSize,
    required this.fontSize,
    required this.paddingH,
  });

  final double height;
  final double iconSize;
  final double fontSize;
  final double paddingH;
}

/// 统一通用按钮组件
class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? label;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final String? tooltip;
  final AppButtonType style;
  final AppButtonSize size;
  final bool danger;
  final bool selected;
  final bool loading;
  final double? width;
  final double? maxWidth;
  final double? minWidth;
  final MainAxisAlignment alignment;
  final EdgeInsetsGeometry? padding;
  final Widget? child;
  final double? height;
  final bool tabularFigures;
  final BorderRadius borderRadius;
  final double spacing;

  const AppButton({
    super.key,
    required this.onPressed,
    this.label,
    this.icon,
    this.leading,
    this.trailing,
    this.tooltip,
    this.style = AppButtonType.secondary,
    this.size = AppButtonSize.medium,
    this.danger = false,
    this.selected = false,
    this.loading = false,
    this.width,
    this.alignment = MainAxisAlignment.center,
    this.padding,
    this.child,
    this.maxWidth,
    this.tabularFigures = false,
    this.height,
    this.borderRadius = AppRadius.xsAll,
    this.spacing = AppSpacing.xs,
    this.minWidth,
  });

  const AppButton.filled({
    super.key,
    required this.onPressed,
    this.label,
    this.icon,
    this.leading,
    this.trailing,
    this.tooltip,
    this.size = AppButtonSize.medium,
    this.loading = false,
    this.width,
    this.alignment = MainAxisAlignment.center,
    this.padding,
    this.maxWidth,
    this.minWidth,
    this.tabularFigures = false,
    this.height,
    this.borderRadius = AppRadius.xsAll,
    this.spacing = AppSpacing.xs,
  }) : style = AppButtonType.filled,
       danger = false,
       selected = false,
       child = null;

  const AppButton.secondary({
    super.key,
    required this.onPressed,
    this.label,
    this.icon,
    this.leading,
    this.trailing,
    this.tooltip,
    this.size = AppButtonSize.medium,
    this.selected = false,
    this.loading = false,
    this.width,
    this.alignment = MainAxisAlignment.center,
    this.padding,
    this.maxWidth,
    this.minWidth,
    this.tabularFigures = false,
    this.height,
    this.borderRadius = AppRadius.xsAll,
    this.spacing = AppSpacing.xs,
    this.child,
  }) : style = AppButtonType.secondary,
       danger = false;

  const AppButton.ghost({
    super.key,
    required this.onPressed,
    this.label,
    this.icon,
    this.leading,
    this.trailing,
    this.tooltip,
    this.size = AppButtonSize.medium,
    this.selected = false,
    this.loading = false,
    this.width,
    this.alignment = MainAxisAlignment.center,
    this.padding,
    this.maxWidth,
    this.minWidth,
    this.tabularFigures = false,
    this.height,
    this.borderRadius = AppRadius.xsAll,
    this.spacing = AppSpacing.xs,
    this.child,
    this.danger = false,
  }) : style = AppButtonType.ghost;

  const AppButton.danger({
    super.key,
    required this.onPressed,
    this.label,
    this.icon,
    this.leading,
    this.trailing,
    this.tooltip,
    this.size = AppButtonSize.medium,
    this.loading = false,
    this.width,
    this.alignment = MainAxisAlignment.center,
    this.padding,
    this.maxWidth,
    this.minWidth,
    this.tabularFigures = false,
    this.height,
    this.borderRadius = AppRadius.xsAll,
    this.spacing = AppSpacing.xs,
  }) : style = AppButtonType.filled,
       danger = true,
       selected = false,
       child = null;

  const AppButton.icon({
    super.key,
    required this.onPressed,
    required IconData this.icon,
    this.tooltip,
    this.style = AppButtonType.ghost,
    this.size = AppButtonSize.medium,
    this.danger = false,
    this.selected = false,
    this.loading = false,
    this.height,
    this.borderRadius = AppRadius.xsAll,
  }) : label = null,
       leading = null,
       trailing = null,
       width = null,
       maxWidth = null,
       minWidth = null,
       alignment = MainAxisAlignment.center,
       child = null,
       padding = EdgeInsets.zero,
       tabularFigures = false,
       spacing = 0;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    final colors = style.resolve(
      Theme.of(context).colorScheme,
      enabled: enabled,
      danger: danger,
      selected: selected,
    );

    final isIconOnly =
        label == null &&
        trailing == null &&
        icon != null &&
        leading == null &&
        child == null;
    final effectiveHeight = height ?? (child == null ? size.height : null);

    final hasBoundedWidth = width != null || maxWidth != null;

    Widget body =
        child ??
        Row(
          mainAxisSize: hasBoundedWidth ? .max : .min,
          mainAxisAlignment: alignment,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: spacing,
          children: [
            if (loading)
              SizedBox.square(
                dimension: size.iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.foreground,
                ),
              )
            else if (leading != null)
              leading!
            else if (icon != null)
              Icon(icon, size: size.iconSize, color: colors.foreground),
            if (label != null)
              Flexible(
                child: Text(
                  label!,
                  style: context.createTextStyle(
                    size: size.fontSize,
                    color: colors.foreground,
                    weight: style == AppButtonType.filled
                        ? FontWeight.w600
                        : FontWeight.w500,
                    tabularFigures: tabularFigures,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
            ?trailing,
          ],
        );

    // 样式继承
    body = DefaultTextStyle(
      style: context.createTextStyle(
        size: size.fontSize,
        color: colors.foreground,
      ),
      child: IconTheme(
        data: IconThemeData(color: colors.foreground, size: size.iconSize),
        child: body,
      ),
    );

    final double minW;
    final double maxW;

    if (isIconOnly) {
      minW = effectiveHeight!;
      maxW = effectiveHeight;
    } else if (width != null) {
      minW = width!;
      maxW = width!;
    } else {
      minW = minWidth ?? 0.0;
      maxW = maxWidth ?? double.infinity;
    }

    final minH = effectiveHeight ?? 0.0;
    final maxH = effectiveHeight ?? double.infinity;

    // 施加尺寸约束
    body = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minW,
        maxWidth: maxW,
        minHeight: minH,
        maxHeight: maxH,
      ),
      child: Padding(
        padding: isIconOnly
            ? EdgeInsets.zero
            : (padding ?? EdgeInsets.symmetric(horizontal: size.paddingH)),
        child: body,
      ),
    );

    return AppTappable(
      onPressed: loading ? null : onPressed,
      tooltip: tooltip,
      background: colors.background,
      hoverBackground: colors.hover,
      borderRadius: borderRadius,
      border: colors.border,
      child: body,
    );
  }
}
