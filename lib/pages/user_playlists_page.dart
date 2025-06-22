import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:zerobit_player/field/app_routes.dart';

import '../getxController/user_playlist_ctrl.dart';
import '../tools/general_style.dart';

final UserPlayListController _userPlayListController =Get.find<UserPlayListController>();
const double _itemHeight = 64.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

class UserPlayList extends StatelessWidget{
  const UserPlayList({super.key});

  Future<void> _createOrRename({required BuildContext context,required String title,required int actionId,String? oldName})async{
    showDialog(
                    barrierDismissible: true,
                    context: context,
                    builder: (BuildContext context){
                      final TextEditingController textCtrl = TextEditingController();
                      return AlertDialog(
              title: Text(title),
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
                  width: 400,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 8,
                    children: [
                      TextField(
                        autofocus: true,
                    controller: textCtrl,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '歌单名称',
                    ),
                  ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
                                      fn: () {
                                        Navigator.pop(context, 'actions');
                                        if(actionId==0){
                                          _userPlayListController.createPlayList(userKey: textCtrl.text);
                                        }
                                        if(actionId==1){
                                          _userPlayListController.renamePlayList(oldKey: oldName!, newKey: textCtrl.text);
                                        }

                                      },
                                      backgroundColor: Colors.transparent,
                                      contentColor:
                                          Theme.of(context).colorScheme.primary,
                                      btnWidth: 72,
                                      btnHeight: 36,
                                      label: "确定",
                                    ),
                        ],
                      )
                    ],
                  ),
                )
              ],
                      );
                    },
                  );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle1=generalTextStyle(ctx: context,size: 'md');
    final textStyle2=generalTextStyle(ctx: context,size: 'sm',opacity: 0.8);

    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
      children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text(
                    '歌单',
                    style: generalTextStyle(
                      ctx: context,
                      size: 28.0,
                      weight: FontWeight.w400,
                    ),
                  ),
                  Obx(()=>Text(
                      '共${_userPlayListController.items.length}个歌单',
                      style: generalTextStyle(ctx: context, size: 'md'),
                    )),
                ],
              ),

              Expanded(flex: 1, child: Container()),

              CustomBtn(
                fn: (){
                  _createOrRename(context: context, title: '新建歌单', actionId: 0,);
                },
                label: "新建歌单",
                icon: PhosphorIconsLight.plus,
                radius: 4,
                btnWidth: 128,
                btnHeight: 48,
              ),

            ],
          ),
        Expanded(
            flex: 1,
            child: Obx(()=>ListView.builder(
              itemCount: _userPlayListController.items.length,
              itemExtent: _itemHeight,
              cacheExtent: _itemHeight*1,
              itemBuilder: (context, index){
                final items=_userPlayListController.items[index];

                return TextButton(
                    onPressed: (){
                      Get.toNamed(AppRoutes.playList, arguments: {'userKey':items.userKey},id: 1);
                    },
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: _borderRadius),
          ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 8,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items.userKey,
                              style: textStyle1,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text("共${items.pathList.length}首音乐",style: textStyle2,),
                          ],
                        ),
                        Expanded(flex: 1,child: Container()),
                        CustomBtn(
                            fn: (){
                               _createOrRename(context: context, title: '重命名', actionId: 1,oldName: items.userKey);
                            },
                          btnHeight: 48,
                          btnWidth: 48,
                          radius: 4,
                          tooltip: "重命名",
                          icon: PhosphorIconsLight.pencilSimpleLine,
                          backgroundColor: Colors.transparent,
                        ),
                        CustomBtn(
                            fn: (){
                              _userPlayListController.removePlayList(userKey: items.userKey);
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
                ));
              },
            )),
        ),
      ],
    ),
    );
  }

}