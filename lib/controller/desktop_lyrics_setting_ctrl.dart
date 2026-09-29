import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/desktop_lyrics_sever.dart';
import 'package:zerobit_player/tools/websocket_model.dart';

import '../field/shared_preferences_key.dart';

class DesktopLyricsSettingController {
  DesktopLyricsSettingController._();
  static final instance = DesktopLyricsSettingController._();
  final DesktopLyricsSever _desktopLyricsSever = DesktopLyricsSever.instance;
  final fontFamily = signal("Microsoft YaHei Light");
  final fontSize = signal(24); // 16-36
  final fontWeight = signal(5); // 0-8  w100-w900
  final overlayColor = signal(0xffff0000);
  final underColor = signal(0xff0000ff);
  final fontOpacity = signal(1.0);

  double windowDx = 50.0;
  double windowDy = 50.0;
  double windowWidth = 450.0;
  double windowHeight = 150.0;
  final isIgnoreMouseEvents = signal(false);

  final lrcAlignment = signal(1);
  final useVerticalDisplayMode = signal(false);

  final useStroke = signal(true);

  final strokeColor = signal(0xff000000);

  final showDoubleLine = signal(false);

  final useDynamicOverlayColor = signal(false);

  final lyricsSwitchAnimateMode = signal(1); // 0 无动画 1 淡入淡出 2滑动 3 缩放

  final showKana = signal(true);

  static const Map<int, String> lrcAlignmentMap = {
    0: '左对齐',
    1: '居中',
    2: '右对齐',
    3: '左右分离',
  };

  static const Map<int, String> lyricsSwitchAnimateModeMap = {
    0: '无',
    1: '淡入淡出',
    2: '滑动',
    3: '缩放',
  };

  SharedPreferences? prefs;

  static const int fontSizeMin = 16;
  static const int fontSizeMax = 48;

  void init() async {
    prefs = await SharedPreferences.getInstance();
    batch(() {
      fontSize.value =
          prefs!.getInt(DesktopSharedPreferencesKey.fontSize) ?? 24;
      fontWeight.value =
          prefs!.getInt(DesktopSharedPreferencesKey.fontWeight) ?? 5;
      fontFamily.value =
          prefs!.getString(DesktopSharedPreferencesKey.fontFamily) ??
          'Microsoft YaHei Light';
      overlayColor.value =
          prefs!.getInt(DesktopSharedPreferencesKey.overlayColor) ?? 0xffff0000;
      underColor.value =
          prefs!.getInt(DesktopSharedPreferencesKey.underColor) ?? 0xff0000ff;
      fontOpacity.value =
          prefs!.getDouble(DesktopSharedPreferencesKey.fontOpacity) ?? 1.0;
      windowDx = prefs!.getDouble(DesktopSharedPreferencesKey.dx) ?? 50.0;
      windowDy = prefs!.getDouble(DesktopSharedPreferencesKey.dy) ?? 50.0;
      windowWidth =
          prefs!.getDouble(DesktopSharedPreferencesKey.windowWidth) ?? 450.0;
      windowHeight =
          prefs!.getDouble(DesktopSharedPreferencesKey.windowHeight) ?? 150.0;
      isIgnoreMouseEvents.value =
          prefs!.getBool(DesktopSharedPreferencesKey.isIgnoreMouseEvents) ??
          false;
      lrcAlignment.value =
          prefs!.getInt(DesktopSharedPreferencesKey.lrcAlignment) ?? 1;
      useVerticalDisplayMode.value =
          prefs!.getBool(DesktopSharedPreferencesKey.displayMode) ?? false;
      useStroke.value =
          prefs!.getBool(DesktopSharedPreferencesKey.useStroke) ?? true;
      strokeColor.value =
          prefs!.getInt(DesktopSharedPreferencesKey.strokeColor) ?? 0xff000000;
      showDoubleLine.value =
          prefs!.getBool(DesktopSharedPreferencesKey.showDoubleLine) ?? false;
      useDynamicOverlayColor.value =
          prefs!.getBool(DesktopSharedPreferencesKey.useDynamicOverlayColor) ??
          false;
      lyricsSwitchAnimateMode.value =
          prefs!.getInt(DesktopSharedPreferencesKey.lyricsSwitchAnimateMode) ??
          1;
      showKana.value =
          prefs!.getBool(DesktopSharedPreferencesKey.showKana) ?? false;
    });
  }

  void setFontSize({required int size}) {
    fontSize.value = size.clamp(fontSizeMin, fontSizeMax);
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setFontSize,
      cmdData: fontSize.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setInt(DesktopSharedPreferencesKey.fontSize, fontSize.value);
  }

  void setFontWeight({required int weight}) {
    fontWeight.value = weight.clamp(0, 8);
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setFontWeight,
      cmdData: fontWeight.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setInt(DesktopSharedPreferencesKey.fontWeight, fontWeight.value);
  }

  void setFontFamily({required String family}) {
    fontFamily.value = family;
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setFontFamily,
      cmdData: fontFamily.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setString(DesktopSharedPreferencesKey.fontFamily, family);
  }

  void setOverlayColor({required int color}) {
    overlayColor.value = color;
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setOverlayColor,
      cmdData: overlayColor.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setInt(DesktopSharedPreferencesKey.overlayColor, color);
  }

  void setUnderColor({required int color}) {
    underColor.value = color;
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setUnderColor,
      cmdData: underColor.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setInt(DesktopSharedPreferencesKey.underColor, color);
  }

  void setFontOpacity({required double opacity}) {
    fontOpacity.value = opacity.clamp(0.0, 1.0);
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setFontOpacity,
      cmdData: fontOpacity.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setDouble(DesktopSharedPreferencesKey.fontOpacity, opacity);
  }

  void setDx({required double dx}) {
    windowDx = dx;
    if (prefs == null) {
      return;
    }
    prefs!.setDouble(DesktopSharedPreferencesKey.dx, dx);
  }

  void setDy({required double dy}) {
    windowDy = dy;
    if (prefs == null) {
      return;
    }
    prefs!.setDouble(DesktopSharedPreferencesKey.dy, dy);
  }

  void setWindowWidth({required double width}) {
    windowWidth = width;
    if (prefs == null) {
      return;
    }
    prefs!.setDouble(DesktopSharedPreferencesKey.windowWidth, width);
  }

  void setWindowHeight({required double height}) {
    windowHeight = height;
    if (prefs == null) {
      return;
    }
    prefs!.setDouble(DesktopSharedPreferencesKey.windowHeight, height);
  }

  void setIgnoreMouseEvents({required bool isIgnore}) {
    isIgnoreMouseEvents.value = isIgnore;
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setIgnoreMouseEvents,
      cmdData: isIgnoreMouseEvents.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setBool(DesktopSharedPreferencesKey.isIgnoreMouseEvents, isIgnore);
  }

  void setLrcAlignment({required int alignment}) {
    lrcAlignment.value = alignment;
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setLrcAlignment,
      cmdData: lrcAlignment.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setInt(DesktopSharedPreferencesKey.lrcAlignment, alignment);
  }

  void setUseVerticalDisplayMode({required bool use}) {
    useVerticalDisplayMode.value = use;
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setDisplayMode,
      cmdData: useVerticalDisplayMode.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setBool(DesktopSharedPreferencesKey.displayMode, use);
  }

  void setStrokeEnable({required bool enable}) {
    useStroke.value = enable;
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setStrokeEnable,
      cmdData: useStroke.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setBool(DesktopSharedPreferencesKey.useStroke, enable);
  }

  void setStrokeColor({required int color}) {
    strokeColor.value = color;
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setStrokeColor,
      cmdData: strokeColor.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setInt(DesktopSharedPreferencesKey.strokeColor, color);
  }

  void setShowDoubleLine({required bool show}) {
    showDoubleLine.value = show;
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.showDoubleLine,
      cmdData: showDoubleLine.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setBool(DesktopSharedPreferencesKey.showDoubleLine, show);
  }

  void setDynamicOverlayColor(int color) {
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setOverlayColor,
      cmdData: color,
    );
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setUnderColor,
      cmdData: 0xFFD4D8E5,
    );
  }

  void setUseDynamicOverlayColor({required bool value, required int color}) {
    useDynamicOverlayColor.value = value;
    if (value) {
      setDynamicOverlayColor(color);
    } else {
      _desktopLyricsSever.sendCmd(
        cmdType: SeverCmdType.setOverlayColor,
        cmdData: overlayColor.value,
      );
      _desktopLyricsSever.sendCmd(
        cmdType: SeverCmdType.setUnderColor,
        cmdData: underColor.value,
      );
    }

    if (prefs == null) {
      return;
    }
    prefs!.setBool(DesktopSharedPreferencesKey.useDynamicOverlayColor, value);
  }

  void setLyricsSwitchAnimateMode({required int mode}) {
    lyricsSwitchAnimateMode.value = mode;
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setLyricsSwitchAnimateMode,
      cmdData: lyricsSwitchAnimateMode.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setInt(DesktopSharedPreferencesKey.lyricsSwitchAnimateMode, mode);
  }

  void setShowKana({required bool value}) {
    showKana.value = value;
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setShowKana,
      cmdData: showKana.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setBool(DesktopSharedPreferencesKey.showKana,value);
  }
}
