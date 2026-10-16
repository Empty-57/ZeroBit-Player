import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/play_queue_menu_anchor.dart';
import 'package:zerobit_player/components/side_bar_constant.dart';
import 'package:zerobit_player/components/widget/app_tappable.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';
import 'package:zerobit_player/tools/paint_cache.dart';

final _mainRoutes = AppRoutes.orderMap.keys.toList();

/// 侧栏导航状态
class SidebarNavState {
  /// 页面转场的起始位移。由导航方向决定
  static Offset beginOffset = _forwardOffset;

  static final currentNavigationIndex = signal(0);
  static final navigationIsExtend = signal(true);

  static const Offset _forwardOffset = Offset(0.1, 0.1);
  static const Offset _backwardOffset = Offset(-0.1, -0.1);

  /// 跳转到第 [targetIndex] 个主导航项，并按方向设置转场位移
  static void navigateTo(BuildContext context, int targetIndex) {
    final current = currentNavigationIndex.value;
    if (current == targetIndex) return;

    beginOffset = current >= targetIndex ? _forwardOffset : _backwardOffset;
    context.push(_mainRoutes[targetIndex]);
  }
}

/// 侧栏当前是否展开。
/// 在 [SignalWidget] 或 SignalBuilder 的 build 中调用即可自动订阅。
bool sideBarIsExpanded(BuildContext context) =>
    MediaQuery.sizeOf(context).width > AppBreakpoint.wide &&
    SidebarNavState.navigationIsExtend.value;

/// 窗口是否宽到允许展开侧栏
bool sideBarCanExpand(BuildContext context) =>
    MediaQuery.sizeOf(context).width > AppBreakpoint.wide;

/// 侧栏导航项。
class SideBarBtn extends SignalWidget {
  final String label;
  final IconData icon;
  final int localIndex;

  const SideBarBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.localIndex,
  });

  @override
  Widget build(BuildContext context) {
    final selected = SidebarNavState.currentNavigationIndex.value == localIndex;

    return SideBarItem(
      icon: icon,
      label: label,
      expanded: sideBarIsExpanded(context),
      selected: selected,
      onTap: selected
          ? null
          : () => SidebarNavState.navigateTo(context, localIndex),
    );
  }
}

/// 侧栏项
class SideBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool expanded;
  final bool selected;
  final VoidCallback? onTap;

  /// 覆盖默认提示语。默认收起态提示 [label]、展开态不提示
  final String? tooltip;

  const SideBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.expanded,
    this.selected = false,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final contentColor = selected ? colorScheme.primary : colorScheme.onSurface;

    return AppTappable(
      onTap: onTap,
      background: selected
          ? colorScheme.primary.withValues(alpha: AppAlpha.fill)
          : null,
      hoverBackground: colorScheme.primary.withValues(alpha: AppAlpha.hover),
      padding: const EdgeInsets.only(
        left: SideBarSpec.itemPaddingLeft, // 不需要设置右内边距了
      ),
      child: SizedBox(
        height: SideBarSpec.itemHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: AppSpacing.md,
          children: [
            Tooltip(
              // tooltip必须放在这，不然切换message时会重新构建子树打断AnimatedOpacity过渡
              message: tooltip ?? (expanded ? '' : label),
              child: Icon(icon, color: contentColor, size: AppIconSize.md),
            ),
            Expanded(
              child: AnimatedOpacity(
                duration: AppDuration.normal,
                curve: AppCurve.standard,
                opacity: expanded ? 1.0 : 0.0,
                child: Text(
                  label,
                  style: context.createTextStyle(
                    size: AppFontSize.md,
                    color: contentColor,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  softWrap: false,
                  overflow: TextOverflow.clip,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SideBar extends SignalWidget {
  const SideBar({super.key, required this.btnList});

  final List<Widget> btnList;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settingController = SettingController.instance;
    final expanded = sideBarIsExpanded(context);

    // btnList 的顺序即 SideBarBtn.localIndex 的顺序，指示条据此定位
    final selectedIndex = SidebarNavState.currentNavigationIndex.value.clamp(
      0,
      btnList.isEmpty ? 0 : btnList.length - 1,
    );

    // 只有背景图或透明背景时才真正需要毛玻璃
    final needsBlur =
        settingController.backgroundImagePath.value.isNotEmpty ||
        settingController.useTransparencyBackground.value;

    return ClipRRect(
      borderRadius: SideBarSpec.radiusAll,
      child: BackdropFilter(
        enabled: needsBlur,
        filter: ImageFilterCache.imageFilter(sigma: SideBarSpec.blurSigma),
        child: AnimatedContainer(
          duration: AppDuration.slow,
          curve: AppCurve.standard,
          width: expanded
              ? SideBarSpec.expandedWidth
              : SideBarSpec.collapsedWidth,
          clipBehavior: Clip.hardEdge,
          padding: SideBarSpec.padding,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer.withValues(
              alpha: SideBarSpec.surfaceAlpha,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: SideBarSpec.itemSpacing,
                children: [
                  ...btnList,
                  const Spacer(),
                  _PlayQueueItem(expanded: expanded),
                  _CollapseItem(expanded: expanded),
                ],
              ),
              AnimatedPositioned(
                duration: AppDuration.normal,
                curve: AppCurve.emphasized,
                left: 0,
                top:
                    selectedIndex *
                        (SideBarSpec.itemHeight + SideBarSpec.itemSpacing) +
                    SideBarSpec.indicatorInset,
                height: SideBarSpec.itemHeight - SideBarSpec.indicatorInset * 2,
                width: SideBarSpec.indicatorWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: AppRadius.xsAll,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 播放队列入口
class _PlayQueueItem extends StatelessWidget {
  final bool expanded;

  const _PlayQueueItem({required this.expanded});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PlayQueueMenuAnchor(
      titleStyle: context.createTextStyle(size: AppFontSize.md),
      highLightTitleStyle: context.createTextStyle(
        size: AppFontSize.md,
        color: colorScheme.primary,
      ),
      subStyle: context.createTextStyle(
        size: AppFontSize.sm,
        opacity: AppAlpha.textSecondary,
      ),
      highLightSubStyle: context.createTextStyle(
        size: AppFontSize.sm,
        color: colorScheme.primary.withValues(alpha: AppAlpha.textSecondary),
      ),
      builder: (controller) => SideBarItem(
        icon: PhosphorIconsLight.queue,
        label: '播放队列',
        expanded: expanded,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// 收起 / 展开侧栏
class _CollapseItem extends StatelessWidget {
  final bool expanded;

  const _CollapseItem({required this.expanded});

  @override
  Widget build(BuildContext context) {
    final canExpand = sideBarCanExpand(context);
    final label = expanded ? '收起侧栏' : '展开侧栏';

    return SideBarItem(
      icon: expanded
          ? PhosphorIconsLight.caretLeft
          : PhosphorIconsLight.caretRight,
      label: label,
      expanded: expanded,
      tooltip: canExpand ? null : '窗口宽度不足',
      onTap: canExpand
          ? () => SidebarNavState.navigationIsExtend.value =
                !SidebarNavState.navigationIsExtend.value
          : null,
    );
  }
}
