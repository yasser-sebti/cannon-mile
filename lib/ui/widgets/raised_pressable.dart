import 'dart:async';

import 'package:flutter/material.dart';

@visibleForTesting
const raisedPressableFaceTransformKey = Key('raised_pressable_face_transform');

class RaisedPressable extends StatefulWidget {
  const RaisedPressable({
    required this.height,
    required this.radius,
    required this.shadowOffset,
    required this.shadowColor,
    required this.onTap,
    required this.child,
    this.width,
    this.enabled = true,
    this.onTapFeedback,
    this.actionDelay = const Duration(milliseconds: 60),
    super.key,
  });

  final double? width;
  final double height;
  final BorderRadius radius;
  final double shadowOffset;
  final Color shadowColor;
  final VoidCallback onTap;
  final Widget child;
  final bool enabled;
  final VoidCallback? onTapFeedback;
  final Duration actionDelay;

  @override
  State<RaisedPressable> createState() => _RaisedPressableState();
}

class _RaisedPressableState extends State<RaisedPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  Timer? _tapTimer;
  bool _isDisposed = false;
  bool _feedbackPlayedForPress = false;

  Duration get _pressDuration =>
      Duration(milliseconds: (widget.shadowOffset * 5.3).round());

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: _pressDuration,
      reverseDuration: _pressDuration,
    );
  }

  @override
  void didUpdateWidget(covariant RaisedPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final duration = _pressDuration;
    _pressController
      ..duration = duration
      ..reverseDuration = duration;
    if (!widget.enabled) {
      _cancelPendingTap();
      _release();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelPendingTap();
    _pressController.dispose();
    super.dispose();
  }

  void _cancelPendingTap() {
    _tapTimer?.cancel();
    _tapTimer = null;
  }

  void _press() {
    if (_isDisposed || !mounted || !widget.enabled) {
      return;
    }
    if (!_feedbackPlayedForPress) {
      _feedbackPlayedForPress = true;
      widget.onTapFeedback?.call();
    }
    _pressController.forward();
  }

  void _release() {
    if (_isDisposed || !mounted) {
      return;
    }
    _feedbackPlayedForPress = false;
    _pressController.reverse();
  }

  void _handleTap() {
    if (!widget.enabled) {
      return;
    }
    _cancelPendingTap();
    _tapTimer = Timer(widget.actionDelay, () {
      _tapTimer = null;
      if (mounted && widget.enabled) {
        widget.onTap();
      }
    });
  }

  void _handleTapCancel() {
    _cancelPendingTap();
    _release();
  }

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: widget.width,
      height: widget.height + widget.shadowOffset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0.5,
            right: 0.5,
            top: widget.shadowOffset,
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.shadowColor,
                borderRadius: widget.radius,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: widget.height,
            child: AnimatedBuilder(
              animation: _pressController,
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: widget.child,
              ),
              builder: (context, child) {
                final eased = Curves.easeOutCubic.transform(
                  _pressController.value,
                );
                return Transform.translate(
                  key: raisedPressableFaceTransformKey,
                  offset: Offset(0, widget.shadowOffset * eased),
                  child: child,
                );
              },
            ),
          ),
        ],
      ),
    );

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        _cancelPendingTap();
        _press();
      },
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _handleTapCancel(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        child: content,
      ),
    );
  }
}
