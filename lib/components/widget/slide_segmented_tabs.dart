import 'package:flutter/material.dart';
import 'package:zerobit_player/components/widget/app_interaction_widget.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

/// 分段 Tab 的单项
class SegmentedTabItem {
  final IconData icon;
  final String label;

  const SegmentedTabItem({required this.icon, required this.label});
}

/// 带滑动动画的分段式 Tab 栏
class SlideSegmentedTabs extends StatelessWidget {
  final List<SegmentedTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// 单段宽度
  final double segmentWidth;
  final double height;

  const SlideSegmentedTabs({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.segmentWidth = AppSize.segment,
    this.height = AppSize.button,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = items.length;

    // 把索引映射到 [-1, 1]：-1 贴左、1 贴右，单段时固定居中
    final indicatorX = count > 1 ? selectedIndex / (count - 1) * 2 - 1 : 0.0;

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
      child: SizedBox(
        width: segmentWidth * count + AppSpacing.xxs * 2,
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: AppDuration.normal,
                curve: AppCurve.emphasized,
                alignment: Alignment(indicatorX, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(
                        alpha: AppAlpha.fillStrong,
                      ),
                      borderRadius: AppRadius.xsAll,
                      border: Border.all(
                        color: colorScheme.primary.withValues(
                          alpha: AppAlpha.borderStrong,
                        ),
                        width: AppSize.hairline,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < count; i++)
                    Expanded(
                      child: _Segment(
                        item: items[i],
                        isSelected: i == selectedIndex,
                        onTap: () => onChanged(i),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final SegmentedTabItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _Segment({
    required this.item,
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
        builder: (context, t, child) {
          final color = Color.lerp(idleColor, colorScheme.primary, t)!;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: hovered && !isSelected
                  ? colorScheme.primary.withValues(alpha: AppAlpha.hover)
                  : null,
              borderRadius: AppRadius.xsAll,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Icon(item.icon, size: AppIconSize.sm, color: color),
                Flexible(
                  child: Text(
                    item.label,
                    style: context.createTextStyle(
                      size: AppFontSize.sm,
                      color: color,
                      weight: FontWeight.lerp(
                        FontWeight.w400,
                        FontWeight.w600,
                        t,
                      )!,
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
