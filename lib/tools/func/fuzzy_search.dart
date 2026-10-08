import '../../hive_manager/models/music_cache_model.dart';

bool _isSubsequence(String target, String q) {
  int i = 0;
  for (int j = 0; j < target.length && i < q.length; j++) {
    if (target[j] == q[i]) i++;
  }
  return i == q.length;
}

int _getScore(MusicCache v, String query) {
  final title = v.title.toLowerCase();
  if (title.startsWith(query)) return 4;
  final artist = v.artist.toLowerCase();
  final album = v.album.toLowerCase();
  if (title.contains(query) ||
      artist.startsWith(query) ||
      album.startsWith(query)) {
    return 3;
  }
  final full = '$title $artist $album';
  if (full.contains(query)) return 2;
  if (_isSubsequence(full, query)) return 1;
  return 0;
}

List<MusicCache> fuzzySearch(List<MusicCache> items, String query) {
  final scoredList = <(MusicCache, int)>[];
  for (final item in items) {
    final score = _getScore(item, query);
    if (score > 0) {
      scoredList.add((item, score));
    }
  }
  scoredList.sort((a, b) => b.$2.compareTo(a.$2));

  return scoredList.map((e) => e.$1).toList();
}
