import 'dart:async';

import 'package:flutter/material.dart';

class ScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration delayBefore;
  final Duration pauseBetween;
  final double velocity;
  final TextAlign textAlign;
  final StrutStyle strutStyle;

  const ScrollText({
    super.key,
    required this.text,
    required this.style,
    this.delayBefore = const Duration(milliseconds: 500),
    this.pauseBetween = const Duration(milliseconds: 1000),
    this.velocity = 50.0,
    this.textAlign = TextAlign.left,
    required this.strutStyle,
  });

  @override
  State<ScrollText> createState() => ScrollTextState();
}

class ScrollTextState extends State<ScrollText> {
  late final ScrollController _scrollController;
  bool _isScrolling = false;
  bool _shouldShowFade = true; // 初始为true防止跳变

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrollLoop());
  }

  @override
  void didUpdateWidget(ScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _scrollController.jumpTo(0.0);

      // 文字改变时，先重置状态，并在下一帧重新计算
      setState(() {
        _isScrolling = false;
        _shouldShowFade = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _startScrollLoop());
    }
  }

  Future<void> _startScrollLoop() async {
    if (!mounted || !_scrollController.hasClients) return;

    final double maxScroll = _scrollController.position.maxScrollExtent;
    final bool overflows = maxScroll > 0;

    if (overflows != _shouldShowFade) {
      setState(() {
        _shouldShowFade = overflows;
      });
    }

    if (!overflows) return;

    _isScrolling = true;

    while (mounted && _isScrolling && _scrollController.hasClients) {
      await Future.delayed(widget.delayBefore);
      if (!mounted || !_isScrolling || !_scrollController.hasClients) break;

      final duration = Duration(
        milliseconds: (maxScroll / widget.velocity * 1000).round(),
      );

      await _scrollController.animateTo(
        maxScroll,
        duration: duration,
        curve: Curves.linear,
      );
      if (!mounted || !_isScrolling || !_scrollController.hasClients) break;

      await Future.delayed(widget.pauseBetween);
      if (!mounted || !_isScrolling || !_scrollController.hasClients) break;

      await _scrollController.animateTo(
        0.0,
        duration: duration,
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _isScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 基础滚动文本结构
    final Widget scrollText = SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        strutStyle: widget.strutStyle,
        maxLines: 1,
        softWrap: false,
        textAlign: widget.textAlign,
      ),
    );

    if (_shouldShowFade) {
      return ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.05, 0.95, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: scrollText,
      );
    }

    return scrollText;
  }
}
