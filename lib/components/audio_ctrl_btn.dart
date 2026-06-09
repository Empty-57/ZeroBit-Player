import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:zerobit_player/custom_widgets/diamond_silder_thumb.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/func_extension.dart';
import 'package:zerobit_player/tools/func/general_style.dart';

const double _radius = 6;
final _isSeekBarDragging = false.obs;

final _seekDraggingValue = 0.0.obs;

const _playModeIcons = [
  PhosphorIconsFill.repeatOnce,
  PhosphorIconsFill.repeat,
  PhosphorIconsFill.shuffleSimple,
];

class GenIconBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final double size;
  final Color? color;
  final Color backgroundColor;
  final VoidCallback? fn;

  const GenIconBtn({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.size,
    this.color,
    this.backgroundColor = Colors.transparent,
    required this.fn,
  });
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      waitDuration: Duration(milliseconds: 100),
      message: tooltip,
      child: TextButton(
        onPressed: () {
          if (fn != null) {
            fn!();
          }
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size(size, size),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
        child: Icon(icon, size: getIconSize(size: 'lg'), color: color),
      ),
    );
  }
}

class AudioCtrlWidget {
  final double size;
  final BuildContext context;
  final Color? color;
  AudioCtrlWidget({required this.size, required this.context, this.color});

  final AudioController _audioController = Get.find<AudioController>();
  final SettingController _settingController = Get.find<SettingController>();

  Widget get speedSet {
    const double btnW = 72;
    const double setBtnHeight = 36;
    final menuController = MenuController();
    final speedList =
        List.generate(16, (index) => index + 5).map((i) {
          final speed = i / 10;
          return CustomBtn(
            fn: () async {
              await setSpeed(speed: speed);
              _audioController.currentSpeed.value = speed;
              menuController.close();
            },
            btnWidth: btnW,
            btnHeight: setBtnHeight,
            label: speed.toString(),
            icon:
                _audioController.currentSpeed.value != speed
                    ? null
                    : PhosphorIconsLight.check,
            iconSize: 'xs',
            contentColor: Theme.of(context).colorScheme.onSecondaryContainer,
            mainAxisAlignment:
                _audioController.currentSpeed.value != speed
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.spaceBetween,
            spacing: 0,
            padding: EdgeInsets.symmetric(horizontal: 12),
            backgroundColor: Colors.transparent,
          );
        }).toList();
    return Theme(
      // Create a unique theme with `ThemeData`.
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: WidgetStateProperty.all(false),
          trackVisibility: WidgetStateProperty.all(false),
          thickness: WidgetStateProperty.all(0),
        ),
      ),
      child: MenuAnchor(
        menuChildren: speedList,
        controller: menuController,
        style: MenuStyle(
          maximumSize: WidgetStatePropertyAll(
            Size.fromHeight(context.height / 2),
          ),
          backgroundColor: WidgetStatePropertyAll(
            Theme.of(
              context,
            ).colorScheme.surfaceContainer.withValues(alpha: 0.8),
          ),
        ),
        builder: (_, MenuController controller, Widget? child) {
          return GenIconBtn(
            tooltip: "倍速",
            icon: PhosphorIconsLight.waveform,
            size: size,
            color: color,
            fn: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
          );
        },
      ),
    );
  }

  Widget get volumeSet => MenuAnchor(
    menuChildren: [
      Obx(
        () => Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              (_settingController.volume.value * 100).round().toString(),
              style: generalTextStyle(
                ctx: context,
                size: 'md',
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            RotatedBox(
              quarterTurns: 3,
              child: Slider(
                min: 0.0,
                max: 1.0,
                value: _settingController.volume.value,
                onChanged: (v) {
                  _audioController.audioSetVolume(vol: v);
                  _settingController.volume.value = v;
                },
                onChangeEnd: (v) {
                  _settingController.putCache();
                },
              ),
            ),
          ],
        ),
      ),
    ],
    style: const MenuStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.only(top: 16)),
    ),
    builder: (_, MenuController controller, Widget? child) {
      // 使用 Listener 包裹按钮以监听鼠标事件
      return Listener(
        onPointerSignal: (pointerSignal) {
          // 判断是否为鼠标滚轮事件
          if (pointerSignal is PointerScrollEvent) {
            final double currentVol = _settingController.volume.value;
            // 每次滚动的步长，0.05 表示 5%
            const double step = 0.05;
            double newVol = currentVol;

            // scrollDelta.dy < 0 表示滚轮向上推 -> 增加音量
            // scrollDelta.dy > 0 表示滚轮向下滚 -> 减小音量
            if (pointerSignal.scrollDelta.dy < 0) {
              newVol = (currentVol + step).clamp(0.0, 1.0);
            } else if (pointerSignal.scrollDelta.dy > 0) {
              newVol = (currentVol - step).clamp(0.0, 1.0);
            }

            // 只有当音量真正发生变化时才执行更新
            if (newVol != currentVol) {
              _settingController.volume.value = newVol;
              _audioController.audioSetVolume(vol: newVol);

              _settingController.putCache.throttle(ms: 500)();
            }
          }
        },
        child: Obx(
          () => GenIconBtn(
            tooltip:
                "音量：${(_settingController.volume * 100).toStringAsFixed(0)}",
            icon: PhosphorIconsFill.speakerHigh,
            size: size,
            color: color,
            fn: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
          ),
        ),
      );
    },
  );

  Widget get skipBack => GenIconBtn(
    tooltip: "上一首",
    icon: PhosphorIconsFill.skipBack,
    size: size,
    color: color,
    fn: () async {
      await _audioController.audioToPrevious();
    }.throttle(ms: 500),
  );

  Widget get toggle => Obx(
    () => GenIconBtn(
      tooltip:
          _audioController.currentState.value == AudioState.playing
              ? "暂停"
              : "播放",
      icon:
          _audioController.currentState.value == AudioState.playing
              ? PhosphorIconsFill.pause
              : PhosphorIconsFill.play,
      size: size,
      color: color,
      fn: () async {
        await _audioController.audioToggle();
      }.throttle(ms: 300),
    ),
  );

  Widget get skipForward => GenIconBtn(
    tooltip: "下一首",
    icon: PhosphorIconsFill.skipForward,
    size: size,
    color: color,
    fn: () async {
      await _audioController.audioToNext();
    }.throttle(ms: 500),
  );

  Widget get changeMode => Obx(
    () => GenIconBtn(
      tooltip:
          SettingController.playModeMap[_settingController.playMode.value] ??
          "单曲循环",
      icon: _playModeIcons[_settingController.playMode.value],
      size: size,
      color: color,
      fn: () {
        _audioController.changePlayMode();
      },
    ),
  );

  Widget get seekSlide => Focus(
    // 禁止键盘事件聚焦
    canRequestFocus: false,
    descendantsAreFocusable: false,
    child: Obx(() {
      late final double duration;
      if (_audioController.currentMetadata.value.path.isNotEmpty) {
        duration = _audioController.currentDuration.value;
      } else {
        _seekDraggingValue.value = 0.0;
        duration = 9999.0;
      }
      return Slider(
        min: 0.0,
        max: duration,
        label:
            _isSeekBarDragging.value
                ? formatTime(totalSeconds: _seekDraggingValue.value)
                : '√',
        value:
            _isSeekBarDragging.value
                ? _seekDraggingValue.value
                : _audioController.currentMs100.value,
        onChangeStart: (v) {
          _seekDraggingValue.value = v;
          _isSeekBarDragging.value = true;
        },
        onChanged: (v) {
          _seekDraggingValue.value = v;
        },
        onChangeEnd: (v) {
          _audioController.currentMs100.value = v;
          _isSeekBarDragging.value = false;
          _audioController.audioSetPositon(pos: v);
          _seekDraggingValue.value = 0.0;
        },
      );
    }),
  );

  Widget get equalizerSet {
    final fontStyle = generalTextStyle(
      ctx: context,
      size: 'sm',
      color: Theme.of(context).colorScheme.onSecondaryContainer,
    );

    final equalizerSliders =
        SettingController.equalizerFCenters.indexed.map((v) {
          return SizedBox(
            width: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 6,
              children: [
                Obx(
                  () => Text(
                    '${_settingController.equalizerGains[v.$1].toStringAsFixed(1)}db',
                    style: fontStyle,
                  ),
                ),

                Material(
                  color: Colors.transparent,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const DiamondSliderThumbShape(
                        horizontalDiagonal: 16,
                        verticalDiagonal: 16,
                      ),
                    ),
                    child: Obx(
                      () => RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          min: SettingController.minGain,
                          max: SettingController.maxGain,
                          value: _settingController.equalizerGains[v.$1],
                          divisions: 48,
                          onChanged: (gain) async {
                            final newGains = List<double>.from(
                              _settingController.equalizerGains,
                            );
                            newGains[v.$1] = gain;
                            _settingController.equalizerGains.value = newGains;
                            await setEqParams(freCenterIndex: v.$1, gain: gain);
                          },
                          onChangeEnd: (gain) {
                            _settingController.putScalableCache();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  '${v.$2 >= 1000 ? '${(v.$2 / 1000).toInt()}k' : v.$2.toInt()}hz',
                  style: fontStyle,
                ),
              ],
            ),
          );
        }).toList();

    final backgroundColor = Theme.of(context).colorScheme.primary;
    return GenIconBtn(
      tooltip: "均衡器",
      icon: PhosphorIconsLight.equalizer,
      size: size,
      color: color,
      fn: () async {
        showDialog(
          barrierDismissible: true,
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("均衡器"),
              titleTextStyle: generalTextStyle(
                ctx: context,
                size: 'xl',
                weight: FontWeight.w600,
              ),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,

              actionsAlignment: MainAxisAlignment.end,
              actions: <Widget>[
                SizedBox(
                  width: context.width * 2 / 3,
                  height: context.height / 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 16,
                    children: [
                      Obx(() {
                        final equalizerGains =
                            _settingController.equalizerGains;
                        return Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          children:
                              SettingController.equalizerGainPresets.entries
                                  .map((entry) {
                                    final isEqual = listEquals(
                                      equalizerGains,
                                      entry.value,
                                    );
                                    return CustomBtn(
                                      fn: () async {
                                        _settingController
                                            .equalizerGains
                                            .value = entry.value;
                                        await _settingController
                                            .putScalableCache();
                                        for (final v in entry.value.indexed) {
                                          await setEqParams(
                                            freCenterIndex: v.$1,
                                            gain: v.$2,
                                          );
                                        }
                                      },
                                      label:
                                          SettingController
                                              .equalizerGainPresetsText[entry
                                              .key],
                                      backgroundColor:
                                          isEqual
                                              ? backgroundColor
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .secondaryContainer
                                                  .withValues(alpha: 0.2),
                                      contentColor:
                                          isEqual
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimary
                                              : backgroundColor,
                                      btnWidth: 96,
                                      btnHeight: 36,
                                    );
                                  })
                                  .toList(),
                        );
                      }),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: equalizerSliders,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
