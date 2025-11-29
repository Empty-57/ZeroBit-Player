import 'dart:io';
import 'dart:convert';
import 'package:fl_charset/fl_charset.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:zerobit_player/tools/lrcTool/parse_lyrics.dart';

import '../../src/rust/api/music_tag_tool.dart';
import '../qrc_decryptor.dart';
import 'lyric_model.dart';

/// 支持的歌词扩展名
const List<String> _lyricExts = [
  LyricFormat.qrc,
  LyricFormat.yrc,
  LyricFormat.lrc,
];
const String _lyricTsSuffix = LyricFormat.lrc;

final _encodingOrders = <Encoding>[
  ascii,
  eucJp,
  shiftJis,
  eucKr,
  gbk,
  utf8,
  windows874,
  latin1,
  latin2,
  latin3,
  latin4,
  latinCyrillic,
  latinArabic,
  latinGreek,
  latinHebrew,
  latin5,
  latin6,
  latinThai,
  latin7,
  latin8,
  latin9,
  latin10,
];

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
    final encoding = Charset.detect(bytes, orders: _encodingOrders);
    if (encoding == null) {
      return null;
    }
    final ext = p.extension(filePath).toLowerCase();
    debugPrint("currentLyrics | encoding: ${encoding.name} ext: $ext");
    final String lrc = encoding.decode(bytes);
    if (ext == LyricFormat.qrc) {
      if (!lrc.trimLeft().startsWith('<?xml') &&
          !lrc.trimLeft().startsWith('<Qrc')) {
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

class _LyricModel {
  final String? lyrics;
  final String? lyricsTs;
  final String type;
  const _LyricModel({
    required this.lyrics,
    required this.lyricsTs,
    required this.type,
  });
}

Future<_LyricModel?> _getLyrics({String? filePath}) async {
  if (filePath == null || filePath.isEmpty) return null;

  final paths = _getLyricPaths(filePath);
  final List<String> mainPaths = paths['mainPaths'];
  final String vtsPath = paths['vtsPath'];

  for (final path in mainPaths) {
    final lyrics = await _safeReadFile(path);
    final ext = p.extension(path);
    String type = ext;
    if (lyrics != null && lyrics.trim().isNotEmpty) {
      String? lyricsTs;
      final detectType = detectLrcType(lyrics);
      if (ext == LyricFormat.lrc &&
          (detectType == LrcType.enhanced ||
              detectType == LrcType.wordByWord)) {
        type = LyricFormat.byWordLrc;
      }

      if (type != LyricFormat.lrc) {
        lyricsTs = await _safeReadFile(vtsPath);
      }

      return _LyricModel(lyrics: lyrics, lyricsTs: lyricsTs, type: type);
    }
  }

  return null;
}

/// 主入口，获取已解析的歌词及翻译
Future<ParsedLyricModel?> getParsedLyric({String? filePath}) async {
  if (filePath == null || filePath.isEmpty) return null;

  final lyricsData = await _getLyrics(filePath: filePath);

  if (lyricsData == null) {
    // 此if块需要判断是否为增强型Lrc
    final embeddedLyrics = await getEmbeddedLyric(path: filePath);
    if (embeddedLyrics == null || embeddedLyrics.isEmpty) {
      return null;
    }

    try {
      final data = jsonDecode(embeddedLyrics);
      String type = data['type'];
      final lyrics = data['lyrics'];
      String? lyricsTs = data['lyricsTs'];

      final detectType = detectLrcType(lyrics);
      if (type == LyricFormat.lrc &&
          (detectType == LrcType.enhanced ||
              detectType == LrcType.wordByWord)) {
        type = LyricFormat.byWordLrc;
        lyricsTs = null;
      }

      if (type == LyricFormat.lrc || type == LyricFormat.byWordLrc) {
        return ParsedLyricModel(
          parsedLrc: parseLrc(lyricData: lyrics, lyricDataTs: lyricsTs),
          type: type,
        );
      }
      if (type == LyricFormat.yrc || type == LyricFormat.qrc) {
        return ParsedLyricModel(
          parsedLrc: parseKaraOkLyric(
            lyricData: lyrics,
            lyricDataTs: lyricsTs,
            type: type,
          ),
          type: type,
        );
      }
    } catch (_) {
      final detectType = detectLrcType(embeddedLyrics);
      if (detectType == LrcType.enhanced || detectType == LrcType.wordByWord) {
        return ParsedLyricModel(
          parsedLrc: parseLrc(lyricData: embeddedLyrics),
          type: LyricFormat.byWordLrc,
        );
      }
      if (detectType == LrcType.lineByLine) {
        return ParsedLyricModel(
          parsedLrc: parseLrc(lyricData: embeddedLyrics),
          type: LyricFormat.lrc,
        );
      }
    }

    return null;
  }

  if (lyricsData.type == LyricFormat.lrc ||
      lyricsData.type == LyricFormat.byWordLrc) {
    return ParsedLyricModel(
      parsedLrc: parseLrc(lyricData: lyricsData.lyrics),
      type: lyricsData.type,
    );
  }
  if (lyricsData.type == LyricFormat.yrc ||
      lyricsData.type == LyricFormat.qrc) {
    return ParsedLyricModel(
      parsedLrc: parseKaraOkLyric(
        lyricData: lyricsData.lyrics,
        lyricDataTs: lyricsData.lyricsTs,
        type: lyricsData.type,
      ),
      type: lyricsData.type,
    );
  }
  return null;
}
