import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Abstract base class for popups and dialogs using the Template Method Pattern.
abstract class BaseModalDialog extends StatelessWidget {
  final String title;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isCentered;
  final bool scrollableContent;
  final double blurSigma;

  const BaseModalDialog({
    super.key,
    required this.title,
    this.borderRadius = 28.0,
    this.padding = const EdgeInsets.all(24.0),
    this.isCentered = true,
    this.scrollableContent = true,
    this.blurSigma = 12.0,
  });

  /// Abstract Method: Subclasses implement this to render specific modal content.
  Widget buildDialogContent(BuildContext context);

  /// Template Method: Optional action buttons displayed at the footer of the modal.
  List<Widget>? buildDialogActions(BuildContext context) => null;

  /// Hook: Optional icon displayed next to the dialog title.
  Widget? buildTitleIcon(BuildContext context) => null;

  /// Template Method: Standardized dialog header row.
  Widget buildDialogHeader(BuildContext context) {
    final titleIcon = buildTitleIcon(context);
    if (isCentered) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (titleIcon != null) ...[
            titleIcon,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (titleIcon != null) ...[
          titleIcon,
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.fraunces(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = buildDialogActions(context);

    Widget dialogBody = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1214).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          buildDialogHeader(context),
          Builder(
            builder: (context) {
              final content = buildDialogContent(context);
              if (content is SizedBox && (content.width == 0 || content.width == null) && (content.height == 0 || content.height == null)) {
                return const SizedBox.shrink();
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  RepaintBoundary(
                    child: scrollableContent
                        ? SingleChildScrollView(child: content)
                        : content,
                  ),
                ],
              );
            },
          ),
          if (actions != null && actions.isNotEmpty) ...[
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: isCentered ? MainAxisAlignment.center : MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ],
      ),
    );

    if (blurSigma > 0) {
      dialogBody = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: dialogBody,
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: dialogBody,
        ),
      ),
    );
  }
}

/// A concrete implementation of BaseModalDialog for quick usage.
class GlassModalDialog extends BaseModalDialog {
  final Widget content;
  final List<Widget>? actions;
  final Widget? titleIcon;

  const GlassModalDialog({
    super.key,
    required super.title,
    required this.content,
    this.actions,
    this.titleIcon,
    super.isCentered = false,
    super.borderRadius = 28.0,
    super.padding = const EdgeInsets.all(24.0),
    super.scrollableContent = true,
    super.blurSigma = 12.0,
  });

  @override
  Widget buildDialogContent(BuildContext context) => content;

  @override
  List<Widget>? buildDialogActions(BuildContext context) => actions;

  @override
  Widget? buildTitleIcon(BuildContext context) => titleIcon;
}

/// Displays a modal dialog with a silky smooth scale and fade transition.
Future<T?> showSmoothModalDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Duration duration = const Duration(milliseconds: 240),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.93, end: 1.0).animate(curve),
          child: child,
        ),
      );
    },
  );
}
