import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/tools/func_extension.dart';

import 'package:zerobit_player/tools/general_style.dart';

import '../getxController/audio_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import 'package:get/get.dart';

final AudioController _audioController = Get.find<AudioController>();
final SettingController _settingController = Get.find<SettingController>();
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
  final VoidCallback? fn;

  const GenIconBtn({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.size,
    required this.fn,
  });
  @override
  Widget build(BuildContext context) {
    return Tooltip(
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
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
        child: Icon(icon, size: getIconSize(size: 'lg')),
      ),
    );
  }
}

class AudioCtrlWidget {
  final double size;
  final BuildContext context;
  const AudioCtrlWidget({required this.size, required this.context});

  Widget get volumeSet => MenuAnchor(
    menuChildren: [
      Column(
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
    ],
    style: MenuStyle(
      padding: WidgetStatePropertyAll(const EdgeInsets.only(top: 16)),
    ),
    builder: (_, MenuController controller, Widget? child) {
      return GenIconBtn(
        tooltip: "音量",
        icon: PhosphorIconsFill.speakerHigh,
        size: size,
        fn: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
      );
    },
  );

  Widget get skipBack => GenIconBtn(
    tooltip: "上一首",
    icon: PhosphorIconsFill.skipBack,
    size: size,
    fn: () async {
      await _audioController.audioToPrevious();
    }.throttle(ms: 500),
  );

  Widget get toggle => GenIconBtn(
    tooltip:
        _audioController.currentState.value == AudioState.playing ? "暂停" : "播放",
    icon:
        _audioController.currentState.value == AudioState.playing
            ? PhosphorIconsFill.pause
            : PhosphorIconsFill.play,
    size: size,
    fn: () async {
      await _audioController.audioToggle();
    }.throttle(ms: 300),
  );

  Widget get skipForward => GenIconBtn(
    tooltip: "下一首",
    icon: PhosphorIconsFill.skipForward,
    size: size,
    fn: () async {
      await _audioController.audioToNext();
    }.throttle(ms: 500),
  );

  Widget get changeMode => GenIconBtn(
    tooltip:
        _settingController.playModeMap[_settingController.playMode.value] ??
        "单曲循环",
    icon: _playModeIcons[_settingController.playMode.value],
    size: size,
    fn: () {
      _audioController.changePlayMode();
    },
  );
}
