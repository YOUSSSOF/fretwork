import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/app_typography.dart';
import 'package:fretwork/core/widgets/core_animated_number.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// A −/+ numeric field with long-press acceleration, for bpm and minutes.
///
/// Holding a button repeats, speeding up the longer it is held — dialling 60 to
/// 200 bpm one tap at a time is not a real interaction.
class CoreStepperField extends StatefulWidget {
  const CoreStepperField({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.label,
    this.suffix,
    this.valueStyle = CoreTextStyle.h2,
    super.key,
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;
  final String? label;
  final String? suffix;
  final CoreTextStyle valueStyle;

  @override
  State<CoreStepperField> createState() => _CoreStepperFieldState();
}

class _CoreStepperFieldState extends State<CoreStepperField> {
  Timer? _repeat;
  int _repeatCount = 0;

  /// The value the repeat loop is working from.
  ///
  /// Not `widget.value`: the parent only re-renders once per frame, so a repeat
  /// ticking faster than 60 Hz would read the same stale value every time and
  /// the hold would advance by one step per frame instead of one per tick.
  late int _current = widget.value;

  @override
  void didUpdateWidget(CoreStepperField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Adopt changes that came from anywhere other than this widget's own loop.
    if (widget.value != oldWidget.value && widget.value != _current) {
      _current = widget.value;
    }
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _apply(int direction) {
    final next = (_current + direction * widget.step).clamp(
      widget.min,
      widget.max,
    );
    if (next == _current) {
      _stopRepeat();
      return;
    }
    _current = next;
    unawaited(HapticFeedback.selectionClick());
    widget.onChanged(next);
  }

  void _startRepeat(int direction) {
    _apply(direction);
    _repeatCount = 0;
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 60), (_) {
      _repeatCount++;
      // Ramp: slow for the first half-second, then every tick.
      final threshold = _repeatCount < 8 ? 4 : (_repeatCount < 24 ? 2 : 1);
      if (_repeatCount % threshold == 0) _apply(direction);
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          CoreText.label(widget.label!),
          const SizedBox(height: Sp.sm),
        ],
        Container(
          decoration: BoxDecoration(
            color: colors.surface1,
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                enabled: widget.value > widget.min,
                onDown: () => _startRepeat(-1),
                onUp: _stopRepeat,
                semanticLabel: 'Decrease',
              ),
              Expanded(
                child: Center(
                  child: CoreAnimatedNumber(
                    value: '${widget.value}',
                    style: widget.valueStyle,
                    suffix: widget.suffix,
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                enabled: widget.value < widget.max,
                onDown: () => _startRepeat(1),
                onUp: _stopRepeat,
                semanticLabel: 'Increase',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onDown,
    required this.onUp,
    required this.semanticLabel,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Listener(
      onPointerDown: enabled ? (_) => onDown() : null,
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: CorePressable(
        // The press animation belongs here, but the value change is driven by
        // the pointer stream above so a hold repeats.
        onPressed: enabled ? () {} : null,
        haptic: false,
        semanticLabel: semanticLabel,
        child: SizedBox(
          width: Layout.touchTarget + Sp.sm,
          height: Layout.touchTarget + Sp.sm,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? colors.textPrimary : colors.textTertiary,
          ),
        ),
      ),
    );
  }
}
