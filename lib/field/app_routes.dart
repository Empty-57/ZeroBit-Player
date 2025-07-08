abstract class AppRoutes {
  static const base = '/base';
  static const home = '/home';
  static const setting = '/setting';
  static const userPlayList = '/userPlayList';
  static const playList = '/playList';
  static const artistView = '/artistView';
  static const lrcView = '/lrcView';

  static const homeOrder=0;
  static const artistViewOrder=1;
  static const userPlayListOrder=2;
  static const settingOrder=3;

  static const Map<String, int> orderMap = {
  home: homeOrder,
  artistView:artistViewOrder,
  userPlayList:userPlayListOrder,
  setting: settingOrder,
};

}
