import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/tools/websocket_model.dart';

import '../desktop_lyrics_sever.dart';

final DesktopLyricsSever _desktopLyricsSever = Get.find<DesktopLyricsSever>();

class DesktopLyricsSettingController extends GetxController {
  final fontFamily = "Microsoft YaHei Light".obs;
  final fontSize = 24.obs; // 16-36
  final fontWeight = 5.obs; // 0-8  w100-w900
  final overlayColor = 0xffff0000.obs;
  final underColor = 0xff0000ff.obs;
  final fontOpacity = 1.0.obs;

  final isLock = false.obs;
  final windowDx = 50.0.obs;
  final windowDy = 50.0.obs;
  final isIgnoreMouseEvents = false.obs;

  final lrcAlignment=1.obs;
  final useVerticalDisplayMode=false.obs;

  static const Map<int, String> lrcAlignmentMap = {0: '左对齐', 1: '居中', 2: '右对齐'};

  SharedPreferences? prefs;

  static const int fontSizeMin = 16;
  static const int fontSizeMax = 36;

  @override
  void onInit() async {
    super.onInit();

    prefs = await SharedPreferences.getInstance();
    fontSize.value = prefs!.getInt('fontSize') ?? 24;
    fontWeight.value = prefs!.getInt('fontWeight') ?? 5;
    fontFamily.value =
        prefs!.getString('fontFamily') ?? 'Microsoft YaHei Light';
    overlayColor.value = prefs!.getInt('overlayColor') ?? 0xffff0000;
    underColor.value = prefs!.getInt('underColor') ?? 0xff0000ff;
    fontOpacity.value = prefs!.getDouble('fontOpacity') ?? 1.0;
    isLock.value = prefs!.getBool('isLock') ?? false;
    windowDx.value = prefs!.getDouble('dx') ?? 50.0;
    windowDy.value = prefs!.getDouble('dy') ?? 50.0;
    isIgnoreMouseEvents.value=prefs!.getBool('isIgnoreMouseEvents')??false;
    lrcAlignment.value=prefs!.getInt('lrcAlignment')??1;
    useVerticalDisplayMode.value=prefs!.getBool('displayMode')??false;
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

  void setIsLock({required bool lock}) {
    isLock.value = lock;
    if (prefs == null) {
      return;
    }
    prefs!.setBool('isLock', lock);
  }

  void setDx({required double dx}) {
    windowDx.value = dx;
    if (prefs == null) {
      return;
    }
    prefs!.setDouble('dx', dx);
  }

  void setDy({required double dy}) {
    windowDy.value = dy;
    if (prefs == null) {
      return;
    }
    prefs!.setDouble('dy', dy);
  }

  void setIgnoreMouseEvents({required bool isIgnore}){
    isIgnoreMouseEvents.value=isIgnore;
    _desktopLyricsSever.sendCmd(
      cmdType: SeverCmdType.setIgnoreMouseEvents,
      cmdData: isIgnoreMouseEvents.value,
    );
    if (prefs == null) {
      return;
    }
    prefs!.setBool('isIgnoreMouseEvents', isIgnore);
  }

  void setLrcAlignment({required int alignment}){
    lrcAlignment.value=alignment;
    _desktopLyricsSever.sendCmd(cmdType: SeverCmdType.setLrcAlignment, cmdData: lrcAlignment.value);
    if (prefs == null) {
      return;
    }
    prefs!.setInt('lrcAlignment', alignment);
  }

  void setUseVerticalDisplayMode({required bool use}){
    useVerticalDisplayMode.value=use;
    _desktopLyricsSever.sendCmd(cmdType: SeverCmdType.setDisplayMode, cmdData: useVerticalDisplayMode.value);
    if (prefs == null) {
      return;
    }
    prefs!.setBool('displayMode', use);
  }
}
