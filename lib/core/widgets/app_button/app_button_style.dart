import 'package:flutter/material.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';

class AppButtonStyles {
  final Color? background;
  final Color foreground;
  final Color? hover;
  final BoxBorder? border;

  const AppButtonStyles({
    required this.background,
    required this.foreground,
    this.hover,
    this.border,
  });
}

/// 按钮类型
enum AppButtonType {
  filled,
  secondary,
  ghost;

  AppButtonStyles resolve(
    ColorScheme scheme, {
    required bool enabled,
    required bool danger,
    required bool selected,
    Color? bgColor,
    Color? fgColor,
  }) {
    if (!enabled) return _resolveDisabled(scheme);

    return switch (this) {
      filled => _resolveFilled(
        scheme,
        danger: danger,
        bg: bgColor,
        fg: fgColor,
      ),
      secondary => _resolveSecondary(
        scheme,
        danger: danger,
        selected: selected,
        bg: bgColor,
        fg: fgColor,
      ),
      ghost => _resolveGhost(
        scheme,
        danger: danger,
        selected: selected,
        bg: bgColor,
        fg: fgColor,
      ),
    };
  }

  /// 禁用态
  AppButtonStyles _resolveDisabled(ColorScheme scheme) {
    return AppButtonStyles(
      background: this == filled
          ? scheme.onSurface.withValues(alpha: AppAlpha.controlFill)
          : null,
      foreground: scheme.onSurface.withValues(alpha: AppAlpha.textFaint),
    );
  }

  /// 填充按钮
  AppButtonStyles _resolveFilled(
    ColorScheme scheme, {
    required bool danger,
    Color? bg,
    Color? fg,
  }) {
    final effectiveBg = bg ?? (danger ? scheme.error : scheme.primary);
    final effectiveFg = fg ?? (danger ? scheme.onError : scheme.onPrimary);

    return AppButtonStyles(
      background: effectiveBg,
      foreground: effectiveFg,
      hover: Color.alphaBlend(
        effectiveFg.withValues(alpha: AppAlpha.hoverOnFill),
        effectiveBg,
      ),
    );
  }

  /// 次级按钮
  AppButtonStyles _resolveSecondary(
    ColorScheme scheme, {
    required bool danger,
    required bool selected,
    Color? bg,
    Color? fg,
  }) {
    final base = danger ? scheme.error : scheme.primary;

    final effectiveBg =
        bg ??
        (selected
            ? scheme.primary.withValues(alpha: AppAlpha.fill)
            : scheme.surfaceContainerHighest.withValues(
                alpha: AppAlpha.surfaceSubtle,
              ));

    final effectiveFg =
        fg ?? _neutralForeground(scheme, danger: danger, selected: selected);

    final borderColor = selected
        ? scheme.primary.withValues(alpha: AppAlpha.borderStrong)
        : scheme.outlineVariant.withValues(alpha: AppAlpha.border);

    return AppButtonStyles(
      background: effectiveBg,
      foreground: effectiveFg,
      border: Border.all(color: borderColor, width: AppSize.hairline),
      hover: Color.alphaBlend(
        base.withValues(alpha: AppAlpha.hover),
        effectiveBg,
      ),
    );
  }

  /// 透明行内按钮
  AppButtonStyles _resolveGhost(
    ColorScheme scheme, {
    required bool danger,
    required bool selected,
    Color? bg,
    Color? fg,
  }) {
    final base = danger ? scheme.error : scheme.primary;

    final effectiveBg =
        bg ??
        (selected ? scheme.primary.withValues(alpha: AppAlpha.fill) : null);
    final effectiveFg =
        fg ?? _neutralForeground(scheme, danger: danger, selected: selected);

    final hoverOverlay = base.withValues(alpha: AppAlpha.fill);

    return AppButtonStyles(
      background: effectiveBg,
      foreground: effectiveFg,
      hover: effectiveBg == null
          ? hoverOverlay
          : Color.alphaBlend(hoverOverlay, effectiveBg),
    );
  }

  /// [secondary] 和 [ghost] 共用的前景色逻辑
  static Color _neutralForeground(
    ColorScheme scheme, {
    required bool danger,
    required bool selected,
  }) {
    if (danger) return scheme.error;
    if (selected) return scheme.primary;
    return scheme.onSurfaceVariant;
  }
}
