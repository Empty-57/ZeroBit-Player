import 'package:flutter/material.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

/// 按钮的视觉层级。一个界面里通常只该有一个 [filled]
enum AppButtonStyle {
  /// 主操作：主色实心
  filled,

  /// 次要操作：中性淡底 + 细描边
  tonal,

  /// 行内 / 菜单操作：常态透明，悬停才出底色
  ghost,
}

/// 按钮尺寸档位。高度、字号、图标、内边距成套给出
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

  /// 页头操作栏
  large(
    height: 42.0,
    iconSize: AppIconSize.sm,
    fontSize: AppFontSize.md,
    paddingH: AppSpacing.lg,
  ),

  /// 菜单项：整行可点，通常配合 [AppButtonStyle.ghost] 与左对齐
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

const double _spinnerStroke = 2.0;

/// 应用级按钮组件。
///
/// 只给 [icon] 不给 [label] 时是方形图标按钮，边长等于高度。
/// 设置 [width] 变为固定宽度
/// 设置 [maxWidth] 给予最大约束
class AppButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? label;
  final IconData? icon;

  /// 自定义前置组件，优先于 [icon]
  final Widget? leading;

  /// 尾随内容
  final Widget? trailing;

  /// 自定义静态子组件
  final Widget? child;

  /// Hover 状态动态构建器
  final Widget Function(BuildContext context, bool hovered)? builder;

  final String? tooltip;
  final AppButtonStyle style;
  final AppButtonSize size;

  /// 破坏性操作
  final bool danger;

  /// 选中态，只对 tonal / ghost 生效
  final bool selected;

  /// 加载中：[leading] 位换成转圈、暂停响应
  final bool loading;

  final double? width;
  final double? minWidth;
  final double? maxWidth;

  /// 覆盖档位高度
  final double? height;

  final double? iconSize;
  final MainAxisAlignment alignment;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  /// 前景 / 背景 / Hover 覆盖
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? hoverColor;
  final BoxBorder? border;

  const AppButton({
    super.key,
    required this.onPressed,
    this.label,
    this.icon,
    this.leading,
    this.trailing,
    this.child,
    this.tooltip,
    this.style = AppButtonStyle.tonal,
    this.size = AppButtonSize.medium,
    this.danger = false,
    this.selected = false,
    this.loading = false,
    this.width,
    this.minWidth,
    this.maxWidth,
    this.height,
    this.iconSize,
    this.alignment = MainAxisAlignment.center,
    this.borderRadius = AppRadius.xsAll,
    this.padding,
    this.foregroundColor,
    this.backgroundColor,
    this.hoverColor,
    this.border,
  }) : builder = null;

  /// 响应 Hover 状态的构造函数
  const AppButton.builder({
    super.key,
    required this.onPressed,
    required this.builder,
    this.tooltip,
    this.style = AppButtonStyle.ghost,
    this.size = AppButtonSize.medium,
    this.danger = false,
    this.selected = false,
    this.loading = false,
    this.width,
    this.minWidth,
    this.maxWidth,
    this.height,
    this.iconSize,
    this.alignment = MainAxisAlignment.center,
    this.borderRadius = AppRadius.xsAll,
    this.padding,
    this.foregroundColor,
    this.backgroundColor,
    this.hoverColor,
    this.border,
  }) : label = null,
       icon = null,
       leading = null,
       trailing = null,
       child = null;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (!mounted || _hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  void didUpdateWidget(AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 变为不可点击或加载中时，立即清除悬停高亮
    if (widget.onPressed == null || widget.loading) {
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final theme = Theme.of(context);
    final colors = _resolveColors(theme.colorScheme, enabled);

    // 构建按钮内部内容
    Widget innerContent;
    if (widget.builder != null) {
      innerContent = widget.builder!(context, enabled && _hovered);
    } else if (widget.child != null) {
      innerContent = widget.child!;
    } else {
      innerContent = _buildStandardContent(context, colors);
    }

    // 2. 尺寸与内边距包裹
    final effectiveHeight = widget.height ?? widget.size.height;
    final iconOnly =
        widget.child == null &&
        widget.builder == null &&
        widget.label == null &&
        widget.trailing == null;
    final squareSide = widget.width ?? effectiveHeight;

    final effectivePadding =
        widget.padding ??
        (iconOnly
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(horizontal: widget.size.paddingH));

    Widget content = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: iconOnly
            ? squareSide
            : (widget.width ?? widget.minWidth ?? 0),
        maxWidth: iconOnly
            ? squareSide
            : (widget.width ?? widget.maxWidth ?? double.infinity),
        minHeight: effectiveHeight,
        maxHeight: effectiveHeight,
      ),
      child: Padding(padding: effectivePadding, child: innerContent),
    );

    // 装饰层动画
    final isHovering = enabled && _hovered;
    final activeBg = isHovering
        ? (widget.hoverColor ?? colors.hover)
        : (widget.backgroundColor ?? colors.background);
    final activeBorder =
        widget.border ??
        (colors.border == null
            ? null
            : Border.all(color: colors.border!, width: AppSize.hairline));

    content = AnimatedContainer(
      duration: AppDuration.instant,
      curve: AppCurve.standard,
      decoration: BoxDecoration(
        color: activeBg,
        borderRadius: widget.borderRadius,
        border: activeBorder,
      ),
      child: content,
    );

    // 手势与 Hover 监听
    if (enabled) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    // 提示词包裹
    if (widget.tooltip != null) {
      content = Tooltip(
        message: widget.tooltip!,
        waitDuration: AppDuration.tooltipWait,
        child: content,
      );
    }

    return content;
  }

  /// 构建标准的 [Icon] + [Label] + [Trailing] 行布局
  Widget _buildStandardContent(BuildContext context, _ButtonColors colors) {
    final effectiveIconSize = widget.iconSize ?? widget.size.iconSize;

    final Widget? lead = widget.loading
        ? SizedBox.square(
            dimension: effectiveIconSize,
            child: CircularProgressIndicator(
              strokeWidth: _spinnerStroke,
              color: colors.foreground,
            ),
          )
        : widget.leading ??
              (widget.icon == null
                  ? null
                  : Icon(
                      widget.icon,
                      size: effectiveIconSize,
                      color: colors.foreground,
                    ));

    final canShrink = widget.width != null || widget.maxWidth != null;
    Widget? text;
    if (widget.label != null) {
      text = Text(
        widget.label!,
        style: context.createTextStyle(
          size: widget.size.fontSize,
          color: colors.foreground,
          weight: widget.style == AppButtonStyle.filled
              ? FontWeight.w600
              : FontWeight.w500,
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
      );
      if (canShrink) text = Flexible(child: text);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: widget.alignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: AppSpacing.sm,
      children: [?lead, ?text, ?widget.trailing],
    );
  }

  /// 计算颜色
  _ButtonColors _resolveColors(ColorScheme scheme, bool enabled) {
    final accent = widget.danger ? scheme.error : scheme.primary;
    final disabledForeground = scheme.onSurface.withValues(
      alpha: AppAlpha.textFaint,
    );
    final controlFill = scheme.onSurface.withValues(
      alpha: AppAlpha.controlFill,
    );

    switch (widget.style) {
      case AppButtonStyle.filled:
        if (!enabled) {
          return _ButtonColors(
            background: controlFill,
            foreground: disabledForeground,
          );
        }
        final bg = widget.backgroundColor ?? accent;
        final fg =
            widget.foregroundColor ??
            (widget.danger ? scheme.onError : scheme.onPrimary);
        return _ButtonColors(
          background: bg,
          foreground: fg,
          hover: Color.alphaBlend(
            fg.withValues(alpha: AppAlpha.hoverOnFill),
            bg,
          ),
        );

      case AppButtonStyle.tonal:
        final bg =
            widget.backgroundColor ??
            (widget.selected
                ? scheme.primary.withValues(alpha: AppAlpha.fill)
                : controlFill);
        return _ButtonColors(
          background: bg,
          foreground: enabled
              ? widget.foregroundColor ?? _neutralForeground(scheme)
              : disabledForeground,
          border: widget.selected
              ? scheme.primary.withValues(alpha: AppAlpha.borderStrong)
              : scheme.outlineVariant.withValues(alpha: AppAlpha.controlBorder),
          hover: enabled
              ? Color.alphaBlend(accent.withValues(alpha: AppAlpha.fill), bg)
              : null,
        );

      case AppButtonStyle.ghost:
        final bg =
            widget.backgroundColor ??
            (widget.selected
                ? scheme.primary.withValues(alpha: AppAlpha.fill)
                : null);
        final hoverLayer = accent.withValues(alpha: AppAlpha.fill);
        return _ButtonColors(
          background: bg,
          foreground: enabled
              ? widget.foregroundColor ?? _neutralForeground(scheme)
              : disabledForeground,
          hover: !enabled
              ? null
              : bg == null
              ? hoverLayer
              : Color.alphaBlend(hoverLayer, bg),
        );
    }
  }

  Color _neutralForeground(ColorScheme scheme) {
    if (widget.danger) return scheme.error;
    if (widget.selected) return scheme.primary;
    return scheme.onSurface;
  }
}

class _ButtonColors {
  final Color? background;
  final Color foreground;
  final Color? hover;
  final Color? border;

  const _ButtonColors({
    required this.background,
    required this.foreground,
    this.hover,
    this.border,
  });
}
