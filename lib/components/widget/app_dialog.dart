import 'package:flutter/material.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

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

  /// 底部操作区
  final Widget? footer;

  final double widthFactor;
  final double heightFactor;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.footer,
    this.widthFactor = AppDialogSpec.widthFactor,
    this.heightFactor = AppDialogSpec.heightFactor,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: Text(title),
      titleTextStyle: context.createTextStyle(
        size: AppFontSize.xl,
        weight: FontWeight.w600,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xsAll),
      backgroundColor: Theme.of(context).colorScheme.surface,
      content: SizedBox(
        width: size.width * widthFactor,
        height: size.height * heightFactor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.lg,
          children: [
            Expanded(child: content),
            ?footer,
          ],
        ),
      ),
    );
  }
}
