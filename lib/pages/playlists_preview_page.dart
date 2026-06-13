import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zerobit_player/controller/user_playlist_ctrl.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/tools/func/general_style.dart';

import '../field/operate_area.dart';

const double _itemHeight = 64.0;
const BorderRadius _borderRadius = BorderRadius.all(Radius.circular(4));

class PlayListPreviewPage extends GetView<UserPlayListController> {
  const PlayListPreviewPage({super.key});

  Future<String?> _showInputDialog(
    BuildContext context, {
    required String title,
    String initialText = '',
  }) async {
    final TextEditingController textCtrl = TextEditingController(
      text: initialText,
    );

    try {
      return await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          final primaryColor = Theme.of(context).colorScheme.primary;
          return AlertDialog(
            title: Text(title),
            titleTextStyle: generalTextStyle(
              ctx: context,
              size: 20,
              weight: FontWeight.w600,
            ),
            shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
            backgroundColor: Theme.of(context).colorScheme.surface,
            content: SizedBox(
              width: 400,
              child: TextField(
                autofocus: true,
                controller: textCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '歌单名称',
                ),
                onSubmitted: (value) => Navigator.pop(context, value),
              ),
            ),
            actions: [
              CustomBtn(
                fn: () => Navigator.pop(context, null),
                backgroundColor: Colors.transparent,
                contentColor: primaryColor,
                btnWidth: 72,
                btnHeight: 36,
                label: "取消",
              ),
              CustomBtn(
                fn: () => Navigator.pop(context, textCtrl.text),
                backgroundColor: primaryColor,
                contentColor: Theme.of(context).colorScheme.onPrimary,
                overlayColor: Theme.of(context).colorScheme.surfaceContainer,
                btnWidth: 72,
                btnHeight: 36,
                label: "确定",
              ),
            ],
          );
        },
      );
    } finally {
      textCtrl.dispose();
    }
  }

  Future<bool> _showDeleteConfirmDialog(
    BuildContext context,
    String playlistName,
  ) async {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('删除歌单'),
              content: Text('确定要删除歌单 "$playlistName" 吗？此操作无法撤销。'),
              shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
              backgroundColor: Theme.of(context).colorScheme.surface,
              actions: [
                CustomBtn(
                  fn: () => Navigator.pop(context, false),
                  backgroundColor: Colors.transparent,
                  contentColor: primaryColor,
                  btnWidth: 72,
                  btnHeight: 36,
                  label: "取消",
                ),
                CustomBtn(
                  fn: () => Navigator.pop(context, true),
                  backgroundColor: Colors.transparent,
                  contentColor: Colors.red,
                  btnWidth: 72,
                  btnHeight: 36,
                  label: "删除",
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            _buildHeader(context),
            Expanded(child: Obx(() => _buildListView(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              '歌单',
              style: generalTextStyle(
                ctx: context,
                size: 'title',
                weight: FontWeight.w600,
              ),
            ),
            Obx(
              () => Text(
                '共${controller.items.length}个歌单',
                style: generalTextStyle(ctx: context, size: 'md'),
              ),
            ),
          ],
        ),
        const Spacer(),
        CustomBtn(
          fn: () async {
            final result = await _showInputDialog(context, title: '新建歌单');
            if (result != null && result.trim().isNotEmpty) {
              controller.createPlayList(userKey: result);
            }
          },
          label: "新建歌单",
          icon: PhosphorIconsLight.plus,
          btnWidth: 128,
          btnHeight: 42,
          mainAxisAlignment: MainAxisAlignment.center,
        ),
      ],
    );
  }

  Widget _buildListView(BuildContext context) {
    final textStyle1 = generalTextStyle(ctx: context, size: 'md');
    final textStyle2 = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);

    return ListView.builder(
      scrollCacheExtent: const ScrollCacheExtent.pixels(_itemHeight),
      itemCount: controller.items.length,
      itemExtent: _itemHeight,
      itemBuilder: (context, index) {
        final item = controller.items[index];
        final displayName = item.userKey.split('_')[0];

        return TextButton(
          key: ValueKey(item.userKey),
          onPressed: () => Get.toNamed(
            AppRoutes.details,
            arguments: {
              'title': displayName,
              'pathList': item.pathList,
              'operateArea': OperateArea.playListDetails,
              'userKey': item.userKey,
            },
            id: 1,
          ),
          style: TextButton.styleFrom(
            shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
            enabledMouseCursor: SystemMouseCursors.click,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: textStyle1,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text("共${item.pathList.length}首音乐", style: textStyle2),
                  ],
                ),
              ),
              CustomBtn(
                fn: () async {
                  final result = await _showInputDialog(
                    context,
                    title: '重命名',
                    initialText: displayName,
                  );
                  if (result != null &&
                      result.trim().isNotEmpty &&
                      result != displayName) {
                    controller.renamePlayList(
                      oldKey: item.userKey,
                      newKey: result,
                    );
                  }
                },
                btnHeight: 48,
                btnWidth: 48,
                radius: 4,
                tooltip: "重命名",
                icon: PhosphorIconsLight.pencilSimpleLine,
                backgroundColor: Colors.transparent,
              ),
              CustomBtn(
                fn: () async {
                  final confirm = await _showDeleteConfirmDialog(
                    context,
                    displayName,
                  );
                  if (confirm) {
                    controller.removePlayList(userKey: item.userKey);
                  }
                },
                btnHeight: 48,
                btnWidth: 48,
                radius: 4,
                tooltip: "删除",
                icon: PhosphorIconsLight.trash,
                contentColor: Colors.red,
                backgroundColor: Colors.transparent,
              ),
            ],
          ),
        );
      },
    );
  }
}
