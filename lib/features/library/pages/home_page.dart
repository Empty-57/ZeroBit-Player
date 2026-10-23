import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zerobit_player/core/network/version_checker.dart';
import 'package:zerobit_player/core/platform/window_background.dart';
import 'package:zerobit_player/core/platform/window_ctrl_bar.dart';
import 'package:zerobit_player/features/player/widgets/play_bar.dart';

import '../../../core/constants/app_routes.dart';
import '../../navigation/side_bar.dart';
import '../../navigation/side_bar_constant.dart';
import '../../setting/controller/setting_ctrl.dart';

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
