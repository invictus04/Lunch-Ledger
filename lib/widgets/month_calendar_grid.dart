import 'package:flutter/material.dart';

import '../models/tiffin_log.dart';
import '../theme/app_theme.dart';
import 'tiffin_style_helper.dart';

/// Read-only monthly calendar grid showing logged meal indicators by day.
class MonthCalendarGrid extends StatelessWidget {
  const MonthCalendarGrid({
    super.key,
    required this.month,
    required this.logsByDay,
    required this.selectedDay,
    required this.today,
    required this.onSelectDay,
  });

  final DateTime month;
  final Map<int, TiffinLog> logsByDay;
  final int? selectedDay;
  final DateTime today;
  final ValueChanged<int> onSelectDay;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final firstWeekdayOffset = DateTime(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = ((firstWeekdayOffset + daysInMonth + 6) ~/ 7) * 7;
    final isCurrentMonth =
        month.year == today.year && month.month == today.month;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: _weekdays
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mutedInk,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalCells,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final day = index - firstWeekdayOffset + 1;
                if (day < 1 || day > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final log = logsByDay[day];
                final style = log != null ? TiffinVisualStyle.of(log.type) : null;
                final isSelected = selectedDay == day;
                final isToday = isCurrentMonth && day == today.day;

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSelectDay(day),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primarySoft
                          : (style?.softBg ?? Colors.transparent),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : (isToday
                                  ? AppTheme.ink.withValues(alpha: 0.45)
                                  : Colors.transparent),
                        width: isSelected ? 1.6 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday || isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: style?.color ?? AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: style?.color ?? Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

