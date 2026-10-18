import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/constants/set_constants.dart';
import 'package:zerobit_player/features/setting/controller/setting_ctrl.dart';

import '../../../../core/storage/models/music_cache_model.dart';
import '../../../../core/utils/details_ctrl_mixin.dart';

/// 列表页各组件共用的一组参数。
class AudioListViewArgs {
  final String title;

  /// 当前页类型
  final String operateArea;

  /// 播放来源标识
  final String audioSource;

  /// 歌单键
  final String userKey;

  final DetailsPageControllerBase controller;

  /// 是否处于多选态
  final Signal<bool> isMulSelect;

  /// 多选态下已选中的曲目
  final ListSignal<MusicCache> selectedList;

  /// 播放全部
  final void Function() onPlayAll;

  const AudioListViewArgs({
    required this.title,
    required this.operateArea,
    required this.audioSource,
    required this.userKey,
    required this.controller,
    required this.isMulSelect,
    required this.selectedList,
    required this.onPlayAll,
  });

  /// 当前页是否为列表视图
  bool get isListView =>
      SettingController.instance.viewModeMap[operateArea] as bool? ?? true;

  /// 当前页的排序类型
  int get sortType =>
      SettingController.instance.sortMap[operateArea] as int? ?? SortType.title;

  /// 清空已选。
  /// 因为batch的原因不用electedList.clear()
  void clearSelection() => selectedList.value = <MusicCache>[];
}
