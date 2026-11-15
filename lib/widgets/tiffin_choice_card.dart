import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/space.dart';
import '../models/tiffin_log.dart';
import '../theme/app_theme.dart';
import 'tiffin_style_helper.dart';

/// Hero card on Home allowing the user to log or update today's meal choice.
class TiffinChoiceCard extends StatelessWidget {
  const TiffinChoiceCard({
    super.key,
    required this.space,
    required this.todayLog,
    required this.isSaving,
    required this.onSelect,
  });

  final Space space;
  final TiffinLog? todayLog;
  final bool isSaving;
  final ValueChanged<TiffinType> onSelect;

  @override
  Widget build(BuildContext context) {
    final currentStyle = TiffinVisualStyle.of(todayLog?.type);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Today's Tiffin",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: currentStyle.softBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        currentStyle.icon,
                        size: 15,
                        color: currentStyle.color,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        todayLog == null
                            ? 'Not logged yet'
                            : '${currentStyle.label} · ${AppConfig.formatInr(todayLog!.cost)}',
                        style: TextStyle(
                          color: currentStyle.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              todayLog == null
                  ? 'Tap an option below to log your lunch for today.'
                  : 'Need to switch? Tap a different option to update today’s entry.',
              style: const TextStyle(
                color: AppTheme.mutedInk,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: TiffinType.values.map((type) {
                final selected = todayLog?.type == type;
                final style = TiffinVisualStyle.of(type);
                final price = space.priceForType(type);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: type == TiffinType.skip ? 0 : 8,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isSaving ? null : () => onSelect(type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? style.softBg : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? style.color : AppTheme.cardBorder,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              style.icon,
                              color: selected ? style.color : AppTheme.mutedInk,
                              size: 24,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              style.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: selected ? style.color : AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppConfig.formatInr(price),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? style.color
                                    : AppTheme.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (isSaving) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );
  }
}

