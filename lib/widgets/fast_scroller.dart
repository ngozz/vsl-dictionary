import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/services.dart' show HapticFeedback;

/// Google/Samsung-Contacts-style fast scroller.
///
/// - Reserves a [gutterWidth] strip on the right; [child] gets the rest.
/// - A thumb (with the current section letter) follows the scroll position
///   and fades out ~1.4s after scrolling stops.
/// - Touching or dragging anywhere in the gutter scrubs the list; a big letter
///   bubble appears next to the thumb and a haptic tick fires per letter change.
///
/// [labelAt] receives the *content position* sitting at the same relative
/// spot in the viewport as the thumb is in the track. That way the first
/// letter shows at the very top and the last letter at the very bottom, even
/// when the last section is shorter than one screen.
class FastScroller extends StatefulWidget {
  final ScrollController controller;
  final String Function(double contentPosition) labelAt;
  final Widget child;
  final double gutterWidth;

  const FastScroller({
    super.key,
    required this.controller,
    required this.labelAt,
    required this.child,
    this.gutterWidth = 36,
  });

  @override
  State<FastScroller> createState() => _FastScrollerState();
}

class _FastScrollerState extends State<FastScroller> {
  static const double _thumbW = 28;
  static const double _thumbH = 48;
  static const double _trackPad = 8; // gap above/below the thumb's travel
  static const double _bubble = 60;
  static const Duration _idleHide = Duration(milliseconds: 1400);

  Timer? _hideTimer;
  bool _active = false; // scrolled recently
  bool _dragging = false;
  String _lastLabel = '';
  bool _retryScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(FastScroller old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  // Scroll notifications can arrive mid-layout; defer setState in that case.
  void _refresh() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  // Used while the list isn't attached / laid out yet (e.g. right after a tab
  // switch). Rebuilds once next frame instead of waiting for the user to scroll.
  void _retryNextFrame() {
    if (_retryScheduled || !mounted) return;
    _retryScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _retryScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_idleHide, () {
      if (mounted && !_dragging) setState(() => _active = false);
    });
  }

  void _onScroll() {
    _active = true;
    _scheduleHide();
    _refresh();
  }

  void _dragTo(double dy, double height) {
    final c = widget.controller;
    // `c.position` throws unless exactly one position is attached.
    if (c.positions.length != 1) return;
    final pos = c.position;
    if (!pos.hasContentDimensions || !pos.hasViewportDimension) return;
    final trackLen = height - 2 * _trackPad - _thumbH;
    if (trackLen <= 0) return;
    final f = ((dy - _trackPad - _thumbH / 2) / trackLen).clamp(0.0, 1.0);
    c.jumpTo(f * pos.maxScrollExtent);
    final label = widget.labelAt(pos.pixels + f * pos.viewportDimension);
    if (label != _lastLabel) {
      _lastLabel = label;
      HapticFeedback.selectionClick();
    }
  }

  void _startDrag(double dy, double height) {
    _hideTimer?.cancel();
    setState(() {
      _dragging = true;
      _active = true;
    });
    _dragTo(dy, height);
  }

  void _endDrag() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(right: widget.gutterWidth),
          child: widget.child,
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: widget.gutterWidth,
          child: LayoutBuilder(
            builder: (context, box) => _buildGutter(context, box.maxHeight),
          ),
        ),
      ],
    );
  }

  Widget _buildGutter(BuildContext context, double height) {
    final c = widget.controller;

    // length != 1: list not attached yet, or two lists briefly share the
    // controller. No dimensions: first layout hasn't happened. Wait a frame.
    if (c.positions.length != 1 ||
        !c.position.hasContentDimensions ||
        !c.position.hasViewportDimension) {
      _retryNextFrame();
      return const SizedBox.shrink();
    }
    final pos = c.position;
    // Nothing to scroll: no thumb, and no retry (so no endless frame loop).
    if (pos.maxScrollExtent <= 0) return const SizedBox.shrink();

    final frac = (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
    final trackLen = height - 2 * _trackPad - _thumbH;
    final top = _trackPad + frac * (trackLen < 0 ? 0 : trackLen);
    final label = widget.labelAt(pos.pixels + frac * pos.viewportDimension);
    final showThumb = _active || _dragging;
    final cs = Theme.of(context).colorScheme;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _startDrag(e.localPosition.dy, height),
      onPointerMove: (e) {
        if (_dragging) _dragTo(e.localPosition.dy, height);
      },
      onPointerUp: (_) => _endDrag(),
      onPointerCancel: (_) => _endDrag(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Thumb with the current letter.
          Positioned(
            top: top,
            right: (widget.gutterWidth - _thumbW) / 2,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: showThumb ? 1 : 0,
                duration: Duration(milliseconds: showThumb ? 120 : 350),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: _thumbW,
                  height: _thumbH,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _dragging ? cs.primary : cs.primaryContainer,
                    borderRadius: BorderRadius.circular(_thumbW / 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _dragging ? cs.onPrimary : cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Big bubble, only while dragging. Sits left of the gutter.
          Positioned(
            top: top + _thumbH / 2 - _bubble / 2,
            right: widget.gutterWidth + 4,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _dragging ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: AnimatedScale(
                  scale: _dragging ? 1 : 0.6,
                  alignment: Alignment.centerRight,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: _bubble,
                    height: _bubble,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}