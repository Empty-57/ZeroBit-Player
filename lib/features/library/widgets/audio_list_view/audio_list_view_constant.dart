library;

import 'package:zerobit_player/core/constants/ui_constants.dart';
import 'package:zerobit_player/features/player/widgets/play_bar_constant.dart';

abstract final class AudioListViewSpec {
  /// 列表行高
  static const double itemHeight = 64.0;

  /// 列表底部留白
  static const double listBottomInset = itemHeight * 2;

  /// 头部封面边长
  static const double headerCoverSize = 240.0;

  /// 操作按钮高度
  static const double actionHeight = 42.0;
  static const double actionSquare = 42.0;

  /// 分组容器的内边距
  static const double actionGroupPadding = AppSpacing.xxs;
  static const double groupedActionHeight =
      actionHeight - actionGroupPadding * 2 + AppSize.hairline * 2;

  /// 播放按钮、排序按钮宽度
  static const double playButtonWidth = 96.0;
  static const double sortButtonWidth = 148.0;

  /// 下拉菜单项宽度
  static const double sortMenuWidth = 128.0;
  static const double playlistMenuWidth = 160.0;

  // 网格视图
  /// 每列最小宽度
  static const double gridMinColumnWidth = 280.0;
  static const int gridMaxColumns = 6;

  static const double gridMainSpacing = AppSpacing.xs;
  static const double gridCrossSpacing = AppSpacing.md;

  /// 网格每行占位高度
  static const double gridRowExtent = itemHeight + gridMainSpacing;

  /// 按内容宽度算网格列数
  static int gridColumnsFor(double contentWidth) =>
      (contentWidth / gridMinColumnWidth).floor().clamp(1, gridMaxColumns);

  // 右键菜单
  static const double menuWidth = 180.0;
  static const double menuItemHeight = 48.0;

  /// 菜单与光标之间的间隙
  static const double menuCursorGap = AppSpacing.xl;

  static const double menuItemPaddingH = AppSpacing.xl;

  // 浮动按钮
  /// 底部悬浮播放栏占用的高度
  static const double playBarInset = PlayBarSpec.occupiedHeight;

  static const double floatingBottom = playBarInset;
  static const double floatingRight = 64.0;
  static const double floatingButtonSize = 40.0;
  static const double floatingSpacing = AppSpacing.xs;

  /// 滚动定位的动画时长
  static const Duration scrollAnimation = Duration(milliseconds: 300);
}
