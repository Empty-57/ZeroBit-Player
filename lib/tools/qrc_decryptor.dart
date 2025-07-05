// 转写自: https://github.com/chenmozhijin/LDDC/tree/main/LDDC/core/decryptor

import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:flutter/cupertino.dart';

const int _encrypt = 1;
const int _devrypt = 0;

final Uint8List _qrcKey = Uint8List.fromList(utf8.encode(r'!@#)(*$%123ZXC!@!@#)(NHL'));

// const _krcKey = Uint8List.fromList(utf8.encode(r"@Gaw^2tGQ61-\xce\xd2ni"));

final Uint8List _privKey = Uint8List.fromList([
  0xc3, 0x4a, 0xd6, 0xca, 0x90, 0x67, 0xf7, 0x52,
  0xd8, 0xa1, 0x66, 0x62, 0x9f, 0x5b, 0x09, 0x00,
  0xc3, 0x5e, 0x95, 0x23, 0x9f, 0x13, 0x11, 0x7e,
  0xd8, 0x92, 0x3f, 0xbc, 0x90, 0xbb, 0x74, 0x0e,
  0xc3, 0x47, 0x74, 0x3d, 0x90, 0xaa, 0x3f, 0x51,
  0xd8, 0xf4, 0x11, 0x84, 0x9f, 0xde, 0x95, 0x1d,
  0xc3, 0xc6, 0x09, 0xd5, 0x9f, 0xfa, 0x66, 0xf9,
  0xd8, 0xf0, 0xf7, 0xa0, 0x90, 0xa1, 0xd6, 0xf3,
  0xc3, 0xf3, 0xd6, 0xa1, 0x90, 0xa0, 0xf7, 0xf0,
  0xd8, 0xf9, 0x66, 0xfa, 0x9f, 0xd5, 0x09, 0xc6,
  0xc3, 0x1d, 0x95, 0xde, 0x9f, 0x84, 0x11, 0xf4,
  0xd8, 0x51, 0x3f, 0xaa, 0x90, 0x3d, 0x74, 0x47,
  0xc3, 0x0e, 0x74, 0xbb, 0x90, 0xbc, 0x3f, 0x92,
  0xd8, 0x7e, 0x11, 0x13, 0x9f, 0x23, 0x95, 0x5e,
  0xc3, 0x00, 0x09, 0x5b, 0x9f, 0x62, 0x66, 0xa1,
  0xd8, 0x52, 0xf7, 0x67, 0x90, 0xca, 0xd6, 0x4a,
]);

// S-Box，共8个，每个256个元素
final List<List<int>> _sbox = [
  [
    14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7,
    0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8,
    4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0,
    15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13
  ],
  [
    15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10,
    3, 13, 4, 7, 15, 2, 8, 15, 12, 0, 1, 10, 6, 9, 11, 5,
    0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15,
    13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9
  ],
  [
    10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8,
    13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1,
    13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7,
    1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12
  ],
  [
    7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15,
    13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9,
    10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4,
    3, 15, 0, 6, 10, 10, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14
  ],
  [
    2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9,
    14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6,
    4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14,
    11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3
  ],
  [
    12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11,
    10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8,
    9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6,
    4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13
  ],
  [
    4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1,
    13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6,
    1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2,
    6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12
  ],
  [
    13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7,
    1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2,
    7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8,
    2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11
  ],
];

/// 从 a（长度至少8的 Uint8List）中取第 b 位，左移 c 位后返回
int _bitnum(Uint8List a, int b, int c) {
  final pos = (b ~/ 32) * 4 + 3 - ((b % 32) ~/ 8);
  return ((a[pos] >>> (7 - b % 8)) & 1) << c;
}

/// 从 32 位整数 a 中无符号右移第 b 位，左移 c 位后返回
int _bitnumIntr(int a, int b, int c) {
  return((a >>> (31 - b)) & 1) << c;
}

/// 将 32 位整数 a 左移 b 位，并与 0x80000000 做与后，逻辑右移 c 位
int _bitnumIntl(int a, int b, int c) {
  return ((a << b) & 0x80000000) >>> c;
}

/// 将 6 位输入 a 转换为对应 S-Box 索引
int _sboxBit(int a) {
  return (a & 32) | ((a & 31) >>> 1) | ((a & 1) << 4);
}

/// 初始置换，将输入 8 字节（64 位）拆成两个 32 位数 [s0, s1]
List<int> _initialPermutation(Uint8List inputData) {
  var s0 = 0, s1 = 0;

  // s0 calculation
  s0 |= _bitnum(inputData, 57, 31); s0 |= _bitnum(inputData, 49, 30);
  s0 |= _bitnum(inputData, 41, 29); s0 |= _bitnum(inputData, 33, 28);
  s0 |= _bitnum(inputData, 25, 27); s0 |= _bitnum(inputData, 17, 26);
  s0 |= _bitnum(inputData, 9, 25);  s0 |= _bitnum(inputData, 1, 24);
  s0 |= _bitnum(inputData, 59, 23); s0 |= _bitnum(inputData, 51, 22);
  s0 |= _bitnum(inputData, 43, 21); s0 |= _bitnum(inputData, 35, 20);
  s0 |= _bitnum(inputData, 27, 19); s0 |= _bitnum(inputData, 19, 18);
  s0 |= _bitnum(inputData, 11, 17); s0 |= _bitnum(inputData, 3, 16);
  s0 |= _bitnum(inputData, 61, 15); s0 |= _bitnum(inputData, 53, 14);
  s0 |= _bitnum(inputData, 45, 13); s0 |= _bitnum(inputData, 37, 12);
  s0 |= _bitnum(inputData, 29, 11); s0 |= _bitnum(inputData, 21, 10);
  s0 |= _bitnum(inputData, 13, 9);  s0 |= _bitnum(inputData, 5, 8);
  s0 |= _bitnum(inputData, 63, 7);  s0 |= _bitnum(inputData, 55, 6);
  s0 |= _bitnum(inputData, 47, 5);  s0 |= _bitnum(inputData, 39, 4);
  s0 |= _bitnum(inputData, 31, 3);  s0 |= _bitnum(inputData, 23, 2);
  s0 |= _bitnum(inputData, 15, 1);  s0 |= _bitnum(inputData, 7, 0);

  // s1 calculation
  s1 |= _bitnum(inputData, 56, 31); s1 |= _bitnum(inputData, 48, 30);
  s1 |= _bitnum(inputData, 40, 29); s1 |= _bitnum(inputData, 32, 28);
  s1 |= _bitnum(inputData, 24, 27); s1 |= _bitnum(inputData, 16, 26);
  s1 |= _bitnum(inputData, 8, 25);  s1 |= _bitnum(inputData, 0, 24);
  s1 |= _bitnum(inputData, 58, 23); s1 |= _bitnum(inputData, 50, 22);
  s1 |= _bitnum(inputData, 42, 21); s1 |= _bitnum(inputData, 34, 20);
  s1 |= _bitnum(inputData, 26, 19); s1 |= _bitnum(inputData, 18, 18);
  s1 |= _bitnum(inputData, 10, 17); s1 |= _bitnum(inputData, 2, 16);
  s1 |= _bitnum(inputData, 60, 15); s1 |= _bitnum(inputData, 52, 14);
  s1 |= _bitnum(inputData, 44, 13); s1 |= _bitnum(inputData, 36, 12);
  s1 |= _bitnum(inputData, 28, 11); s1 |= _bitnum(inputData, 20, 10);
  s1 |= _bitnum(inputData, 12, 9);  s1 |= _bitnum(inputData, 4, 8);
  s1 |= _bitnum(inputData, 62, 7);  s1 |= _bitnum(inputData, 54, 6);
  s1 |= _bitnum(inputData, 46, 5);  s1 |= _bitnum(inputData, 38, 4);
  s1 |= _bitnum(inputData, 30, 3);  s1 |= _bitnum(inputData, 22, 2);
  s1 |= _bitnum(inputData, 14, 1);  s1 |= _bitnum(inputData, 6, 0);

  return [s0 >>> 0, s1 >>> 0]; // 转换为无符号32位整数
}

/// 逆置换，将两个 32 位数 s0, s1 合成 8 字节数据
Uint8List _inversePermutation(int s0, int s1) {
  final Uint8List data = Uint8List(8);

  data[3] = (_bitnumIntr(s1, 7, 7) |
      _bitnumIntr(s0, 7, 6) |
      _bitnumIntr(s1, 15, 5) |
      _bitnumIntr(s0, 15, 4) |
      _bitnumIntr(s1, 23, 3) |
      _bitnumIntr(s0, 23, 2) |
      _bitnumIntr(s1, 31, 1) |
      _bitnumIntr(s0, 31, 0));

  data[2] = (_bitnumIntr(s1, 6, 7) |
      _bitnumIntr(s0, 6, 6) |
      _bitnumIntr(s1, 14, 5) |
      _bitnumIntr(s0, 14, 4) |
      _bitnumIntr(s1, 22, 3) |
      _bitnumIntr(s0, 22, 2) |
      _bitnumIntr(s1, 30, 1) |
      _bitnumIntr(s0, 30, 0));

  data[1] = (_bitnumIntr(s1, 5, 7) |
      _bitnumIntr(s0, 5, 6) |
      _bitnumIntr(s1, 13, 5) |
      _bitnumIntr(s0, 13, 4) |
      _bitnumIntr(s1, 21, 3) |
      _bitnumIntr(s0, 21, 2) |
      _bitnumIntr(s1, 29, 1) |
      _bitnumIntr(s0, 29, 0));

  data[0] = (_bitnumIntr(s1, 4, 7) |
      _bitnumIntr(s0, 4, 6) |
      _bitnumIntr(s1, 12, 5) |
      _bitnumIntr(s0, 12, 4) |
      _bitnumIntr(s1, 20, 3) |
      _bitnumIntr(s0, 20, 2) |
      _bitnumIntr(s1, 28, 1) |
      _bitnumIntr(s0, 28, 0));

  data[7] = (_bitnumIntr(s1, 3, 7) |
      _bitnumIntr(s0, 3, 6) |
      _bitnumIntr(s1, 11, 5) |
      _bitnumIntr(s0, 11, 4) |
      _bitnumIntr(s1, 19, 3) |
      _bitnumIntr(s0, 19, 2) |
      _bitnumIntr(s1, 27, 1) |
      _bitnumIntr(s0, 27, 0));

  data[6] = (_bitnumIntr(s1, 2, 7) |
      _bitnumIntr(s0, 2, 6) |
      _bitnumIntr(s1, 10, 5) |
      _bitnumIntr(s0, 10, 4) |
      _bitnumIntr(s1, 18, 3) |
      _bitnumIntr(s0, 18, 2) |
      _bitnumIntr(s1, 26, 1) |
      _bitnumIntr(s0, 26, 0));

  data[5] = (_bitnumIntr(s1, 1, 7) |
      _bitnumIntr(s0, 1, 6) |
      _bitnumIntr(s1, 9, 5) |
      _bitnumIntr(s0, 9, 4) |
      _bitnumIntr(s1, 17, 3) |
      _bitnumIntr(s0, 17, 2) |
      _bitnumIntr(s1, 25, 1) |
      _bitnumIntr(s0, 25, 0));

  data[4] = (_bitnumIntr(s1, 0, 7) |
      _bitnumIntr(s0, 0, 6) |
      _bitnumIntr(s1, 8, 5) |
      _bitnumIntr(s0, 8, 4) |
      _bitnumIntr(s1, 16, 3) |
      _bitnumIntr(s0, 16, 2) |
      _bitnumIntr(s1, 24, 1) |
      _bitnumIntr(s0, 24, 0));

  return data;
}

/// 基本函数 f，对 32 位 state 和 6 字节子密钥进行运算，返回 32 位结果
int _f(int state, List<int> key) {
  int uState = state & 0xFFFFFFFF;

  int t1 = (_bitnumIntl(uState, 31, 0) |
      ((uState & 0xF0000000) >>> 1) |
      _bitnumIntl(uState, 4, 5) |
      _bitnumIntl(uState, 3, 6) |
      ((uState & 0x0F000000) >>> 3) |
      _bitnumIntl(uState, 8, 11) |
      _bitnumIntl(uState, 7, 12) |
      ((uState & 0x00F00000) >>> 5) |
      _bitnumIntl(uState, 12, 17) |
      _bitnumIntl(uState, 11, 18) |
      ((uState & 0x000F0000) >>> 7) |
      _bitnumIntl(uState, 16, 23));

  int t2 = (_bitnumIntl(uState, 15, 0) |
      ((uState & 0x0000F000) << 15) |
      _bitnumIntl(uState, 20, 5) |
      _bitnumIntl(uState, 19, 6) |
      ((uState & 0x00000F00) << 13) |
      _bitnumIntl(uState, 24, 11) |
      _bitnumIntl(uState, 23, 12) |
      ((uState & 0x000000F0) << 11) |
      _bitnumIntl(uState, 28, 17) |
      _bitnumIntl(uState, 27, 18) |
      ((uState & 0x0000000F) << 9) |
      _bitnumIntl(uState, 0, 23));

  // 将 t1, t2 拆成 6 字节，并与子密钥异或
  final List<int> lrgstate_ = [
    (t1 >>> 24) & 0x000000ff, (t1 >>> 16) & 0x000000ff, (t1 >>> 8) & 0x000000ff,
    (t2 >>> 24) & 0x000000ff, (t2 >>> 16) & 0x000000ff, (t2 >>> 8) & 0x000000ff,
  ];

  final List<int> lrgstate = List.filled(6, 0);
  for (int i = 0; i < 6; i++) {
    lrgstate[i] = lrgstate_[i] ^ key[i];
  }

  // 根据 S-Box 进行置换
  int newState = 0;
  newState |= (_sbox[0][_sboxBit(lrgstate[0] >>> 2)] << 28);
  newState |= (_sbox[1][_sboxBit(((lrgstate[0] & 0x03) << 4) | (lrgstate[1] >>> 4))] << 24);
  newState |= (_sbox[2][_sboxBit(((lrgstate[1] & 0x0F) << 2) | (lrgstate[2] >>> 6))] << 20);
  newState |= (_sbox[3][_sboxBit(lrgstate[2] & 0x3F)] << 16);
  newState |= (_sbox[4][_sboxBit(lrgstate[3] >>> 2)] << 12);
  newState |= (_sbox[5][_sboxBit(((lrgstate[3] & 0x03) << 4) | (lrgstate[4] >>> 4))] << 8);
  newState |= (_sbox[6][_sboxBit(((lrgstate[4] & 0x0F) << 2) | (lrgstate[5] >>> 6))] << 4);
  newState |= _sbox[7][_sboxBit(lrgstate[5] & 0x3F)];

  // 最终的 P-置换
  int result = 0;
  result |= _bitnumIntl(newState, 15, 0);
  result |= _bitnumIntl(newState, 6, 1);
  result |= _bitnumIntl(newState, 19, 2);
  result |= _bitnumIntl(newState, 20, 3);
  result |= _bitnumIntl(newState, 28, 4);
  result |= _bitnumIntl(newState, 11, 5);
  result |= _bitnumIntl(newState, 27, 6);
  result |= _bitnumIntl(newState, 16, 7);
  result |= _bitnumIntl(newState, 0, 8);
  result |= _bitnumIntl(newState, 14, 9);
  result |= _bitnumIntl(newState, 22, 10);
  result |= _bitnumIntl(newState, 25, 11);
  result |= _bitnumIntl(newState, 4, 12);
  result |= _bitnumIntl(newState, 17, 13);
  result |= _bitnumIntl(newState, 30, 14);
  result |= _bitnumIntl(newState, 9, 15);
  result |= _bitnumIntl(newState, 1, 16);
  result |= _bitnumIntl(newState, 7, 17);
  result |= _bitnumIntl(newState, 23, 18);
  result |= _bitnumIntl(newState, 13, 19);
  result |= _bitnumIntl(newState, 31, 20);
  result |= _bitnumIntl(newState, 26, 21);
  result |= _bitnumIntl(newState, 2, 22);
  result |= _bitnumIntl(newState, 8, 23);
  result |= _bitnumIntl(newState, 18, 24);
  result |= _bitnumIntl(newState, 12, 25);
  result |= _bitnumIntl(newState, 29, 26);
  result |= _bitnumIntl(newState, 5, 27);
  result |= _bitnumIntl(newState, 21, 28);
  result |= _bitnumIntl(newState, 10, 29);
  result |= _bitnumIntl(newState, 3, 30);
  result |= _bitnumIntl(newState, 24, 31);

  return result;
}

/// 对单个 8 字节块执行 16 轮加解密，返回 8 字节结果
Uint8List _crypt(Uint8List inputData, List<List<int>> key) {
  List<int> perm = _initialPermutation(inputData);
  int s0 = perm[0];
  int s1 = perm[1];

  // 前 15 轮
  for (int idx = 0; idx < 15; idx++) {
    int previousS1 = s1;
    s1 = _f(s1, key[idx]) ^ s0;
    s0 = previousS1;
  }
  // 第 16 轮（最后一轮不交换）
  s0 = _f(s1, key[15]) ^ s0;

  // 逆置换
  return _inversePermutation(s0, s1);
}

/// 生成 16 轮子密钥表，每轮 6 字节
List<List<int>> _keySchedule(Uint8List key, int mode) {
  final List<List<int>> schedule =
      List.generate(16, (_) => List.filled(6, 0));

  final List<int> keyRndShift = [
    1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1
  ];
  final List<int> keyPermC = [
    56, 48, 40, 32, 24, 16, 8, 0,
    57, 49, 41, 33, 25, 17, 9, 1,
    58, 50, 42, 34, 26, 18, 10, 2,
    59, 51, 43, 35
  ];
  final List<int> keyPermD = [
    62, 54, 46, 38, 30, 22, 14, 6,
    61, 53, 45, 37, 29, 21, 13, 5,
    60, 52, 44, 36, 28, 20, 12, 4,
    27, 19, 11, 3
  ];
  final List<int> keyCompression = [
    13, 16, 10, 23, 0, 4, 2, 27,
    14, 5, 20, 9, 22, 18, 11, 3,
    25, 7, 15, 6, 26, 19, 12, 1,
    40, 51, 30, 36, 46, 54, 29, 39,
    50, 44, 32, 47, 43, 48, 38, 55,
    33, 52, 45, 41, 49, 35, 28, 31
  ];

  int c = 0;
  int d = 0;

  // 初始置换 C, D（各 28 位）
  for (int i = 0; i < 28; i++) {
    c += _bitnum(key, keyPermC[i], 31 - i);
    d += _bitnum(key, keyPermD[i], 31 - i);
  }

  for (int i = 0; i < 16; i++) {
    // 循环左移
    c = (((c << keyRndShift[i]) | (c >>> (28 - keyRndShift[i]))) &
        0xFFFFFFF0);
    d = (((d << keyRndShift[i]) | (d >>> (28 - keyRndShift[i]))) &
        0xFFFFFFF0);

    // 计算生成子密钥的索引：加密正序，解密反序
    int togen = (mode == _devrypt) ? (15 - i) : i;

    // 清空当前轮的子密钥
    for (int j = 0; j < 6; j++) {
      schedule[togen][j] = 0;
    }

    // 压缩置换：前 24 位来自 C，后 24 位来自 D
    for (int j = 0; j < 24; j++) {
      schedule[togen][j ~/ 8] |=
          _bitnumIntr(c, keyCompression[j], 7 - (j % 8));
    }
    for (int j = 24; j < 48; j++) {
      schedule[togen][j ~/ 8] |=
          _bitnumIntr(d, keyCompression[j] - 27, 7 - (j % 8));
    }
  }

  return schedule;
}

void _qmc1Decrypt(Uint8List data) {
  for (int i = 0; i < data.length; i++) {
    final keyIndex = i > 0x7FFF ? (i % 0x7FFF) & 0x7F : i & 0x7F;
    data[i] ^= _privKey[keyIndex];
  }
}

/// 3DES 密钥调度：返回包含 3 个 16 轮子密钥表的列表
List<List<List<int>>> _tripleDesKeySetup(Uint8List key, int mode) {
  // key.length == 24
  if (mode == _encrypt) {
    return [
      _keySchedule(key.sublist(0, 8), _encrypt),
      _keySchedule(key.sublist(8, 16), _devrypt),
      _keySchedule(key.sublist(16, 24), _encrypt),
    ];
  }
  // 解密：倒序并切换每段子密钥方向
  return [
    _keySchedule(key.sublist(16, 24), _devrypt),
    _keySchedule(key.sublist(8, 16), _encrypt),
    _keySchedule(key.sublist(0, 8), _devrypt),
  ];
}

/// 3DES 分组加/解密：对单个 8 字节块，依次经过三个 DES
Uint8List _tripleDesCrypt(Uint8List data, List<List<List<int>>> key) {
  for (int i = 0; i < 3; i++) {
    data = _crypt(data, key[i]);
  }
  return data;
}

Future<String?> qrcDecrypt({required dynamic encryptedQrc,required bool isLocal}) async {
  if (encryptedQrc == null) {
    return null;
  }

  Uint8List encryptedBytes;
  if (encryptedQrc is String) {
    encryptedBytes = Uint8List.fromList(hex.decode(encryptedQrc));
  } else if (encryptedQrc is Uint8List) {
    encryptedBytes = encryptedQrc;
  } else {
    debugPrint('未知类型');
    return null;
  }

  try {
    if (isLocal) {
      _qmc1Decrypt(encryptedBytes);
      encryptedBytes = encryptedBytes.sublist(11);
    }

      final List<int> data = [];
final schedule = _tripleDesKeySetup(_qrcKey, _devrypt);

  for (int i = 0; i < encryptedBytes.length; i += 8) {
    data.addAll([..._tripleDesCrypt(encryptedBytes.sublist(i), schedule)]);
  }

    return utf8.decode(ZLibDecoder().convert(data));
  } catch (e) {
    debugPrint('解压失败: $e');
    return null;
  }
}
