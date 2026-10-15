import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

/// 空状态图标尺寸
const double _iconSize = 30.0;
const double _iconSizeDense = 20.0;
const double _paddingV = 28.0;
const double _paddingVDense = 14.0;

/// 通用空状态
class AppEmptyState extends StatelessWidget {
  final String text;
  final IconData icon;

  /// 是否开启紧凑模式
  final bool dense;

  const AppEmptyState({
    super.key,
    required this.text,
    this.icon = PhosphorIconsLight.musicNotes,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: dense ? _paddingVDense : _paddingV,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: dense ? AppSpacing.md : AppSpacing.lg,
        children: [
          Icon(
            icon,
            size: dense ? _iconSizeDense : _iconSize,
            color: colorScheme.onSurfaceVariant.withValues(
              alpha: AppAlpha.textFaint,
            ),
          ),
          Text(
            text,
            style: context.createTextStyle(
              size: dense ? AppFontSize.sm : AppFontSize.md,
              opacity: AppAlpha.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
