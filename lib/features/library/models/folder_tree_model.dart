import 'package:path/path.dart' as p;
import 'package:zerobit_player/core/constants/ui_constants.dart';

/// 文件夹树的尺寸常量
abstract final class FolderTreeSpec {
  /// 树形视图行高
  static const double rowHeight = 44.0;

  /// 每一级的缩进宽度
  static const double indent = 22.0;

  /// 展开箭头尺寸。音乐行用等宽占位，让文字与上一级文件夹名对齐
  static const double caretSize = AppIconSize.xs;

  /// 文件夹 / 音符图标尺寸
  static const double iconSize = AppIconSize.sm;

  /// 缩进线粗细与颜色不透明度
  static const double lineWidth = 1.0;
  static const double lineAlpha = 0.25;

  /// 标题与艺术家列的宽度比
  static const int titleFlex = 2;
  static const int artistFlex = 1;
}

/// 树节点：既可以是文件夹，也可以是音乐文件
class FolderTreeNode {
  /// 显示名称：根节点为完整路径，子文件夹为文件夹名，音乐为不含扩展名的文件名
  final String name;

  /// 完整路径
  final String path;

  final bool isFolder;

  /// 子节点：顺序为「文件夹在前、音乐在后」，各自按名称排序
  final List<FolderTreeNode> children;

  /// 该节点下（含所有子孙）的音乐数量
  final int songCount;

  const FolderTreeNode({
    required this.name,
    required this.path,
    required this.isFolder,
    required this.children,
    required this.songCount,
  });
}

/// [FolderTreeNode] 的构建器。构建期可变，`freeze` 后产出不可变节点
class _NodeBuilder {
  final String name;
  final String path;
  final Map<String, _NodeBuilder> folders = {};
  final List<String> files = [];

  _NodeBuilder(this.name, this.path);

  /// 取 [folderName] 的子构建器，不存在则建立
  _NodeBuilder child(String folderName) => folders.putIfAbsent(
    folderName,
    () => _NodeBuilder(folderName, p.join(path, folderName)),
  );

  FolderTreeNode freeze() {
    final children = <FolderTreeNode>[];
    int count = 0;

    // 文件夹在前，按名称排序
    final folderNames = folders.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final folderName in folderNames) {
      final node = folders[folderName]!.freeze();
      count += node.songCount;
      children.add(node);
    }

    // 音乐文件在后，同样按名称排序
    files.sort(
      (a, b) =>
          p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()),
    );
    for (final filePath in files) {
      children.add(
        FolderTreeNode(
          name: p.basenameWithoutExtension(filePath),
          path: filePath,
          isFolder: false,
          children: const [],
          songCount: 1,
        ),
      );
    }
    count += files.length;

    return FolderTreeNode(
      name: name,
      path: path,
      isFolder: true,
      children: children,
      songCount: count,
    );
  }
}

/// 压平后的一行，带上绘制缩进线所需的信息
class FolderTreeRow {
  final FolderTreeNode node;

  /// 父节点，根节点为 null。播放音乐时用它取同级曲目作为播放列表
  final FolderTreeNode? parent;

  /// 缩进线状态，长度即层级深度；每一位表示该层「后面是否还有兄弟」
  final List<bool> lines;

  const FolderTreeRow({
    required this.node,
    required this.parent,
    required this.lines,
  });
}

/// 由「根目录 → 该目录下所有音乐路径」构建树
List<FolderTreeNode> buildFolderRoots(Map<String, List<String>> snapshot) {
  final roots = <FolderTreeNode>[];

  snapshot.forEach((rootPath, filePaths) {
    final builder = _NodeBuilder(rootPath, rootPath);

    for (final filePath in filePaths) {
      List<String> segments;
      try {
        // 取相对根目录的路径并按层级拆开
        segments = p.split(p.relative(filePath, from: rootPath));
      } catch (_) {
        // 跨盘符等异常路径，退化成直接挂在根节点下
        segments = [p.basename(filePath)];
      }
      if (segments.isEmpty) continue;

      var node = builder;
      // 最后一段是文件名，只用前面的层级建文件夹
      for (int i = 0; i < segments.length - 1; i++) {
        node = node.child(segments[i]);
      }
      node.files.add(filePath);
    }

    roots.add(builder.freeze());
  });

  return roots;
}

/// 按展开状态把树压成一维可见行列表，只有可见行才会进入 ListView
List<FolderTreeRow> flattenVisibleRows({
  required List<FolderTreeNode> roots,
  required Set<String> expandedPaths,
}) {
  final rows = <FolderTreeRow>[];

  void walk(FolderTreeNode node, FolderTreeNode? parent, List<bool> lines) {
    rows.add(FolderTreeRow(node: node, parent: parent, lines: lines));

    if (!node.isFolder || !expandedPaths.contains(node.path)) return;

    final children = node.children;
    final depth = lines.length;
    for (int i = 0; i < children.length; i++) {
      // +1：当前节点自己占一层
      final childLines = List<bool>.filled(depth + 1, false);
      for (int j = 0; j < depth; j++) {
        childLines[j] = lines[j];
      }
      // 末位记录「这个子节点后面是否还有兄弟」，决定竖线是否贯穿整行
      childLines[depth] = i != children.length - 1;
      walk(children[i], node, childLines);
    }
  }

  for (final root in roots) {
    walk(root, null, const <bool>[]);
  }
  return rows;
}
