import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/constants/operate_area.dart';
import 'package:zerobit_player/core/network/version_checker.dart';
import 'package:zerobit_player/core/platform/window_background.dart';
import 'package:zerobit_player/core/platform/window_ctrl_bar.dart';
import 'package:zerobit_player/features/library/pages/album_preview_page.dart';
import 'package:zerobit_player/features/library/pages/artist_preview_page.dart';
import 'package:zerobit_player/features/library/pages/audio_info_edit_page.dart';
import 'package:zerobit_player/features/library/pages/folders_preview_page.dart';
import 'package:zerobit_player/features/library/pages/local_music_page.dart';
import 'package:zerobit_player/features/library/pages/uni_details_page.dart';
import 'package:zerobit_player/features/player/views/play_page.dart';
import 'package:zerobit_player/features/player/widgets/play_bar.dart';
import 'package:zerobit_player/features/playlist/pages/playlists_preview_page.dart';
import 'package:zerobit_player/features/setting/pages/setting_page.dart';
import 'package:zerobit_player/features/statistics/pages/statistics_page.dart';

import '../core/constants/app_routes.dart';
import '../core/theme/theme_manager.dart';
import '../core/widgets/get_snack_bar.dart';
import '../features/navigation/side_bar.dart';
import '../features/navigation/side_bar_constant.dart';
import '../features/setting/controller/setting_ctrl.dart';

class _DiagonalSlide extends StatefulWidget {
  const _DiagonalSlide({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<_DiagonalSlide> createState() => _DiagonalSlideState();
}

class _DiagonalSlideState extends State<_DiagonalSlide> {
  late CurvedAnimation _primaryCurved;
  late CurvedAnimation _secondaryCurved;

  late Animation<Offset> _inSlide;
  late Animation<double> _inFade;
  late Animation<Offset> _outSlide;
  late Animation<double> _outFade;

  @override
  void initState() {
    super.initState();
    _createAnimations();
  }

  @override
  void didUpdateWidget(_DiagonalSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.secondaryAnimation != widget.secondaryAnimation) {
      _disposeAnimations();
      _createAnimations();
    }
  }

  void _createAnimations() {
    _primaryCurved = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn.flipped,
    );

    _secondaryCurved = CurvedAnimation(
      parent: widget.secondaryAnimation,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn.flipped,
    );

    _inSlide = Tween<Offset>(
      begin: SidebarNavState.beginOffset,
      end: Offset.zero,
    ).animate(_primaryCurved);

    _inFade = Tween<double>(begin: 0.0, end: 1.0).animate(_primaryCurved);

    _outSlide = Tween<Offset>(
      begin: Offset.zero,
      end: -SidebarNavState.beginOffset,
    ).animate(_secondaryCurved);

    _outFade = Tween<double>(begin: 1.0, end: 0.0).animate(_secondaryCurved);
  }

  void _disposeAnimations() {
    _primaryCurved.dispose();
    _secondaryCurved.dispose();
  }

  @override
  void dispose() {
    _disposeAnimations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _inFade,
      child: SlideTransition(
        position: _inSlide,
        child: FadeTransition(
          opacity: _outFade,
          child: SlideTransition(position: _outSlide, child: widget.child),
        ),
      ),
    );
  }
}

final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

// 路由切换动画页面构造函数
CustomTransitionPage<void> _buildNormalPage({
  required GoRouterState state,
  required Widget child,
  String? name,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: name,
    arguments: state.extra,
    maintainState: false,
    transitionDuration: 250.ms,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return _DiagonalSlide(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
}

final CurveTween _playPageCurve = CurveTween(curve: Curves.fastOutSlowIn);

final Tween<Offset> _playPageSlideTween = Tween<Offset>(
  begin: const Offset(0.0, 0.2),
  end: Offset.zero,
);

// 播放页面切换动画构造函数
CustomTransitionPage<void> _buildPlayPage({
  required GoRouterState state,
  required Widget child,
  String? name,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: name,
    arguments: state.extra,
    maintainState: false,
    transitionDuration: 300.ms,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: _playPageSlideTween.animate(animation.drive(_playPageCurve)),
        child: FadeTransition(
          opacity: animation.drive(_playPageCurve),
          child: child,
        ),
      );
    },
  );
}

final GoRouter _router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.home,
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      observers: [
        NestedObserver(
          onRouteChanged: (name) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (AppRoutes.orderMap_[name] case final index?) {
                SidebarNavState.currentNavigationIndex.value = index;
              }
            });
          },
        ),
      ],
      builder: (context, state, child) {
        return HomePage(child: child);
      },
      routes: [
        GoRoute(
          path: AppRoutes.home,
          name: AppRoutes.home,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.home,
            child: const LocalMusicPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.setting,
          name: AppRoutes.setting,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.setting,
            child: const SettingPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.playListPreview,
          name: AppRoutes.playListPreview,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.playListPreview,
            child: const PlayListPreviewPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.artistPreview,
          name: AppRoutes.artistPreview,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.artistPreview,
            child: const ArtistPreviewPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.albumPreview,
          name: AppRoutes.albumPreview,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.albumPreview,
            child: const AlbumPreviewPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.foldersPreview,
          name: AppRoutes.foldersPreview,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.foldersPreview,
            child: const FoldersPreviewPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.statistics,
          name: AppRoutes.statistics,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.statistics,
            child: const StatisticsPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.details,
          name: AppRoutes.details,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.details,
            child: const UniDetailsPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.audioInfoEdit,
          name: AppRoutes.audioInfoEdit,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.audioInfoEdit,
            child: const AudioInfoEditorPage(),
          ),
        ),
      ],
    ),

    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.playPage,
      name: AppRoutes.playPage,
      pageBuilder: (context, state) => _buildPlayPage(
        state: state,
        name: AppRoutes.playPage,
        child: const PlayPage(),
      ),
    ),
  ],
);

class MainFrame extends StatelessWidget {
  const MainFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeService themeService = ThemeService.instance;
    final SettingController settingController = SettingController.instance;
    // 整个 App 外层套 ExcludeSemantics，规避 Flutter Windows 引擎的一个未修 bug: AccessibilityBridge 中的空父级解引用
    // issue #175041 / #192689 / #193410 / #193715，以及 PR #190903
    return ExcludeSemantics(
      child: SignalBuilder(
        builder: (context) => MaterialApp.router(
          routerConfig: _router,
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: settingController.themeMode.value == 'dark'
              ? ThemeMode.dark
              : ThemeMode.light,
          // themeAnimationStyle: AnimationStyle.noAnimation,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class NestedObserver extends NavigatorObserver {
  final void Function(String? routeName) onRouteChanged;

  NestedObserver({required this.onRouteChanged});

  String? _getName(Route<dynamic>? route) {
    final args = route?.settings.arguments as Map<String, dynamic>? ?? {};
    String? name;
    name = route?.settings.name;
    if (args['operateArea'] != null) {
      name = OperateArea.nameMap[args['operateArea']];
    }
    return name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onRouteChanged(_getName(previousRoute));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    onRouteChanged(_getName(route));
  }
}

class HomePage extends StatefulWidget {
  final Widget child; // 接收 ShellRoute 分发的嵌套页面

  const HomePage({super.key, required this.child});

  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SettingController.instance.useAutoUpdate.value) {
        VersionChecker.checkAndShowDialog(
          context,
          showNoUpdateToast: false,
          showErrorToast: false,
        );
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const WindowBackgroundImage(),
        const WindowBackgroundOverlay(),
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const WindowControllerBar(),
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.all(SideBarSpec.outerPadding),
                    child: SideBar(
                      btnList: <Widget>[
                        SideBarBtn(
                          label: '音乐',
                          icon: PhosphorIconsLight.musicNoteSimple,
                          localIndex: AppRoutes.homeOrder,
                        ),
                        SideBarBtn(
                          label: '艺术家',
                          icon: PhosphorIconsLight.userFocus,
                          localIndex: AppRoutes.artistPreviewOrder,
                        ),
                        SideBarBtn(
                          label: '专辑',
                          icon: PhosphorIconsLight.vinylRecord,
                          localIndex: AppRoutes.albumPreviewOrder,
                        ),
                        SideBarBtn(
                          label: '歌单',
                          icon: PhosphorIconsLight.playlist,
                          localIndex: AppRoutes.playListPreviewOrder,
                        ),
                        SideBarBtn(
                          label: '文件夹',
                          icon: PhosphorIconsLight.folders,
                          localIndex: AppRoutes.foldersPreviewOrder,
                        ),
                        SideBarBtn(
                          label: '统计',
                          icon: PhosphorIconsLight.chartLine,
                          localIndex: AppRoutes.statisticsOrder,
                        ),
                        SideBarBtn(
                          label: '设置',
                          icon: PhosphorIconsLight.gearSix,
                          localIndex: AppRoutes.settingOrder,
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
        const PlayBar(),
      ],
    );
  }
}
