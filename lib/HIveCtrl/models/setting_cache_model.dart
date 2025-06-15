class SettingCache {
  final String themeMode;
  final int apiIndex;
  final double volume;
  final List<String> folders;
  final Map sortMap;
  final Map viewModeMap;
  final bool isReverse;
  final int themeColor;

  const SettingCache({
    required this.themeMode,
    required this.apiIndex,
    required this.volume,
    required this.folders,
    required this.sortMap,
    required this.viewModeMap,
    required this.isReverse,
    required this.themeColor,
  });
}
