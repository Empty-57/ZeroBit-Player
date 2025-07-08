import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/HIveCtrl/models/user_playlist_model.dart';
import 'package:zerobit_player/components/audio_gen_pages.dart';
import '../field/operate_area.dart';
import '../getxController/play_list_ctrl.dart';
import '../field/tag_suffix.dart';

class PlayList extends StatelessWidget {
  const PlayList({super.key});

  @override
  Widget build(BuildContext context) {
    final UserPlayListCache userArgs =
        (ModalRoute.of(context)!.settings.arguments
            as Map)['userPlayListCache'];

    late final PlayListController playListController;

    Get.delete<PlayListController>(tag: userArgs.userKey);
    playListController = Get.put(
      PlayListController(userArgs: userArgs),
      tag: userArgs.userKey,
    );

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                  tileMode: TileMode.clamp,
                ).createShader(bounds);
              },
              child: Obx(
                  () => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      child: SizedBox.expand(
                        child: Image.memory(
                        playListController.headCover.value,
                        key: ValueKey(
                          playListController.headCover.value.hashCode,
                        ),
                        cacheWidth: 800,
                        cacheHeight: 800,
                        fit: BoxFit.fill,
                      ),
                      ),
                      transitionBuilder: (
                        Widget child,
                        Animation<double> anim,
                      ) {
                        return FadeTransition(opacity: anim, child: child);
                      },
                    ),
                ),
            ),
          ),
        ),

        AudioGenPages(
          title: userArgs.userKey.split(TagSuffix.playList)[0],
          operateArea: OperateArea.playList,
          audioSource: userArgs.userKey,
          controller: playListController,
          backgroundColor: Colors.transparent,
        ),
      ],
    );
  }
}
