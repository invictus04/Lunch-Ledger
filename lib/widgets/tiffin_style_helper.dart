import 'package:flutter/material.dart';

import '../models/tiffin_log.dart';
import '../theme/app_theme.dart';

/// Visual styling tokens for each [TiffinType] (and unlogged pending state).
class TiffinVisualStyle {
  const TiffinVisualStyle({
    required this.label,
    required this.color,
    required this.softBg,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color softBg;
  final IconData icon;

  static TiffinVisualStyle of(TiffinType? type) {
    switch (type) {
      case TiffinType.full:
        return const TiffinVisualStyle(
          label: 'Full',
          color: AppTheme.fullColor,
          softBg: AppTheme.fullSoft,
          icon: Icons.rice_bowl_rounded,
        );
      case TiffinType.half:
        return const TiffinVisualStyle(
          label: 'Half',
          color: AppTheme.halfColor,
          softBg: AppTheme.halfSoft,
          icon: Icons.lunch_dining_rounded,
        );
      case TiffinType.skip:
        return const TiffinVisualStyle(
          label: 'Skip',
          color: AppTheme.skipColor,
          softBg: AppTheme.skipSoft,
          icon: Icons.do_not_disturb_on_outlined,
        );
      case null:
        return const TiffinVisualStyle(
          label: 'Pending',
          color: AppTheme.pendingColor,
          softBg: AppTheme.pendingSoft,
          icon: Icons.schedule_rounded,
        );
    }
  }
}

