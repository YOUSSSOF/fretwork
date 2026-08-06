import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/app_typography.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';
import 'package:fretwork/core/widgets/core_segmented_grid.dart';
import 'package:fretwork/core/widgets/core_sheet.dart';
import 'package:fretwork/core/widgets/core_text.dart';

@immutable
class CoreTabItem {
  const CoreTabItem({
    required this.id,
    required this.label,
    this.shortLabel,
    this.badge,
    this.marked = false,
  });

  final String id;
  final String label;

  /// Deliberately shortened form ("Frag 7" for "Fragment 7"), used in
  /// scrollable mode past [CoreTabs.shortLabelThreshold] items. Shortening is a
  /// choice the caller makes; the component never ellipsizes.
  final String? shortLabel;

  final String? badge;

  /// Marks today's scheduled variant with a dot, so the user can find what the
  /// routine picked without scrubbing through eighteen fragments.
  final bool marked;
}

enum CoreTabsMode { fitted, scrollable }

/// The navigation pattern for exercise variants at every count, from two parts
/// up to Example 11's eighteen fragments.
///
/// The component copes with count by changing *layout mode*, never by refusing
/// to render, wrapping to a second row, compressing a tab below its density
/// minimum, or ellipsizing a label. Those four are the non-negotiables and are
/// covered by tests at 320/390/430/768 dp across 2–24 items in all densities.
class CoreTabs extends StatefulWidget {
  const CoreTabs({
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.density = CoreTabsDensity.regular,
    this.showIndexJump = true,
    super.key,
  });

  final List<CoreTabItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final CoreTabsDensity density;
  final bool showIndexJump;

  /// Past this many items in scrollable mode, [CoreTabItem.shortLabel] is used
  /// where the caller supplied one. Full labels still head the detail panel, so
  /// nothing is actually lost.
  static const int shortLabelThreshold = 10;

  static const double indicatorHeight = 3;
  static const double indexJumpWidth = 40;
  static const double markerDotSize = 4;

  /// How far past a tab boundary the row may come to rest before it snaps back,
  /// as a fraction of that tab's width.
  static const double snapTolerance = 0.20;

  @override
  State<CoreTabs> createState() => _CoreTabsState();
}

class _CoreTabsState extends State<CoreTabs> with TickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();

  late final AnimationController _indicator = AnimationController(
    vsync: this,
    duration: Motion.indicatorTravelCap,
  );

  _TabLayout? _layout;
  int _fromIndex = 0;
  int _toIndex = 0;
  bool _snapping = false;

  int get _selectedIndex {
    final index = widget.items.indexWhere((i) => i.id == widget.selectedId);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _fromIndex = _toIndex = _selectedIndex;
    _indicator.value = 1;
  }

  @override
  void didUpdateWidget(CoreTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _selectedIndex;
    if (next != _toIndex) {
      _fromIndex = _toIndex;
      _toIndex = next;
      if (context.reduceMotion) {
        _indicator.value = 1;
      } else {
        _indicator.forward(from: 0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  @override
  void dispose() {
    _indicator.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Centres the selected tab, clamped so the first and last tabs sit flush
  /// against the edges rather than floating mid-viewport.
  void _revealSelected() {
    final layout = _layout;
    if (layout == null || layout.mode != CoreTabsMode.scrollable) return;
    if (!_scroll.hasClients) return;

    final index = _toIndex.clamp(0, layout.widths.length - 1);
    final target =
        layout.origins[index] + layout.widths[index] / 2 - layout.viewport / 2;
    final clamped = target.clamp(0.0, _scroll.position.maxScrollExtent);

    if (context.reduceMotion) {
      _scroll.jumpTo(clamped);
      return;
    }
    unawaited(
      _scroll.animateTo(
        clamped,
        duration: Motion.indicatorTravelCap,
        curve: Motion.emphasize,
      ),
    );
  }

  /// Settles to the nearest tab boundary when the row comes to rest with a tab
  /// clipped at the leading edge.
  void _snapToNearest() {
    final layout = _layout;
    if (layout == null || _snapping || !_scroll.hasClients) return;
    final offset = _scroll.offset;
    final max = _scroll.position.maxScrollExtent;
    if (offset <= 0 || offset >= max) return;

    for (var i = 0; i < layout.origins.length; i++) {
      final origin = layout.origins[i];
      final delta = (offset - origin).abs();
      if (delta > 0.5 && delta <= layout.widths[i] * CoreTabs.snapTolerance) {
        _snapping = true;
        unawaited(
          _scroll
              .animateTo(
                origin.clamp(0.0, max),
                duration: Motion.fast,
                curve: Motion.standard,
              )
              .whenComplete(() => _snapping = false),
        );
        return;
      }
    }
  }

  Future<void> _openIndexJump() async {
    // Fire-and-forget: opening the sheet must not wait on the haptic channel.
    unawaited(HapticFeedback.selectionClick());
    final picked = await showCoreSheet<String>(
      context: context,
      title: 'Jump to',
      builder: (sheetContext) => CoreSegmentedGrid<String>(
        items: [
          for (final item in widget.items)
            CoreSegmentedItem(value: item.id, label: item.label),
        ],
        selected: {widget.selectedId},
        onChanged: (value) => Navigator.of(sheetContext).pop(value),
      ),
    );
    if (picked != null) widget.onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final density = widget.density;
    if (widget.items.isEmpty) return SizedBox(height: density.height);

    final selectedStyle = CoreText.styleOf(
      context,
      CoreTextStyle.label,
      weight: FontWeight.w600,
    );
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _measure(
          available: constraints.maxWidth,
          density: density,
          style: selectedStyle,
          textScaler: textScaler,
        );
        _layout = layout;

        final row = _TabRow(
          items: widget.items,
          layout: layout,
          density: density,
          selectedIndex: _selectedIndex,
          fromIndex: _fromIndex,
          toIndex: _toIndex,
          indicator: _indicator,
          onSelected: widget.onSelected,
        );

        if (layout.mode == CoreTabsMode.fitted) {
          return SizedBox(height: density.height, child: row);
        }

        return SizedBox(
          height: density.height,
          child: Row(
            children: [
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollEndNotification) {
                      _snapToNearest();
                    }
                    // Rebuild so the edge fades track the new extents.
                    if (notification is ScrollUpdateNotification) {
                      setState(() {});
                    }
                    return false;
                  },
                  child: _EdgeFades(
                    controller: _scroll,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(width: layout.contentWidth, child: row),
                    ),
                  ),
                ),
              ),
              if (widget.showIndexJump)
                _IndexJumpButton(onPressed: _openIndexJump),
            ],
          ),
        );
      },
    );
  }

  _TabLayout _measure({
    required double available,
    required CoreTabsDensity density,
    required TextStyle style,
    required TextScaler textScaler,
  }) {
    // Every label is measured at the *selected* weight, so the row never
    // reflows when the selection moves between a 400 and a 600 label.
    final naturalWidths = <double>[];
    final labelWidths = <double>[];
    final useShort = widget.items.length > CoreTabs.shortLabelThreshold;

    for (final item in widget.items) {
      final text = useShort ? (item.shortLabel ?? item.label) : item.label;
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final labelWidth = painter.width + (item.badge != null ? 26 : 0);
      painter.dispose();
      labelWidths.add(labelWidth);
      naturalWidths.add(
        math.max(labelWidth + 2 * density.horizontalPad, density.minTabWidth),
      );
    }

    final naturalTotal = naturalWidths.fold<double>(0, (a, b) => a + b);

    if (naturalTotal <= available) {
      // Fitted: share the viewport evenly. Every tab is at least its natural
      // width because the natural total already fits.
      final each = available / widget.items.length;
      return _TabLayout(
        mode: CoreTabsMode.fitted,
        widths: List.filled(widget.items.length, each),
        labelWidths: labelWidths,
        origins: [for (var i = 0; i < widget.items.length; i++) i * each],
        contentWidth: available,
        viewport: available,
        usesShortLabels: false,
      );
    }

    // Scrollable: tabs keep their natural measured width. Compressing them to
    // fit is what produces cramped, overlapping rows, so it is never done.
    final viewport = widget.showIndexJump
        ? math.max(0.0, available - CoreTabs.indexJumpWidth)
        : available;
    final origins = <double>[];
    var cursor = 0.0;
    for (final width in naturalWidths) {
      origins.add(cursor);
      cursor += width;
    }

    return _TabLayout(
      mode: CoreTabsMode.scrollable,
      widths: naturalWidths,
      labelWidths: labelWidths,
      origins: origins,
      contentWidth: cursor,
      viewport: viewport,
      usesShortLabels: useShort,
    );
  }
}

@immutable
class _TabLayout {
  const _TabLayout({
    required this.mode,
    required this.widths,
    required this.labelWidths,
    required this.origins,
    required this.contentWidth,
    required this.viewport,
    required this.usesShortLabels,
  });

  final CoreTabsMode mode;
  final List<double> widths;
  final List<double> labelWidths;
  final List<double> origins;
  final double contentWidth;
  final double viewport;
  final bool usesShortLabels;
}

class _TabRow extends StatelessWidget {
  const _TabRow({
    required this.items,
    required this.layout,
    required this.density,
    required this.selectedIndex,
    required this.fromIndex,
    required this.toIndex,
    required this.indicator,
    required this.onSelected,
  });

  final List<CoreTabItem> items;
  final _TabLayout layout;
  final CoreTabsDensity density;
  final int selectedIndex;
  final int fromIndex;
  final int toIndex;
  final Animation<double> indicator;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var i = 0; i < items.length; i++)
          Positioned(
            left: layout.origins[i],
            width: layout.widths[i],
            top: 0,
            bottom: 0,
            child: _Tab(
              item: items[i],
              selected: i == selectedIndex,
              short: layout.usesShortLabels,
              onPressed: () => onSelected(items[i].id),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: CoreTabs.indicatorHeight,
          child: AnimatedBuilder(
            animation: indicator,
            builder: (context, _) => CustomPaint(
              painter: _IndicatorPainter(
                t: Motion.emphasize.transform(indicator.value.clamp(0, 1)),
                rawT: indicator.value.clamp(0, 1),
                fromCenter: _centerOf(fromIndex),
                toCenter: _centerOf(toIndex),
                fromWidth: _labelWidthOf(fromIndex),
                toWidth: _labelWidthOf(toIndex),
                gradient: context.colors.accentGradientBright,
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _centerOf(int index) {
    final i = index.clamp(0, layout.origins.length - 1);
    return layout.origins[i] + layout.widths[i] / 2;
  }

  double _labelWidthOf(int index) {
    final i = index.clamp(0, layout.labelWidths.length - 1);
    // Never wider than the tab it belongs to.
    return math.min(layout.labelWidths[i], layout.widths[i]);
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.selected,
    required this.short,
    required this.onPressed,
  });

  final CoreTabItem item;
  final bool selected;
  final bool short;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = short ? (item.shortLabel ?? item.label) : item.label;

    return CorePressable(
      onPressed: onPressed,
      dim: 0,
      pressedScale: 0.94,
      semanticLabel: item.label,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Colours crossfade rather than snapping, but the weight is
              // fixed at 600 for measurement so the row never reflows.
              AnimatedDefaultTextStyle(
                duration: context.motion(Motion.fast),
                style: CoreText.styleOf(
                  context,
                  CoreTextStyle.label,
                  weight: FontWeight.w600,
                  color: selected ? colors.textPrimary : colors.textSecondary,
                ),
                child: Text(text, maxLines: 1, softWrap: false),
              ),
              if (item.badge != null) ...[
                const SizedBox(width: Sp.xs),
                _MiniBadge(text: item.badge!),
              ],
            ],
          ),
          if (item.marked)
            Positioned(
              top: Sp.xs,
              child: Container(
                width: CoreTabs.markerDotSize,
                height: CoreTabs.markerDotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accentStrong,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.xs, vertical: 1),
      decoration: BoxDecoration(
        color: colors.selection,
        border: Border.all(color: colors.border),
      ),
      child: CoreText.caption(text, color: colors.textPrimary),
    );
  }
}

/// Paints the indicator bar, stretching it at the midpoint of a move so travel
/// reads as one elastic object rather than a bar teleporting between labels.
class _IndicatorPainter extends CustomPainter {
  const _IndicatorPainter({
    required this.t,
    required this.rawT,
    required this.fromCenter,
    required this.toCenter,
    required this.fromWidth,
    required this.toWidth,
    required this.gradient,
  });

  final double t;
  final double rawT;
  final double fromCenter;
  final double toCenter;
  final double fromWidth;
  final double toWidth;
  final Gradient gradient;

  static const double stretchFactor = 0.18;

  @override
  void paint(Canvas canvas, Size size) {
    final center = fromCenter + (toCenter - fromCenter) * t;
    final base = fromWidth + (toWidth - fromWidth) * t;
    // Peaks at the midpoint of the travel and returns to 1 at both ends.
    final stretch = 1 + stretchFactor * math.sin(math.pi * rawT);
    final width = math.max(base, math.max(fromWidth, toWidth) * stretch);

    final rect = Rect.fromLTWH(center - width / 2, 0, width, size.height);
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(_IndicatorPainter old) =>
      old.t != t ||
      old.fromCenter != fromCenter ||
      old.toCenter != toCenter ||
      old.fromWidth != fromWidth ||
      old.toWidth != toWidth;
}

/// Gradient masks over whichever edges have content beyond them. Without this
/// there is no reliable signal that the row scrolls at all.
class _EdgeFades extends StatelessWidget {
  const _EdgeFades({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasClients = controller.hasClients;
    final offset = hasClients ? controller.offset : 0.0;
    final max = hasClients ? controller.position.maxScrollExtent : 0.0;
    final showLeading = offset > 1;
    final showTrailing = max - offset > 1;
    final surface = context.colors.surface0;

    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: _Fade(visible: showLeading, colour: surface, leading: true),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: _Fade(visible: showTrailing, colour: surface, leading: false),
        ),
      ],
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({
    required this.visible,
    required this.colour,
    required this.leading,
  });

  final bool visible;
  final Color colour;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: context.motion(Motion.fast),
        opacity: visible ? 1 : 0,
        child: Container(
          width: Layout.edgeFadeWidth,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: leading ? Alignment.centerLeft : Alignment.centerRight,
              end: leading ? Alignment.centerRight : Alignment.centerLeft,
              colors: [colour, colour.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

class _IndexJumpButton extends StatelessWidget {
  const _IndexJumpButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CorePressable(
      onPressed: onPressed,
      semanticLabel: 'Jump to a tab',
      child: Container(
        width: CoreTabs.indexJumpWidth,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.border)),
        ),
        child: Icon(
          Icons.expand_more_rounded,
          size: 20,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}
