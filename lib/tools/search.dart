import 'package:zerobit_player/HIveCtrl/models/music_cache_model.dart';

void search({
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
