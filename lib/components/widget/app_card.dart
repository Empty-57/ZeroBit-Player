import 'package:flutter/material.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

import 'app_button/button_shell.dart';

/// 应用级卡片外壳
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 是否加一圈主色描边，用于需要强调的卡片
  final bool emphasized;

  /// 覆盖默认表面色，用于卡片内嵌卡片这类需要区分层级的场合
  final Color? color;

  final Color? hoverBackground;

  final VoidCallback? onTap;

  final BorderRadius borderRadius;
  final double borderWidth;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.emphasized = false,
    this.color,
    this.onTap,
    this.borderRadius = AppRadius.mdAll,
    this.borderWidth = AppSize.hairline,
    this.hoverBackground,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final background =
        color ??
        colorScheme.surfaceContainer.withValues(alpha: AppAlpha.surface);
    final border = Border.all(
      color: emphasized
          ? colorScheme.primary.withValues(alpha: AppAlpha.borderStrong)
          : colorScheme.outlineVariant.withValues(alpha: AppAlpha.border),
      width: borderWidth,
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: borderRadius,
          border: border,
        ),
        child: padding == EdgeInsets.zero
            ? child
            : Padding(padding: padding, child: child),
      );
    }

    return AppTappable(
      onPressed: onTap,
      borderRadius: borderRadius,
      background: background,
      hoverBackground:
          hoverBackground ??
          Color.alphaBlend(
            colorScheme.primary.withValues(alpha: AppAlpha.hover),
            background,
          ),
      border: border,
      child: padding == EdgeInsets.zero
          ? child
          : Padding(padding: padding, child: child),
    );
  }
}
