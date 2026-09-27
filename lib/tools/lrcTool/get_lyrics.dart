import 'dart:convert';
import 'dart:io';

import 'package:fl_charset/fl_charset.dart';
import 'package:path/path.dart' as p;
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/logger.dart';
import 'package:zerobit_player/tools/lrcTool/parse_lyrics.dart';

import '../../API/apis.dart';
import '../../field/set_constants.dart';
import '../../hive_manager/models/music_cache_model.dart';
import '../../src/rust/api/music_tag_tool.dart';
import 'krc_decryptor.dart';
import 'krc_extract_decode.dart';
import 'lyric_model.dart';
import 'qrc_decryptor.dart';

/// 支持的歌词扩展名
const List<String> _lyricExts = [
  LyricFormat.qrc,
  LyricFormat.krc,
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
    LoggerUni.i("localLyric | encoding: ${encoding.name} ext: $ext");
    final String lrc = encoding.decode(bytes);
    if (ext == LyricFormat.qrc) {
      if (!lrc.trimLeft().startsWith('<?xml') &&
          !lrc.trimLeft().startsWith('<Qrc')) {
        return await qrcDecrypt(encryptedQrc: bytes, isLocal: true);
      }
      return lrc;
    }

    if (ext == LyricFormat.krc) {
      if (!lrc.trimLeft().startsWith('[ti:') &&
          !lrc.trimLeft().contains(']<0')) {
        return krcDecrypt(lrc);
      }
      return lrc;
    }

    return lrc;
  } catch (e, stackTrace) {
    LoggerUni.w('读取本地歌词失败 Path: $filePath', e, stackTrace);
    return null;
  }
}

class LyricModel {
  final String? lyrics;
  final String? lyricsTs;
  final String type;
  const LyricModel({
    required this.lyrics,
    required this.lyricsTs,
    required this.type,
  });
}

Future<LyricModel?> _getLocalLyrics({required String filePath}) async {
  if (filePath.isEmpty) return null;

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

      if (type == LyricFormat.qrc || type == LyricFormat.yrc) {
        lyricsTs = await _safeReadFile(vtsPath);
      }

      if (type == LyricFormat.krc) {
        lyricsTs = krcExtractAndDecodeLanguage(lyrics);
      }

      return LyricModel(lyrics: lyrics, lyricsTs: lyricsTs, type: type);
    }
  }

  return null;
}

Future<LyricModel?> _getEmbeddedLyrics({required String filePath}) async {
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
        (detectType == LrcType.enhanced || detectType == LrcType.wordByWord)) {
      type = LyricFormat.byWordLrc;
      lyricsTs = null;
    }

    return LyricModel(lyrics: lyrics, lyricsTs: lyricsTs, type: type);
  } catch (_) {
    final detectType = detectLrcType(embeddedLyrics);
    if (detectType == LrcType.enhanced || detectType == LrcType.wordByWord) {
      return LyricModel(
        lyrics: embeddedLyrics,
        lyricsTs: null,
        type: LyricFormat.byWordLrc,
      );
    }
    if (detectType == LrcType.lineByLine) {
      return LyricModel(
        lyrics: embeddedLyrics,
        lyricsTs: null,
        type: LyricFormat.lrc,
      );
    }
  }
  return null;
}

Future<LyricModel?> getNetLyrics({required MusicCache metadata}) async {
  final searchedLyric = await getLrcBySearch(
    text: "${metadata.title} - ${metadata.artist}",
    offset: 1,
    limit: 1,
  );

  if (searchedLyric.isEmpty) return null;

  final lyricInfo = searchedLyric.first?.lyric;
  if (lyricInfo == null) return null;

  final type = lyricInfo.type;
  LyricModel? parsedResult;

  if (type == LyricFormat.lrc) {
    parsedResult = LyricModel(
      lyrics: lyricInfo.lrc,
      lyricsTs: lyricInfo.translate,
      type: type,
    );
  } else if (type == LyricFormat.yrc ||
      type == LyricFormat.qrc ||
      type == LyricFormat.krc) {
    parsedResult = LyricModel(
      lyrics: lyricInfo.verbatimLrc,
      lyricsTs: lyricInfo.translate,
      type: type,
    );
  }

  if (parsedResult == null) return null;

  return parsedResult;
}

/// 主入口，获取已解析的歌词及翻译
Future<ParsedLyricModel?> getParsedLyric({required String filePath}) async {
  if (filePath.isEmpty) return null;
  final lyricSource = SettingController.instance.lyricSource.value;
  final sources = [
    lyricSource,
    ...SettingController.lyricSourceMap.keys.where(
      (source) => source != lyricSource,
    ),
  ];
  String label = 'localLyric';

  LyricModel? lyricsData;
  for (final source in sources) {
    (lyricsData, label) = switch (source) {
      LyricSourceType.local => (
        await _getLocalLyrics(filePath: filePath),
        'localLyric',
      ),
      LyricSourceType.embedded => (
        await _getEmbeddedLyrics(filePath: filePath),
        'embeddedLyric',
      ),
      LyricSourceType.net => (
        await getNetLyrics(
          metadata: AudioController.instance.currentMetadata.value,
        ),
        'netLyric',
      ),
      _ => (null, ''),
    };
    if (lyricsData != null) {
      break;
    }
  }

  if (lyricsData == null) return null;

  LoggerUni.i("$label | type: ${lyricsData.type}");
  if (lyricsData.type == LyricFormat.lrc ||
      lyricsData.type == LyricFormat.byWordLrc) {
    return ParsedLyricModel(
      parsedLrc: await parseLrc(lyricData: lyricsData.lyrics),
      type: lyricsData.type,
    );
  }
  if (lyricsData.type == LyricFormat.yrc ||
      lyricsData.type == LyricFormat.qrc ||
      lyricsData.type == LyricFormat.krc) {
    return ParsedLyricModel(
      parsedLrc: await parseKaraOkLyric(
        lyricData: lyricsData.lyrics,
        lyricDataTs: lyricsData.lyricsTs,
        type: lyricsData.type,
      ),
      type: lyricsData.type,
    );
  }
  return null;
}
