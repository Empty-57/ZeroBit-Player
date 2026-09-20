import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/tools/cover_lru_cache.dart';

enum CoverResolutionFlag { small, middle, big }

const double _coverSize = 48.0;
const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
final double _dpr = PlatformDispatcher.instance.views.first.devicePixelRatio;

// CoverQuality.low 返回的缩略图最长边就是150
const int _maxSmallCoverResolution = 150;

// CoverQuality.middle 返回的缩略图最长边就是450
const int _maxMiddleCoverResolution = 450;

// CoverQuality.high 返回的缩略图最长边就是800
const int _maxBigCoverResolution = 800;

const _coverCoverResolutionMap = <CoverResolutionFlag, int>{
  CoverResolutionFlag.small: _maxSmallCoverResolution,
  CoverResolutionFlag.middle: _maxMiddleCoverResolution,
  CoverResolutionFlag.big: _maxBigCoverResolution,
};

class LoadU8Cover extends StatefulWidget {
  final Uint8List data;
  final CoverResolutionFlag coverResolutionFlag;
  final double? width;
  final double? height;

  const LoadU8Cover({
    super.key,
    required this.data,
    this.coverResolutionFlag = CoverResolutionFlag.small,
    double? size,
    double? width,
    double? height,
  }) : assert(
         size == null || (width == null && height == null),
         '[参数冲突]：size 与 (width/height) 互斥，不可同时设置',
       ),
       width = size ?? width ?? height,
       height = size ?? height ?? width;

  @override
  State<LoadU8Cover> createState() => _LoadU8CoverState();
}

class _LoadU8CoverState extends State<LoadU8Cover> {
  ImageProvider? _imageProvider;
  late final int _cacheResolution;

  @override
  void initState() {
    super.initState();
    final sideLength = widget.width ?? widget.height ?? _coverSize;
    final dprSize = (sideLength * _dpr).round();
    _cacheResolution =
        dprSize >
            (_coverCoverResolutionMap[widget.coverResolutionFlag] ??
                _maxSmallCoverResolution)
        ? _maxSmallCoverResolution
        : dprSize;
    _triggerLoad(isInit: true);
  }

  @override
  void didUpdateWidget(LoadU8Cover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _imageProvider = null;
      _triggerLoad();
    }
  }

  @override
  void dispose() {
    _imageProvider?.evict();
    super.dispose();
  }

  void _applyImageData(Uint8List data) {
    final provider = ResizeImage.resizeIfNeeded(
      _cacheResolution,
      _cacheResolution,
      MemoryImage(data),
    );
    _imageProvider = provider;
  }

  void _triggerLoad({bool isInit = false}) {
    setState(() => _applyImageData(widget.data));
  }

  @override
  Widget build(BuildContext context) {
    final provider = _imageProvider;
    if (provider != null) {
      return Image(
        image: provider,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: child,
          );
        },
      );
    }
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: const BoxDecoration(color: Color(0x1A808080)),
    );
  }
}

class LoadLocalOrNetCover extends StatefulWidget {
  final MusicCache music;
  final CoverResolutionFlag coverResolutionFlag;
  final CoverQuality coverQuality;
  final double? width;
  final double? height;

  const LoadLocalOrNetCover({
    super.key,
    required this.music,
    this.coverResolutionFlag = CoverResolutionFlag.small,
    this.coverQuality = CoverQuality.low,
    double? size,
    double? width,
    double? height,
  }) : assert(
         size == null || (width == null && height == null),
         '[参数冲突]：size 与 (width/height) 互斥，不可同时设置',
       ),
       width = size ?? width ?? height,
       height = size ?? height ?? width;

  @override
  State<LoadLocalOrNetCover> createState() => _LoadLocalOrNetCoverState();
}

class _LoadLocalOrNetCoverState extends State<LoadLocalOrNetCover> {
  ImageProvider? _imageProvider;
  late final int _cacheResolution;
  Timer? _debounceTimer;
  @override
  void initState() {
    super.initState();
    final sideLength = widget.width ?? widget.height ?? _coverSize;
    final dprSize = (sideLength * _dpr).round();
    _cacheResolution =
        dprSize >
            (_coverCoverResolutionMap[widget.coverResolutionFlag] ??
                _maxSmallCoverResolution)
        ? _maxSmallCoverResolution
        : dprSize;
    _triggerLoad(isInit: true);
  }

  @override
  void didUpdateWidget(LoadLocalOrNetCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.music.path != oldWidget.music.path) {
      _imageProvider = null;
      _triggerLoad();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _imageProvider?.evict();
    super.dispose();
  }

  void _applyImageData(Uint8List data) {
    final provider = ResizeImage.resizeIfNeeded(
      _cacheResolution,
      _cacheResolution,
      MemoryImage(data),
    );
    _imageProvider = provider;
  }

  void _triggerLoad({bool isInit = false}) {
    _debounceTimer?.cancel();

    final cachedData = CoverLRUCache.get(widget.music.path);
    if (cachedData != null) {
      if (isInit) {
        _applyImageData(cachedData);
      } else {
        setState(() => _applyImageData(cachedData));
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) _loadCoverAndSave();
    });
  }

  Future<void> _loadCoverAndSave() async {
    final targetPath = widget.music.path;
    final coverData = await getCover(
      path: targetPath,
      sizeFlag: widget.coverQuality,
    );

    if (!mounted || widget.music.path != targetPath) return;

    Uint8List? finalData;

    if (coverData == null) {
      final title = widget.music.title;
      final artist =
          (widget.music.artist.isNotEmpty && widget.music.artist != 'UNKNOWN')
          ? ' - ${widget.music.artist}'
          : '';
      final generatedData = await saveCoverByText(
        text: title + artist,
        songPath: targetPath,
      );

      if (!mounted || widget.music.path != targetPath) return;

      if (generatedData != null && generatedData.isNotEmpty) {
        // saveCoverByText 已经把封面写回音频文件，这里重新读一次小图，
        // 读不到才退回用原图
        final smallData = await getCover(
          path: targetPath,
          sizeFlag: widget.coverQuality,
        );

        if (!mounted || widget.music.path != targetPath) return;

        finalData = smallData ?? Uint8List.fromList(generatedData);
      }
    } else {
      finalData = coverData;
    }

    if (finalData != null && finalData.isNotEmpty) {
      CoverLRUCache.put(targetPath, finalData);
      setState(() => _applyImageData(finalData!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _imageProvider;
    if (provider != null) {
      return ClipRRect(
        borderRadius: _coverBorderRadius,
        child: Image(
          image: provider,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: child,
            );
          },
        ),
      );
    }
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: const Color(0x1A808080),
        borderRadius: _coverBorderRadius,
      ),
    );
  }
}
