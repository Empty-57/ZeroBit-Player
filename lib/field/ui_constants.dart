library;

import 'package:flutter/material.dart';

abstract final class AppFontSize {
  static const double xs = 11.0;
  static const double sm = 13.0;
  static const double md = 15.0;
  static const double lg = 17.0;
  static const double xl = 19.0;
  static const double xxl = 21.0;
  static const double subtitle = 24.0;
  static const double title = 31.0;
}

abstract final class AppIconSize {
  static const double xs = 14.0;
  static const double sm = 18.0;
  static const double md = 20.0;
  static const double lg = 22.0;
}

abstract final class AppSpacing {
  /// 2 — 同组文字之间
  static const double xxs = 2.0;

  /// 4 — 图标与紧邻文字
  static const double xs = 4.0;

  /// 6 — 紧凑行内间距
  static const double sm = 6.0;

  /// 8 — 常规行内间距
  static const double md = 8.0;

  /// 12 — 卡片内元素间距
  static const double lg = 12.0;

  /// 16 — 卡片内边距 / 区块间距
  static const double xl = 16.0;

  /// 24 — 区块之间
  static const double xxl = 24.0;

  /// 32 — 页面顶部留白
  static const double huge = 32.0;

  /// 页面内边距
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(
    AppSpacing.xl,
    AppSpacing.huge,
    AppSpacing.xl,
    AppSpacing.xl,
  );
}

abstract final class AppRadius {
  /// 4 — 列表行、小按钮
  static const double xs = 4.0;

  /// 6 — 分段项、徽章
  static const double sm = 6.0;

  /// 8 — 卡片内嵌容器
  static const double md = 8.0;

  /// 12 — 卡片
  static const double lg = 12.0;

  /// 16 — 大面积容器
  static const double xl = 16.0;

  /// 全圆角（药丸）
  static const double pill = 999.0;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

abstract final class AppAlpha {
  /// 卡片等一级表面
  static const double surface = 0.6;

  /// 需要更实的表面（弹层、强调卡）
  static const double surfaceStrong = 0.82;

  /// 卡片内的二级表面（内嵌容器、轨道底）
  static const double surfaceSubtle = 0.32;

  /// 强调色轻填充：未选中的可点区域
  static const double fill = 0.1;

  /// 强调色填充：选中态
  static const double fillStrong = 0.2;

  /// 常规描边
  static const double border = 0.16;

  /// 强调描边
  static const double borderStrong = 0.38;

  /// 进度条 / 分割线的轨道底色
  static const double track = 0.24;

  /// 次级文字
  static const double textSecondary = 0.72;

  /// 三级文字（说明、单位）
  static const double textTertiary = 0.52;

  /// 占位、禁用态文字
  static const double textFaint = 0.38;

  /// 鼠标悬停的叠加色
  static const double hover = 0.07;
}

abstract final class AppDuration {
  /// 90ms — 颜色、透明度等即时反馈
  static const Duration instant = Duration(milliseconds: 90);

  /// 150ms — 小范围位移、交叉淡入
  static const Duration fast = Duration(milliseconds: 150);

  /// 220ms — 常规过渡（指示器、面板切换）
  static const Duration normal = Duration(milliseconds: 220);

  /// 320ms — 大幅位移、数值增长
  static const Duration slow = Duration(milliseconds: 320);

  /// 1500ms — snackBarInfo
  static const Duration snackBarInfo = Duration(milliseconds: 1500);

  /// 2500ms — snackBarWarning
  static const Duration snackBarWarning = Duration(milliseconds: 2500);

  /// 3500ms — snackBarError
  static const Duration snackBarError = Duration(milliseconds: 3500);

  /// Tooltip 悬停等待
  static const Duration tooltipWait = Duration(milliseconds: 150);
}

abstract final class AppCurve {
  /// 通用减速曲线
  static const Curve standard = Curves.easeOutCubic;

  /// 更强的减速
  static const Curve emphasized = Curves.easeOutQuart;

  /// 先慢后快再慢，用于进出场
  static const Curve inOut = Curves.fastOutSlowIn;
}

/// 响应式断点
abstract final class AppBreakpoint {
  static const double wide = 1100.0;
}

/// 常用控件尺寸
abstract final class AppSize {
  /// 方形图标按钮边长
  static const double iconButton = 36.0;

  /// 常规按钮高度
  static const double button = 40.0;

  /// 分段 Tab 的单段宽度
  static const double segment = 112.0;

  /// 列表行高
  static const double listTile = 64.0;

  /// 小封面（列表行内）
  static const double coverSm = 48.0;

  /// 中封面（强调卡）
  static const double coverMd = 56.0;

  /// 细进度条 / 热度条高度
  static const double trackThin = 2.0;

  /// 常规进度条高度
  static const double track = 4.0;

  /// 分割线 / 网格线粗细
  static const double hairline = 1.0;
}
