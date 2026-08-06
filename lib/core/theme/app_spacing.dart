import 'package:flutter/widgets.dart';

/// Spacing scale. Named `Sp` deliberately — it is used on almost every line of
/// layout code and a longer name would drown the widget trees.
abstract final class Sp {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
}

/// Radii. The design system is deliberately sharp: containers and buttons are
/// square. Only genuinely circular elements use [Rd.pill] or a circle shape.
abstract final class Rd {
  static const BorderRadius none = BorderRadius.zero;
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Layout constants that carry meaning beyond "a number that looked right".
abstract final class Layout {
  /// Minimum touch target, enforced everywhere including at compact density.
  static const double touchTarget = 44;

  /// Width of the gradient bar under a [CoreSectionHeader]-style title.
  static const double sectionUnderlineWidth = 96;
  static const double sectionUnderlineHeight = 4;

  /// Maximum content width so the layout does not sprawl on tablets.
  static const double maxContentWidth = 720;

  /// Fade mask width on the overflowing edges of a scrollable tab row.
  static const double edgeFadeWidth = 24;
}

/// Card density, driven by [Preferences.cardDensity].
enum CardDensity {
  compact,
  regular;

  double get padding => switch (this) {
    CardDensity.compact => Sp.md,
    CardDensity.regular => Sp.lg,
  };

  double get gap => switch (this) {
    CardDensity.compact => Sp.sm,
    CardDensity.regular => Sp.md,
  };
}

/// Tab density, driving [CoreTabs] measurement (see §6.3 of the plan).
enum CoreTabsDensity {
  compact,
  regular,
  large;

  double get horizontalPad => switch (this) {
    CoreTabsDensity.compact => 12,
    CoreTabsDensity.regular => 16,
    CoreTabsDensity.large => 20,
  };

  double get minTabWidth => switch (this) {
    CoreTabsDensity.compact => 56,
    CoreTabsDensity.regular => 72,
    CoreTabsDensity.large => 88,
  };

  /// Never below the touch-target floor, whatever the density says.
  double get height => switch (this) {
    CoreTabsDensity.compact => 44,
    CoreTabsDensity.regular => 48,
    CoreTabsDensity.large => 56,
  };
}
