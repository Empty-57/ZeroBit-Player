import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/folder_tree/folder_tree_model.dart';
import 'package:zerobit_player/components/widget/app_button/app_button.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

/// 树行用到的文本样式
typedef FolderTreeStyles = ({
  TextStyle title,
  TextStyle sub,
  TextStyle highlight,
});

/// 单行树节点：缩进线 + 文件夹或音乐内容
class FolderTreeRowView extends StatelessWidget {
  final FolderTreeRow row;
  final FolderTreeStyles styles;
  final Color lineColor;

  /// 音乐行对应的元数据，文件夹行为 null
  final MusicCache? metadata;

  /// 当前播放路径，用于高亮正在播放的那一行
  final Signal<String> currentPath;

  final bool isExpanded;
  final VoidCallback onTap;

  const FolderTreeRowView({
    super.key,
    required this.row,
    required this.styles,
    required this.lineColor,
    required this.metadata,
    required this.currentPath,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final depth = row.lines.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (depth > 0)
          // 缩进线区域，宽度随层级增长
          CustomPaint(
            size: Size(depth * FolderTreeSpec.indent, FolderTreeSpec.rowHeight),
            painter: FolderIndentPainter(lines: row.lines, color: lineColor),
          ),
        Expanded(
          child: row.node.isFolder
              ? _FolderRow(
                  node: row.node,
                  styles: styles,
                  isExpanded: isExpanded,
                  onTap: onTap,
                )
              : SignalBuilder(
                  builder: (_) => _MusicRow(
                    node: row.node,
                    metadata: metadata,
                    styles: styles,
                    isPlaying: currentPath.value == row.node.path,
                    onTap: onTap,
                  ),
                ),
        ),
      ],
    );
  }
}

/// 行的点击区域外观
class _RowShell extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  /// 正在播放
  final bool highlighted;

  const _RowShell({
    required this.child,
    required this.onTap,
    required this.tooltip,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton.ghost(
      onPressed: onTap,
      tooltip: tooltip,
      selected: highlighted,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      size: .large,
      height: FolderTreeSpec.rowHeight,
      child: child,
    );
  }
}

class _FolderRow extends StatelessWidget {
  final FolderTreeNode node;
  final FolderTreeStyles styles;
  final bool isExpanded;
  final VoidCallback onTap;

  const _FolderRow({
    required this.node,
    required this.styles,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _RowShell(
      onTap: onTap,
      tooltip: node.path,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          Icon(
            isExpanded
                ? PhosphorIconsLight.caretDown
                : PhosphorIconsLight.caretRight,
            size: FolderTreeSpec.caretSize,
            color: styles.sub.color,
          ),
          Icon(
            isExpanded
                ? PhosphorIconsLight.folderOpen
                : PhosphorIconsLight.folderSimple,
            size: FolderTreeSpec.iconSize,
            color: colorScheme.primary,
          ),
          Expanded(
            child: Text(
              node.name,
              style: styles.title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('${node.songCount}', style: styles.sub),
        ],
      ),
    );
  }
}

class _MusicRow extends StatelessWidget {
  final FolderTreeNode node;
  final MusicCache? metadata;
  final FolderTreeStyles styles;
  final bool isPlaying;
  final VoidCallback onTap;

  const _MusicRow({
    required this.node,
    required this.metadata,
    required this.styles,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = metadata;
    final mainStyle = isPlaying ? styles.highlight : styles.title;
    final title = (meta != null && meta.title.isNotEmpty)
        ? meta.title
        : node.name;

    return _RowShell(
      onTap: onTap,
      tooltip: title,
      highlighted: isPlaying,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          // 占位：与文件夹行的展开箭头等宽，让文字和上一级文件夹名对齐
          const SizedBox(width: FolderTreeSpec.caretSize),
          Icon(
            isPlaying
                ? PhosphorIconsFill.musicNoteSimple
                : PhosphorIconsLight.musicNoteSimple,
            size: FolderTreeSpec.iconSize,
            color: mainStyle.color,
          ),
          Expanded(
            flex: FolderTreeSpec.titleFlex,
            child: Text(
              title,
              style: mainStyle,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (meta != null) ...[
            Expanded(
              flex: FolderTreeSpec.artistFlex,
              child: Text(
                meta.artist,
                style: styles.sub,
                textAlign: TextAlign.right,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(formatTime(totalSeconds: meta.duration), style: styles.sub),
          ],
        ],
      ),
    );
  }
}

/// 缩进线绘制：每一层一根竖线，最后一层带拐角横线接到节点上
class FolderIndentPainter extends CustomPainter {
  final List<bool> lines;
  final Color color;

  const FolderIndentPainter({required this.lines, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final depth = lines.length;
    if (depth == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = FolderTreeSpec.lineWidth
      ..style = PaintingStyle.stroke;

    final centerY = size.height * 0.5;

    for (int i = 0; i < depth; i++) {
      final x = i * FolderTreeSpec.indent + FolderTreeSpec.indent * 0.5;

      if (i < depth - 1) {
        // 中间层：该层后面还有兄弟时，竖线贯穿整行
        if (lines[i]) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        continue;
      }

      // 最后一层：竖线 + 拐角横线。
      // 后面还有兄弟就画到底，否则画到中部
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, lines[i] ? size.height : centerY),
        paint,
      );
      canvas.drawLine(
        Offset(x, centerY),
        Offset((i + 1) * FolderTreeSpec.indent, centerY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FolderIndentPainter old) {
    if (old.color != color || old.lines.length != lines.length) return true;
    for (int i = 0; i < lines.length; i++) {
      if (old.lines[i] != lines[i]) return true;
    }
    return false;
  }
}
