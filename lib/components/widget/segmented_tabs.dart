import 'package:flutter/material.dart';
import 'package:zerobit_player/components/widget/app_tappable.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

/// 分段 Tab 的单项
class SegmentedTabItem {
  final IconData icon;
  final String label;

  const SegmentedTabItem({required this.icon, required this.label});
}

/// 分段式 Tab 栏：等宽分段 + 滑动高亮指示器。
///
/// 指示器用 [AnimatedAlign] + [FractionallySizedBox] 实现：各段等宽，
/// 选中项的对齐系数可由索引线性算出，无需测量布局或维护 AnimationController。
class SegmentedTabs extends StatelessWidget {
  final List<SegmentedTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// 单段宽度
  final double segmentWidth;
  final double height;

  const SegmentedTabs({
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
              // 分段层必须铺满轨道：Stack 的非定位子级只会拿到松约束并贴左上角，
              // 那样每段高度仅等于图标文字的行高，内容贴顶、悬停色块也只有一行高
              Positioned.fill(
                child: Row(
                  // 每段撑满轨道高度，点击与悬停区域才和指示器等大
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
      // 已选中时不再响应点击，省掉一次无效的状态写入
      onTap: isSelected ? null : onTap,
      builder: (context, hovered) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
        duration: AppDuration.normal,
        curve: AppCurve.standard,
        // 用一个 0→1 的进度同时驱动图标与文字，避免两处动画不同步
        builder: (context, t, child) {
          final color = Color.lerp(idleColor, colorScheme.primary, t)!;
          return DecoratedBox(
            decoration: BoxDecoration(
              // 未选中项悬停时给一层淡底，读起来是「候选」而不是「已选」
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
