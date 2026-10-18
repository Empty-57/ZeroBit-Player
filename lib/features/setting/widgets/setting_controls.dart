import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/app_interaction_widget.dart';
import 'package:zerobit_player/core/widgets/app_text_segmented.dart';
import 'package:zerobit_player/features/setting/widgets/setting_constant.dart';

import '../../../core/widgets/app_button/app_button.dart';

/// 开关
class SettingSwitch extends SignalWidget {
  final Signal<bool> value;
  final ValueChanged<bool> onChanged;

  const SettingSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Switch(
        value: value.value,
        onChanged: onChanged,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}

/// 文字分段控件
class SettingSegmented extends SignalWidget {
  final Map<int, String> options;
  final Signal<int> value;
  final ValueChanged<int> onChanged;

  const SettingSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextSegmented<int>(
      options: options,
      value: value.value,
      onChanged: onChanged,
    );
  }
}

/// 整数滑块 + 步进器 支持滚轮
class SettingIntSlider extends SignalWidget {
  final Signal<int> value;
  final int min;
  final int max;

  /// 值确定下来时调用
  final ValueChanged<int> onCommit;

  /// 显示值的格式化
  final String Function(int)? formatter;

  /// 拖动过程是否触发 [onCommit]
  final bool live;

  const SettingIntSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onCommit,
    this.formatter,
    this.live = false,
  });

  void _adjust(int direction) {
    final next = (value.value + direction).clamp(min, max);
    if (next == value.value) return;
    value.value = next;
    onCommit(next);
  }

  @override
  Widget build(BuildContext context) {
    final current = value.value.clamp(min, max);

    return _SliderShell(
      valueText: formatter?.call(current) ?? '$current',
      sliderValue: current.toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: max > min ? max - min : null,
      onSliderChanged: (v) {
        final next = v.round();
        value.value = next;
        if (live) onCommit(next);
      },
      onSliderCommit: (v) => onCommit(v.round()),
      onDecrease: current > min ? () => _adjust(-1) : null,
      onIncrease: current < max ? () => _adjust(1) : null,
      onScroll: _adjust,
    );
  }
}

/// 浮点数滑块 步长按 [divisions] 等分 ，功能同 [SettingIntSlider]
class SettingSlider extends SignalWidget {
  final Signal<double> value;
  final double min;
  final double max;
  final int? divisions;

  final ValueChanged<double> onCommit;
  final String Function(double)? formatter;
  final bool live;

  const SettingSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onCommit,
    this.divisions,
    this.formatter,
    this.live = false,
  });

  /// 没有分段时按百分之一量程步进
  double get _step =>
      divisions != null ? (max - min) / divisions! : (max - min) / 100;

  void _adjust(int direction) {
    final current = value.value;
    final next = (current + _step * direction).clamp(min, max);
    if (next == current) return;
    value.value = next;
    onCommit(next);
  }

  @override
  Widget build(BuildContext context) {
    final current = value.value.clamp(min, max);

    return _SliderShell(
      valueText: formatter?.call(current) ?? current.toStringAsFixed(2),
      sliderValue: current,
      min: min,
      max: max,
      divisions: divisions,
      onSliderChanged: (v) {
        value.value = v;
        if (live) onCommit(v);
      },
      onSliderCommit: onCommit,
      onDecrease: current > min ? () => _adjust(-1) : null,
      onIncrease: current < max ? () => _adjust(1) : null,
      onScroll: _adjust,
    );
  }
}

/// 两种滑块共用的外壳
class _SliderShell extends StatelessWidget {
  final String valueText;
  final double sliderValue;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<double> onSliderCommit;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final ValueChanged<int> onScroll;

  const _SliderShell({
    required this.valueText,
    required this.sliderValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onSliderChanged,
    required this.onSliderCommit,
    required this.onDecrease,
    required this.onIncrease,
    required this.onScroll,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ScrollAdjustRegion(
      onAdjust: onScroll,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.sm,
        children: [
          _StepButton(
            icon: PhosphorIconsLight.minus,
            tooltip: '减小',
            onPressed: onDecrease,
          ),
          SizedBox(
            width: SettingControlSpec.sliderWidth,
            child: Material(
              color: Colors.transparent,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  showValueIndicator: ShowValueIndicator.never,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  min: min,
                  max: max,
                  divisions: divisions,
                  value: sliderValue,
                  onChanged: onSliderChanged,
                  onChangeEnd: onSliderCommit,
                ),
              ),
            ),
          ),
          _StepButton(
            icon: PhosphorIconsLight.plus,
            tooltip: '增大',
            onPressed: onIncrease,
          ),
          Container(
            width: SettingControlSpec.sliderValueWidth,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: AppAlpha.fill),
              borderRadius: AppRadius.xsAll,
            ),
            child: Text(
              valueText,
              textAlign: TextAlign.center,
              style: context.createTextStyle(
                size: AppFontSize.sm,
                color: colorScheme.primary,
                weight: FontWeight.w600,
                tabularFigures: true,
              ),
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return AppButton.icon(
      onPressed: onPressed,
      style: .secondary,
      tooltip: enabled ? tooltip : null,
      icon: icon,
      size: .small,
    );
  }
}

/// 设置页的操作按钮
class SettingActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  /// 自定义前置组件
  final Widget? leading;

  const SettingActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton.secondary(
      onPressed: onPressed,
      leading: leading,
      icon: icon,
      size: .medium,
      label: label,
      selected: true,
      spacing: AppSpacing.sm,
      minWidth: SettingControlSpec.buttonMinWidth,
      maxWidth: SettingControlSpec.buttonMaxWidth,
    );
  }
}

/// 方形图标按钮
class SettingIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool danger;

  const SettingIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton.icon(
      danger: danger,
      onPressed: onPressed,
      tooltip: tooltip,
      style: .secondary,
      icon: icon,
    );
  }
}

/// 只读值展示
class SettingValueText extends StatelessWidget {
  final String text;

  const SettingValueText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      text,
      style: context.createTextStyle(
        size: AppFontSize.md,
        color: colorScheme.primary,
        weight: FontWeight.w600,
        tabularFigures: true,
      ),
      maxLines: 1,
      softWrap: false,
    );
  }
}
