import 'package:flutter/material.dart';

import '../theme/style_manager.dart';
import 'app_button/app_button.dart';
import 'app_button/app_button_style.dart';

/// 对话框通用尺寸
abstract final class AppDialogSpec {
  /// 常规对话框相对窗口的尺寸
  static const double widthFactor = 0.5;
  static const double heightFactor = 0.5;

  /// 对话框内列表的行高
  static const double listRowHeight = 44.0;

  /// 对话框内搜索框高度
  static const double searchFieldHeight = 38.0;

  /// 底部按钮最小宽度
  static const double actionMinWidth = 72.0;
  static const double actionMaxWidth = 180.0;
}

/// 应用级对话框外壳。
class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;

  /// 自定义底部操作区。标准的「取消 / 确定」用 [AppDialogActions]
  final Widget? footer;

  /// 宽度比例，null 时按内容自适应，要求内容有固有宽高
  final double? widthFactor;

  /// 高度比例，null 时按内容自适应
  final double? heightFactor;

  /// 内容区内边距
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

  /// 带标准「取消 / 确定」的小对话框，尺寸默认按内容自适应
  factory AppDialog.confirm({
    Key? key,
    required String title,
    required Widget content,
    required VoidCallback onConfirm,
    String confirmLabel = '确定',
    String cancelLabel = '取消',
    VoidCallback? onCancel,
    bool isDangerous = false,
    double? widthFactor = AppDialogSpec.widthFactor,
    double? heightFactor = AppDialogSpec.heightFactor,
  }) {
    return AppDialog(
      key: key,
      title: title,
      content: content,
      widthFactor: widthFactor,
      heightFactor: heightFactor,
      footer: AppDialogActions(
        onConfirm: onConfirm,
        onCancel: onCancel,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDangerous: isDangerous,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final colorScheme = Theme.of(context).colorScheme;

    final isFixedHeight = heightFactor != null;
    final paddedContent = Padding(padding: contentPadding, child: content);

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
        width: widthFactor == null ? null : size.width * widthFactor!,
        height: isFixedHeight ? size.height * heightFactor! : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: isFixedHeight ? MainAxisSize.max : MainAxisSize.min,
          spacing: AppSpacing.lg,
          children: [
            // 定高时内容吃满剩余空间，自适应时按内容收缩
            if (isFixedHeight)
              Expanded(child: paddedContent)
            else
              paddedContent,
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// 对话框底部的标准操作区：左侧可选的附加操作，右侧「取消 / 确定」
class AppDialogActions extends StatelessWidget {
  /// 为 null 时确定键禁用
  final VoidCallback? onConfirm;

  /// 为 null 时直接关闭对话框
  final VoidCallback? onCancel;

  final String confirmLabel;
  final String cancelLabel;
  final IconData? confirmIcon;

  /// 是否是破坏性动作
  final bool isDangerous;

  /// 是否执行中
  final bool loading;

  /// 是否只留取消键
  final bool showConfirm;

  /// 左侧附加组件
  final Widget? leading;

  final double? width;

  const AppDialogActions({
    super.key,
    this.onConfirm,
    this.onCancel,
    this.confirmLabel = '确定',
    this.cancelLabel = '取消',
    this.confirmIcon,
    this.isDangerous = false,
    this.loading = false,
    this.showConfirm = true,
    this.leading,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.md,
      children: [
        ?leading,
        const Spacer(flex: 2),
        Flexible(
          child: AppButton.secondary(
            onPressed: loading
                ? null
                : onCancel ?? () => Navigator.pop(context),
            label: cancelLabel,
            minWidth: AppDialogSpec.actionMinWidth,
            maxWidth: AppDialogSpec.actionMaxWidth,
          ),
        ),
        if (showConfirm)
          Flexible(
            child: AppButton(
              onPressed: onConfirm,
              label: confirmLabel,
              icon: confirmIcon,
              style: AppButtonType.filled,
              danger: isDangerous,
              loading: loading,
              minWidth: AppDialogSpec.actionMinWidth,
              maxWidth: AppDialogSpec.actionMaxWidth,
            ),
          ),
      ],
    );
  }
}
