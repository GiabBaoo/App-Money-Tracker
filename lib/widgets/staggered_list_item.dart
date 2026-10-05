import 'package:flutter/material.dart';

class StaggeredListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;

  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 25),
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Tối ưu triệt để 120fps: Chỉ tạo animation cho 5 phần tử đầu tiên trong viewport.
    // Các phần tử từ thứ 6 trở đi xuất hiện tức thì khi cuộn, loại bỏ hoàn toàn hiện tượng khựng lag khi lướt danh sách.
    if (widget.index < 5) {
      _controller = AnimationController(vsync: this, duration: widget.duration);

      _fadeAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeOutQuad),
      );

      _slideAnimation = Tween<Offset>(begin: const Offset(0.0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeOutCubic),
      );

      final delayMs = (widget.index * 25).clamp(0, 100);
      if (delayMs == 0) {
        _controller!.forward();
      } else {
        Future.delayed(Duration(milliseconds: delayMs), () {
          if (mounted) {
            _controller?.forward();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return widget.child;
    }

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnimation!,
        child: SlideTransition(
          position: _slideAnimation!,
          child: widget.child,
        ),
      ),
    );
  }
}
