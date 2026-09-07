import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Abstract base class for interactive list item tiles implementing Polymorphism & Strategy Pattern.
abstract class BaseListItemWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const BaseListItemWidget({
    super.key,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = const EdgeInsets.symmetric(vertical: 4.0),
  });

  /// Abstract Method: Leading avatar or icon widget.
  Widget buildLeading(BuildContext context);

  /// Abstract Method: Main title widget.
  Widget buildTitle(BuildContext context);

  /// Hook: Optional subtitle widget.
  Widget? buildSubtitle(BuildContext context) => null;

  /// Hook: Optional trailing value or action widget.
  Widget? buildTrailing(BuildContext context) => null;

  /// Hook: Item background decoration.
  BoxDecoration buildDecoration(BuildContext context) {
    return BoxDecoration(
      color: const Color(0xFF18181A).withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = buildSubtitle(context);
    final trailing = buildTrailing(context);

    Widget content = Container(
      padding: padding,
      margin: margin,
      decoration: buildDecoration(context),
      child: DefaultTextStyle.merge(
        style: GoogleFonts.fraunces(),
        child: Row(
          children: [
            buildLeading(context),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildTitle(context),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    subtitle,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing,
            ],
          ],
        ),
      ),
    );

    if (onTap != null || onLongPress != null) {
      content = GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: content,
      );
    }

    return content;
  }
}
