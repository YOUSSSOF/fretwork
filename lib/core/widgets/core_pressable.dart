import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';

/// The press response every tappable thing in the app is built on.
///
/// Down: scale to 0.968 and dim 4 % over [Motion.instant].
/// Up: spring back with [Motion.snappy] — released, not eased, so the surface
/// feels like it has mass.
/// Drag out: cancels, same spring back, no callback.
///
/// The press is driven from [Listener.onPointerDown] rather than
/// `GestureDetector.onTapDown`, because the tap recognizer holds the callback
/// until it wins the arena or its 100 ms deadline expires. A tenth of a second
/// of dead time before anything moves is exactly the lag that makes an app feel
/// cheap, and everything else in the UI inherits it from here.
///
/// This is a [StatefulWidget] because it genuinely needs a [TickerProvider];
/// that is the exception the plan allows for `core/widgets`.
class CorePressable extends StatefulWidget {
  const CorePressable({
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.pressedScale = 0.968,
    this.dim = 0.04,
    this.haptic = true,
    this.semanticLabel,
    this.button = true,
    this.behavior = HitTestBehavior.opaque,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final double dim;
  final bool haptic;
  final String? semanticLabel;
  final bool button;
  final HitTestBehavior behavior;

  bool get enabled => onPressed != null || onLongPress != null;

  @override
  State<CorePressable> createState() => _CorePressableState();
}

class _CorePressableState extends State<CorePressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.instant,
    reverseDuration: Motion.snappyCurve.settleDuration,
  );

  late final Animation<double> _press = CurvedAnimation(
    parent: _controller,
    curve: Curves.linear,
    reverseCurve: Motion.snappyCurve.flipped,
  );

  /// Cached rather than read from context in the gesture callbacks: a cancel
  /// can arrive while the element is being deactivated, and an inherited-widget
  /// lookup at that point throws.
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = context.reduceMotion;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pressDown() {
    if (!widget.enabled) return;
    if (_reduced) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  void _release() {
    if (!widget.enabled) return;
    if (_reduced) {
      _controller.value = 0;
      return;
    }
    // Reversed through the spring, so the release overshoots very slightly and
    // settles rather than easing flatly back to rest.
    _controller.reverse();
  }

  void _handleTap() {
    final callback = widget.onPressed;
    if (callback == null) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    callback();
  }

  void _handleLongPress() {
    final callback = widget.onLongPress;
    if (callback == null) return;
    if (widget.haptic) HapticFeedback.mediumImpact();
    callback();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.button,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: Listener(
        behavior: widget.behavior,
        onPointerDown: (_) => _pressDown(),
        onPointerCancel: (_) => _release(),
        child: GestureDetector(
          behavior: widget.behavior,
          onTapUp: (_) => _release(),
          onTapCancel: _release,
          onTap: widget.onPressed == null ? null : _handleTap,
          onLongPress: widget.onLongPress == null ? null : _handleLongPress,
          child: AnimatedBuilder(
            animation: _press,
            builder: (context, child) {
              final t = _press.value.clamp(0.0, 1.0);
              final scale = 1 - (1 - widget.pressedScale) * t;
              final dim = widget.dim * t;
              return Transform.scale(
                scale: scale,
                filterQuality: FilterQuality.low,
                child: dim <= 0.001
                    // Skipped entirely at rest: a colour filter costs a
                    // save-layer, and this widget wraps every tile in every
                    // list in the app.
                    ? child
                    : ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: dim),
                          BlendMode.srcATop,
                        ),
                        child: child,
                      ),
              );
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
