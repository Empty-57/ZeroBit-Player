import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobit_player/components/setting/setting_constant.dart';
import 'package:zerobit_player/components/setting/setting_controls.dart';
import 'package:zerobit_player/components/setting/setting_fields.dart';
import 'package:zerobit_player/components/setting/setting_surface.dart';
import 'package:zerobit_player/components/widget/get_snack_bar.dart';
import 'package:zerobit_player/controller/desktop_lyrics_setting_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/field/shared_preferences_key.dart';
import 'package:zerobit_player/logger.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';
import 'package:zerobit_player/tools/version_checker.dart';

final SettingController _setting = SettingController.instance;
final DesktopLyricsSettingController _desktopLyrics =
    DesktopLyricsSettingController.instance;

String _percent(double value) => '${(value * 100).round()}%';

String _integer(double value) => value.round().toString();

String _fontWeight(int level) => '${level * 100 + 100}';

/// 常规设置
class GeneralSetTab extends StatelessWidget {
  const GeneralSetTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingTabBody(
      groups: [
        const SettingGroup(
          title: '音乐库',
          children: [SettingRow(label: '歌曲文件夹', control: SettingFolderField())],
        ),
        SettingGroup(
          title: '歌词',
          children: [
            SettingRow(
              label: 'API 源',
              control: SettingSegmented(
                options: SettingController.apiMap,
                value: _setting.apiIndex,
                onChanged: (value) {
                  _setting.apiIndex.value = value;
                  unawaited(_setting.putCache(isSaveFolders: false));
                },
              ),
            ),
            SettingRow(
              label: '首选歌词来源',
              control: SettingSegmented(
                options: SettingController.lyricSourceMap,
                value: _setting.lyricSource,
                onChanged: (value) => _setting.setLyricSource(value: value),
              ),
            ),
            SettingRow(
              label: '自动从 API 获取歌词',
              control: SettingSwitch(
                value: _setting.autoGetLyrics,
                onChanged: (val) => _setting.setAutoGetLyrics(value: val),
              ),
            ),
            SettingRow(
              label: '自动保存获取的歌词到本地',
              control: SettingSwitch(
                value: _setting.autoDownloadLrc,
                onChanged: (val) {
                  _setting.autoDownloadLrc.value = val;
                  unawaited(_setting.putCache());
                },
              ),
            ),
          ],
        ),
        SettingGroup(
          title: '系统',
          children: [
            SettingRow(
              label: '关闭窗口后在后台运行',
              control: SettingSwitch(
                value: _setting.close2Tray,
                onChanged: (val) => _setting.setClose2Tray(value: val),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 播放设置
class PlaySetTab extends StatelessWidget {
  const PlaySetTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingTabBody(
      groups: [
        SettingGroup(
          title: '音频输出',
          children: [
            SettingRow(
              label: '启用独占模式',
              control: SettingSwitch(
                value: _setting.useExclusiveMode,
                onChanged: (val) => _setting.setExclusiveMode(use: val),
              ),
            ),
            SettingRow(
              label: '启用音量平衡（ReplayGain）',
              description: '需要音频有 ReplayGain 标签才能生效',
              control: SettingSwitch(
                value: _setting.useReplayGain,
                onChanged: (val) => _setting.setUseReplayGain(value: val),
              ),
            ),
          ],
        ),
        SettingGroup(
          title: '切歌与过渡',
          children: [
            SettingRow(
              label: '使用音量过渡',
              description: '播放、暂停、停止和定位时平滑调整音量',
              control: SettingSwitch(
                value: _setting.useVolumeFade,
                onChanged: (val) => _setting.setUseVolumeFade(value: val),
              ),
            ),
            SettingRow(
              label: '无缝播放',
              description: '切歌时跳过音频首尾的静音',
              control: SettingSwitch(
                value: _setting.useSkipSilence,
                onChanged: (val) => _setting.setUseSkipSilence(value: val),
              ),
            ),
            SettingRow(
              label: '静音阈值',
              description: '低于这个音量则视为静音，单位 dB',
              control: SettingSlider(
                value: _setting.silenceThresholdDb,
                min: -70.0,
                max: -30.0,
                divisions: 20,
                formatter: _integer,
                onCommit: (v) => _setting.setSilenceThresholdDb(value: v),
              ),
            ),
            SettingRow(
              label: '交叉渐入渐出',
              description: '切歌时上一首淡出、下一首淡入并短暂重叠，同时自动跳过音频首尾的静音（独占模式下不生效）',
              control: SettingSwitch(
                value: _setting.useCrossfade,
                onChanged: (val) => _setting.setUseCrossfade(value: val),
              ),
            ),
            SettingRow(
              label: '过渡时间',
              description: '渐入渐出的时长，单位毫秒',
              control: SettingSlider(
                value: _setting.crossfadeDuration,
                min: 200.0,
                max: 5000.0,
                divisions: 48,
                formatter: _integer,
                onCommit: (v) => _setting.setCrossfadeDuration(value: v),
              ),
            ),
          ],
        ),
        SettingGroup(
          title: '系统集成',
          children: [
            SettingRow(
              label: '使用任务栏缩略图工具栏控制播放',
              control: SettingSwitch(
                value: _setting.useTaskBarCtrl,
                onChanged: (val) => _setting.setUseTaskBarCtrl(value: val),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 外观设置
class AppearanceSetTab extends StatelessWidget {
  const AppearanceSetTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingTabBody(
      groups: [
        SettingGroup(
          title: '主题',
          children: [
            SettingRow(
              label: '主题色',
              control: SettingColorField(
                color: _setting.themeColor,
                onChanged: (color) {
                  _setting.themeColor.value = color;
                  // 桌面歌词跟随主题色时要一起改，否则两边颜色会脱节
                  if (_desktopLyrics.useDynamicOverlayColor.value) {
                    _desktopLyrics.setDynamicOverlayColor(color);
                  }
                  unawaited(_setting.putCache());
                },
              ),
            ),
            SettingRow(
              label: '动态主题色',
              control: SettingSwitch(
                value: _setting.dynamicThemeColor,
                onChanged: (val) {
                  _setting.dynamicThemeColor.value = val;
                  unawaited(_setting.putCache());
                },
              ),
            ),
            SettingRow(
              label: '字体',
              control: SettingFontField(
                fontFamily: _setting.fontFamily,
                onChanged: (font) {
                  _setting.fontFamily.value = font;
                  unawaited(_setting.putCache());
                },
              ),
            ),
          ],
        ),
        SettingGroup(
          title: '背景',
          children: [
            const SettingRow(
              label: '背景图片',
              description: '选择图片后请不要移动或删除图片',
              control: SettingBackgroundField(),
            ),
            SettingRow(
              label: '使用透明背景',
              control: SettingSwitch(
                value: _setting.useTransparencyBackground,
                onChanged: (val) =>
                    _setting.setUseTransparencyBackground(value: val),
              ),
            ),
            SettingRow(
              label: '背景不透明度',
              control: SettingSlider(
                value: _setting.backgroundImageOpacity,
                min: 0.0,
                max: 1.0,
                formatter: _percent,
                onCommit: (v) => _setting.setBackgroundImageOpacity(value: v),
              ),
            ),
            SettingRow(
              label: '背景模糊',
              control: SettingSlider(
                value: _setting.backgroundImageBlur,
                min: 0.0,
                max: 36.0,
                divisions: 18,
                formatter: _integer,
                onCommit: (v) => _setting.setBackgroundImageBlur(value: v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 歌词设置
class LyricsSetTab extends StatelessWidget {
  const LyricsSetTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingTabBody(
      groups: [
        SettingGroup(
          title: '字体',
          children: [
            SettingRow(
              label: '字号',
              control: SettingIntSlider(
                value: _setting.lrcFontSize,
                min: SettingController.lrcFontSizeMin,
                max: SettingController.lrcFontSizeMax,
                onCommit: (_) =>
                    unawaited(_setting.putCache(isSaveFolders: false)),
              ),
            ),
            SettingRow(
              label: '字重',
              control: SettingIntSlider(
                value: _setting.lrcFontWeight,
                min: SettingController.lrcFontWeightMin,
                max: SettingController.lrcFontWeightMax,
                formatter: _fontWeight,
                onCommit: (_) =>
                    unawaited(_setting.putCache(isSaveFolders: false)),
              ),
            ),
            SettingRow(
              label: '字符间距',
              control: SettingSlider(
                value: _setting.lrcLetterSpacing,
                min: -5.0,
                max: 10.0,
                divisions: 30,
                formatter: (v) => v.toStringAsFixed(1),
                onCommit: (v) => _setting.setLrcLetterSpacing(value: v),
              ),
            ),
            const Padding(
              padding: SettingLayout.rowPadding,
              child: _LyricsPreview(),
            ),
          ],
        ),
        SettingGroup(
          title: '视觉效果',
          children: [
            SettingRow(
              label: '使用 3D 封面',
              description: '会跟随鼠标位置进行动画，此效果比较占用性能',
              control: SettingSwitch(
                value: _setting.useTilt3DCover,
                onChanged: (val) => _setting.setUseTilt3DCover(val: val),
              ),
            ),
            SettingRow(
              label: '使用动态背景',
              description: '此效果比较占用性能',
              control: SettingSwitch(
                value: _setting.useMesh,
                onChanged: (val) => _setting.setUseMesh(value: val),
              ),
            ),
            SettingRow(
              label: '歌词行模糊',
              description: '此效果比较占用性能',
              control: SettingSwitch(
                value: _setting.useBlur,
                onChanged: (val) {
                  _setting.useBlur.value = val;
                  unawaited(_setting.putCache());
                },
              ),
            ),
            SettingRow(
              label: '使用弹性滚动',
              description: '此效果比较占用性能',
              control: SettingSwitch(
                value: _setting.useSpringScroll,
                onChanged: (val) => _setting.setSpringScroll(value: val),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 歌词预览
class _LyricsPreview extends StatelessWidget {
  const _LyricsPreview();

  static const String _sample = '预览 Preview プレビューです 123';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.lg,
      children: [
        Text('预览', style: context.createTextStyle(size: AppFontSize.md)),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(
              alpha: AppAlpha.surfaceSubtle,
            ),
            borderRadius: AppRadius.mdAll,
          ),
          child: SignalBuilder(
            builder: (context) {
              final isDark = _setting.themeMode.value == 'dark';
              final fontSize = _setting.lrcFontSize.value.toDouble();
              final baseStyle = context.createTextStyle(
                size: fontSize,
                color: colorScheme.onSecondaryContainer.withValues(
                  alpha: isDark ? 0.2 : 0.3,
                ),
                weight: FontWeight.values[_setting.lrcFontWeight.value],
                letterSpacing: _setting.lrcLetterSpacing.value,
              );
              final strutStyle = StrutStyle(
                fontSize: fontSize,
                forceStrutHeight: true,
              );

              return Column(
                children: [
                  Transform.scale(
                    scale: 1.1,
                    child: Text(
                      _sample,
                      style: baseStyle.copyWith(
                        color: baseStyle.color?.withValues(alpha: 0.8),
                      ),
                      strutStyle: strutStyle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  Text(
                    _sample,
                    style: baseStyle,
                    strutStyle: strutStyle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 桌面歌词设置
class DesktopLyricsSetTab extends StatelessWidget {
  const DesktopLyricsSetTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingTabBody(
      groups: [
        SettingGroup(
          title: '开关',
          children: [
            SettingRow(
              label: '开启桌面歌词',
              control: SettingSwitch(
                value: _setting.showDesktopLyrics,
                onChanged: (val) => _setting.setShowDesktopLyrics(val),
              ),
            ),
          ],
        ),
        SettingGroup(
          title: '字体',
          children: [
            SettingRow(
              label: '字号',
              control: SettingIntSlider(
                value: _desktopLyrics.fontSize,
                min: DesktopLyricsSettingController.fontSizeMin,
                max: DesktopLyricsSettingController.fontSizeMax,
                live: true,
                onCommit: (value) => _desktopLyrics.setFontSize(size: value),
              ),
            ),
            SettingRow(
              label: '字重',
              control: SettingIntSlider(
                value: _desktopLyrics.fontWeight,
                min: SettingController.lrcFontWeightMin,
                max: SettingController.lrcFontWeightMax,
                formatter: _fontWeight,
                live: true,
                onCommit: (value) =>
                    _desktopLyrics.setFontWeight(weight: value),
              ),
            ),
            SettingRow(
              label: '歌词字体',
              control: SettingFontField(
                fontFamily: _desktopLyrics.fontFamily,
                onChanged: (font) => _desktopLyrics.setFontFamily(family: font),
              ),
            ),
            SettingRow(
              label: '不透明度',
              control: SettingSlider(
                value: _desktopLyrics.fontOpacity,
                min: 0.0,
                max: 1.0,
                formatter: _percent,
                live: true,
                onCommit: (v) => _desktopLyrics.setFontOpacity(opacity: v),
              ),
            ),
          ],
        ),
        SettingGroup(
          title: '颜色',
          children: [
            SettingRow(
              label: '已播放颜色跟随主题色',
              control: SettingSwitch(
                value: _desktopLyrics.useDynamicOverlayColor,
                onChanged: (val) => _desktopLyrics.setUseDynamicOverlayColor(
                  value: val,
                  color: _setting.themeColor.value,
                ),
              ),
            ),
            SettingRow(
              label: '已播放颜色',
              control: SettingColorField(
                color: _desktopLyrics.overlayColor,
                enableAlpha: true,
                onChanged: (color) =>
                    _desktopLyrics.setOverlayColor(color: color),
              ),
            ),
            SettingRow(
              label: '未播放颜色',
              control: SettingColorField(
                color: _desktopLyrics.underColor,
                enableAlpha: true,
                onChanged: (color) =>
                    _desktopLyrics.setUnderColor(color: color),
              ),
            ),
            SettingRow(
              label: '描边',
              control: SettingSwitch(
                value: _desktopLyrics.useStroke,
                onChanged: (val) => _desktopLyrics.setStrokeEnable(enable: val),
              ),
            ),
            SettingRow(
              label: '描边颜色',
              control: SettingColorField(
                color: _desktopLyrics.strokeColor,
                enableAlpha: true,
                onChanged: (color) {
                  _desktopLyrics.strokeColor.value = color;
                  _desktopLyrics.setStrokeColor(color: color);
                },
              ),
            ),
          ],
        ),
        SettingGroup(
          title: '排版与交互',
          children: [
            SettingRow(
              label: '对齐方式',
              control: SettingSegmented(
                options: DesktopLyricsSettingController.lrcAlignmentMap,
                value: _desktopLyrics.lrcAlignment,
                onChanged: (value) =>
                    _desktopLyrics.setLrcAlignment(alignment: value),
              ),
            ),
            SettingRow(
              label: '歌词切换特效',
              control: SettingSegmented(
                options:
                    DesktopLyricsSettingController.lyricsSwitchAnimateModeMap,
                value: _desktopLyrics.lyricsSwitchAnimateMode,
                onChanged: (value) =>
                    _desktopLyrics.setLyricsSwitchAnimateMode(mode: value),
              ),
            ),
            SettingRow(
              label: '使用双行显示',
              control: SettingSwitch(
                value: _desktopLyrics.showDoubleLine,
                onChanged: (val) => _desktopLyrics.setShowDoubleLine(show: val),
              ),
            ),
            SettingRow(
              label: '显示日语假名',
              control: SettingSwitch(
                value: _desktopLyrics.showKana,
                onChanged: (val) => _desktopLyrics.setShowKana(value: val),
              ),
            ),
            SettingRow(
              label: '竖排显示',
              control: SettingSwitch(
                value: _desktopLyrics.useVerticalDisplayMode,
                onChanged: (val) =>
                    _desktopLyrics.setUseVerticalDisplayMode(use: val),
              ),
            ),
            SettingRow(
              label: '忽略鼠标事件',
              description: '若开启，桌面歌词窗口将不接受任何鼠标事件',
              control: SettingSwitch(
                value: _desktopLyrics.isIgnoreMouseEvents,
                onChanged: (val) =>
                    _desktopLyrics.setIgnoreMouseEvents(isIgnore: val),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 快捷键设置
class HotkeysSetTab extends StatelessWidget {
  const HotkeysSetTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingTabBody(
      groups: [
        SettingGroup(
          title: '快捷键',
          children: [
            SettingRow(
              label: '播放 / 暂停',
              control: SettingHotkeyField(
                hotKey: _setting.hotKeyToggle,
                prefKey: SharedPreferencesKey.toggleHidString,
                onRecorded: (key) {
                  _setting.hotKeyToggle.value = key;
                  _setting.setToggleHid(key: key);
                },
              ),
            ),
            SettingRow(
              label: '上一首',
              control: SettingHotkeyField(
                hotKey: _setting.hotKeyPrevious,
                prefKey: SharedPreferencesKey.previousHidString,
                onRecorded: (key) {
                  _setting.hotKeyPrevious.value = key;
                  _setting.setPreviousHid(key: key);
                },
              ),
            ),
            SettingRow(
              label: '下一首',
              control: SettingHotkeyField(
                hotKey: _setting.hotKeyNext,
                prefKey: SharedPreferencesKey.nextHidString,
                onRecorded: (key) {
                  _setting.hotKeyNext.value = key;
                  _setting.setNextHid(key: key);
                },
              ),
            ),
            SettingRow(
              label: '切换全屏',
              control: SettingHotkeyField(
                hotKey: _setting.hotKeyFullScreen,
                prefKey: SharedPreferencesKey.fullScreenHidString,
                onRecorded: (key) {
                  _setting.hotKeyFullScreen.value = key;
                  _setting.setFullScreenHid(key: key);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _launchUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url));
  } catch (e, stackTrace) {
    LoggerUni.w('跳转失败 URL: $url', e, stackTrace);
    showSnackBar(title: 'ERROR', msg: '跳转失败！');
  }
}

/// 关于
class AboutTab extends StatelessWidget {
  final Future<PackageInfo> packageInfoFuture;

  const AboutTab({super.key, required this.packageInfoFuture});

  @override
  Widget build(BuildContext context) {
    return SettingTabBody(
      groups: [
        SettingGroup(
          title: '版本',
          children: [
            SettingRow(
              label: '当前版本',
              control: FutureBuilder<PackageInfo>(
                future: packageInfoFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox.shrink();
                  }
                  return SettingValueText(
                    text: snapshot.hasData ? snapshot.data!.version : '获取版本号失败',
                  );
                },
              ),
            ),
            SettingRow(
              label: '自动检查更新',
              control: SettingSwitch(
                value: _setting.useAutoUpdate,
                onChanged: (val) => _setting.setUseAutoUpdate(value: val),
              ),
            ),
            const SettingRow(label: '检查更新', control: _CheckUpdateButton()),
          ],
        ),
        SettingGroup(
          title: '链接',
          children: [
            SettingRow(
              label: '官网',
              control: SettingActionButton(
                label: '访问官网',
                icon: PhosphorIconsLight.globe,
                onPressed: () => unawaited(_launchUrl(SettingLinks.site)),
              ),
            ),
            SettingRow(
              label: '项目主页',
              control: SettingActionButton(
                label: '前往仓库',
                icon: PhosphorIconsLight.code,
                onPressed: () => unawaited(_launchUrl(SettingLinks.repo)),
              ),
            ),
            SettingRow(
              label: '问题反馈',
              control: SettingActionButton(
                label: '创建问题',
                icon: PhosphorIconsLight.bug,
                onPressed: () => unawaited(_launchUrl(SettingLinks.report)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckUpdateButton extends StatefulWidget {
  const _CheckUpdateButton();

  @override
  State<_CheckUpdateButton> createState() => _CheckUpdateButtonState();
}

class _CheckUpdateButtonState extends State<_CheckUpdateButton>
    with SingleTickerProviderStateMixin {
  static const Duration _spinPeriod = Duration(milliseconds: 1000);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: _spinPeriod,
  );

  bool _loading = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_loading) return;
    setState(() => _loading = true);
    unawaited(_spin.repeat());

    await VersionChecker.checkAndShowDialog(
      context,
      showNoUpdateToast: true,
      showErrorToast: true,
    );

    if (!mounted) return;
    _spin.stop();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = _loading
        ? colorScheme.onSurfaceVariant.withValues(alpha: AppAlpha.textFaint)
        : colorScheme.primary;

    return SettingActionButton(
      label: _loading ? '检查中' : '检查更新',
      onPressed: _loading ? null : () => unawaited(_check()),
      leading: RotationTransition(
        turns: _spin,
        child: Icon(
          _loading
              ? PhosphorIconsLight.spinnerGap
              : PhosphorIconsLight.arrowClockwise,
          size: AppIconSize.sm,
          color: iconColor,
        ),
      ),
    );
  }
}
