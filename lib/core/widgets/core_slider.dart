import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// A slider with haptic detents and an optional suggestion marker on the track.
///
/// Used for session length, tempo and text scale. The marker exists so the
/// onboarding slider can show the recommended value for the chosen milestone
/// without pre-selecting it and hiding the choice.
class CoreSlider extends StatefulWidget {
  const CoreSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.suggestion,
    this.label,
    this.formatValue,
    this.onChangeEnd,
    super.key,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final int? divisions;
  final double? suggestion;
  final String? label;
  final String Function(double value)? formatValue;

  @override
  State<CoreSlider> createState() => _CoreSliderState();
}

class _CoreSliderState extends State<CoreSlider> {
  double? _lastDetent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final format = widget.formatValue ?? (v) => v.round().toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CoreText.label(widget.label!),
                CoreText.mono(format(widget.value)),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) => Stack(
            alignment: Alignment.center,
            children: [
              if (widget.suggestion != null)
                _SuggestionMark(
                  fraction:
                      ((widget.suggestion! - widget.min) /
                              (widget.max - widget.min))
                          .clamp(0.0, 1.0),
                  width: constraints.maxWidth,
                  color: colors.textTertiary,
                ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: colors.accentStrong,
                  inactiveTrackColor: colors.border,
                  thumbColor: colors.textPrimary,
                  overlayColor: colors.selection,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 9,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20,
                  ),
                  trackShape: const RectangularSliderTrackShape(),
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: Slider(
                  value: widget.value.clamp(widget.min, widget.max),
                  min: widget.min,
                  max: widget.max,
                  divisions: widget.divisions,
                  onChanged: (value) {
                    _maybeDetent(value);
                    widget.onChanged(value);
                  },
                  onChangeEnd: widget.onChangeEnd,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One tick per whole step, not per pixel of drag.
  void _maybeDetent(double value) {
    final rounded = value.roundToDouble();
    if (_lastDetent == rounded) return;
    _lastDetent = rounded;
    unawaited(HapticFeedback.selectionClick());
  }
}

class _SuggestionMark extends StatelessWidget {
  const _SuggestionMark({
    required this.fraction,
    required this.width,
    required this.color,
  });

  final double fraction;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Slider insets its track by the overlay radius at each end.
    const inset = 24.0;
    final usable = (width - inset * 2).clamp(0.0, double.infinity);
    return Positioned(
      left: inset + usable * fraction - 1,
      child: Container(width: 2, height: 16, color: color),
    );
  }
}
