import 'dart:convert';

import 'package:flutter/cupertino.dart';

/// 提取并解码 KRC 文本中的 language Base64 数据
String? krcExtractAndDecodeLanguage(String? krcText) {
  if (krcText == null) {
    return null;
  }
  RegExp regExp = RegExp(r'\[language:(.*?)\]');
  Match? match = regExp.firstMatch(krcText);
  if (match != null) {
    String base64String = match.group(1)!;
    // 如果 base64 字符串为空，直接返回
    if (base64String.trim().isEmpty) return null;

    try {
      // Base64 转字符串解
      List<int> bytes = base64Decode(base64String);
      String decodedText = utf8.decode(bytes);
      return decodedText;
    } catch (e) {
      debugPrint("Decode Base64 Err: $e");
      return null;
    }
  }
  return null;
}