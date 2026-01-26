import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';
import 'package:zerobit_player/tools/websocket_model.dart';

import 'getxController/audio_ctrl.dart';
import 'getxController/desktop_lyrics_setting_ctrl.dart';
import 'getxController/lyric_ctrl.dart';
import 'getxController/setting_ctrl.dart';

class DesktopLyricsSever extends GetxController {
  final LyricController _lyricController = Get.find<LyricController>();
  final AudioController _audioController = Get.find<AudioController>();
  final SettingController _settingController = Get.find<SettingController>();
  final _wsUrl = Uri.parse('ws://127.0.0.1:7070');

  HttpServer? _server;
  IOWebSocketChannel? _channel;
  StreamSubscription? _listen;

  Worker? _lineWorker;
  Worker? _ms20Worker;

  DesktopLyricsSettingController get _desktopLyricsSettingController =>
      Get.find<DesktopLyricsSettingController>();

  @override
  void onInit() {
    super.onInit();

    if (_settingController.showDesktopLyrics.value) {
      connect();
    }

    ever(_audioController.currentState, (_) {
      _refreshStatus();
    });
  }

  void _refreshStatus() {
    sendCmd(
      cmdType: SeverCmdType.changeStatus,
      cmdData: _audioController.currentState.value.index,
    );
  }

  void _lineWorkerFn() {
    if (_channel == null) {
      return;
    }
    final lyrics = _audioController.currentLyrics.value?.parsedLrc;
    int lineIndex = _lyricController.currentLineIndex.value;
    int nextLineIndex = lineIndex+1;
    final type = _audioController.currentLyrics.value?.type;
    if (lyrics == null || lyrics.isEmpty || type == null) {
      try {
        final jsonData = jsonEncode(
          LyricsIOModel.sendData('暂无歌词', '', LyricFormat.lrc),
        );
        _add(jsonData);
      } catch (_) {}
      return;
    }
    if (lineIndex < 0 || lineIndex >= lyrics.length) {
      lineIndex = 0;
      nextLineIndex=1;
      _lyricController.currentWordIndex.value = 0;
      _lyricController.wordProgress.value = 0.0;
    }

    final currLyrics = lyrics[lineIndex].lyricText;
    final nextLyrics = nextLineIndex>lyrics.length-1? [WordEntry(start: 0.0, duration: 0.0, lyricWord: '')]: lyrics[nextLineIndex].lyricText;

    final translate = lyrics[lineIndex].translate;
    final nextTranslate = nextLineIndex>lyrics.length-1? '': lyrics[nextLineIndex].translate;

    if (type == LyricFormat.lrc) {
      try {
        final jsonData = jsonEncode(
          LyricsIOModel.sendData(currLyrics, translate, type),
        );
        _add(jsonData);

        final nextJsonData = jsonEncode(
           LyricsIOModel.sendNextData(nextLyrics, nextTranslate, type),
        );
        _add(nextJsonData);
      } catch (_) {}
    } else {
      final line =
          (currLyrics as List<WordEntry>).map((v) {
            return WordEntry.toJson(v);
          }).toList();

      final nextLine =
          (nextLyrics as List<WordEntry>).map((v) {
            return WordEntry.toJson(v);
          }).toList();

      try {
        final jsonData = jsonEncode(
          LyricsIOModel.sendData(line, translate, type),
        );
        _add(jsonData);

        final  nextJsonData = jsonEncode(
          LyricsIOModel.sendNextData(nextLine, nextTranslate, type),
        );
        _add( nextJsonData);

      } catch (_) {}
    }
  }

  void _startLineWorker() {
    _lineWorker = everAll(
      [_lyricController.currentLineIndex, _audioController.currentLyrics],
      (_) {
        _lineWorkerFn();
      },
    );
  }

  void _ms20WorkerFn() {
    try {
      final jsonData = jsonEncode(
        LyricsIOModel.sendPosition(
          _lyricController.currentWordIndex.value,
          _lyricController.wordProgress.value,
        ),
      );
      _add(jsonData);
    } catch (_) {}
  }

  void _startMs20Worker() {
    _ms20Worker = ever(
      _lyricController.currentMs20,
      (_) {
        _ms20WorkerFn();
      },
      condition:
          () =>
              (_audioController.currentLyrics.value?.type ?? LyricFormat.lrc) !=
                  LyricFormat.lrc ||
              _lyricController.currentLineIndex.value < 0,
    );
  }

  void connect() async{
    try {
      _startLineWorker();
      _startMs20Worker();
      _wakeUpDesktopLyrics();
      _server = await HttpServer.bind(_wsUrl.host, _wsUrl.port, shared: true);
      await for (HttpRequest request in _server!) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocketTransformer.upgrade(request).then((socket) async {
            _channel = IOWebSocketChannel(socket);
            _listen = _channel!.stream.listen((message) {
              if (message == 'ok') {
                _lineWorkerFn();
                _ms20WorkerFn();
                _refreshStatus();
                sendCmd(
                  cmdType: SeverCmdType.putConfig,
                  cmdData: {
                    'fontFamily':
                        _desktopLyricsSettingController.fontFamily.value,
                    'fontSize': _desktopLyricsSettingController.fontSize.value,
                    'fontWeight':
                        _desktopLyricsSettingController.fontWeight.value,
                    'overlayColor':
                        _desktopLyricsSettingController.overlayColor.value,
                    'underColor':
                        _desktopLyricsSettingController.underColor.value,
                    'fontOpacity':
                        _desktopLyricsSettingController.fontOpacity.value,
                    'isLock': _desktopLyricsSettingController.isLock.value,
                    'dx': _desktopLyricsSettingController.windowDx,
                    'dy': _desktopLyricsSettingController.windowDy,
                    'windowWidth':_desktopLyricsSettingController.windowWidth,
                    'windowHeight':_desktopLyricsSettingController.windowHeight,
                    'isIgnoreMouseEvents':_desktopLyricsSettingController.isIgnoreMouseEvents.value,
                    'lrcAlignment':_desktopLyricsSettingController.lrcAlignment.value,
                    'displayMode':_desktopLyricsSettingController.useVerticalDisplayMode.value,
                    'useStroke':_desktopLyricsSettingController.useStroke.value,
                    'strokeColor':_desktopLyricsSettingController.strokeColor.value,
                    'showDoubleLine':_desktopLyricsSettingController.showDoubleLine.value,
                  },
                );
              }
              _messageHandle(message);
            }, onError: (e) => debugPrint(e.toString()));
          });
        } else {
          await request.response.close();
          close();
        }
      }
    } catch (e) {
      debugPrint(e.toString());
      close();
      return;
    }
  }

  void _wakeUpDesktopLyrics() async {
    try {
      final dir = p.dirname(Platform.resolvedExecutable);
      final fullPath = p.join(
        dir,
        r'desktop_lyrics\zerobit_player_desktop_lyrics.exe',
      );
      await Process.start(fullPath, []);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _messageHandle(dynamic msg) async {
    try {
      final data = jsonDecode(msg) as Map<String, dynamic>;

      final type = data['type'] as String;
      final cmdType = data['cmdType'] as String;
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
            close();
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
            _desktopLyricsSettingController.setIsLock(lock: cmdData);
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
    } catch (_) {}
  }

  void _add(dynamic msg) {
    if (_channel == null) {
      return;
    }

    try {
      _channel!.sink.add(msg);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void sendCmd({required String cmdType, required dynamic cmdData}) {
    try {
      final jsonData = jsonEncode(LyricsIOModel.sendCmd(cmdType, cmdData));
      _add(jsonData);
    } catch (_) {}
  }

  Future<void> close() async {
    try {
      sendCmd(cmdType: SeverCmdType.shutdown, cmdData: null);

      if (_lineWorker != null) {
        _lineWorker!.dispose();
        _lineWorker = null;
      }

      if (_ms20Worker != null) {
        _ms20Worker!.dispose();
        _ms20Worker = null;
      }

      if (_listen != null) {
        await _listen!.cancel();
        _listen = null;
      }

      if (_channel != null) {
        await _channel!.sink.close(status.normalClosure);
        _channel = null;
      }

      if (_server != null) {
        await _server!.close();
        _server = null;
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
