import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:get/get.dart';
import 'package:pinyin/pinyin.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/hive_box.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/tools/details_ctrl_mixin.dart';

class MusicCacheController extends GetxController
    with DetailsPageControllerBase {
  @override
  final items = <MusicCache>[].obs;

  SplayTreeMap<String, List<String>> artistItemsDict =
      SplayTreeMap<String, List<String>>((a, b) => a.compareTo(b));
  final artistHasLetter = <String>[];
  double _artistViewScrollOffset = 0.0;

  SplayTreeMap<String, List<String>> albumItemsDict =
      SplayTreeMap<String, List<String>>((a, b) => a.compareTo(b));
  final albumHasLetter = <String>[];
  double _albumViewScrollOffset = 0.0;

  final _musicCacheBox = HiveBox.musicCacheBox;

  final currentScanAudio = ''.obs;
  final searchText = ''.obs;
  final searchResult = <MusicCache>[].obs;

  static final _alphaRegex = RegExp(r'[A-Z]');

  // 用于通知  DetailsPageBaseController 进行数据更改
  final songUpdatedSignal = Rx<MusicCache?>(null);

  void _search({
    required List<MusicCache> searchResult,
    required List<MusicCache> items,
    required String searchText,
  }) {
    final query = searchText.trim();
    searchResult.clear();
    if (query.isEmpty) {
      return;
    }
    final escaped = RegExp.escape(query);
    final regex = RegExp(escaped, caseSensitive: false);

    searchResult
      ..clear()
      ..addAll(
        items.where((v) {
          final fields = [v.title, v.artist, v.album];

          return fields.any((value) => regex.hasMatch(value));
        }),
      );
  }

  @override
  void onInit() {
    super.onInit();
    debounce(searchText, (_) {
      _search(
        searchResult: searchResult,
        items: items,
        searchText: searchText.value,
      );
    }, time: const Duration(milliseconds: 500));
  }

  void loadData() {
    items.value = _musicCacheBox.getAll();
    itemReSort(operateArea: OperateArea.allMusic);
    _groupItems();
  }

  String getLetter({required String str}) {
    final trimmedStr = str.trim();
    if (trimmedStr.isEmpty) return '#';

    final firstChar = trimmedStr[0];
    final pinyin = PinyinHelper.getFirstWordPinyin(firstChar);

    if (pinyin.isEmpty) {
      final upperChar = firstChar.toUpperCase();
      return _alphaRegex.hasMatch(upperChar) ? upperChar : '#';
    }
    return pinyin[0].toUpperCase();
  }

  void _groupItems() {
    artistItemsDict.clear(); // 每次都清除旧数据
    albumItemsDict.clear();
    artistHasLetter.clear();
    albumHasLetter.clear();
    for (var v in items) {
      // 处理艺术家
      final artists = v.artist.split('/');
      for (var artistName in artists) {
        final name = artistName.trim().isEmpty ? 'UNKNOWN' : artistName.trim();
        final letter = getLetter(str: name);
        final key = letter + name;

        artistItemsDict.putIfAbsent(key, () => []).add(v.path);
        artistHasLetter.addIf(!artistHasLetter.contains(letter), letter);
      }

      // 处理专辑
      final album = v.album.trim().isEmpty ? 'UNKNOWN' : v.album.trim();
      final albumLetter = getLetter(str: album);
      final albumKey = albumLetter + album;

      albumItemsDict.putIfAbsent(albumKey, () => []).add(v.path);
      albumHasLetter.addIf(!albumHasLetter.contains(albumLetter), albumLetter);
    }
    artistHasLetter.sort();
    albumHasLetter.sort();
  }

  Future<void> remove({required MusicCache metadata}) async {
    items.removeWhere((v) => v.path == metadata.path);
    await _musicCacheBox.del(
      key: md5.convert(utf8.encode(metadata.path)).toString(),
    );
    _groupItems(); // 数据删除后重新分组
  }

  double? rwScrollOffset({
    required String route,
    bool rw = true,
    double? offset,
  }) {
    // true: read, false: write
    assert(
      (rw && offset == null) || (!rw && offset != null),
      'rw=true -> offset=null  rw=false -> offset!=null',
    );
    if (rw) {
      if (route == AppRoutes.albumDetails) {
        return _albumViewScrollOffset;
      } else {
        return _artistViewScrollOffset;
      }
    } else {
      if (route == AppRoutes.albumDetails) {
        _albumViewScrollOffset = offset!;
      } else {
        _artistViewScrollOffset = offset!;
      }
      return null;
    }
  }

  MusicCache putMetadata({
    required String path,
    required int index,
    required EditableMetadata data,
  }) {
    editTags(path: path, data: data);
    final oldCache = items[index];
    final newCache = MusicCache(
      title: data.title ?? path,
      artist: data.artist ?? "UNKNOWN",
      album: data.album ?? "UNKNOWN",
      trackNumber: oldCache.trackNumber,
      genre: data.genre ?? "UNKNOWN",
      duration: oldCache.duration,
      bitrate: oldCache.bitrate,
      sampleRate: oldCache.sampleRate,
      bitDepth: oldCache.bitDepth,
      channels: oldCache.channels,
      trackGain: oldCache.trackGain,
      trackPeak: oldCache.trackPeak,
      path: oldCache.path,
    );

    _musicCacheBox.put(
      data: newCache,
      key: md5.convert(utf8.encode(path)).toString(),
    );
    items[index] = newCache;

    _groupItems(); // 数据修改后重新分组

    songUpdatedSignal.value = newCache;
    return newCache;
  }
}
