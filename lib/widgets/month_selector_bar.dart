import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Shared `< Month YYYY >` navigation bar used across History and Money tabs.
class MonthSelectorBar extends StatelessWidget {
  const MonthSelectorBar({
    super.key,
    required this.month,
    required this.today,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final DateTime today;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  bool get canGoNext {
    final currentMonth = DateTime(today.year, today.month);
    return month.isBefore(currentMonth);
  }

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy').format(month);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Previous month',
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
            ),
            IconButton(
              onPressed: canGoNext ? onNext : null,
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Next month',
            ),
          ],
        ),
      ),
    );
  }
}

