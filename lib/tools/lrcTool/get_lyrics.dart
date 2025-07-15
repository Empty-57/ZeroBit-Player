import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:zerobit_player/tools/lrcTool/parse_lyrics.dart';

import '../qrc_decryptor.dart';
import 'lyric_model.dart';

/// 支持的歌词扩展名
const List<String> _lyricExts = [LyricFormat.qrc, LyricFormat.yrc, LyricFormat.lrc];
const String _lyricTsSuffix = LyricFormat.lrc;

/// 获取主歌词路径和翻译歌词路径
Map<String, dynamic> _getLyricPaths(String filePath) {
  final dir = p.dirname(filePath);
  final baseName = p.basenameWithoutExtension(filePath);

  return {
    'mainPaths': _lyricExts.map((ext) => p.join(dir, '$baseName$ext')).toList(),
    'vtsPath': p.join(dir, '$baseName$_lyricTsSuffix'),
  };
}

Future<String?> _safeReadFile(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final ext = p.extension(filePath).toLowerCase();

    final lrc = utf8.decode(bytes, allowMalformed: true);
    if (ext == LyricFormat.qrc) {
      if (!lrc.trimLeft().startsWith('<?xml')) {
        return await qrcDecrypt(encryptedQrc: bytes, isLocal: true);
      }
      return lrc;
    }

    return lrc;
  } catch (e) {
    debugPrint('Error reading $filePath: $e');
    return null;
  }
}

/// 主入口，获取歌词及翻译
Future<Map<String, dynamic>?> getLyrics({String? filePath}) async {
  if (filePath == null || filePath.isEmpty) return null;

  final paths = _getLyricPaths(filePath);
  final List<String> mainPaths = paths['mainPaths'];
  final String vtsPath = paths['vtsPath'];

  // 启动翻译歌词读取
  final Future<String?> lyricsTsFuture = _safeReadFile(vtsPath);

  for (final path in mainPaths) {
    final lyrics = await _safeReadFile(path);
    final ext = p.extension(path);
    if (lyrics != null && lyrics.trim().isNotEmpty) {
      String? lyricsTs;

      if (ext != LyricFormat.lrc) {
        lyricsTs = await lyricsTsFuture;
      }

      return {'lyrics': lyrics, 'lyrics_ts': lyricsTs, 'type': ext};
    }
  }

  return null;
}

Future<Map<String, dynamic>?> getParsedLyric({String? filePath}) async {
  if (filePath == null || filePath.isEmpty) return null;

  final lyricsData = await getLyrics(filePath: filePath);
  if (lyricsData?['type'] == LyricFormat.lrc) {
    return {
      'parsedLrc': parseLrc(lyricsData?['lyrics']),
      'type': lyricsData?['type'],
    };
  }
  if (lyricsData?['type'] == LyricFormat.yrc || lyricsData?['type'] == LyricFormat.qrc) {
    return {
      'parsedLrc': parseKaraOkLyric(
        lyricsData?['lyrics'],
        lyricsData?['lyrics_ts'],
        type: lyricsData?['type'],
      ),
      'type': lyricsData?['type'],
    };
  }
  return null;
}
