import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/constants/operate_area.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/covers.dart';

import 'audio_list_view_action_bar.dart';
import 'audio_list_view_args.dart';
import 'audio_list_view_constant.dart';

/// 列表页头部
class AudioPageHeader extends StatelessWidget {
  final AudioListViewArgs args;

  const AudioPageHeader({super.key, required this.args});

  bool get _showCover =>
      args.operateArea != OperateArea.allMusic &&
      args.operateArea != OperateArea.foldersDetails;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: AppSpacing.xl,
      children: [
        if (_showCover) _HeaderCover(args: args),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.md,
            children: [
              Text(
                args.title,
                style: context.createTextStyle(
                  size: AppFontSize.title,
                  weight: FontWeight.w600,
                ),
                softWrap: false,
                overflow: TextOverflow.fade,
                maxLines: 1,
              ),
              SignalBuilder(
                builder: (context) => Text(
                  '共 ${args.controller.items.length} 首',
                  style: context.createTextStyle(
                    size: AppFontSize.md,
                    opacity: AppAlpha.textSecondary,
                    tabularFigures: true,
                  ),
                ),
              ),
              AudioActionBar(args: args),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderCover extends StatelessWidget {
  final AudioListViewArgs args;

  const _HeaderCover({required this.args});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: args.title + args.operateArea,
      createRectTween: (begin, end) =>
          MaterialRectArcTween(begin: begin, end: end),
      child: SignalBuilder(
        builder: (context) => LoadU8Cover(
          data: args.controller.headCover.value,
          coverResolutionFlag: CoverResolutionFlag.middle,
          size: AudioListViewSpec.headerCoverSize,
          evictOnDispose: false,
          borderRadius: AppRadius.smAll,
        ),
      ),
    );
  }
}
