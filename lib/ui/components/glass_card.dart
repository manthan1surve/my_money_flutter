import 'package:flutter/material.dart';
import '../base/base_card.dart';

/// Reusable GlassCard component extending the OO base GlassCardWidget.
class GlassCard extends GlassCardWidget {
  const GlassCard({
    super.key,
    required super.child,
    super.borderRadius = 20.0,
    super.padding = const EdgeInsets.all(24.0),
    super.margin = const EdgeInsets.symmetric(vertical: 12.0),
    super.width = double.infinity,
    super.height = double.nan,
    super.onTap,
  });
}
