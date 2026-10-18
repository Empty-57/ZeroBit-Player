import 'package:flutter/material.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';

/// 卡片 / 区块的标题行
class StatSectionHeader extends StatelessWidget {
  final String title;
  final String? caption;
  final Widget? trailing;

  const StatSectionHeader({
    super.key,
    required this.title,
    this.caption,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: AppSpacing.lg,
      children: [
        Text(
          title,
          style: context.createTextStyle(
            size: AppFontSize.lg,
            weight: FontWeight.w600,
          ),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
        ),
        if (caption != null)
          Text(
            caption!,
            style: context.createTextStyle(
              size: AppFontSize.sm,
              opacity: AppAlpha.textTertiary,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

/// 主色药丸徽章
class StatPill extends StatelessWidget {
  final String text;
  final IconData? icon;

  const StatPill({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: AppAlpha.fill),
        borderRadius: AppRadius.xsAll,
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: AppAlpha.border),
          width: AppSize.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.sm,
        children: [
          if (icon != null)
            Icon(icon, size: AppIconSize.xs, color: colorScheme.primary),
          Text(
            text,
            style: context.createTextStyle(
              size: AppFontSize.sm,
              color: colorScheme.primary,
              weight: FontWeight.w600,
              tabularFigures: true,
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}
