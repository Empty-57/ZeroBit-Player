import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/widget/audio_ctrl_btn.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/tools/details_ctrl_mixin.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/general_style.dart';
import 'package:zerobit_player/tools/func/sync_cache.dart';

const double _itemHeight = 64.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

/// 树形视图行高
const double _treeItemHeight = 44.0;

/// 树形视图每一级的缩进宽度
const double _treeIndent = 22.0;

/// 树节点：既可以是文件夹，也可以是音乐文件
class _TreeNode {
  /// 显示名称：根节点为完整路径，子文件夹为文件夹名，音乐为不含扩展名的文件名
  final String name;

  /// 完整路径
  final String path;

  final bool isFolder;

  /// 子节点：顺序为「文件夹在前、音乐在后」，按名称排序
  final List<_TreeNode> children;

  /// 该节点下（含所有子孙）的音乐数量
  final int songCount;

  const _TreeNode({
    required this.name,
    required this.path,
    required this.isFolder,
    required this.children,
    required this.songCount,
  });
}

/// [_TreeNode] 的构建器
class _NodeBuilder {
  final String name;
  final String path;
  final Map<String, _NodeBuilder> folders = {};
  final List<String> files = [];

  _NodeBuilder(this.name, this.path);

  /// 获取 [folderName] 的构建器并建立folders的映射
  _NodeBuilder child(String folderName) => folders.putIfAbsent(
    folderName,
    () => _NodeBuilder(folderName, p.join(path, folderName)),
  );

  /// 构建 [_TreeNode]
  _TreeNode freeze() {
    final children = <_TreeNode>[];
    int count = 0; // 总音频数

    // 排序并构建文件夹的 _TreeNode
    final folderNames = folders.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final folderName in folderNames) {
      final node = folders[folderName]!.freeze();
      count += node.songCount;
      children.add(node);
    }

    // 排序并构建音频文件的 _TreeNode
    files.sort(
      (a, b) =>
          p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()),
    );
    for (final filePath in files) {
      children.add(
        _TreeNode(
          name: p.basenameWithoutExtension(filePath),
          path: filePath,
          isFolder: false,
          children: const [],
          songCount: 1,
        ),
      );
    }
    count += files.length;

    return _TreeNode(
      name: name,
      path: path,
      isFolder: true,
      children: children,
      songCount: count,
    );
  }
}

/// 表示一行节点上的属性
class _TreeRow {
  final _TreeNode node;

  /// 父节点，根节点为 null
  final _TreeNode? parent;

  /// 缩进线状态，长度即层级深度
  /// 若为true则表示还有兄弟节点
  final List<bool> lines;

  const _TreeRow({
    required this.node,
    required this.parent,
    required this.lines,
  });
}

/// 播放控制器，直接复用 [DetailsPageControllerBase]
class _FolderTreePlayController with DetailsPageControllerBase {
  void dispose() {
    items.dispose();
    headCover.dispose();
  }
}

/// 缩进线绘制
class _IndentLinePainter extends CustomPainter {
  final List<bool> lines;
  final Color color;

  const _IndentLinePainter({required this.lines, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final int depth = lines.length;
    if (depth == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double centerY = size.height * 0.5;

    for (int i = 0; i < depth; i++) {
      final double x = i * _treeIndent + _treeIndent * 0.5;
      // 外层
      if (i < depth - 1) {
        if (lines[i]) {
          // 有兄弟节点时画直线贯穿整行
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        continue;
      }

      // 最后一层，竖线 + 拐角横线
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, lines[i] ? size.height : centerY),
        paint,
      );
      canvas.drawLine(
        Offset(x, centerY),
        Offset((i + 1) * _treeIndent, centerY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_IndentLinePainter old) {
    if (old.color != color || old.lines.length != lines.length) return true;
    for (int i = 0; i < lines.length; i++) {
      if (old.lines[i] != lines[i]) return true;
    }
    return false;
  }
}

class FoldersPreviewPage extends StatefulWidget {
  const FoldersPreviewPage({super.key});

  @override
  State<FoldersPreviewPage> createState() => _FoldersPreviewPageState();
}

class _FoldersPreviewPageState extends State<FoldersPreviewPage> {
  final SettingController _settingController = SettingController.instance;
  final MusicCacheController _musicCacheController =
      MusicCacheController.instance;
  final AudioController _audioController = AudioController.instance;

  /// 根目录 -> 该目录下所有音乐路径，进入页面时重新扫描一次
  final MapSignal<String, List<String>> _folderPathMap = mapSignal({});

  /// 视图模式：false = 平铺，true = 树形
  final Signal<bool> _viewMode = signal(false);

  /// 驱动信号，展开/收起或扫描进度变化时自增，驱动树形视图刷新
  final Signal<int> _rowsVersion = signal(0);

  final _playController = _FolderTreePlayController();

  /// 已展开的文件夹路径
  final Set<String> _expandedPaths = {};

  /// 已经自动展开过的根目录，避免用户手动收起后又被自动展开
  final Set<String> _autoExpandedRoots = {};

  List<_TreeNode> _roots = const [];
  List<_TreeRow> _rows = const [];

  /// 路径 -> 元数据，树形视图展示标题/歌手/时长时使用
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
        _roots = _buildRoots(snapshot);
        for (final root in _roots) {
          // 根目录默认展开一次
          if (_autoExpandedRoots.add(root.path)) {
            _expandedPaths.add(root.path);
          }
        }
        _rebuildRows();
      });
    });

    _scanFolders();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _treeWorker?.call();
    _playController.dispose();
    _folderPathMap.dispose();
    _viewMode.dispose();
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

  /// 构建 [_folderPathMap]
  List<_TreeNode> _buildRoots(Map<String, List<String>> snapshot) {
    final roots = <_TreeNode>[];
    snapshot.forEach((rootPath, filePaths) {
      final builder = _NodeBuilder(rootPath, rootPath); // 获取_TreeNode构建器
      for (final filePath in filePaths) {
        List<String> segments; // 文件路径层级
        try {
          segments = p.split(
            p.relative(filePath, from: rootPath),
          ); // 获取从根路径的相对路径并拆分
        } catch (_) {
          // 跨盘符等异常路径，退化成直接挂在根节点下
          segments = [p.basename(filePath)];
        }
        if (segments.isEmpty) continue;
        _NodeBuilder node = builder; // node引用在builder上，开始初始化builder的数据
        for (int i = 0; i < segments.length - 1; i++) {
          node = node.child(segments[i]);
        }
        node.files.add(filePath);
      }
      roots.add(builder.freeze()); //构建并添加_TreeNode
    });
    return roots;
  }

  /// 按展开状态把树压成一维可见行列表，只有可见行才会进入 ListView
  void _rebuildRows() {
    final rows = <_TreeRow>[];
    for (int i = 0; i < _roots.length; i++) {
      _flatten(_roots[i], null, const <bool>[], rows);
    }
    _rows = rows;
    _rowsVersion.value++;
  }

  /// 循环构建rows
  void _flatten(
    _TreeNode node,
    _TreeNode? parent,
    List<bool> lines,
    List<_TreeRow> out,
  ) {
    out.add(_TreeRow(node: node, parent: parent, lines: lines));

    if (!node.isFolder || !_expandedPaths.contains(node.path)) return;

    final children = node.children;
    final int depth = lines.length;
    for (int i = 0; i < children.length; i++) {
      // 构建缩进深度
      final childLines = List<bool>.filled(depth + 1, false); // +1：当前节点占一层
      for (int j = 0; j < depth; j++) {
        childLines[j] = lines[j];
      }
      // 最后一位记录「当前子节点后面是否还有兄弟」
      childLines[depth] = i != children.length - 1;
      _flatten(children[i], node, childLines, out);
    }
  }

  void _toggleExpand(String path) {
    if (!_expandedPaths.remove(path)) {
      _expandedPaths.add(path);
    }
    _rebuildRows();
  }

  /// 播放树形视图中的音乐：以它所在文件夹的直属音乐作为播放列表
  void _playTreeSong(_TreeRow row) {
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
      '${parent.path}_${OperateArea.foldersDetails}_${DateTime.now().millisecondsSinceEpoch}',
      metadata: target,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle1 = generalTextStyle(ctx: context, size: 'md');
    final textStyle2 = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);
    final colorScheme = Theme.of(context).colorScheme;
    final highLightStyle = generalTextStyle(
      ctx: context,
      size: 'md',
      color: colorScheme.primary,
    );
    final lineColor = colorScheme.onSurface.withValues(alpha: 0.25);

    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text(
                    '文件夹',
                    style: generalTextStyle(
                      ctx: context,
                      size: 'title',
                      weight: FontWeight.w600,
                    ),
                  ),
                  SignalBuilder(
                    builder: (context) => Text(
                      '共${_settingController.folders.length}个文件夹',
                      style: generalTextStyle(ctx: context, size: 'md'),
                    ),
                  ),
                ],
              ),
              SignalBuilder(
                builder: (context) {
                  final isTree = _viewMode.value;
                  return GenIconBtn(
                    tooltip: isTree ? '切换到平铺视图' : '切换到树形视图',
                    icon: isTree
                        ? PhosphorIconsLight.treeStructure
                        : PhosphorIconsLight.listBullets,
                    size: 42,
                    fn: () => _viewMode.value = !isTree,
                  );
                },
              ),
            ],
          ),
          Expanded(
            flex: 1,
            child: SignalBuilder(
              builder: (context) {
                if (_viewMode.value) {
                  return _buildTreeView(
                    textStyle1: textStyle1,
                    textStyle2: textStyle2,
                    highLightStyle: highLightStyle,
                    lineColor: lineColor,
                  );
                }
                return _buildFlatView(
                  textStyle1: textStyle1,
                  textStyle2: textStyle2,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 平铺视图
  Widget _buildFlatView({
    required TextStyle textStyle1,
    required TextStyle textStyle2,
  }) {
    final snapshot = _folderPathMap.value;
    final folders = snapshot.keys.toList();

    if (folders.isEmpty) {
      return Center(child: Text('暂无可展示的文件夹', style: textStyle2));
    }

    return ListView.builder(
      scrollCacheExtent: const ScrollCacheExtent.pixels(_itemHeight * 1),
      itemCount: _settingController.folders.length,
      itemExtent: _itemHeight,
      itemBuilder: (context, index) {
        if (index > folders.length - 1) {
          return const SizedBox.shrink();
        }

        final folder = folders[index];
        final pathList = snapshot[folder] ?? const <String>[];

        return TextButton(
          onPressed: () {
            context.push(
              AppRoutes.details,
              extra: {
                'pathList': pathList,
                'title': folder,
                'operateArea': OperateArea.foldersDetails,
              },
            );
          },
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: _borderRadius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 8,
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder,
                      style: textStyle1,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text("共${pathList.length}首音乐", style: textStyle2),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 树形视图
  Widget _buildTreeView({
    required TextStyle textStyle1,
    required TextStyle textStyle2,
    required TextStyle highLightStyle,
    required Color lineColor,
  }) {
    _rowsVersion.value; // 订阅驱动信号
    final rows = _rows;

    if (rows.isEmpty) {
      return Center(child: Text('暂无可展示的文件夹', style: textStyle2));
    }

    return ListView.builder(
      scrollCacheExtent: const ScrollCacheExtent.pixels(_treeItemHeight * 4),
      itemCount: rows.length,
      itemExtent: _treeItemHeight,
      itemBuilder: (context, index) {
        final row = rows[index];
        return _TreeRowView(
          row: row,
          lineColor: lineColor,
          textStyle: textStyle1,
          subStyle: textStyle2,
          highLightStyle: highLightStyle,
          metadata: row.node.isFolder ? null : _metaMap[row.node.path],
          currentPath: _audioController.currentPath,
          isExpanded: _expandedPaths.contains(row.node.path),
          onTap: () {
            if (row.node.isFolder) {
              _toggleExpand(row.node.path);
            } else {
              _playTreeSong(row);
            }
          },
        );
      },
    );
  }
}

/// 单行树节点
class _TreeRowView extends StatelessWidget {
  final _TreeRow row;
  final Color lineColor;
  final TextStyle textStyle;
  final TextStyle subStyle;
  final TextStyle highLightStyle;
  final MusicCache? metadata;
  final Signal<String> currentPath;
  final bool isExpanded;
  final VoidCallback onTap;

  const _TreeRowView({
    required this.row,
    required this.lineColor,
    required this.textStyle,
    required this.subStyle,
    required this.highLightStyle,
    required this.metadata,
    required this.currentPath,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final node = row.node;
    final int depth = row.lines.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (depth > 0)
          // 缩进线区域，宽度随层级增长
          CustomPaint(
            size: Size(depth * _treeIndent, _treeItemHeight),
            painter: _IndentLinePainter(lines: row.lines, color: lineColor),
          ),
        Expanded(
          child: node.isFolder
              ? _buildFolderRow(node)
              : SignalBuilder(
                  builder: (context) {
                    final isPlaying = currentPath.value == node.path;
                    return _buildMusicRow(node, isPlaying);
                  },
                ),
        ),
      ],
    );
  }

  ButtonStyle get _rowBtnStyle => TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    minimumSize: const Size(0, _treeItemHeight),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    alignment: Alignment.centerLeft,
    shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
  );

  Widget _buildFolderRow(_TreeNode node) {
    return TextButton(
      onPressed: onTap,
      style: _rowBtnStyle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 6,
        children: [
          Icon(
            isExpanded
                ? PhosphorIconsLight.caretDown
                : PhosphorIconsLight.caretRight,
            size: 14,
            color: subStyle.color,
          ),
          Icon(
            isExpanded
                ? PhosphorIconsLight.folderOpen
                : PhosphorIconsLight.folderSimple,
            size: 18,
            color: textStyle.color,
          ),
          Expanded(
            child: Text(
              node.name,
              style: textStyle,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Text('${node.songCount}', style: subStyle),
        ],
      ),
    );
  }

  Widget _buildMusicRow(_TreeNode node, bool isPlaying) {
    final meta = metadata;
    final mainStyle = isPlaying ? highLightStyle : textStyle;
    final title = (meta != null && meta.title.isNotEmpty)
        ? meta.title
        : node.name;

    return TextButton(
      onPressed: onTap,
      style: _rowBtnStyle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 6,
        children: [
          // 占位，让音乐行的文字和上一级文件夹名对齐
          const SizedBox(width: 14),
          Icon(
            isPlaying
                ? PhosphorIconsFill.musicNoteSimple
                : PhosphorIconsLight.musicNoteSimple,
            size: 18,
            color: mainStyle.color,
          ),
          Expanded(
            child: Text(
              title,
              style: mainStyle,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (meta != null) ...[
            Expanded(
              child: Text(
                meta.artist,
                style: subStyle,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: .right,
                maxLines: 1,
              ),
            ),
            Text(formatTime(totalSeconds: meta.duration), style: subStyle),
          ],
        ],
      ),
    );
  }
}
