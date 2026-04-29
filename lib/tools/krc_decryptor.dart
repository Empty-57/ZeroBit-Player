import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';

final List<int> _krcKey = [
  64,
  71,
  97,
  119,
  94,
  50,
  116,
  71,
  81,
  54,
  49,
  45,
  206,
  210,
  110,
  105,
];

String? decodeKrc(String content) {
  List<int> bytes = base64Decode(content);

  if (bytes.length <= 4) {
    debugPrint('解压失败:krc');
    return null;
  }
  List<int> contentBytes = bytes.sublist(4);

  try {
    Uint8List krcCompress = Uint8List(contentBytes.length);
    for (int k = 0; k < contentBytes.length; k++) {
      krcCompress[k] = contentBytes[k] ^ _krcKey[k % 16];
    }

    return utf8.decode(zlib.decode(krcCompress));
  } catch (e) {
    debugPrint('解压失败: $e');
    return null;
  }
}
