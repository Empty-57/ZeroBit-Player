import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;

import 'lyric_model.dart';

const String lyricTsSuffix = LyricFormat.lrc;

Future<void> saveLyrics({required String? path ,required Get4NetLrcModel? lrcData}) async {
  if (lrcData==null || path == null || path.isEmpty) {
    return;
  }

  try {
    final String dir = p.dirname(path);
    final String baseName = p.basenameWithoutExtension(path);

    final String lyricType = lrcData.type.startsWith('.') ? lrcData.type:'.${lrcData.type}';
    final String? lrcContent = lrcData.verbatimLrc??lrcData.lrc;

    if (lrcContent==null || lrcContent.isEmpty) {
      return;
    }

    final String? translateContent = lrcData.translate;

    final deleteQrcFile = File(p.join(dir, '$baseName${LyricFormat.qrc}'));
    final deleteYrcFile = File(p.join(dir, '$baseName${LyricFormat.yrc}'));

    if (await deleteQrcFile.exists()) {
      await deleteQrcFile.delete();
    }

    if (await deleteYrcFile.exists()) {
      await deleteYrcFile.delete();
    }

    final newLrcFile = File(p.join(dir, '$baseName$lyricType'));
    await newLrcFile.writeAsString(lrcContent);

    if (translateContent != null && translateContent.isNotEmpty) {
      final newTranslateFile = File(p.join(dir, '$baseName$lyricTsSuffix'));
      await newTranslateFile.writeAsString(translateContent);
    }

  } catch (err) {
    debugPrint('saveLyrics err: $err');
  }
}