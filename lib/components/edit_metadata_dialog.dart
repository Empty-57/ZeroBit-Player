import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:transparent_image/transparent_image.dart';

import '../API/apis.dart';
import '../HIveCtrl/models/music_cache_model.dart';
import '../custom_widgets/custom_button.dart';
import '../getxController/music_cache_ctrl.dart';
import '../getxController/play_list_ctrl.dart';
import '../src/rust/api/music_tag_tool.dart';
import '../tools/format_time.dart';
import '../tools/general_style.dart';

const double _metadataDialogW = 600;
const double _metadataDialogH = 580;
const _coverBorderRadius = BorderRadius.all(Radius.circular(6));

const double _bigCoverSize = 200;
const int _coverBigRenderSize = 800;
const double _menuWidth = 180;
const double _menuHeight = 48;
const double _menuRadius = 0;

final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();

class EditMetadataDialog extends StatelessWidget {
  final MenuController menuController;
  final MusicCache metadata;
  final int index;
  const EditMetadataDialog({
    super.key,
    required this.menuController,
    required this.metadata,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return CustomBtn(
      fn: () {
        menuController.close();
        showDialog(
          barrierDismissible: true,
          context: context,
          builder: (BuildContext context) {
            final TextEditingController titleCtrl = TextEditingController();
            titleCtrl.text = metadata.title;

            final TextEditingController artistCtrl = TextEditingController();
            artistCtrl.text = metadata.artist;

            final TextEditingController albumCtrl = TextEditingController();
            albumCtrl.text = metadata.album;

            final TextEditingController genreCtrl = TextEditingController();
            genreCtrl.text = metadata.genre;

            final TextStyle textStyle = generalTextStyle(
              ctx: context,
              size: 'lg',
            );

            final OutlineInputBorder border = OutlineInputBorder();

            var src = Uint8List(0).obs;

            var isSave = false.obs;

            return AlertDialog(
              title: Text(metadata.title),
              titleTextStyle: generalTextStyle(
                ctx: context,
                size: 20,
                weight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,

              actionsAlignment: MainAxisAlignment.end,
              actions: [
                SizedBox(
                  width: _metadataDialogW,
                  height: _metadataDialogH,
                  child: Column(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 24,
                            children: [
                              FutureBuilder<Uint8List?>(
                                future: getCover(
                                  path: metadata.path,
                                  sizeFlag: 1,
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Center(
                                      child: Obx(
                                      () => ClipRRect(
                                        borderRadius: _coverBorderRadius,
                                        child: FadeInImage(
                                          placeholder: MemoryImage(
                                            kTransparentImage,
                                          ),
                                          image: ResizeImage(
                                            MemoryImage(
                                              src.value.isNotEmpty
                                                  ? src.value
                                                  : snapshot.data!,
                                            ),
                                            width: _coverBigRenderSize,
                                            height: _coverBigRenderSize,
                                          ),
                                          height: _bigCoverSize,
                                          width: _bigCoverSize,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    );
                                  }
                                  return SizedBox(
                                    height: _bigCoverSize,
                                    width: _bigCoverSize,
                                  );
                                },
                              ),

                              TextField(
                                controller: titleCtrl,
                                decoration: InputDecoration(
                                  border: border,
                                  labelText: '标题',
                                ),
                              ),
                              TextField(
                                controller: artistCtrl,
                                decoration: InputDecoration(
                                  border: border,
                                  labelText: '艺术家',
                                ),
                              ),
                              TextField(
                                controller: albumCtrl,
                                decoration: InputDecoration(
                                  border: border,
                                  labelText: '专辑',
                                ),
                              ),
                              TextField(
                                controller: genreCtrl,
                                decoration: InputDecoration(
                                  border: border,
                                  labelText: '流派',
                                ),
                              ),
                              Text(
                                "时长  ${formatTime(totalSeconds: metadata.duration)}",
                                style: textStyle,
                              ),
                              Text(
                                "比特率  ${metadata.bitrate ?? "UNKNOWN"}kbps",
                                style: textStyle,
                              ),
                              Text(
                                "采样率  ${metadata.sampleRate ?? "UNKNOWN"}hz",
                                style: textStyle,
                              ),
                              Text(
                                "路径  ${metadata.path}",
                                style: textStyle,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Obx(
                        () => Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 8,
                          children:
                              !isSave.value
                                  ? [
                                    CustomBtn(
                                      fn: () async {
                                        isSave.value = true;
                                        final title = metadata.title;
                                        final artist =
                                            metadata.artist.isNotEmpty
                                                ? ' - ${metadata.artist}'
                                                : '';
                                        final coverData_ =
                                            await saveCoverByText(
                                              text: title + artist,
                                              songPath: metadata.path,
                                            );
                                        if (coverData_ != null &&
                                            coverData_.isNotEmpty) {
                                          src.value = Uint8List.fromList(
                                            coverData_,
                                          );
                                          _musicCacheController
                                              .items[index]
                                              .src = null;
                                        }
                                        isSave.value = false;
                                      },
                                      backgroundColor: Colors.transparent,
                                      contentColor:
                                          Theme.of(context).colorScheme.primary,
                                      btnWidth: 128,
                                      btnHeight: 36,
                                      label: "匹配网络封面",
                                    ),
                                    CustomBtn(
                                      fn: () async {
                                        final result = await FilePicker.platform
                                            .pickFiles(
                                              type: FileType.image,
                                              allowMultiple: false,
                                              withData: true,
                                            );

                                        if (result != null &&
                                            result.files.isNotEmpty) {
                                          final imgSrc =
                                              result.files.first.bytes;
                                          if (imgSrc != null) {
                                            src.value = imgSrc;
                                          }
                                        }
                                      },
                                      backgroundColor: Colors.transparent,
                                      contentColor:
                                          Theme.of(context).colorScheme.primary,
                                      btnWidth: 128,
                                      btnHeight: 36,
                                      label: "选择本地封面",
                                    ),
                                    CustomBtn(
                                      fn: () {
                                        Navigator.pop(context, 'actions');
                                      },
                                      backgroundColor: Colors.transparent,
                                      contentColor:
                                          Theme.of(context).colorScheme.primary,
                                      btnWidth: 72,
                                      btnHeight: 36,
                                      label: "取消",
                                    ),
                                    CustomBtn(
                                      fn: () async {
                                        isSave.value = true;
                                        if (src.value.isNotEmpty) {
                                          await editCover(
                                            path: metadata.path,
                                            src: src.value,
                                          );
                                        }
                                        MusicCache newCache= await _musicCacheController.putMetadata(
                                          path: metadata.path,
                                          index: _musicCacheController.items.indexWhere((v)=>v.path==metadata.path),
                                          data: EditableMetadata(
                                            title: titleCtrl.text,
                                            artist: artistCtrl.text,
                                            album: albumCtrl.text,
                                            genre: genreCtrl.text,
                                          ),
                                        );

                                        PlayListController.audioListSyncMetadata(index: index,newCache: newCache);

                                        isSave.value = false;
                                        Navigator.pop(context, 'actions');
                                      },
                                      backgroundColor: Colors.transparent,
                                      contentColor:
                                          Theme.of(context).colorScheme.primary,
                                      btnWidth: 72,
                                      btnHeight: 36,
                                      label: "确定",
                                    ),
                                  ]
                                  : [
                                    Text(
                                      "执行中……",
                                      style: generalTextStyle(
                                        ctx: context,
                                        size: 'md',
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
      btnHeight: _menuHeight,
      btnWidth: _menuWidth,
      radius: _menuRadius,
      icon: PhosphorIconsLight.pencilSimpleLine,
      label: "修改元数据",
      mainAxisAlignment: MainAxisAlignment.start,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
