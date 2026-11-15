import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/money_summary.dart';
import '../theme/app_theme.dart';

/// Leader-only monthly per-member total breakdown for vendor bill settlement.
class LeaderMemberBreakdownCard extends StatelessWidget {
  const LeaderMemberBreakdownCard({
    super.key,
    required this.rows,
    required this.grandTotal,
  });

  final List<MemberMonthlyTotal> rows;
  final double grandTotal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  size: 20,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Leader Billing Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Leader Only',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Monthly total per member using snapshotted daily prices.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.mutedInk),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Text(
                'No member logs for this month yet.',
                style: TextStyle(color: AppTheme.mutedInk),
              )
            else ...[
              ...rows.map((row) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: AppTheme.primarySoft,
                        child: Text(
                          row.member.user.initials,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.member.user.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.ink,
                              ),
                            ),
                            Text(
                              '${row.fullCount} Full · ${row.halfCount} Half · ${row.skipCount} Skip',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        AppConfig.formatInr(row.totalSpend),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.ink,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Space Vendor Grand Total',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: AppTheme.ink,
                    ),
                  ),
                  Text(
                    AppConfig.formatInr(grandTotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

