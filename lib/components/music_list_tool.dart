import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/tools/cover_lru_cache.dart';
import 'package:zerobit_player/tools/details_ctrl_mixin.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/func_extension.dart';

const double _itemSpacing = 16.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

class MusicTile extends StatelessWidget {
  final MusicCache metadata;
  final TextStyle titleStyle;
  final TextStyle highLightTitleStyle;
  final TextStyle subStyle;
  final TextStyle highLightSubStyle;
  final String audioSource;
  final String operateArea;
  final RxBool isMulSelect;
  final RxList<MusicCache> selectedList;
  final bool viewMode;
  final DetailsPageControllerBase baseBontroller;

  const MusicTile({
    super.key,
    required this.metadata,
    required this.titleStyle,
    required this.highLightTitleStyle,
    required this.subStyle,
    required this.highLightSubStyle,
    required this.audioSource,
    required this.operateArea,
    required this.isMulSelect,
    required this.selectedList,
    required this.viewMode,
    required this.baseBontroller,
  });

  void _onTileTapped() {
    if (isMulSelect.value) {
      final index = selectedList.indexWhere((v) => v.path == metadata.path);
      if (index != -1) {
        selectedList.removeAt(index);
      } else {
        selectedList.add(metadata);
      }
    } else {
      baseBontroller.play(audioSource, metadata: metadata);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget cover = AsyncCover(music: metadata);

    return Obx(() {
      final isPlaying =
          baseBontroller.audioController.currentPath.value == metadata.path;
      final isSelected = selectedList.any((v) => v.path == metadata.path);

      final subTextStyle = isPlaying ? highLightSubStyle : subStyle;
      final textStyle = isPlaying ? highLightTitleStyle : titleStyle;

      return TextButton(
        onPressed: _onTileTapped.throttle(ms: isMulSelect.value ? 10 : 500),
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
          backgroundColor:
              isSelected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: _itemSpacing,
          children: [
            if (operateArea == OperateArea.albumDetails)
              Text(
                metadata.trackNumber.toString().padLeft(2, '0'),
                style: subTextStyle,
              ),
            cover,
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metadata.title,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: textStyle,
                  ),
                  Text(
                    metadata.artist,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: subTextStyle,
                  ),
                ],
              ),
            ),
            if (viewMode)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _itemSpacing),
                  child: Text(
                    metadata.album,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: subTextStyle,
                  ),
                ),
              ),
            Text(
              formatTime(totalSeconds: metadata.duration),
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: subTextStyle,
            ),
          ],
        ),
      );
    });
  }
}

const double _coverSize = 48.0;
const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
final double _dpr = PlatformDispatcher.instance.views.first.devicePixelRatio;

class AsyncCover extends StatefulWidget {
  final MusicCache music;
  final double size;
  const AsyncCover({super.key, required this.music, this.size = _coverSize});

  @override
  State<AsyncCover> createState() => _AsyncCoverState();
}

class _AsyncCoverState extends State<AsyncCover> {
  Future<Uint8List?>? _coverFuture;
  late final int _cacheResolution;

  @override
  void initState() {
    super.initState();
    _cacheResolution = (widget.size * _dpr).round();
    _triggerLoad();
  }

  @override
  void didUpdateWidget(AsyncCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.music.path != oldWidget.music.path ||
        !identical(widget.music, oldWidget.music)) {
      _triggerLoad();
    }
  }

  void _triggerLoad() {
    final cachedData = CoverLRUCache.get(widget.music.path);
    if (cachedData != null) {
      setState(() {
        _coverFuture = Future.value(cachedData);
      });
      return;
    }

    setState(() {
      _coverFuture = _loadCoverAndSave();
    });
  }

  Future<Uint8List?> _loadCoverAndSave() async {
    await Future.delayed(const Duration(milliseconds: 100)); //防抖
    if (!mounted) return null;

    Uint8List? finalData;
    final coverData = await getCover(path: widget.music.path, sizeFlag: 0);

    if (coverData == null) {
      final title = widget.music.title;
      final artist =
          (widget.music.artist.isNotEmpty && widget.music.artist != 'UNKNOWN')
              ? ' - ${widget.music.artist}'
              : '';
      final generatedData = await saveCoverByText(
        text: title + artist,
        songPath: widget.music.path,
      );
      if (generatedData != null && generatedData.isNotEmpty) {
        finalData = Uint8List.fromList(generatedData);
      }
    } else {
      finalData = coverData;
    }

    if (finalData != null && mounted) {
      CoverLRUCache.put(widget.music.path, finalData);
    }

    return finalData;
  }

  Widget _renderCover(Uint8List imageBytes) {
    return ClipRRect(
      borderRadius: _coverBorderRadius,
      child: Image.memory(
        imageBytes,
        key: ValueKey(imageBytes.hashCode),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        cacheWidth: _cacheResolution,
        cacheHeight: _cacheResolution,
        gaplessPlayback: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _coverFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return _renderCover(snapshot.data!);
        }
        return Container(
          height: widget.size,
          width: widget.size,
          decoration: BoxDecoration(
            color: const Color(0x1A808080),
            borderRadius: _coverBorderRadius,
          ),
        );
      },
    );
  }
}
