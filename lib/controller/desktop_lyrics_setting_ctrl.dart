import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerobit_player/desktop_lyrics_sever.dart';
import 'package:zerobit_player/tools/websocket_model.dart';

class DesktopLyricsSettingController {
  DesktopLyricsSettingController._();
  static final instance = DesktopLyricsSettingController._();
  final DesktopLyricsSever _desktopLyricsSever = DesktopLyricsSever.instance;
  final fontFamily = "Microsoft YaHei Light".obs;
  final fontSize = 24.obs; // 16-36
  final fontWeight = 5.obs; // 0-8  w100-w900
  final overlayColor = 0xffff0000.obs;
  final underColor = 0xff0000ff.obs;
  final fontOpacity = 1.0.obs;

  double windowDx = 50.0;
  double windowDy = 50.0;
  double windowWidth = 450.0;
  double windowHeight = 150.0;
  final isIgnoreMouseEvents = false.obs;

  final lrcAlignment = 1.obs;
  final useVerticalDisplayMode = false.obs;

  final useStroke = true.obs;

  final strokeColor = 0xff000000.obs;

  final showDoubleLine = false.obs;

  final useDynamicOverlayColor = false.obs;

  final lyricsSwitchAnimateMode = 1.obs; // 0 无动画 1 淡入淡出 2滑动 3 缩放

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
    fontSize.value = prefs!.getInt('fontSize') ?? 24;
    fontWeight.value = prefs!.getInt('fontWeight') ?? 5;
    fontFamily.value =
        prefs!.getString('fontFamily') ?? 'Microsoft YaHei Light';
    overlayColor.value = prefs!.getInt('overlayColor') ?? 0xffff0000;
    underColor.value = prefs!.getInt('underColor') ?? 0xff0000ff;
    fontOpacity.value = prefs!.getDouble('fontOpacity') ?? 1.0;
    windowDx = prefs!.getDouble('dx') ?? 50.0;
    windowDy = prefs!.getDouble('dy') ?? 50.0;
    windowWidth = prefs!.getDouble('windowWidth') ?? 450.0;
    windowHeight = prefs!.getDouble('windowHeight') ?? 150.0;
    isIgnoreMouseEvents.value = prefs!.getBool('isIgnoreMouseEvents') ?? false;
    lrcAlignment.value = prefs!.getInt('lrcAlignment') ?? 1;
    useVerticalDisplayMode.value = prefs!.getBool('displayMode') ?? false;
    useStroke.value = prefs!.getBool('useStroke') ?? true;
    strokeColor.value = prefs!.getInt('strokeColor') ?? 0xff000000;
    showDoubleLine.value = prefs!.getBool('showDoubleLine') ?? false;
    useDynamicOverlayColor.value =
        prefs!.getBool('useDynamicOverlayColor') ?? false;
    lyricsSwitchAnimateMode.value =
        prefs!.getInt('lyricsSwitchAnimateMode') ?? 1;
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
    prefs!.setInt('fontSize', fontSize.value);
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
    prefs!.setInt('fontWeight', fontWeight.value);
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
    prefs!.setString('fontFamily', family);
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
    prefs!.setInt('overlayColor', color);
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
    prefs!.setInt('underColor', color);
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
    prefs!.setDouble('fontOpacity', opacity);
  }

  void setDx({required double dx}) {
    windowDx = dx;
    if (prefs == null) {
      return;
    }
    prefs!.setDouble('dx', dx);
  }

  void setDy({required double dy}) {
    windowDy = dy;
    if (prefs == null) {
      return;
    }
    prefs!.setDouble('dy', dy);
  }

  void setWindowWidth({required double width}) {
    windowWidth = width;
    if (prefs == null) {
      return;
    }
    prefs!.setDouble('windowWidth', width);
  }

  void setWindowHeight({required double height}) {
    windowHeight = height;
    if (prefs == null) {
      return;
    }
    prefs!.setDouble('windowHeight', height);
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
    prefs!.setBool('isIgnoreMouseEvents', isIgnore);
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
    prefs!.setInt('lrcAlignment', alignment);
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
    prefs!.setBool('displayMode', use);
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
    prefs!.setBool('useStroke', enable);
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
    prefs!.setInt('strokeColor', color);
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
    prefs!.setBool('showDoubleLine', show);
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
    prefs!.setBool('useDynamicOverlayColor', value);
  }

  void setLyricsSwitchAnimateMode({required int mode}) {
    lyricsSwitchAnimateMode.value = mode;
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.lyricsSwitchAnimateMode,
      cmdData: lyricsSwitchAnimateMode.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setInt('lyricsSwitchAnimateMode', mode);
  }
}
