abstract class LyricsMessageType {
  static const data = 'data';
  static const nextData = 'nextData';
  static const position = 'position';
  static const cmd = 'cmd';
}

abstract class SeverCmdType {
  static const shutdown = 'shutdown';
  static const changeStatus = 'changeStatus';
  static const setFontSize = 'setFontSize';
  static const setFontWeight = 'setFontWeight';
  static const setFontFamily = 'setFontFamily';
  static const setOverlayColor = 'setOverlayColor';
  static const setUnderColor = 'setUnderColor';
  static const setFontOpacity = 'setFontOpacity';
  static const putConfig = 'putConfig';
  static const setIgnoreMouseEvents = 'setIgnoreMouseEvents';
  static const setLrcAlignment = 'setLrcAlignment';
  static const setDisplayMode = 'setDisplayMode';
  static const setStrokeEnable='setStrokeEnable';
  static const setStrokeColor='setStrokeColor';
  static const heartBeat = 'heartBeat';
  static const showDoubleLine='showDoubleLine';
}

abstract class ClientCmdType {
  static const toggle = 'toggle';
  static const next = 'next';
  static const previous = 'previous';
  static const close = 'close';
  static const addFontSize = 'addFontSize';
  static const decFontSize = 'decFontSize';
  static const switchLock = 'switchLock';
  static const setDx = 'setDx';
  static const setDy = 'setDy';
  static const heartBeat = 'heartBeat';
  static const setWindowWidth = 'setWindowWidth';
  static const setWindowHeight = 'setWindowHeight';
}

class LyricsIOModel {
  static Map<String, dynamic> sendData(
    dynamic lyrics,
    String translate,
    String lyricsType,
  ) {
    return {
      'type': LyricsMessageType.data,
      'lyrics': lyrics,
      'translate': translate,
      'lyricsType': lyricsType,
    };
  }

  static Map<String, dynamic> sendNextData(
    dynamic lyrics,
    String translate,
    String lyricsType,
  ) {
    return {
      'type': LyricsMessageType.nextData,
      'lyrics': lyrics,
      'translate': translate,
      'lyricsType': lyricsType,
    };
  }

  static Map<String, dynamic> sendPosition(int wordIndex, double progress) {
    return {
      'type': LyricsMessageType.position,
      'wordIndex': wordIndex,
      'progress': progress,
    };
  }

  static Map<String, dynamic> sendCmd(String cmdType, dynamic cmdData) {
    return {
      'type': LyricsMessageType.cmd,
      'cmdType': cmdType,
      'cmdData': cmdData,
    };
  }
}
