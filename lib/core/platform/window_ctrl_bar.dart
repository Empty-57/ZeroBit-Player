import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player/core/platform/window_ctrl.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/theme/theme_manager.dart';
import 'package:zerobit_player/core/widgets/app_interaction_widget.dart';
import 'package:zerobit_player/features/library/widgets/library_search_dialog.dart';
import 'package:zerobit_player/features/setting/controller/setting_ctrl.dart';

import '../utils/paint_cache.dart';

const double _barHeight = 48.0;
const double _logoSize = 24.0;
const double _buttonSize = AppSize.iconButton;
const double _blurSigma = 16.0;

/// 标题栏表面不透明度
const double _surfaceAlpha = 0.4;

class WindowControllerBar extends StatelessWidget {
  final bool showLogo;
  final bool useCaretDown;
  final bool useSearch;
  final bool useThemeSwitch;
  final bool onlyDarkMode;
  final bool useBlur;

  const WindowControllerBar({
    super.key,
    this.showLogo = true,
    this.useCaretDown = false,
    this.useSearch = true,
    this.useThemeSwitch = true,
    this.onlyDarkMode = false,
    this.useBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settingController = SettingController.instance;

    final content = Container(
      height: _barHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: colorScheme.surfaceContainer.withValues(
        alpha: useBlur ? _surfaceAlpha : 0.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: AppSpacing.md,
        children: [
          _BarButton(
            icon: useCaretDown
                ? PhosphorIconsLight.caretDown
                : PhosphorIconsLight.caretLeft,
            tooltip: '返回',
            onlyDarkMode: onlyDarkMode,
            onTap: () {
              if (context.canPop()) context.pop();
            },
          ),
          Expanded(
            child: _DragArea(
              child: showLogo
                  ? _AppIdentity(onlyDarkMode: onlyDarkMode)
                  : const SizedBox.expand(),
            ),
          ),
          if (useSearch)
            _BarButton(
              icon: PhosphorIconsLight.magnifyingGlass,
              tooltip: '搜索',
              onlyDarkMode: onlyDarkMode,
              onTap: () => showLibrarySearchDialog(context),
            ),
          if (useThemeSwitch)
            SignalBuilder(
              builder: (_) {
                final isDark = settingController.themeMode.value == 'dark';
                return _BarButton(
                  icon: isDark
                      ? PhosphorIconsLight.moon
                      : PhosphorIconsLight.sun,
                  tooltip: isDark ? '暗色主题' : '亮色主题',
                  onlyDarkMode: onlyDarkMode,
                  onTap: ThemeService.instance.setThemeMode,
                );
              },
            ),
          _WindowButtons(onlyDarkMode: onlyDarkMode),
        ],
      ),
    );

    if (!useBlur) return content;

    return ClipRect(
      child: SignalBuilder(
        builder: (_) => BackdropFilter(
          enabled:
              settingController.backgroundImagePath.value.isNotEmpty ||
              settingController.useTransparencyBackground.value,
          filter: ImageFilterCache.imageFilter(sigma: _blurSigma),
          child: content,
        ),
      ),
    );
  }
}

/// 可拖拽窗口的空白区
class _DragArea extends StatelessWidget {
  final Widget child;

  const _DragArea({required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: WindowController.instance.toggleMaximize,
      child: child,
    );
  }
}

class _AppIdentity extends StatelessWidget {
  final bool onlyDarkMode;

  const _AppIdentity({required this.onlyDarkMode});

  @override
  Widget build(BuildContext context) {
    final cacheSize = (_logoSize * MediaQuery.devicePixelRatioOf(context))
        .round();

    return SizedBox.expand(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: AppSpacing.md,
        children: [
          Image.asset(
            r'assets/app_icon.ico',
            width: _logoSize,
            height: _logoSize,
            fit: BoxFit.cover,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            gaplessPlayback: true,
          ),
          Text(
            'ZeroBit Player',
            style: context.createTextStyle(
              size: AppFontSize.sm,
              color: _foregroundOf(context, onlyDarkMode),
              opacity: AppAlpha.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  final bool onlyDarkMode;

  const _WindowButtons({required this.onlyDarkMode});

  @override
  Widget build(BuildContext context) {
    final windowController = WindowController.instance;
    final settingController = SettingController.instance;

    return SignalBuilder(
      builder: (_) {
        final isFullScreen = windowController.isFullScreen.value;
        final isMaximized = windowController.isMaximized.value;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isFullScreen) ...[
              _BarButton(
                icon: PhosphorIconsLight.minus,
                tooltip: '最小化',
                onlyDarkMode: onlyDarkMode,
                onTap: windowManager.minimize,
              ),
              _BarButton(
                icon: isMaximized
                    ? PhosphorIconsLight.cornersIn
                    : PhosphorIconsLight.cornersOut,
                tooltip: isMaximized ? '还原' : '最大化',
                onlyDarkMode: onlyDarkMode,
                onTap: windowController.toggleMaximize,
              ),
            ],
            _BarButton(
              icon: isFullScreen
                  ? PhosphorIconsLight.arrowsInSimple
                  : PhosphorIconsLight.arrowsOutSimple,
              tooltip: isFullScreen ? '退出全屏' : '全屏',
              onlyDarkMode: onlyDarkMode,
              onTap: windowController.toggleFullScreen,
            ),
            _BarButton(
              icon: PhosphorIconsLight.x,
              tooltip: settingController.close2Tray.value ? '隐藏到托盘' : '退出',
              onlyDarkMode: onlyDarkMode,
              danger: true,
              onTap: () async {
                if (settingController.close2Tray.value) {
                  await windowManager.hide();
                  return;
                }
                await windowController.closeAndClean();
              },
            ),
          ],
        );
      },
    );
  }
}

/// 标题栏前景色
Color _foregroundOf(BuildContext context, bool onlyDarkMode) => onlyDarkMode
    ? ThemeService.instance.darkTheme.colorScheme.onSurface
    : Theme.of(context).colorScheme.onSurface;

/// 标题栏按钮
class _BarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool onlyDarkMode;

  final bool danger;

  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.onlyDarkMode,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = _foregroundOf(context, onlyDarkMode);

    return Tooltip(
      message: tooltip,
      waitDuration: AppDuration.tooltipWait,
      child: HoverBuilder(
        onPressed: onTap,
        builder: (context, hovered) {
          final Color? background;
          final Color foreground;
          if (hovered && danger) {
            background = colorScheme.error;
            foreground = colorScheme.onError;
          } else if (hovered) {
            background = baseColor.withValues(alpha: AppAlpha.hover);
            foreground = baseColor;
          } else {
            background = null;
            foreground = baseColor;
          }

          return AnimatedContainer(
            duration: AppDuration.instant,
            curve: AppCurve.standard,
            width: _buttonSize,
            height: _buttonSize,
            decoration: BoxDecoration(
              color: background,
              borderRadius: AppRadius.xsAll,
            ),
            child: Center(
              child: Icon(icon, size: AppIconSize.md, color: foreground),
            ),
          );
        },
      ),
    );
  }
}
