library;

import 'package:flutter/material.dart';
import 'package:zerobit_player/field/ui_constants.dart';

/// 页面布局常量
abstract final class StatisticsLayout {
  /// 概览卡由 2 列切到 3 列的宽度阈值，与侧栏展开用同一个断点
  static const double wideBreakpoint = AppBreakpoint.wide;

  static const int overviewColumnsWide = 3;
  static const int overviewColumnsNarrow = 2;

  /// 概览单卡高度
  static const double overviewTileHeight = 58.0;

  /// 概览卡左侧图标容器边长
  static const double overviewIconBox = 34.0;

  /// 排行榜行高
  static const double rankTileHeight = 64.0;

  /// 列表底部留白
  static const double listBottomInset = rankTileHeight * 2;

  /// 排名徽章尺寸
  static const double rankBadgeSize = 24.0;

  /// 榜单行右侧数值列宽度
  static const double rankTrailingWidth = 150.0;

  /// 页面内容内边距
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(
    AppSpacing.xl,
    AppSpacing.huge,
    AppSpacing.xl,
    AppSpacing.xl,
  );

  /// 习惯指标卡高度
  static const double metricTileHeight = 112.0;

  /// Tab 内容切换时的横向位移比例
  static const double tabSlideOffset = 0.08;
}

/// 时段图表常量
abstract final class StatisticsChartSpec {
  /// 绘图区高度（不含底部标签行）
  static const double plotHeight = 176.0;

  /// Y 轴刻度列宽
  static const double axisLabelWidth = 46.0;

  /// Y 轴与绘图区之间的间隙
  static const double axisGap = AppSpacing.md;

  /// 刻度行高。刻度文字与网格线共用同一行，文字才能垂直居中于网格线
  static const double tickRowHeight = 16.0;

  /// 底部 X 轴标签行高
  static const double labelRowHeight = 20.0;

  /// 读数行高度，需容纳右侧的总计徽章
  static const double readoutHeight = 28.0;

  /// 网格分段数
  static const int tickDivisions = 4;

  /// 柱子最大宽度比例
  static const double barFactor = 0.8;

  /// 柱子之间的间隙，均分到单元格两侧
  static const double barGap = AppSpacing.sm;

  /// 当天无记录时柱子的占位高度
  static const double barEmptyHeight = 2.0;

  /// 有记录时柱子的最小高度，保证极小值也可见
  static const double barMinHeight = 4.0;

  /// 柱子顶部圆角
  static const Radius barTopRadius = Radius.circular(AppRadius.xs);

  /// 柱子hover的透明度
  static const double barHoverAlpha = 0.9;
  static const double barAlpha = 0.55;

  /// 维度切换的分段按钮尺寸
  static const double modeSegmentWidth = 84.0;
  static const double modeSegmentHeight = 34.0;

  /// 时段标题固定宽度，切换时翻页按钮不会左右跳动
  static const double periodTitleWidth = 160.0;

  /// 翻页按钮边长
  static const double pagerButton = 30.0;

  /// Y 轴候选刻度步长（秒）。把峰值向上取整到这些的值，
  static const List<double> tickSteps = <double>[
    30, // 30 秒
    60, // 1 分
    120, // 2 分
    300, // 5 分
    600, // 10 分
    900, // 15 分
    1200, // 20 分
    1800, // 30 分
    2700, // 45 分
    3600, // 1 时
    5400, // 1.5 时
    7200, // 2 时
    10800, // 3 时
    14400, // 4 时
    21600, // 6 时
    43200, // 12 时
  ];

  /// 完全没有记录时的刻度上限：每格 1 分钟
  static const double emptyAxisMax = 60.0 * tickDivisions;
}

/// 热力图常量
abstract final class StatisticsHeatmapSpec {
  /// 色块边长
  static const double cellSize = 15.0;

  /// 色块圆角
  static const BorderRadius cellRadius = BorderRadius.all(Radius.circular(3.0));

  /// 色块四周留的间隙，同时充当鼠标命中区
  static const double cellGap = 3.0;

  /// 单格占位（含间隙）
  static const double cellExtent = cellSize + cellGap * 2;

  /// 左侧星期标签列宽
  static const double weekLabelWidth = 30.0;

  /// 顶部月份标签行高
  static const double columnLabelHeight = 18.0;

  /// 图例色块边长与间距
  static const double legendBoxSize = 12.0;
  static const double legendGap = 2.0;

  /// 强度档位数（0 为无记录，1~4 为由浅到深）
  static const int maxLevel = 4;

  static const List<String> weekdayLabels = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];
}

/// 收听时段图表的视图维度
abstract class ChartViewMode {
  static const int weekly = 0;
  static const int daily = 1;
}
