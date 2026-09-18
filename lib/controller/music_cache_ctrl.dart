import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pinyin/pinyin.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/hive_box.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/tools/details_ctrl_mixin.dart';

class MusicCacheController with DetailsPageControllerBase {
  MusicCacheController._();
  static final MusicCacheController instance = MusicCacheController._();

  @override
  final items = listSignal(<MusicCache>[]);

  SplayTreeMap<String, List<String>> artistItemsDict =
      SplayTreeMap<String, List<String>>((a, b) => a.compareTo(b));
  final artistHasLetter = <String>[];
  double _artistViewScrollOffset = 0.0;

  SplayTreeMap<String, List<String>> albumItemsDict =
      SplayTreeMap<String, List<String>>((a, b) => a.compareTo(b));
  final albumHasLetter = <String>[];
  double _albumViewScrollOffset = 0.0;

  double _homeViewScrollOffset = 0.0;

  final _musicCacheBox = HiveBox.musicCacheBox;

  final currentScanAudio = signal('');
  final _searchText = signal('');

  late final searchResult = computed<List<MusicCache>>(() {
    final query = _searchText.value.trim();
    if (query.isEmpty) {
      return const [];
    }
    final escaped = RegExp.escape(query);
    final regex = RegExp(escaped, caseSensitive: false);

    return items.where((v) {
      final fields = [v.title, v.artist, v.album];

      return fields.any((value) => regex.hasMatch(value));
    }).toList();
  });

  static final _alphaRegex = RegExp(r'[A-Z]');

  // 用于通知  DetailsPageBaseController 进行数据更改
  final songUpdatedSignal = signal<MusicCache?>(null);

  Timer? _debounceTimer;

  void resetSearch() {
    _debounceTimer?.cancel();
    _searchText.value = '';
  }

  void onInputChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchText.value = text;
    });
  }

  void dispose() {
    _debounceTimer?.cancel();
    currentScanAudio.dispose();
    _searchText.dispose();
    searchResult.dispose();
    songUpdatedSignal.dispose();
    items.dispose();
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
        if (!artistHasLetter.contains(letter)) {
          artistHasLetter.add(letter);
        }
      }

      // 处理专辑
      final album = v.album.trim().isEmpty ? 'UNKNOWN' : v.album.trim();
      final albumLetter = getLetter(str: album);
      final albumKey = albumLetter + album;

      albumItemsDict.putIfAbsent(albumKey, () => []).add(v.path);
      if (!albumHasLetter.contains(albumLetter)) {
        albumHasLetter.add(albumLetter);
      }
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
      switch (route) {
        case AppRoutes.albumDetails:
          return _albumViewScrollOffset;
        case AppRoutes.artistDetails:
          return _artistViewScrollOffset;
        case AppRoutes.home:
          return _homeViewScrollOffset;
        default:
          return null;
      }
    } else {
      switch (route) {
        case AppRoutes.albumDetails:
          _albumViewScrollOffset = offset!;
        case AppRoutes.artistDetails:
          _artistViewScrollOffset = offset!;
        case AppRoutes.home:
          _homeViewScrollOffset = offset!;
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
