class MusicCache {
  final String title;
  final String artist;
  final String album;
  final int trackNumber;
  final String genre;
  final double duration;
  final int? bitrate;
  final int? sampleRate;
  final int bitDepth;
  final int channels;
  final double trackGain;
  final double trackPeak;
  final String path;

  MusicCache({
    required this.title,
    required this.artist,
    required this.album,
    required this.trackNumber,
    required this.genre,
    required this.duration,
    required this.bitrate,
    required this.sampleRate,
    required this.bitDepth,
    required this.channels,
    required this.trackGain,
    required this.trackPeak,
    required this.path,
  });
}
