import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';

/// 应用级通用输入框
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final IconData? icon;
  final Widget? prefix;
  final Widget? suffix;
  final Widget? suffixIcon;
  final bool autofocus;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final BorderRadius borderRadius;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
  final List<TextInputFormatter>? inputFormatters;
  final int? hintMaxLines;
  final TextStyle? style;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.icon,
    this.prefix,
    this.suffix,
    this.suffixIcon,
    this.autofocus = false,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.borderRadius = AppRadius.xsAll,
    this.fillColor,
    this.contentPadding,
    this.inputFormatters,
    this.hintMaxLines,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final effectiveFillColor =
        fillColor ??
        scheme.surfaceContainerHighest.withValues(alpha: AppAlpha.controlFill);

    final border = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: AppAlpha.borderStrong),
        width: AppSize.hairline,
      ),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: scheme.primary, width: AppSize.trackThin),
    );

    final disabledBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: AppAlpha.textFaint),
        width: AppSize.hairline,
      ),
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      enabled: enabled,
      obscureText: obscureText,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: style ?? context.createTextStyle(size: AppFontSize.md),
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.createTextStyle(
          size: AppFontSize.md,
          opacity: AppAlpha.textSecondary,
        ),
        hintText: hintText,
        hintStyle: context.createTextStyle(
          size: AppFontSize.sm,
          opacity: AppAlpha.textFaint,
        ),
        prefixIcon: icon != null
            ? Icon(
                icon,
                size: AppIconSize.sm,
                color: scheme.onSurfaceVariant.withValues(
                  alpha: AppAlpha.textSecondary,
                ),
              )
            : prefix,
        suffix: suffix,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: effectiveFillColor,
        border: border,
        enabledBorder: border,
        focusedBorder: focusedBorder,
        disabledBorder: disabledBorder,
        contentPadding: contentPadding ?? const EdgeInsets.all(AppSpacing.md),
        hintMaxLines: hintMaxLines,
      ),
    );
  }
}
