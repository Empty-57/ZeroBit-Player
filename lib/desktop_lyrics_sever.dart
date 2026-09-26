import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:signals/signals_flutter.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:zerobit_player/logger.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';
import 'package:zerobit_player/tools/websocket_model.dart';

import 'controller/audio_ctrl.dart';
import 'controller/desktop_lyrics_setting_ctrl.dart';
import 'controller/lyric_ctrl.dart';
import 'controller/setting_ctrl.dart';

class DesktopLyricsSever {
  DesktopLyricsSever._();
  static final instance = DesktopLyricsSever._();

  late final LyricController _lyricController = LyricController.instance;
  late final AudioController _audioController = AudioController.instance;
  final SettingController _settingController = SettingController.instance;
  final _wsUrl = Uri.parse('ws://127.0.0.1:7070');

  HttpServer? _server;
  IOWebSocketChannel? _channel;
  StreamSubscription? _listen;

  EffectCleanup? _lineWorker;
  EffectCleanup? _stateWorker;

  DesktopLyricsSettingController get _desktopLyricsSettingController =>
      DesktopLyricsSettingController.instance;

  void init() {
    if (_settingController.showDesktopLyrics.value) {
      connect();
    }
  }

  void _startStateWorker() {
    _stateWorker = effect(() {
      _audioController.currentState.value;
      untracked(() {
        if (_settingController.showDesktopLyrics.value) {
          _refreshStatus();
        }
      });
    });
  }

  void _refreshStatus() {
    sendCmd(
      cmdType: SeverCmdType.changeStatus,
      cmdData: _audioController.currentState.value.index,
    );
  }

  void _lineWorkerFn() {
    if (_channel == null) return;

    final lyrics = _audioController.currentLyrics.value?.parsedLrc;
    int lineIndex = _lyricController.currentLineIndex.value;
    int nextLineIndex = lineIndex + 1;
    final type = _audioController.currentLyrics.value?.type;

    // 无歌词状态
    if (lyrics == null || lyrics.isEmpty || type == null) {
      _sendJson(LyricsIOModel.sendData('暂无歌词', '', LyricFormat.lrc));
      _sendJson(LyricsIOModel.sendNextData('', '', LyricFormat.lrc));
      return;
    }

    if (lineIndex < 0 || lineIndex >= lyrics.length) {
      lineIndex = 0;
      nextLineIndex = 1;
      _lyricController.currentWordIndexNotifier.value = 0;
      _lyricController.wordProgress.value = 0.0;
    }

    final currLyrics = lyrics[lineIndex].lyricText;
    final nextLyrics = nextLineIndex > lyrics.length - 1
        ? (type == LyricFormat.lrc
              ? ''
              : [
                  WordEntry(
                    start: 0.0,
                    duration: 0.0,
                    lyricWord: '',
                    furigana: '',
                  ),
                ])
        : lyrics[nextLineIndex].lyricText;

    final translate = lyrics[lineIndex].translate;
    final nextTranslate = nextLineIndex > lyrics.length - 1
        ? ''
        : lyrics[nextLineIndex].translate;

    if (type == LyricFormat.lrc) {
      _sendJson(LyricsIOModel.sendData(currLyrics, translate, type));
      _sendJson(LyricsIOModel.sendNextData(nextLyrics, nextTranslate, type));
    } else {
      final line = (currLyrics as List<WordEntry>)
          .map((v) => WordEntry.toJson(v))
          .toList();
      final nextLine = (nextLyrics as List<WordEntry>)
          .map((v) => WordEntry.toJson(v))
          .toList();

      _sendJson(LyricsIOModel.sendData(line, translate, type));
      _sendJson(LyricsIOModel.sendNextData(nextLine, nextTranslate, type));
    }
  }

  void _startLineWorker() {
    _lineWorker = effect(() {
      _lyricController.currentLineIndex.value;
      _audioController.currentLyrics.value;
      untracked(_lineWorkerFn);
    });
  }

  void _ms20WorkerFn() {
    if ((_audioController.currentLyrics.value?.type ?? LyricFormat.lrc) !=
        LyricFormat.lrc) {
      _sendJson(
        LyricsIOModel.sendPosition(
          _lyricController.currentWordIndexNotifier.value,
          _lyricController.wordProgress.value,
        ),
      );
    }
  }

  void _startMs20Worker() {
    _lyricController.currentMs20Notifier.addListener(_ms20WorkerFn);
  }

  void connect() async {
    await close();

    _startStateWorker();
    _startLineWorker();
    _startMs20Worker();
    _wakeUpDesktopLyrics();

    try {
      // 启动本地 HttpServer
      _server = await HttpServer.bind(_wsUrl.host, _wsUrl.port, shared: true);
      _server!.listen((HttpRequest request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocketTransformer.upgrade(request).then((socket) {
            _channel = IOWebSocketChannel(socket);
            _listen = _channel!.stream.listen(
              _onMessageReceived,
              onError: (e, stackTrace) {
                LoggerUni.e('桌面歌词 WebSocket 通信异常', e, stackTrace);
              },
            );
          });
        } else {
          request.response.close();
        }
      });
    } catch (e, stackTrace) {
      LoggerUni.e('桌面歌词服务器启动失败 (端口可能被占用)', e, stackTrace);
      await close();
    }
  }

  /// 处理 WebSocket 接收消息的分发
  void _onMessageReceived(dynamic message) {
    if (message == 'ok') {
      // 客户端初次连接握手成功，推送初始化数据
      _lineWorkerFn();
      _ms20WorkerFn();
      _refreshStatus();
      _sendConfig();
      return;
    }
    _messageHandle(message);
  }

  void _wakeUpDesktopLyrics() async {
    try {
      final dir = p.dirname(Platform.resolvedExecutable);
      final fullPath = p.join(
        dir,
        r'desktop_lyrics\zerobit_player_desktop_lyrics.exe',
      );
      if (!File(fullPath).existsSync()) {
        LoggerUni.w('未找到桌面歌词可执行程序: $fullPath');
        return;
      }
      await Process.start(fullPath, []);
    } catch (e, stackTrace) {
      LoggerUni.e('拉起桌面歌词进程失败', e, stackTrace);
    }
  }

  void _sendConfig() {
    sendCmd(
      cmdType: SeverCmdType.putConfig,
      cmdData: {
        'fontFamily': _desktopLyricsSettingController.fontFamily.value,
        'fontSize': _desktopLyricsSettingController.fontSize.value,
        'fontWeight': _desktopLyricsSettingController.fontWeight.value,
        'overlayColor':
            _desktopLyricsSettingController.useDynamicOverlayColor.value
            ? _settingController.themeColor.value
            : _desktopLyricsSettingController.overlayColor.value,
        'underColor':
            _desktopLyricsSettingController.useDynamicOverlayColor.value
            ? 0xFFD4D8E5
            : _desktopLyricsSettingController.underColor.value,
        'fontOpacity': _desktopLyricsSettingController.fontOpacity.value,
        'dx': _desktopLyricsSettingController.windowDx,
        'dy': _desktopLyricsSettingController.windowDy,
        'windowWidth': _desktopLyricsSettingController.windowWidth,
        'windowHeight': _desktopLyricsSettingController.windowHeight,
        'isIgnoreMouseEvents':
            _desktopLyricsSettingController.isIgnoreMouseEvents.value,
        'lrcAlignment': _desktopLyricsSettingController.lrcAlignment.value,
        'displayMode':
            _desktopLyricsSettingController.useVerticalDisplayMode.value,
        'useStroke': _desktopLyricsSettingController.useStroke.value,
        'strokeColor': _desktopLyricsSettingController.strokeColor.value,
        'showDoubleLine': _desktopLyricsSettingController.showDoubleLine.value,
        'lyricsSwitchAnimateMode':
            _desktopLyricsSettingController.lyricsSwitchAnimateMode.value,
      },
    );
  }

  Future<void> _messageHandle(dynamic msg) async {
    try {
      final data = jsonDecode(msg as String);
      if (data is! Map<String, dynamic>) return;

      final type = data['type'] as String?;
      final cmdType = data['cmdType'] as String?;
      final cmdData = data['cmdData'];

      if (type == 'clientCmd') {
        switch (cmdType) {
          case ClientCmdType.toggle:
            _audioController.audioToggle();
            return;
          case ClientCmdType.next:
            _audioController.audioToNext();
            return;
          case ClientCmdType.previous:
            _audioController.audioToPrevious();
            return;
          case ClientCmdType.close:
            _settingController.showDesktopLyrics.value = false;
            await _settingController.putScalableCache();
            await close();
            return;
          case ClientCmdType.addFontSize:
            _desktopLyricsSettingController.fontSize.value++;
            _desktopLyricsSettingController.setFontSize(
              size: _desktopLyricsSettingController.fontSize.value,
            );
            return;
          case ClientCmdType.decFontSize:
            _desktopLyricsSettingController.fontSize.value--;
            _desktopLyricsSettingController.setFontSize(
              size: _desktopLyricsSettingController.fontSize.value,
            );
            return;
          case ClientCmdType.switchLock:
            _desktopLyricsSettingController.setIgnoreMouseEvents(
              isIgnore: cmdData,
            );
            return;
          case ClientCmdType.setDx:
            _desktopLyricsSettingController.setDx(dx: cmdData);
            return;
          case ClientCmdType.setDy:
            _desktopLyricsSettingController.setDy(dy: cmdData);
            return;
          case ClientCmdType.setWindowWidth:
            _desktopLyricsSettingController.setWindowWidth(width: cmdData);
            return;
          case ClientCmdType.setWindowHeight:
            _desktopLyricsSettingController.setWindowHeight(height: cmdData);
            return;
          case ClientCmdType.heartBeat:
            sendCmd(cmdType: SeverCmdType.heartBeat, cmdData: 'pong');
            return;
        }
      }
    } catch (e, stackTrace) {
      LoggerUni.w('解析客户端指令失败: $msg', e, stackTrace);
    }
  }

  /// 统一发送方法，集中管理异常与日志
  void _sendJson(dynamic model) {
    if (_channel == null) return;
    try {
      final jsonData = jsonEncode(model);
      _channel!.sink.add(jsonData);
    } catch (e, stackTrace) {
      LoggerUni.e('桌面歌词发送数据失败', e, stackTrace);
    }
  }

  void sendCmd({required String cmdType, required dynamic cmdData}) {
    _sendJson(LyricsIOModel.sendCmd(cmdType, cmdData));
  }

  Future<void> close() async {
    _lineWorker?.call();
    _lineWorker = null;

    _lyricController.currentMs20Notifier.removeListener(_ms20WorkerFn);

    _stateWorker?.call();
    _stateWorker = null;

    try {
      sendCmd(cmdType: SeverCmdType.shutdown, cmdData: null);

      if (_listen != null) {
        await _listen!.cancel();
        _listen = null;
      }

      if (_channel != null) {
        await _channel!.sink.close(status.normalClosure);
        _channel = null;
      }

      if (_server != null) {
        await _server!.close(force: true);
        _server = null;
      }
    } catch (e, stackTrace) {
      LoggerUni.e('桌面歌词服务关闭时发生异常', e, stackTrace);
    }
  }
}
