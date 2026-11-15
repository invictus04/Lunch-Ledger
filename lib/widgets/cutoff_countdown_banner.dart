import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/space.dart';
import '../theme/app_theme.dart';

/// Displays the live countdown to the Space's daily order cut-off, or a clear
/// warning banner when cut-off has passed (logging remains allowed).
class CutoffCountdownBanner extends StatelessWidget {
  const CutoffCountdownBanner({
    super.key,
    required this.space,
    required this.now,
  });

  final Space space;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final isPast = space.isPastCutoffAt(now);
    final remaining = space.timeUntilCutoffAt(now);

    final bgColor = isPast ? AppTheme.warningBg : AppTheme.fullSoft;
    final borderColor = isPast ? AppTheme.warningBorder : const Color(0xFFB7E4CB);
    final fgColor = isPast ? AppTheme.warningFg : AppTheme.fullColor;

    final title = isPast
        ? 'Past daily cut-off (${space.cutoffDisplay})'
        : 'Order window open · ${AppConfig.formatDurationCompact(remaining)} left';
    final subtitle = isPast
        ? 'Logging is still allowed, please confirm late changes with your Leader.'
        : 'Daily cut-off at ${space.cutoffDisplay}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPast ? Icons.warning_amber_rounded : Icons.timer_outlined,
            color: fgColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: fgColor.withValues(alpha: 0.9),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

