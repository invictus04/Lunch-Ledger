import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/money_summary.dart';
import '../theme/app_theme.dart';

/// Displays week-wise spend and weekday projections inside the selected month.
class WeekBudgetList extends StatelessWidget {
  const WeekBudgetList({
    super.key,
    required this.month,
    required this.weeks,
  });

  final DateTime month;
  final List<WeekBudgetRow> weeks;

  @override
  Widget build(BuildContext context) {
    final monthShort = DateFormat('MMM').format(month);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Week-Wise Budget',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Actual spend logged per week plus remaining Mon–Fri projection.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.mutedInk),
            ),
            const SizedBox(height: 12),
            ...weeks.map((week) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Week ${week.weekNumber} ($monthShort ${week.startDay}–${week.endDay})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${week.fullCount} Full · ${week.halfCount} Half · ${week.skipCount} Skip'
                            '${week.remainingWeekdays > 0 ? ' · ${week.remainingWeekdays} weekdays left' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppConfig.formatInr(week.actualSpend),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppTheme.ink,
                          ),
                        ),
                        if (week.remainingWeekdays > 0)
                          Text(
                            'Est. ${AppConfig.formatInr(week.totalProjectedWeekSpend)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

