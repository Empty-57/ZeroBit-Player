import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/folder_tree/folder_tree_model.dart';
import 'package:zerobit_player/components/folder_tree/folder_tree_row_view.dart';
import 'package:zerobit_player/components/widget/app_empty_state.dart';
import 'package:zerobit_player/components/widget/app_tappable.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/tools/details_ctrl_mixin.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';
import 'package:zerobit_player/tools/func/sync_cache.dart';

/// 平铺视图行高
const double _flatRowHeight = 64.0;

/// 平铺视图的文件夹图标块
const double _folderIconBox = AppSize.coverSm;

/// 列表底部留白
const double _bottomInset = _flatRowHeight * 2;

/// 文件夹树的播放控制器，直接复用 [DetailsPageControllerBase]
class _FolderTreePlayController with DetailsPageControllerBase {
  void dispose() {
    items.dispose();
    headCover.dispose();
  }
}

class FoldersPreviewPage extends StatefulWidget {
  const FoldersPreviewPage({super.key});

  @override
  State<FoldersPreviewPage> createState() => _FoldersPreviewPageState();
}

class _FoldersPreviewPageState extends State<FoldersPreviewPage> {
  final _settingController = SettingController.instance;
  final _musicCacheController = MusicCacheController.instance;
  final _audioController = AudioController.instance;

  /// 根目录 → 该目录下所有音乐路径，进入页面时重新扫描一次
  final MapSignal<String, List<String>> _folderPathMap = mapSignal({});

  /// 视图模式：false = 平铺，true = 树形
  final Signal<bool> _isTreeView = signal(false);

  /// 驱动信号。展开 / 收起或扫描进度变化时自增，驱动树形视图刷新
  final Signal<int> _rowsVersion = signal(0);

  final _playController = _FolderTreePlayController();

  /// 已展开的文件夹路径
  final Set<String> _expandedPaths = {};

  /// 已经自动展开过的根目录，避免用户手动收起后又被自动展开
  final Set<String> _autoExpandedRoots = {};

  List<FolderTreeNode> _roots = const [];
  List<FolderTreeRow> _rows = const [];

  /// 路径 → 元数据，树形视图展示标题 / 艺术家 / 时长时使用
  Map<String, MusicCache> _metaMap = const {};

  EffectCleanup? _treeWorker;

  /// 防止 dispose 之后扫描的异步回调仍然写入已释放的 signal
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();

    // 扫描结果或音乐缓存变化时重建树
    _treeWorker = effect(() {
      final snapshot = _folderPathMap.value;
      final cacheItems = _musicCacheController.items.value;
      untracked(() {
        _metaMap = {for (final m in cacheItems) m.path: m};
        _roots = buildFolderRoots(snapshot);
        for (final root in _roots) {
          // 根目录默认展开一次
          if (_autoExpandedRoots.add(root.path)) {
            _expandedPaths.add(root.path);
          }
        }
        _rebuildRows();
      });
    });

    unawaited(_scanFolders());
  }

  @override
  void dispose() {
    _isDisposed = true;
    _treeWorker?.call();
    _playController.dispose();
    _folderPathMap.dispose();
    _isTreeView.dispose();
    _rowsVersion.dispose();
    super.dispose();
  }

  Future<void> _scanFolders() async {
    // 先快照一份：scanAudioPaths 内部会移除不可访问的目录，直接遍历原列表会并发修改
    for (final folder in [..._settingController.folders]) {
      final paths = (await scanAudioPaths([
        folder,
      ], _settingController)).toList();
      if (_isDisposed) return;
      _folderPathMap[folder] = paths;
    }
  }

  void _rebuildRows() {
    _rows = flattenVisibleRows(roots: _roots, expandedPaths: _expandedPaths);
    _rowsVersion.value++;
  }

  void _toggleExpand(String path) {
    if (!_expandedPaths.remove(path)) {
      _expandedPaths.add(path);
    }
    _rebuildRows();
  }

  /// 播放树形视图中的音乐：以它所在文件夹的直属音乐作为播放列表
  void _playTreeSong(FolderTreeRow row) {
    final parent = row.parent;
    if (parent == null) return;

    final songs = <MusicCache>[];
    MusicCache? target;
    for (final child in parent.children) {
      if (child.isFolder) continue;
      final meta = _metaMap[child.path];
      if (meta == null) continue;
      songs.add(meta);
      if (child.path == row.node.path) target = meta;
    }
    if (target == null) return;

    _playController.items.value = songs;
    _playController.play(
      '${parent.path}_${OperateArea.foldersDetails}_'
      '${DateTime.now().millisecondsSinceEpoch}',
      metadata: target,
    );
  }

  void _openFolderDetails(String folder, List<String> pathList) {
    context.push(
      AppRoutes.details,
      extra: {
        'pathList': pathList,
        'title': folder,
        'operateArea': OperateArea.foldersDetails,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final treeStyles = (
      title: context.createTextStyle(size: AppFontSize.md),
      sub: context.createTextStyle(
        size: AppFontSize.sm,
        opacity: AppAlpha.textTertiary,
      ),
      highlight: context.createTextStyle(
        size: AppFontSize.md,
        color: colorScheme.primary,
      ),
    );
    final lineColor = colorScheme.onSurface.withValues(
      alpha: FolderTreeSpec.lineAlpha,
    );

    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xl,
        children: [
          _buildHeader(),
          Expanded(
            child: SignalBuilder(
              builder: (context) => AnimatedSwitcher(
                duration: AppDuration.fast,
                child: _isTreeView.value
                    ? _buildTreeView(
                        key: const ValueKey(true),
                        styles: treeStyles,
                        lineColor: lineColor,
                      )
                    : _buildFlatView(
                        key: const ValueKey(false),
                        styles: treeStyles,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.md,
          children: [
            Text(
              '文件夹',
              style: context.createTextStyle(
                size: AppFontSize.title,
                weight: FontWeight.w600,
              ),
            ),
            SignalBuilder(
              builder: (context) {
                final total = _settingController.folders.length;
                final scanned = _folderPathMap.value.length;
                final suffix = scanned < total ? ' · 正在扫描 $scanned/$total' : '';

                return Text(
                  '共 $total 个文件夹$suffix',
                  style: context.createTextStyle(
                    size: AppFontSize.md,
                    opacity: AppAlpha.textSecondary,
                    tabularFigures: true,
                  ),
                );
              },
            ),
          ],
        ),
        SignalBuilder(
          builder: (_) {
            final isTree = _isTreeView.value;
            return _ViewToggleButton(
              isTreeView: isTree,
              onTap: () => _isTreeView.value = !isTree,
            );
          },
        ),
      ],
    );
  }

  /// 没有可展示内容时的占位
  Widget? _buildPlaceholder({required int scanned}) {
    final total = _settingController.folders.length;
    if (total == 0) {
      return const AppEmptyState(
        text: '还没有添加文件夹，去设置里添加音乐目录',
        icon: PhosphorIconsLight.folderOpen,
      );
    }
    if (scanned == 0) {
      return const Center(child: CircularProgressIndicator());
    }
    return null;
  }

  Widget _buildFlatView({required Key key, required FolderTreeStyles styles}) {
    final snapshot = _folderPathMap.value;
    final folders = snapshot.keys.toList();

    final placeholder = _buildPlaceholder(scanned: folders.length);
    if (placeholder != null) return KeyedSubtree(key: key, child: placeholder);

    return ListView.builder(
      key: key,
      scrollCacheExtent: const ScrollCacheExtent.pixels(_flatRowHeight * 4),
      // 只渲染已经扫完的目录
      itemCount: folders.length,
      itemExtent: _flatRowHeight,
      padding: const EdgeInsets.only(bottom: _bottomInset),
      addAutomaticKeepAlives: false,
      addSemanticIndexes: false,
      itemBuilder: (context, index) {
        final folder = folders[index];
        final pathList = snapshot[folder] ?? const <String>[];
        return _FlatFolderTile(
          folder: folder,
          songCount: pathList.length,
          styles: styles,
          onTap: () => _openFolderDetails(folder, pathList),
        );
      },
    );
  }

  Widget _buildTreeView({
    required Key key,
    required FolderTreeStyles styles,
    required Color lineColor,
  }) {
    _rowsVersion.value; // 订阅驱动信号
    final rows = _rows;

    final placeholder = _buildPlaceholder(scanned: _folderPathMap.value.length);
    if (placeholder != null) return KeyedSubtree(key: key, child: placeholder);

    return ListView.builder(
      key: key,
      scrollCacheExtent: const ScrollCacheExtent.pixels(
        FolderTreeSpec.rowHeight * 4,
      ),
      itemCount: rows.length,
      itemExtent: FolderTreeSpec.rowHeight,
      padding: const EdgeInsets.only(bottom: _bottomInset),
      addAutomaticKeepAlives: false,
      addSemanticIndexes: false,
      itemBuilder: (context, index) {
        final row = rows[index];
        return FolderTreeRowView(
          row: row,
          styles: styles,
          lineColor: lineColor,
          metadata: row.node.isFolder ? null : _metaMap[row.node.path],
          currentPath: _audioController.currentPath,
          isExpanded: _expandedPaths.contains(row.node.path),
          onTap: () => row.node.isFolder
              ? _toggleExpand(row.node.path)
              : _playTreeSong(row),
        );
      },
    );
  }
}

/// 平铺视图的一行
class _FlatFolderTile extends StatelessWidget {
  final String folder;
  final int songCount;
  final FolderTreeStyles styles;
  final VoidCallback onTap;

  const _FlatFolderTile({
    required this.folder,
    required this.songCount,
    required this.styles,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: AppTappable(
        onTap: onTap,
        tooltip: folder,
        hoverBackground: colorScheme.primary.withValues(alpha: AppAlpha.hover),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: AppSpacing.lg,
          children: [
            Container(
              width: _folderIconBox,
              height: _folderIconBox,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(
                  alpha: AppAlpha.surfaceStrong,
                ),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(
                PhosphorIconsLight.folderSimple,
                size: AppIconSize.md,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xxs,
                children: [
                  Text(
                    folder,
                    style: styles.title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('共 $songCount 首音乐', style: styles.sub),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  final bool isTreeView;
  final VoidCallback onTap;

  const _ViewToggleButton({required this.isTreeView, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = colorScheme.surfaceContainerHighest.withValues(
      alpha: AppAlpha.surfaceSubtle,
    );

    return AppTappable(
      onTap: onTap,
      tooltip: isTreeView ? '切换到平铺视图' : '切换到树形视图',
      background: background,
      hoverBackground: Color.alphaBlend(
        colorScheme.primary.withValues(alpha: AppAlpha.hover),
        background,
      ),
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: AppAlpha.border),
        width: AppSize.hairline,
      ),
      child: SizedBox.square(
        dimension: AppSize.button,
        child: Center(
          child: Icon(
            isTreeView
                ? PhosphorIconsLight.treeStructure
                : PhosphorIconsLight.listBullets,
            size: AppIconSize.md,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
