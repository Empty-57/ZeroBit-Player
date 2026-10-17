import 'package:flutter/material.dart';
import 'package:zerobit_player/components/widget/app_Interaction_widget.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

/// 单段高度
const double _segmentHeight = 32.0;

/// 单段水平内边距
const EdgeInsets _segmentPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.lg,
);

/// 文字分段控件
class AppTextSegmented<T> extends StatelessWidget {
  /// 选项 : 显示文字
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  const AppTextSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: AppAlpha.surfaceSubtle,
        ),
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: AppAlpha.border),
          width: AppSize.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xxs,
          children: [
            for (final entry in options.entries)
              _SegmentChip(
                label: entry.value,
                isSelected: entry.key == value,
                onTap: () => onChanged(entry.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final idleColor = colorScheme.onSurfaceVariant.withValues(
      alpha: AppAlpha.textSecondary,
    );

    return HoverBuilder(
      onPressed: isSelected ? null : onTap,
      builder: (context, hovered) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
        duration: AppDuration.normal,
        curve: AppCurve.standard,
        builder: (context, t, child) => DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: AppAlpha.fillStrong * t)
                : (hovered
                      ? colorScheme.primary.withValues(alpha: AppAlpha.hover)
                      : null),
            borderRadius: AppRadius.xsAll,
            border: Border.all(
              color: colorScheme.primary.withValues(
                alpha: AppAlpha.borderStrong * t,
              ),
              width: AppSize.hairline,
            ),
          ),
          child: SizedBox(
            height: _segmentHeight,
            child: Padding(
              padding: _segmentPadding,
              child: Center(
                child: Text(
                  label,
                  style: context.createTextStyle(
                    size: AppFontSize.sm,
                    color: Color.lerp(idleColor, colorScheme.primary, t),
                    weight: FontWeight.lerp(
                      FontWeight.w400,
                      FontWeight.w600,
                      t,
                    )!,
                  ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
