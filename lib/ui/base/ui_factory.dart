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
                GoogleFonts.castoro(
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

  /// Factory method to construct styled input fields across forms.
  static Widget buildInputField({
    required TextEditingController controller,
    required String hintText,
    String? labelText,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefixIcon,
    Widget? suffixIcon,
    int maxLines = 1,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null) ...[
          Text(
            labelText,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            focusNode: focusNode,
            onChanged: onChanged,
            style: GoogleFonts.castoro(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.castoro(color: Colors.white38, fontSize: 16),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  /// Factory method for building metric stat badges.
  static Widget buildStatBadge({
    required String label,
    required String value,
    Color color = Colors.white,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
              ),
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
