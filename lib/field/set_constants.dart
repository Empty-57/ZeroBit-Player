abstract class SortType {
  static const int title = 0;
  static const int artist = 1;
  static const int album = 2;
  static const int duration = 3;
  static const int editTime = 4;
  static const int createTime = 5;
  static const int trackNumber = 6;
}

abstract class SpectrogramStyleType {
  static const int none = 0;
  static const int rect = 1;
  static const int waveform = 2;
  static const int wave = 3;
}

abstract class LrcAlignmentType {
  static const int left = 0;
  static const int center = 1;
  static const int right = 2;
}
