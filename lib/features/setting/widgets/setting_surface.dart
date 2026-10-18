import 'package:flutter/material.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/app_card.dart';
import 'package:zerobit_player/features/setting/widgets/setting_constant.dart';

/// 一个设置行：左侧标题与说明，右侧控件。
class SettingRow extends StatelessWidget {
  final String label;

  /// 补充说明
  final String? description;

  final Widget control;

  const SettingRow({
    super.key,
    required this.label,
    required this.control,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: SettingLayout.rowPadding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: SettingLayout.rowMinHeight,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: SettingLayout.rowGap,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: AppSpacing.xs,
                children: [
                  Text(
                    label,
                    style: context.createTextStyle(size: AppFontSize.md),
                  ),
                  if (description != null)
                    Text(
                      description!,
                      style: context.createTextStyle(
                        size: AppFontSize.sm,
                        opacity: AppAlpha.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            control,
          ],
        ),
      ),
    );
  }
}

/// 一组设置项：组标题 + 一张卡片，卡片内各行以分隔线隔开
class SettingGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingGroup({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dividerColor = colorScheme.outlineVariant.withValues(
      alpha: AppAlpha.border,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: SettingLayout.groupTitleGap,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs),
          child: Text(
            title,
            style: context.createTextStyle(
              size: AppFontSize.sm,
              color: colorScheme.primary,
              weight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        AppCard(
          // 行自带内边距，卡片不再额外留白
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: AppSize.hairline,
                    thickness: AppSize.hairline,
                    color: dividerColor,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Tab 内容的滚动容器
class SettingTabBody extends StatelessWidget {
  final List<Widget> groups;

  const SettingTabBody({super.key, required this.groups});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        right: SettingLayout.scrollbarInset,
        bottom: SettingLayout.contentBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: SettingLayout.groupSpacing,
        children: groups,
      ),
    );
  }
}
