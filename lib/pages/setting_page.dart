import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zerobit_player/components/setting/setting_constant.dart';
import 'package:zerobit_player/components/setting/setting_fields.dart';
import 'package:zerobit_player/components/setting/setting_tabs.dart';
import 'package:zerobit_player/components/widget/segmented_tabs.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  int _currentTabIndex = 0;
  bool _isForward = true;

  late final Future<PackageInfo> _packageInfoFuture;

  static const List<SegmentedTabItem> _tabs = [
    SegmentedTabItem(icon: PhosphorIconsLight.gearSix, label: '常规'),
    SegmentedTabItem(icon: PhosphorIconsLight.play, label: '播放'),
    SegmentedTabItem(icon: PhosphorIconsLight.palette, label: '外观'),
    SegmentedTabItem(icon: PhosphorIconsLight.playlist, label: '歌词'),
    SegmentedTabItem(icon: PhosphorIconsLight.creditCard, label: '桌面歌词'),
    SegmentedTabItem(icon: PhosphorIconsLight.option, label: '快捷键'),
    SegmentedTabItem(icon: PhosphorIconsLight.warningCircle, label: '关于'),
  ];

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
    unawaited(loadFontsList());
  }

  void _onTabChanged(int index) {
    if (_currentTabIndex == index) return;
    setState(() {
      _isForward = index > _currentTabIndex;
      _currentTabIndex = index;
    });
  }

  Widget _buildContent(int index) => switch (index) {
    0 => const GeneralSetTab(),
    1 => const PlaySetTab(),
    2 => const AppearanceSetTab(),
    3 => const LyricsSetTab(),
    4 => const DesktopLyricsSetTab(),
    5 => const HotkeysSetTab(),
    _ => AboutTab(packageInfoFuture: _packageInfoFuture),
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xl,
        children: [
          Text(
            '设置',
            style: context.createTextStyle(
              size: AppFontSize.title,
              weight: FontWeight.w600,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedTabs(
              items: _tabs,
              selectedIndex: _currentTabIndex,
              onChanged: _onTabChanged,
              segmentWidth: SettingLayout.tabSegmentWidth,
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppDuration.fast,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topCenter,
                children: [...previousChildren, ?currentChild],
              ),
              transitionBuilder: (child, animation) {
                // 进场的一方从切换方向的一侧滑入，离场的一方往反方向退出
                final isIncoming =
                    child.key is ValueKey<int> &&
                    (child.key as ValueKey<int>).value == _currentTabIndex;
                const distance = SettingLayout.tabSlideOffset;
                final beginDx = _isForward == isIncoming ? distance : -distance;

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(beginDx, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_currentTabIndex),
                child: _buildContent(_currentTabIndex),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
