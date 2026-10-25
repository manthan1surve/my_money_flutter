import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Factory class implementing the Factory Pattern for UI widgets.
class UIComponentFactory {
  /// Builds a standardized Section Header widget.
  static Widget buildSectionHeader({
    required String title,
    Widget? action,
    EdgeInsetsGeometry padding = const EdgeInsets.only(bottom: 12.0),
    TextStyle? style,
  }) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: style ??
                GoogleFonts.fraunces(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
          ),
          ?action,
        ],
      ),
    );
  }

  /// Factory method to construct empty state views.
  static Widget buildEmptyState({
    required String message,
    IconData icon = Icons.inbox_outlined,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
