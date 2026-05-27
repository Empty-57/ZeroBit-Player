import 'package:zerobit_player/field/app_routes.dart';

abstract class OperateArea {
  static const allMusic = 'allMusic';
  static const playListDetails = 'playListDetails';
  static const artistDetails = 'artistDetails';
  static const albumDetails = 'albumDetails';
  static const foldersDetails = 'foldersDetails';

  static const Map<String, String> nameMap = {
    allMusic: AppRoutes.home,
    playListDetails: AppRoutes.playListDetails,
    artistDetails: AppRoutes.artistDetails,
    albumDetails: AppRoutes.albumDetails,
    foldersDetails: AppRoutes.foldersDetails,
  };
}
