import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/space.dart';
import '../theme/app_theme.dart';

/// Displays the live countdown to the Space's daily order cut-off, with clear
/// locked status for regular members and override status for Space Leaders.
class CutoffCountdownBanner extends StatelessWidget {
  const CutoffCountdownBanner({
    super.key,
    required this.space,
    required this.now,
    this.isLeader = false,
  });

  final Space space;
  final DateTime now;
  final bool isLeader;

  @override
  Widget build(BuildContext context) {
    final isPast = space.isPastCutoffAt(now);
    final remaining = space.timeUntilCutoffAt(now);

    final bgColor = isPast
        ? (isLeader ? AppTheme.pendingSoft : const Color(0xFFFEF2F2))
        : AppTheme.fullSoft;
    final borderColor = isPast
        ? (isLeader ? AppTheme.warningBorder : const Color(0xFFFECACA))
        : const Color(0xFFB7E4CB);
    final fgColor = isPast
        ? (isLeader ? AppTheme.warningFg : const Color(0xFF991B1B))
        : AppTheme.fullColor;

    final title = isPast
        ? (isLeader
            ? 'Cut-off passed · Leader Override active'
            : 'Order cut-off passed (${space.cutoffDisplay})')
        : 'Order window open · ${AppConfig.formatDurationCompact(remaining)} left';

    final subtitle = isPast
        ? (isLeader
            ? 'As Space Leader, you can still log or adjust meals past ${space.cutoffDisplay}.'
            : 'Meals are locked for today. Contact your Space Leader for changes.')
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
            isPast
                ? (isLeader ? Icons.shield_outlined : Icons.lock_clock_rounded)
                : Icons.timer_outlined,
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
                    color: fgColor.withAlpha(220),
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
