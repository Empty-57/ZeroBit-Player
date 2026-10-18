import 'dart:convert';

import '../../../core/utils/logger.dart';

/// 提取并解码 KRC 文本中的 language Base64 数据
String? krcExtractAndDecodeLanguage(String? krcText) {
  if (krcText == null) {
    return null;
  }
  final RegExp regExp = RegExp(r'\[language:(.*?)\]');
  final Match? match = regExp.firstMatch(krcText);
  if (match != null) {
    final String base64String = match.group(1)!;
    // 如果 base64 字符串为空，直接返回
    if (base64String.trim().isEmpty) return null;

    try {
      // Base64 转字符串解
      final List<int> bytes = base64Decode(base64String);
      final String decodedText = utf8.decode(bytes);
      return decodedText;
    } catch (e, stackTrace) {
      LoggerUni.w("解码Base64失败", e, stackTrace);
      return null;
    }
  }
  return null;
}
