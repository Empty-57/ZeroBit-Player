import 'package:flutter/material.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

import 'general_btn.dart';

/// 对话框通用尺寸
abstract final class AppDialogSpec {
  /// 常规对话框相对窗口的尺寸
  static const double widthFactor = 0.5;
  static const double heightFactor = 0.5;

  /// 对话框内列表的行高
  static const double listRowHeight = 38.0;

  /// 对话框内搜索框高度
  static const double searchFieldHeight = 38.0;
}

/// 应用级对话框外壳。
class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;

  /// 自定义底部操作区
  final Widget? footer;

  /// 宽度比例，null 时自适应
  final double? widthFactor;

  /// 高度比例，null 时自适应
  final double? heightFactor;

  /// 内容区与底部/边缘的间距控制
  final EdgeInsetsGeometry contentPadding;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.footer,
    this.widthFactor = AppDialogSpec.widthFactor,
    this.heightFactor = AppDialogSpec.heightFactor,
    this.contentPadding = const EdgeInsets.only(top: AppSpacing.sm),
  });

  factory AppDialog.confirm({
    Key? key,
    required String title,
    required Widget content,
    required VoidCallback onConfirm,
    String confirmLabel = '确定',
    String cancelLabel = '取消',
    VoidCallback? onCancel,
    bool isDangerous = false,
    double? widthFactor,
    double? heightFactor,
    double buttonWidth = 84.0,
    double buttonHeight = 36.0,
  }) {
    return AppDialog(
      key: key,
      title: title,
      content: content,
      heightFactor: heightFactor,
      widthFactor: widthFactor,
      footer: Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: AppSpacing.md,
            children: [
              GeneralBtn(
                fn: onCancel ?? () => Navigator.pop(context),
                label: cancelLabel,
                btnWidth: buttonWidth,
                btnHeight: buttonHeight,
                mainAxisAlignment: MainAxisAlignment.center,
                backgroundColor: Colors.transparent,
                contentColor: colorScheme.onSurfaceVariant,
                borderWidth: AppSize.hairline,
                borderColor: colorScheme.outlineVariant.withValues(
                  alpha: AppAlpha.border,
                ),
              ),
              GeneralBtn(
                fn: onConfirm,
                label: confirmLabel,
                btnWidth: buttonWidth,
                btnHeight: buttonHeight,
                mainAxisAlignment: MainAxisAlignment.center,
                backgroundColor: isDangerous
                    ? colorScheme.error
                    : colorScheme.primary,
                contentColor: colorScheme.onPrimary,
                overlayColor: colorScheme.surface,
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final colorScheme = Theme.of(context).colorScheme;

    final isFixedWidth = widthFactor != null;
    final effectiveWidth = isFixedWidth ? size.width * widthFactor! : null;

    final isFixedHeight = heightFactor != null;
    final effectiveHeight = isFixedHeight ? size.height * heightFactor! : null;

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: isFixedHeight ? MainAxisSize.max : MainAxisSize.min,
      spacing: AppSpacing.lg,
      children: [
        if (isFixedHeight)
          Expanded(
            child: Padding(padding: contentPadding, child: content),
          )
        else
          Padding(padding: contentPadding, child: content),
        ?footer,
      ],
    );

    return AlertDialog(
      title: Text(title),
      titleTextStyle: context.createTextStyle(
        size: AppFontSize.xl,
        weight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xsAll),
      backgroundColor: colorScheme.surface,
      content: SizedBox(
        width: effectiveWidth,
        height: effectiveHeight,
        child: body,
      ),
    );
  }
}
