abstract class AppRoutes {
  static const root = '/';
  static const base = '/base';
  static const home = '/home';
  static const setting = '/setting';

  static const playListPreview = '/playListPreview';
  static const playListDetails = '/playListDetails';

  static const artistPreview = '/artistPreview';
  static const artistDetails = '/artistDetails';

  static const albumPreview = '/albumPreview';
  static const albumDetails = '/albumDetails';

  static const foldersPreview = '/foldersPreview';
  static const foldersDetails = '/foldersDetails';

  static const details = '/details';

  static const playPage = '/playPage';

  static const homeOrder = 0;

  static const artistPreviewOrder = 1;
  static const artistDetailsOrder = 1;

  static const albumPreviewOrder = 2;
  static const albumDetailsOrder = 2;

  static const playListPreviewOrder = 3;
  static const playListDetailsOrder = 3;

  static const foldersPreviewOrder = 4;
  static const foldersDetailsOrder = 4;

  static const settingOrder = 5;

  static const detailsOrder = 0;

  static const Map<String, int> orderMap = {
    home: homeOrder,

    artistPreview: artistPreviewOrder,

    albumPreview: albumPreviewOrder,

    playListPreview: playListPreviewOrder,

    foldersPreview: foldersPreviewOrder,

    setting: settingOrder,
  };

  static const Map<String, int> orderMap_ = {
    root: homeOrder,
    home: homeOrder,

    artistPreview: artistPreviewOrder,
    artistDetails: artistDetailsOrder,

    albumPreview: albumPreviewOrder,
    albumDetails: albumDetailsOrder,

    playListPreview: playListPreviewOrder,
    playListDetails: playListDetailsOrder,

    foldersPreview: foldersPreviewOrder,
    foldersDetails: foldersDetailsOrder,

    details: detailsOrder,

    setting: settingOrder,
  };
}
