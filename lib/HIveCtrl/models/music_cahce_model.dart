import 'dart:typed_data';

class MusicCache {
  final String title;
  final String artist;
  final String album;
  final String genre;
  final double duration;
  final int? bitrate;
  final int? sampleRate;
  final String path;

  Uint8List? src;

  MusicCache({
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.duration,
    required this.bitrate,
    required this.sampleRate,
    required this.path,
    this.src,
  });
}
