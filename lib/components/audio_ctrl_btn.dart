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
      waitDuration: const Duration(milliseconds: 100),
      message: tooltip,
      child: TextButton(
        onPressed: fn,
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

class _SeekSlideWidget extends StatefulWidget {
  final AudioController audioController;
  const _SeekSlideWidget({super.key, required this.audioController});

  @override
  State<_SeekSlideWidget> createState() => _SeekSlideWidgetState();
}

class _SeekSlideWidgetState extends State<_SeekSlideWidget> {
  final _isSeekBarDragging = ValueNotifier<bool>(false);
  final _seekDraggingValue = ValueNotifier<double>(0.0);

  @override
  void dispose() {
    _isSeekBarDragging.dispose();
    _seekDraggingValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          widget.audioController.currentMs100,
          _isSeekBarDragging,
          _seekDraggingValue,
        ]),
        builder: (_, _) {
          final pathIsEmpty =
              widget.audioController.currentMetadata.value.path.isEmpty;
          final double duration =
              pathIsEmpty
                  ? 9999.0
                  : widget.audioController.currentDuration.value;

          final double sliderValue =
              pathIsEmpty
                  ? 0.0
                  : (_isSeekBarDragging.value
                      ? _seekDraggingValue.value
                      : widget.audioController.currentMs100.value);

          return Slider(
            min: 0.0,
            max: duration,
            label:
                _isSeekBarDragging.value
                    ? formatTime(totalSeconds: _seekDraggingValue.value)
                    : '√',
            value: sliderValue,
            onChangeStart: (v) {
              _seekDraggingValue.value = v;
              _isSeekBarDragging.value = true;
            },
            onChanged: (v) {
              _seekDraggingValue.value = v;
            },
            onChangeEnd: (v) {
              widget.audioController.currentMs100.value = v;
              _isSeekBarDragging.value = false;
              widget.audioController.audioSetPositon(pos: v);
              _seekDraggingValue.value = 0.0;
            },
          );
        },
      ),
    );
  }
}

class AudioCtrlWidget {
  final double size;
  final BuildContext context;
  final Color? color;

  AudioCtrlWidget({required this.size, required this.context, this.color});

  Widget get speedSet => _SpeedSetBtn(size: size, color: color);

  Widget get volumeSet => _VolumeSetBtn(size: size, color: color);

  Widget get skipBack => _SkipBackBtn(size: size, color: color);

  Widget get toggle => _PlayToggleBtn(size: size, color: color);

  Widget get skipForward => _SkipForwardBtn(size: size, color: color);

  Widget get changeMode => _PlayModeBtn(size: size, color: color);

  Widget get seekSlide =>
      _SeekSlideWidget(audioController: Get.find<AudioController>());

  Widget get equalizerSet => _EqualizerBtn(size: size, color: color);
}

class _SpeedSetBtn extends StatelessWidget {
  final double size;
  final Color? color;
  const _SpeedSetBtn({required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final AudioController audioController = Get.find<AudioController>();
    final menuController = MenuController();

    final speedList =
        List.generate(16, (index) => index + 5).map((i) {
          final speed = i / 10;
          return Obx(() {
            final isCurrent = audioController.currentSpeed.value == speed;
            return CustomBtn(
              fn: () async {
                await setSpeed(speed: speed);
                audioController.currentSpeed.value = speed;
                menuController.close();
              },
              btnWidth: 72,
              btnHeight: 36,
              label: speed.toString(),
              icon: isCurrent ? PhosphorIconsLight.check : null,
              iconSize: 'xs',
              contentColor: Theme.of(context).colorScheme.onSecondaryContainer,
              mainAxisAlignment:
                  isCurrent
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.end,
              spacing: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              backgroundColor: Colors.transparent,
            );
          });
        }).toList();

    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: const ScrollbarThemeData(
          thumbVisibility: WidgetStatePropertyAll(false),
          trackVisibility: WidgetStatePropertyAll(false),
          thickness: WidgetStatePropertyAll(0),
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
        builder: (_, MenuController controller, __) {
          return GenIconBtn(
            tooltip: "倍速",
            icon: PhosphorIconsLight.waveform,
            size: size,
            color: color,
            fn:
                () =>
                    controller.isOpen ? controller.close() : controller.open(),
          );
        },
      ),
    );
  }
}

class _VolumeSetBtn extends StatelessWidget {
  final double size;
  final Color? color;
  const _VolumeSetBtn({required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final AudioController audioController = Get.find<AudioController>();
    final SettingController settingController = Get.find<SettingController>();
    final menuController = MenuController();

    return MenuAnchor(
      controller: menuController,
      menuChildren: [
        Obx(
          () => Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                (settingController.volume.value * 100).round().toString(),
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
                  value: settingController.volume.value,
                  onChanged: (v) {
                    audioController.audioSetVolume(vol: v);
                    settingController.volume.value = v;
                  },
                  onChangeEnd: (_) => settingController.putCache(),
                ),
              ),
            ],
          ),
        ),
      ],
      style: const MenuStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.only(top: 16)),
      ),
      builder: (ctx, MenuController controller, __) {
        return Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              final double currentVol = settingController.volume.value;
              const double step = 0.05;
              double newVol = currentVol;

              // scrollDelta.dy < 0 表示滚轮向上推 -> 增加音量
              // scrollDelta.dy > 0 表示滚轮向下滚 -> 减小音量
              if (pointerSignal.scrollDelta.dy < 0) {
                newVol = (currentVol + step).clamp(0.0, 1.0);
              } else if (pointerSignal.scrollDelta.dy > 0) {
                newVol = (currentVol - step).clamp(0.0, 1.0);
              }

              if (newVol != currentVol) {
                settingController.volume.value = newVol;
                audioController.audioSetVolume(vol: newVol);
                settingController.putCache.throttle(ms: 500)();
              }
            }
          },
          child: Obx(
            () => GenIconBtn(
              tooltip:
                  "音量：${(settingController.volume.value * 100).toStringAsFixed(0)}",
              icon: PhosphorIconsFill.speakerHigh,
              size: size,
              color: color,
              fn:
                  () =>
                      controller.isOpen
                          ? controller.close()
                          : controller.open(),
            ),
          ),
        );
      },
    );
  }
}

class _SkipBackBtn extends StatelessWidget {
  final double size;
  final Color? color;
  const _SkipBackBtn({required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final AudioController audioController = Get.find<AudioController>();
    return GenIconBtn(
      tooltip: "上一首",
      icon: PhosphorIconsFill.skipBack,
      size: size,
      color: color,
      fn: () async {
        await audioController.audioToPrevious();
      }.throttle(ms: 500),
    );
  }
}

class _PlayToggleBtn extends StatelessWidget {
  final double size;
  final Color? color;
  const _PlayToggleBtn({required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final AudioController audioController = Get.find<AudioController>();
    return Obx(() {
      final isPlaying =
          audioController.currentState.value == AudioState.playing;
      return GenIconBtn(
        tooltip: isPlaying ? "暂停" : "播放",
        icon: isPlaying ? PhosphorIconsFill.pause : PhosphorIconsFill.play,
        size: size,
        color: color,
        fn: () async {
          await audioController.audioToggle();
        }.throttle(ms: 300),
      );
    });
  }
}

class _SkipForwardBtn extends StatelessWidget {
  final double size;
  final Color? color;
  const _SkipForwardBtn({required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final AudioController audioController = Get.find<AudioController>();
    return GenIconBtn(
      tooltip: "下一首",
      icon: PhosphorIconsFill.skipForward,
      size: size,
      color: color,
      fn: () async {
        await audioController.audioToNext();
      }.throttle(ms: 500),
    );
  }
}

class _PlayModeBtn extends StatelessWidget {
  final double size;
  final Color? color;
  const _PlayModeBtn({required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final AudioController audioController = Get.find<AudioController>();
    final SettingController settingController = Get.find<SettingController>();
    return Obx(() {
      final mode = settingController.playMode.value;
      return GenIconBtn(
        tooltip: SettingController.playModeMap[mode] ?? "单曲循环",
        icon: _playModeIcons[mode],
        size: size,
        color: color,
        fn: () => audioController.changePlayMode(),
      );
    });
  }
}

class _EqualizerBtn extends StatelessWidget {
  final double size;
  final Color? color;
  const _EqualizerBtn({required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final SettingController settingController = Get.find<SettingController>();
    final fontStyle = generalTextStyle(
      ctx: context,
      size: 'sm',
      color: Theme.of(context).colorScheme.onSecondaryContainer,
    );

    return GenIconBtn(
      tooltip: "均衡器",
      icon: PhosphorIconsLight.equalizer,
      size: size,
      color: color,
      fn: () => _showEqualizerDialog(context, settingController, fontStyle),
    );
  }

  void _showEqualizerDialog(
    BuildContext context,
    SettingController settingController,
    TextStyle fontStyle,
  ) {
    final backgroundColor = Theme.of(context).colorScheme.primary;

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
                    '${settingController.equalizerGains[v.$1].toStringAsFixed(1)}db',
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
                          value: settingController.equalizerGains[v.$1],
                          divisions: 48,
                          onChanged: (gain) async {
                            final newGains = List<double>.from(
                              settingController.equalizerGains,
                            );
                            newGains[v.$1] = gain;
                            settingController.equalizerGains.value = newGains;
                            await setEqParams(freCenterIndex: v.$1, gain: gain);
                          },
                          onChangeEnd:
                              (_) => settingController.putScalableCache(),
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
          shape: const RoundedRectangleBorder(
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
                    final equalizerGains = settingController.equalizerGains;
                    return Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children:
                          SettingController.equalizerGainPresets.entries.map((
                            entry,
                          ) {
                            final isEqual = listEquals(
                              equalizerGains,
                              entry.value,
                            );
                            return CustomBtn(
                              fn: () async {
                                settingController.equalizerGains.value =
                                    entry.value;
                                await settingController.putScalableCache();
                                for (final v in entry.value.indexed) {
                                  await setEqParams(
                                    freCenterIndex: v.$1,
                                    gain: v.$2,
                                  );
                                }
                              },
                              label:
                                  SettingController
                                      .equalizerGainPresetsText[entry.key],
                              backgroundColor:
                                  isEqual
                                      ? backgroundColor
                                      : Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer
                                          .withValues(alpha: 0.2),
                              contentColor:
                                  isEqual
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : backgroundColor,
                              btnWidth: 96,
                              btnHeight: 36,
                            );
                          }).toList(),
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
  }
}
