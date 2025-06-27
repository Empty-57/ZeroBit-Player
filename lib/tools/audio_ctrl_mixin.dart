import 'dart:typed_data';
import 'package:transparent_image/transparent_image.dart';
import '../HIveCtrl/models/music_cahce_model.dart';
import 'package:get/get.dart';

mixin AudioControllerGenClass {
  RxList<MusicCache> get items;

  Rx<Uint8List> get headCover => kTransparentImage.obs;

  void itemReSort({required int type});

  void itemReverse();
}
