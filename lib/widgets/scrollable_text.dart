import 'package:flutter/material.dart';

/// A text widget that automatically scrolls horizontally if the content overflows
class ScrollableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration scrollDuration;
  final Duration pauseDuration;
  final int maxLines;
  final TextAlign textAlign;
  final double scrollSpeed;

  const ScrollableText(
    this.text, {
    super.key,
    this.style,
    this.scrollDuration = const Duration(seconds: 3),
    this.pauseDuration = const Duration(seconds: 1),
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.scrollSpeed = 30.0, // pixels per second
  });

  @override
  State<ScrollableText> createState() => _ScrollableTextState();
}

class _ScrollableTextState extends State<ScrollableText>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  bool _needsScrolling = false;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: widget.scrollDuration,
      vsync: this,
    );
    
    // Check if scrolling is needed after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollingNeeded();
    });
  }

  @override
  void didUpdateWidget(ScrollableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // Reset animation and check if new text needs scrolling
      _animationController.reset();
      _isScrolling = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfScrollingNeeded();
      });
    }
  }

  void _checkIfScrollingNeeded() {
    if (!mounted) return;
    
    try {
      // Check if the scroll view has content that overflows
      if (_scrollController.hasClients && 
          _scrollController.position.maxScrollExtent > 0) {
        setState(() {
          _needsScrolling = true;
        });
        
        // Start scrolling after initial pause
        Future.delayed(widget.pauseDuration, () {
          if (mounted && !_isScrolling) {
            _startScrolling();
          }
        });
      } else {
        setState(() {
          _needsScrolling = false;
        });
      }
    } catch (e) {
      // Handle any errors gracefully
      setState(() {
        _needsScrolling = false;
      });
    }
  }

  void _startScrolling() async {
    if (!mounted || !_needsScrolling || _isScrolling) return;
    
    setState(() {
      _isScrolling = true;
    });

    try {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      // Calculate duration based on scroll distance and speed
      final duration = Duration(
        milliseconds: (maxScroll / widget.scrollSpeed * 1000).round(),
      );

      // Scroll to the end (right to left)
      await _scrollController.animateTo(
        maxScroll,
        duration: duration,
        curve: Curves.linear,
      );

      if (!mounted) return;

      // Pause at the end
      await Future.delayed(widget.pauseDuration);

      if (!mounted) return;

      // Scroll back to the beginning and stay there
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500), // Quick return
        curve: Curves.easeOut,
      );

      if (mounted) {
        setState(() {
          _isScrolling = false;
        });
        // Do not start scrolling again - one-time scroll only
      }
    } catch (e) {
      // Handle any animation errors
      if (mounted) {
        setState(() {
          _isScrolling = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(), // Prevent manual scrolling
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: widget.maxLines,
        textAlign: widget.textAlign,
        overflow: TextOverflow.visible,
      ),
    );
  }
}

/// A specialized scrollable text for app bar titles
class ScrollableAppBarTitle extends StatelessWidget {
  final String title;
  final TextStyle? style;
  final Duration scrollDuration;
  final Duration pauseDuration;

  const ScrollableAppBarTitle(
    this.title, {
    super.key,
    this.style,
    this.scrollDuration = const Duration(seconds: 4),
    this.pauseDuration = const Duration(seconds: 1),
  });

  @override
  Widget build(BuildContext context) {
    return ScrollableText(
      title,
      style: style,
      scrollDuration: scrollDuration,
      pauseDuration: pauseDuration,
      scrollSpeed: 25.0, // Slightly slower for better readability
    );
  }
}