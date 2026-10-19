import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:zerobit_player/core/constants/ui_constants.dart';
import 'package:zerobit_player/core/network/apis.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';

import '../storage/models/music_cache_model.dart';
import '../utils/cover_lru_cache.dart';

enum CoverResolutionFlag { small, middle, big }

const double _defaultCoverSize = 48.0;

const _coverResolutionMap = <CoverResolutionFlag, int>{
  CoverResolutionFlag.small: 200,
  CoverResolutionFlag.middle: 600,
  CoverResolutionFlag.big: 1000,
};

double _getDevicePixelRatio() {
  return PlatformDispatcher.instance.views.firstOrNull?.devicePixelRatio ?? 1.0;
}

int _calculateCacheResolution({
  required double? width,
  required double? height,
  required CoverResolutionFlag flag,
}) {
  final sideLength = width ?? height ?? _defaultCoverSize;
  final dpr = _getDevicePixelRatio();
  final dprSize = (sideLength * dpr).round();
  final maxResolution = _coverResolutionMap[flag] ?? 600;
  return dprSize.clamp(1, maxResolution);
}

class _CoverImageFrame extends StatelessWidget {
  final ImageProvider? imageProvider;
  final double? width;
  final double? height;
  final bool useFrameBuilderCallback;

  const _CoverImageFrame({
    required this.imageProvider,
    this.width,
    this.height,
    required this.useFrameBuilderCallback,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(color: Color(0x1A808080)),
    );

    final provider = imageProvider;
    if (provider == null) return placeholder;

    return Image(
      image: provider,
      width: width,
      height: height,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => placeholder,
      frameBuilder: useFrameBuilderCallback
          ? (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: AppDuration.slow,
                curve: Curves.easeOut,
                child: child,
              );
            }
          : null,
    );
  }
}

class LoadU8Cover extends StatefulWidget {
  final Uint8List data;
  final CoverResolutionFlag coverResolutionFlag;
  final double? width;
  final double? height;
  final bool useFrameBuilderCallback;
  final bool evictOnDispose;

  const LoadU8Cover({
    super.key,
    required this.data,
    this.coverResolutionFlag = CoverResolutionFlag.small,
    double? size,
    double? width,
    double? height,
    this.useFrameBuilderCallback = true,
    this.evictOnDispose = true,
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

  void _updateProvider() {
    final cacheRes = _calculateCacheResolution(
      width: widget.width,
      height: widget.height,
      flag: widget.coverResolutionFlag,
    );

    _imageProvider = ResizeImage(
      MemoryImage(widget.data),
      width: cacheRes,
      height: cacheRes,
      policy: ResizeImagePolicy.fit,
    );
  }

  @override
  void initState() {
    super.initState();
    _updateProvider();
  }

  @override
  void didUpdateWidget(LoadU8Cover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data ||
        widget.width != oldWidget.width ||
        widget.height != oldWidget.height ||
        widget.coverResolutionFlag != oldWidget.coverResolutionFlag) {
      if (widget.evictOnDispose) {
        unawaited(_imageProvider?.evict());
      }
      _updateProvider();
    }
  }

  @override
  void dispose() {
    if (widget.evictOnDispose) {
      unawaited(_imageProvider?.evict());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CoverImageFrame(
      imageProvider: _imageProvider,
      width: widget.width,
      height: widget.height,
      useFrameBuilderCallback: widget.useFrameBuilderCallback,
    );
  }
}

class LoadLocalOrNetCover extends StatefulWidget {
  final MusicCache music;
  final CoverResolutionFlag coverResolutionFlag;
  final CoverQuality coverQuality;
  final double? width;
  final double? height;
  final bool useFrameBuilderCallback;
  final bool evictOnDispose;

  const LoadLocalOrNetCover({
    super.key,
    required this.music,
    this.coverResolutionFlag = CoverResolutionFlag.small,
    this.coverQuality = CoverQuality.low,
    double? size,
    double? width,
    double? height,
    this.useFrameBuilderCallback = true,
    this.evictOnDispose = true,
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
  Timer? _debounceTimer;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _triggerLoad();
  }

  @override
  void didUpdateWidget(LoadLocalOrNetCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.music.path != oldWidget.music.path ||
        widget.width != oldWidget.width ||
        widget.height != oldWidget.height ||
        widget.coverQuality != oldWidget.coverQuality ||
        widget.coverResolutionFlag != oldWidget.coverResolutionFlag) {
      if (widget.evictOnDispose) {
        unawaited(_imageProvider?.evict());
      }
      _imageProvider = null;
      _triggerLoad();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.evictOnDispose) {
      unawaited(_imageProvider?.evict());
    }
    super.dispose();
  }

  void _applyImageData(Uint8List data) {
    if (!mounted) return;
    final cacheRes = _calculateCacheResolution(
      width: widget.width,
      height: widget.height,
      flag: widget.coverResolutionFlag,
    );

    setState(() {
      _imageProvider = ResizeImage(
        MemoryImage(data),
        width: cacheRes,
        height: cacheRes,
        policy: ResizeImagePolicy.fit,
      );
    });
  }

  void _triggerLoad({bool isInit = false}) {
    _debounceTimer?.cancel();

    final targetPath = widget.music.path;
    _loadedPath = targetPath;

    Uint8List? cachedData;
    if (widget.coverQuality == CoverQuality.low) {
      cachedData = CoverLRUCache.get(targetPath);
    }

    if (cachedData != null) {
      _applyImageData(cachedData);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && _loadedPath == targetPath) {
        _loadCoverAndSave(targetPath);
      }
    });
  }

  Future<void> _loadCoverAndSave(String targetPath) async {
    final coverData = await getCover(
      path: targetPath,
      sizeFlag: widget.coverQuality,
    );

    if (!mounted || _loadedPath != targetPath) return;

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

      if (!mounted || _loadedPath != targetPath) return;

      if (generatedData != null && generatedData.isNotEmpty) {
        // saveCoverByText 写入文件后，重新按品质读取缩略图，读不到则退回原图
        final smallData = await getCover(
          path: targetPath,
          sizeFlag: widget.coverQuality,
        );

        if (!mounted || _loadedPath != targetPath) return;
        finalData = smallData ?? Uint8List.fromList(generatedData);
      }
    } else {
      finalData = coverData;
    }

    if (finalData != null && finalData.isNotEmpty) {
      if (widget.coverQuality == CoverQuality.low) {
        CoverLRUCache.put(targetPath, finalData);
      }
      _applyImageData(finalData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CoverImageFrame(
      imageProvider: _imageProvider,
      width: widget.width,
      height: widget.height,
      useFrameBuilderCallback: widget.useFrameBuilderCallback,
    );
  }
}

class LoadNetworkCover extends StatefulWidget {
  final String url;
  final CoverResolutionFlag coverResolutionFlag;
  final double? width;
  final double? height;
  final bool useFrameBuilderCallback;
  final bool evictOnDispose;

  const LoadNetworkCover({
    super.key,
    required this.url,
    this.coverResolutionFlag = CoverResolutionFlag.small,
    double? size,
    double? width,
    double? height,
    this.useFrameBuilderCallback = true,
    this.evictOnDispose = true,
  }) : assert(
         size == null || (width == null && height == null),
         '[参数冲突]：size 与 (width/height) 互斥，不可同时设置',
       ),
       width = size ?? width ?? height,
       height = size ?? height ?? width;

  @override
  State<LoadNetworkCover> createState() => _LoadNetworkCoverState();
}

class _LoadNetworkCoverState extends State<LoadNetworkCover> {
  ImageProvider? _imageProvider;

  void _updateProvider() {
    if (widget.url.isEmpty) {
      _imageProvider = null;
      return;
    }

    final cacheRes = _calculateCacheResolution(
      width: widget.width,
      height: widget.height,
      flag: widget.coverResolutionFlag,
    );

    _imageProvider = ResizeImage(
      NetworkImage(widget.url),
      width: cacheRes,
      height: cacheRes,
      policy: ResizeImagePolicy.fit,
    );
  }

  @override
  void initState() {
    super.initState();
    _updateProvider();
  }

  @override
  void didUpdateWidget(LoadNetworkCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url ||
        widget.width != oldWidget.width ||
        widget.height != oldWidget.height ||
        widget.coverResolutionFlag != oldWidget.coverResolutionFlag) {
      if (widget.evictOnDispose) {
        unawaited(_imageProvider?.evict());
      }
      _updateProvider();
    }
  }

  @override
  void dispose() {
    if (widget.evictOnDispose) {
      unawaited(_imageProvider?.evict());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CoverImageFrame(
      imageProvider: _imageProvider,
      width: widget.width,
      height: widget.height,
      useFrameBuilderCallback: widget.useFrameBuilderCallback,
    );
  }
}
