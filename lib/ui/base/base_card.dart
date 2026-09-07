import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Abstract base class for UI card containers using Object-Oriented design.
abstract class BaseCardWidget extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const BaseCardWidget({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(24.0),
    this.margin = const EdgeInsets.symmetric(vertical: 12.0),
    this.width = double.infinity,
    this.height = double.nan,
    this.onTap,
  });

  /// Abstract Method: Must be implemented by concrete card subclasses to build internal container decoration.
  Widget buildCardContainer(BuildContext context, Widget cardChild);

  /// Hook: Override box shadow array if custom elevation is needed.
  List<BoxShadow> buildBoxShadow(BuildContext context) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      width: width,
      height: height.isNaN ? null : height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: buildBoxShadow(context),
      ),
      child: DefaultTextStyle.merge(
        style: GoogleFonts.fraunces(),
        child: buildCardContainer(context, child),
      ),
    );

    if (onTap != null) {
      card = GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    if (margin != EdgeInsets.zero) {
      card = Padding(
        padding: margin,
        child: card,
      );
    }
    return card;
  }
}

/// Polymorphic Glassmorphism Card implementation extending BaseCardWidget.
class GlassCardWidget extends BaseCardWidget {
  final double blurSigma;
  final Color? backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final Gradient? gradient;

  const GlassCardWidget({
    super.key,
    required super.child,
    super.borderRadius = 24.0,
    super.padding = const EdgeInsets.all(24.0),
    super.margin = const EdgeInsets.symmetric(vertical: 12.0),
    super.width = double.infinity,
    super.height = double.nan,
    super.onTap,
    this.blurSigma = 24.0,
    this.backgroundColor,
    this.borderColor = Colors.white,
    this.borderWidth = 1.0,
    this.gradient,
  });

  @override
  List<BoxShadow> buildBoxShadow(BuildContext context) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        blurRadius: 30,
        spreadRadius: 0,
        offset: const Offset(0, 10),
      ),
    ];
  }

  @override
  Widget buildCardContainer(BuildContext context, Widget cardChild) {
    final effectiveGradient = gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.06),
          ],
          stops: const [0.0, 1.0],
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor?.withValues(alpha: 0.12),
            gradient: backgroundColor == null ? effectiveGradient : null,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor.withValues(alpha: 0.22),
              width: borderWidth,
            ),
          ),
          child: cardChild,
        ),
      ),
    );
  }
}

/// Polymorphic Solid Card implementation extending BaseCardWidget.
class SolidCardWidget extends BaseCardWidget {
  final Color backgroundColor;
  final Border? border;

  const SolidCardWidget({
    super.key,
    required super.child,
    super.borderRadius = 20.0,
    super.padding = const EdgeInsets.all(24.0),
    super.margin = const EdgeInsets.symmetric(vertical: 12.0),
    super.width = double.infinity,
    super.height = double.nan,
    super.onTap,
    this.backgroundColor = const Color(0xFF121212),
    this.border,
  });

  @override
  Widget buildCardContainer(BuildContext context, Widget cardChild) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: cardChild,
    );
  }
}
