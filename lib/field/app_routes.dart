abstract class AppRoutes {
  static const base = '/base';
  static const home = '/home';
  static const setting = '/setting';
  static const userPlayList = '/userPlayList';
  static const playList = '/playList';
  static const artistView = '/artistView';
  static const artistList = '/artistList';
  static const albumView = '/albumView';
  static const albumList = '/albumList';
  static const lrcView = '/lrcView';
  static const foldersView='/foldersView';
  static const foldersList='/foldersList';

  static const homeOrder=0;
  static const artistViewOrder=1;
  static const albumViewOrder=2;
  static const userPlayListOrder=3;
  static const foldersViewOrder=4;
  static const settingOrder=5;

  static const Map<String, int> orderMap = {
    home: homeOrder,
    artistView:artistViewOrder,
    albumView:albumViewOrder,
    userPlayList:userPlayListOrder,
    foldersView:foldersViewOrder,
    setting: settingOrder,
};

}
