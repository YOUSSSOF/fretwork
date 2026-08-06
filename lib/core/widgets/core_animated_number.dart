import 'package:flutter/material.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_typography.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// A numeric readout whose digits roll rather than swap.
///
/// Each digit position is its own [AnimatedSwitcher] keyed on its character, so
/// changing 119 → 120 rolls only the two digits that actually changed. Digits
/// are tabular, so the width never shifts mid-roll.
class CoreAnimatedNumber extends StatelessWidget {
  const CoreAnimatedNumber({
    required this.value,
    this.style = CoreTextStyle.display,
    this.color,
    this.prefix,
    this.suffix,
    this.suffixStyle,
    super.key,
  });

  final String value;
  final CoreTextStyle style;
  final Color? color;
  final String? prefix;
  final String? suffix;
  final CoreTextStyle? suffixStyle;

  /// Convenience for integers, which is what almost every call site has.
  factory CoreAnimatedNumber.integer(
    int value, {
    CoreTextStyle style = CoreTextStyle.display,
    Color? color,
    String? prefix,
    String? suffix,
    CoreTextStyle? suffixStyle,
    Key? key,
  }) => CoreAnimatedNumber(
    value: '$value',
    style: style,
    color: color,
    prefix: prefix,
    suffix: suffix,
    suffixStyle: suffixStyle,
    key: key,
  );

  @override
  Widget build(BuildContext context) {
    final duration = context.motion(Motion.base);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (prefix != null)
          CoreText(prefix!, style: style, color: color, tabular: true),
        for (var i = 0; i < value.length; i++)
          _Digit(
            character: value[i],
            // Keyed by position so digit 0 keeps its slot as the number grows.
            position: i,
            total: value.length,
            style: style,
            color: color,
            duration: duration,
          ),
        if (suffix != null) ...[
          const SizedBox(width: 2),
          CoreText(
            suffix!,
            style: suffixStyle ?? CoreTextStyle.label,
            color: color,
          ),
        ],
      ],
    );
  }
}

class _Digit extends StatelessWidget {
  const _Digit({
    required this.character,
    required this.position,
    required this.total,
    required this.style,
    required this.color,
    required this.duration,
  });

  final String character;
  final int position;
  final int total;
  final CoreTextStyle style;
  final Color? color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Motion.emphasize,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) {
        // Enters from below and leaves upward — the direction reads as a
        // counter advancing rather than a generic crossfade.
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.center, children: [...previous, ?current]),
      child: CoreText(
        character,
        key: ValueKey('$position-$total-$character'),
        style: style,
        color: color,
        tabular: true,
      ),
    );
  }
}
