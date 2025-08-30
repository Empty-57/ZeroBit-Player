class SettingCache {
  final String themeMode;
  final int apiIndex;
  final double volume;
  final List<String> folders;
  final Map sortMap;
  final Map viewModeMap;
  final bool isReverse;
  final int themeColor;
  final int playMode;
  final bool dynamicThemeColor;
  final String fontFamily;
  final int lrcAlignment;
  final int lrcFontSize;
  final int lrcFontWeight;
  final bool autoDownloadLrc;
  final bool useBlur;

  const SettingCache({
    required this.themeMode,
    required this.apiIndex,
    required this.volume,
    required this.folders,
    required this.sortMap,
    required this.viewModeMap,
    required this.isReverse,
    required this.themeColor,
    required this.playMode,
    required this.dynamicThemeColor,
    required this.fontFamily,
    required this.lrcAlignment,
    required this.lrcFontSize,
    required this.lrcFontWeight,
    required this.autoDownloadLrc,
    required this.useBlur,
  });
}
