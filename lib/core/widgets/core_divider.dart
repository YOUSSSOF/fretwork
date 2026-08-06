import 'package:flutter/material.dart';
import 'package:fretwork/core/theme/app_colors.dart';

/// A hairline at the border colour. A plain [Container] rather than Material's
/// [Divider] so it never introduces its own vertical space.
class CoreDivider extends StatelessWidget {
  const CoreDivider({this.indent = 0, this.vertical = false, super.key});

  final double indent;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final colour = context.colors.border;
    if (vertical) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: indent),
        child: Container(width: 1, color: colour),
      );
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: Container(height: 1, color: colour),
    );
  }
}
